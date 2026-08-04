import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 宣纸纹理：只生成一次（首次进入时），之后作为图片缓存，
/// 每帧只是廉价地贴图，避免动画/滚动时反复重绘。
/// 亮色与深色各一张，跟随主题切换。
ui.Image? _cachedPaperImage;
ui.Image? _cachedDarkPaperImage;
bool _darkImageLoading = false;

Future<ui.Image> _ensurePaperImage({required bool dark}) async {
  final cache = dark ? _cachedDarkPaperImage : _cachedPaperImage;
  if (cache != null) return cache;
  // 防重入：build 可能多次触发深色纹理生成，等待在途任务完成
  if (dark && _darkImageLoading) {
    while (_darkImageLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    return _cachedDarkPaperImage!;
  }
  if (dark) _darkImageLoading = true;
  try {
    const w = 1080;
    const h = 1920;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _paintTexture(canvas, Size(w.toDouble(), h.toDouble()), dark: dark);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    if (dark) {
      _cachedDarkPaperImage = image;
    } else {
      _cachedPaperImage = image;
    }
    return image;
  } finally {
    if (dark) _darkImageLoading = false;
  }
}

/// 实际绘制宣纸纹理（仅在生成缓存时执行一次）。
void _paintTexture(Canvas canvas, Size size, {required bool dark}) {
  final random = Random(20260803);

  // 底色：亮色为暖白宣纸，深色为墨色纸张
  final base = dark ? const Color(0xFF211D19) : const Color(0xFFF7F4ED);
  final baseEnd = dark ? const Color(0xFF2A251F) : const Color(0xFFE8DFC8);
  final fiberColor = dark ? const Color(0xFFD8C9A8) : const Color(0xFF3E3527);

  final gradient = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(base, dark ? Colors.black : Colors.white, 0.18)!,
        base,
        Color.lerp(base, baseEnd, 0.55)!,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Offset.zero & size, gradient);

  // Mottled blotches.
  final blotch = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, 28);
  for (var i = 0; i < 42; i++) {
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final r = 30 + random.nextDouble() * 110;
    blotch.color = (random.nextBool() ? fiberColor : Colors.white)
        .withValues(alpha: dark ? 0.030 : 0.020);
    canvas.drawCircle(Offset(x, y), r, blotch);
  }

  // Faint fibers.
  final fiber = Paint()
    ..strokeWidth = 0.7
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 260; i++) {
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final angle = random.nextDouble() * pi * 2;
    final len = 4 + random.nextDouble() * 14;
    fiber.color =
        (random.nextBool() ? fiberColor : Colors.white).withValues(alpha: 0.035);
    canvas.drawLine(
        Offset(x, y), Offset(x + cos(angle) * len, y + sin(angle) * len), fiber);
  }

  // Tiny speckles.
  final speck = Paint();
  for (var i = 0; i < 900; i++) {
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final r = 0.4 + random.nextDouble() * 1.1;
    speck.color = (random.nextBool() ? fiberColor : Colors.white)
        .withValues(alpha: dark ? 0.06 : 0.05);
    canvas.drawCircle(Offset(x, y), r, speck);
  }

  // Vignette.
  final vignette = Paint()
    ..shader = RadialGradient(
      center: Alignment.center,
      radius: 0.75,
      colors: [
        Colors.transparent,
        Colors.transparent,
        (dark ? Colors.black : fiberColor).withValues(alpha: dark ? 0.18 : 0.10),
      ],
      stops: const [0.0, 0.72, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Offset.zero & size, vignette);
}

class _CachedPaperPainter extends CustomPainter {
  _CachedPaperPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final image = dark ? _cachedDarkPaperImage : _cachedPaperImage;
    if (image == null) {
      // 兜底：生成完成前先用纯纸色
      canvas.drawRect(Offset.zero & size,
          Paint()..color = dark ? const Color(0xFF211D19) : const Color(0xFFF7F4ED));
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _CachedPaperPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// 全屏宣纸背景（纹理缓存后仅贴图，动画期间不重绘）。
/// 跟随主题明暗自动切换深浅两套纹理。
class RicePaperBackground extends StatefulWidget {
  const RicePaperBackground({super.key});

  @override
  State<RicePaperBackground> createState() => _RicePaperBackgroundState();
}

class _RicePaperBackgroundState extends State<RicePaperBackground> {
  @override
  void initState() {
    super.initState();
    // 异步生成亮色纹理缓存，完成后触发重绘
    _ensurePaperImage(dark: false).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark && _cachedDarkPaperImage == null) {
      // 首次进入深色模式：异步生成深色纹理
      _ensurePaperImage(dark: true).then((_) {
        if (mounted) setState(() {});
      });
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CachedPaperPainter(dark: dark),
        size: Size.infinite,
      ),
    );
  }
}
