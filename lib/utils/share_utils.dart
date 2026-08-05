import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/widgets/entry_share_card.dart';

const MethodChannel _shareChannel = MethodChannel('moyun/share');

/// 常见分享目标的主题色（首字母圆块用）
const Map<String, int> _targetColors = {
  'com.tencent.mm': 0xFF07C160, // 微信
  'com.tencent.mobileqq': 0xFF12B7F5, // QQ
  'com.qzone': 0xFFF2B23C, // QQ空间
  'com.sina.weibo': 0xFFE6162D, // 微博
  'com.whatsapp': 0xFF25D366,
  'org.telegram.messenger': 0xFF229ED9,
  'com.twitter.android': 0xFF14171A,
  'com.facebook.katana': 0xFF1877F2,
  'com.instagram.android': 0xFFE4405F,
  'com.ss.android.ugc.aweme': 0xFF161823,
};

/// 生成日记图片并展示自研分享面板（保存相册 + 已安装的常用应用）。
Future<void> shareEntryAsImage(
  BuildContext context,
  Entry entry,
  List<EntryImage> images,
) async {
  final file = await _renderEntryImage(context, entry, images);
  if (file == null || !context.mounted) return;

  final targets = await _getShareTargets();
  if (!context.mounted) return;

  await _showShareSheet(context, file.path, targets, entry.text);
}

/// 渲染分享卡片为 PNG 临时文件（自研面板与保存相册共用）。
Future<File?> _renderEntryImage(
  BuildContext context,
  Entry entry,
  List<EntryImage> images,
) async {
  final key = GlobalKey();
  final width = MediaQuery.of(context).size.width - 48;
  final overlay = Overlay.of(context, rootOverlay: true);

  // 预加载日记图片字节（最多 4 张，与首页卡片一致）
  final imageBytes = <Uint8List>[];
  for (final image in images.take(4)) {
    try {
      final bytes = await File(
        '${await ImageStorage.instance.getInternalFolder()}/${image.imgPath}',
      ).readAsBytes();
      imageBytes.add(bytes);
    } catch (_) {
      // 图片缺失时跳过，不影响分享
    }
  }

  // 屏幕外渲染分享卡片，再截图成 PNG（2x 已足够清晰）
  final overlayEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: EntryShareCard(
          entry: entry,
          imageBytes: imageBytes,
          width: width,
        ),
      ),
    ),
  );
  overlay.insert(overlayEntry);
  await WidgetsBinding.instance.endOfFrame;

  try {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final file =
        File('${tempDir.path}/moyun_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  } finally {
    overlayEntry.remove();
  }
}

Future<List<Map<dynamic, dynamic>>> _getShareTargets() async {
  try {
    final result =
        await _shareChannel.invokeMethod<List<dynamic>>('getShareTargets');
    return result?.cast<Map<dynamic, dynamic>>() ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<bool> _shareTo(String package, String path) async {
  try {
    return await _shareChannel
            .invokeMethod<bool>('shareTo', {'package': package, 'path': path}) ??
        false;
  } catch (_) {
    return false;
  }
}

Future<bool> _saveToGallery(String path) async {
  try {
    return await _shareChannel.invokeMethod<bool>('saveToGallery', {
      'path': path,
    }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// 自研玻璃分享面板：复制文字 + 保存到相册 + 已安装的常用应用
Future<void> _showShareSheet(
  BuildContext context,
  String path,
  List<Map<dynamic, dynamic>> targets,
  String entryText,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final columns = 4;
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.white.withValues(alpha: 0.75),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        '分享到',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _ShareTargetTile(
                          label: '复制文字',
                          color: const Color(0xFF8A8177),
                          icon: Icons.copy_rounded,
                          onTap: () async {
                            await Clipboard.setData(
                                ClipboardData(text: entryText));
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('日记内容已复制')),
                              );
                            }
                          },
                        ),
                        _ShareTargetTile(
                          label: '保存相册',
                          color: const Color(0xFF5A4D41),
                          icon: Icons.download_rounded,
                          onTap: () async {
                            final ok = await _saveToGallery(path);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? '已保存到系统相册'
                                      : '保存失败，请重试'),
                                ),
                              );
                            }
                          },
                        ),
                        for (final target in targets)
                          _ShareTargetTile(
                            label: target['name'] as String? ?? '',
                            color: Color(_targetColors[
                                    target['package'] as String?] ??
                                0xFF5A4D41),
                            onTap: () async {
                              final ok = await _shareTo(
                                target['package'] as String,
                                path,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('分享失败')),
                                  );
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ShareTargetTile extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _ShareTargetTile({
    required this.label,
    required this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 24)
                : Text(
                    label.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 底部弹出分享菜单（长按卡片或编辑页分享键共用）。
Future<void> showShareMenu(
  BuildContext context,
  Entry entry,
  List<EntryImage> images,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Colors.white.withValues(alpha: 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.image_outlined),
                      title: const Text('分享为图片'),
                      subtitle: const Text('生成日记图片，可发到微信、QQ、WhatsApp 等'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        shareEntryAsImage(context, entry, images);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
