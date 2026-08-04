import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/widgets/entry_share_card.dart';

/// 把日记渲染成图片并调用系统分享面板（微信/QQ/WhatsApp 等由系统列出）。
Future<void> shareEntryAsImage(
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

  // 屏幕外渲染分享卡片，再截图成 PNG（2x 已足够清晰，3x 徒增内存与耗时）
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
    if (byteData == null) return;

    final tempDir = await getTemporaryDirectory();
    final file =
        File('${tempDir.path}/moyun_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      fileNameOverrides: ['墨云日记.png'],
    ));
  } finally {
    overlayEntry.remove();
  }
}

/// 底部弹出分享菜单（长按卡片或编辑页分享键共用），磨砂玻璃样式。
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
