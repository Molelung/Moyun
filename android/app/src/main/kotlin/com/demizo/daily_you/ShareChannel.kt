package com.demizo.daily_you

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 自研分享通道：查询已安装的常用分享目标、按包名直接分享图片、
 * 保存图片到系统相册（绕过系统分享面板）。
 */
class ShareChannel : MethodChannel.MethodCallHandler {
    private var activity: FlutterFragmentActivity? = null

    companion object {
        private const val CHANNEL = "moyun/share"

        private data class Target(val name: String, val packageName: String)

        private val TARGETS = listOf(
            Target("微信", "com.tencent.mm"),
            Target("QQ", "com.tencent.mobileqq"),
            Target("QQ空间", "com.qzone"),
            Target("微博", "com.sina.weibo"),
            Target("WhatsApp", "com.whatsapp"),
            Target("Telegram", "org.telegram.messenger"),
            Target("X", "com.twitter.android"),
            Target("Facebook", "com.facebook.katana"),
            Target("Instagram", "com.instagram.android"),
            Target("抖音", "com.ss.android.ugc.aweme"),
        )
    }

    fun register(activity: FlutterFragmentActivity, engine: FlutterEngine) {
        this.activity = activity
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getShareTargets" -> result.success(getInstalledTargets())
            "shareTo" -> {
                val packageName = call.argument<String>("package")
                val path = call.argument<String>("path")
                if (packageName == null || path == null) {
                    result.error("bad_args", "package and path required", null)
                    return
                }
                result.success(shareTo(packageName, path))
            }
            "saveToGallery" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "path required", null)
                    return
                }
                result.success(saveToGallery(path))
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledTargets(): List<Map<String, String>> {
        val activity = activity ?: return emptyList()
        val pm = activity.packageManager
        return TARGETS.mapNotNull { target ->
            val installed = try {
                pm.getApplicationInfo(target.packageName, 0)
                true
            } catch (_: Exception) {
                false
            }
            if (installed) mapOf("name" to target.name, "package" to target.packageName)
            else null
        }
    }

    private fun shareTo(packageName: String, path: String): Boolean {
        val activity = activity ?: return false
        val file = File(path)
        if (!file.exists()) return false

        val uri: Uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            file,
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            setPackage(packageName)
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun saveToGallery(path: String): Boolean {
        val activity = activity ?: return false
        val file = File(path)
        if (!file.exists()) return false

        val displayName = "Moyun_${System.currentTimeMillis()}.png"
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+：MediaStore 免权限写入
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/Moyun",
                    )
                }
                val resolver = activity.contentResolver
                val uri = resolver.insert(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: return false
                resolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { it.copyTo(out) }
                } ?: return false
                true
            } else {
                // Android 9-：写入公共 Pictures 目录后广播扫描
                val dir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
                    "Moyun",
                )
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, displayName)
                file.copyTo(dest, overwrite = true)
                MediaScannerConnection.scanFile(activity, arrayOf(dest.absolutePath), null, null)
                true
            }
        } catch (_: Exception) {
            false
        }
    }
}
