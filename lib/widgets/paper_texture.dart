import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 宣纸纹理：只生成一次（首次进入时），之后作为图片缓存，
/// 每帧只是廉价地贴图，避免动画/滚动时反复重绘。
ui.Image? _cachedPaperImage;

Future<void> _ensurePaperImage() async {
  if (_cachedPaperImage != null) return;
  const w = 1080;
  const h = 1920;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _paintTexture(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  _cachedPaperImage = await picture.toImage(w, h);
}

/// 实际绘制宣纸纹理（仅在生成缓存时执行一次）。
void _paintTexture(Canvas canvas, Size size) {
  final random = Random(20260803);

  // Warm vertical gradient across the sheet.
  final gradient = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0xFFF7F4ED), Colors.white, 0.18)!,
        const Color(0xFFF7F4ED),
        Color.lerp(const Color(0xFFF7F4ED), const Color(0xFFE8DFC8), 0.55)!,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Offset.zero & size, gradient);

  // Mottled blotches.
  final blotch = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, 28);
  for (var i = 0; i < 42; i++) {
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final r = 30 + random.nextDouble() * 110;
    blotch.color = (random.nextBool()
            ? const Color(0xFF3E3527)
            : Colors.white)
        .withValues(alpha: 0.020);
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
    fiber.color = (random.nextBool()
            ? const Color(0xFF3E3527)
            : Colors.white)
        .withValues(alpha: 0.035);
    canvas.drawLine(
        Offset(x, y), Offset(x + cos(angle) * len, y + sin(angle) * len), fiber);
  }

  // Tiny speckles.
  final speck = Paint();
  for (var i = 0; i < 900; i++) {
    final x = random.nextDouble() * size.width;
    final y = random.nextDouble() * size.height;
    final r = 0.4 + random.nextDouble() * 1.1;
    speck.color = (random.nextBool()
            ? const Color(0xFF3E3527)
            : Colors.white)
        .withValues(alpha: 0.05);
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
        const Color(0xFF3E3527).withValues(alpha: 0.10),
      ],
      stops: const [0.0, 0.72, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Offset.zero & size, vignette);
}

class _CachedPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final image = _cachedPaperImage;
    if (image == null) {
      // 兜底：生成完成前先用纯纸色
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFFF7F4ED));
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 全屏宣纸背景（纹理缓存后仅贴图，动画期间不重绘）。
class RicePaperBackground extends StatefulWidget {
  const RicePaperBackground({super.key});

  @override
  State<RicePaperBackground> createState() => _RicePaperBackgroundState();
}

class _RicePaperBackgroundState extends State<RicePaperBackground> {
  @override
  void initState() {
    super.initState();
    // 异步生成一次纹理缓存，完成后触发重绘
    _ensurePaperImage().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CachedPaperPainter(),
        size: Size.infinite,
      ),
    );
  }
}
