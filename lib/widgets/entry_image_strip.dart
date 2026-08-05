import 'dart:typed_data';

import 'package:daily_you/models/image.dart';
import 'package:daily_you/widgets/local_image_cache.dart';
import 'package:daily_you/widgets/local_image_loader.dart';
import 'package:flutter/material.dart';

/// 自适应图片摆放：
/// - 1 张：按原比例居中的大图（不超过 [maxHeight] 与宽度的 62%）；
/// - 2 张：左右并排；
/// - 3 张：左侧大图 + 右侧两小图（2:1 拼图）；
/// - 4 张及以上：2x2 网格，超过 [maxImages] 时在第 4 格叠加「+N」。
class EntryImageStrip extends StatelessWidget {
  final List<EntryImage> images;
  final int maxImages;
  final double gap;
  final double radius;

  const EntryImageStrip({
    super.key,
    required this.images,
    this.maxImages = 4,
    this.gap = 6,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final visible = images.take(maxImages).toList();
    final overflow = images.length - visible.length;
    if (visible.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (visible.length == 1) {
          return _SingleImage(
              path: visible.first.imgPath,
              maxW: constraints.maxWidth,
              radius: radius);
        }
        return _ImageGridLayout(
          count: visible.length,
          overflow: overflow,
          gap: gap,
          radius: radius,
          cellBuilder: (index, w, h) => LocalImageLoader(
              imagePath: visible[index].imgPath),
        );
      },
    );
  }
}

/// 内存图片（如分享卡片导出）版本的自适应摆放，逻辑与 [EntryImageStrip] 一致。
class EntryImageBytesGrid extends StatelessWidget {
  final List<Uint8List> images;
  final int maxImages;
  final double gap;
  final double radius;

  const EntryImageBytesGrid({
    super.key,
    required this.images,
    this.maxImages = 4,
    this.gap = 6,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final visible = images.take(maxImages).toList();
    final overflow = images.length - visible.length;
    if (visible.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (visible.length == 1) {
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.memory(
                  visible.first,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          );
        }
        return _ImageGridLayout(
          count: visible.length,
          overflow: overflow,
          gap: gap,
          radius: radius,
          cellBuilder: (index, w, h) => Image.memory(
            visible[index],
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}

/// 通用 2/3/4+ 拼图布局：由 [cellBuilder] 生成原比例填满的缩略图。
class _ImageGridLayout extends StatelessWidget {
  final int count;
  final int overflow;
  final double gap;
  final double radius;
  final Widget Function(int index, double width, double height) cellBuilder;

  const _ImageGridLayout({
    required this.count,
    required this.overflow,
    required this.gap,
    required this.radius,
    required this.cellBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (count == 2) {
          final w = (maxW - gap) / 2;
          return SizedBox(
            height: 150,
            child: Row(
              children: [
                _wrapped(0, w, 150),
                SizedBox(width: gap),
                _wrapped(1, w, 150),
              ],
            ),
          );
        }
        if (count == 3) {
          final leftW = (maxW - gap) * 0.62;
          final rightW = maxW - leftW - gap;
          final cellH = (172 - gap) / 2;
          return SizedBox(
            height: 172,
            child: Row(
              children: [
                SizedBox(width: leftW, child: _wrapped(0, leftW, 172)),
                SizedBox(width: gap),
                SizedBox(
                  width: rightW,
                  child: Column(
                    children: [
                      _wrapped(1, rightW, cellH),
                      SizedBox(height: gap),
                      _wrapped(2, rightW, cellH),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final cellW = (maxW - gap) / 2;
        final cellH = cellW * 0.72;
        return Column(
          children: [
            Row(
              children: [
                _wrapped(0, cellW, cellH),
                SizedBox(width: gap),
                _wrapped(1, cellW, cellH),
              ],
            ),
            SizedBox(height: gap),
            Row(
              children: [
                _wrapped(2, cellW, cellH),
                SizedBox(width: gap),
                _wrapped(3, cellW, cellH),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _wrapped(int index, double w, double h) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            cellBuilder(index, w, h),
            if (overflow > 0 && index == count - 1)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 单图：按原比例等比缩放，居中放置，最高 [maxHeight]。
class _SingleImage extends StatelessWidget {
  final String path;
  final double maxW;
  final double radius;

  const _SingleImage({required this.path, required this.maxW, required this.radius});

  @override
  Widget build(BuildContext context) {
    const maxH = 220.0;
    final maxBoxW = maxW * 0.62;
    return FutureBuilder<double?>(
      future: LocalImageCache.instance.getImageAspectRatio(path),
      builder: (context, snapshot) {
        final ratio = snapshot.data ?? (4 / 3);
        var w = maxH * ratio;
        var h = maxH;
        if (w > maxBoxW) {
          w = maxBoxW;
          h = maxBoxW / ratio;
        }
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: w,
              height: h,
              child: LocalImageLoader(imagePath: path),
            ),
          ),
        );
      },
    );
  }
}
