import 'dart:typed_data';
import 'dart:ui';

import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/models/image.dart';
import 'package:flutter/material.dart';

/// 编辑页点按图片后的大图查看器：左右滑动切换图片，双指/双击缩放平移。
class FullScreenImageViewerPage extends StatefulWidget {
  final List<EntryImage> images;
  final int initialIndex;

  const FullScreenImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewerPage> createState() =>
      _FullScreenImageViewerPageState();
}

class _FullScreenImageViewerPageState extends State<FullScreenImageViewerPage> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPage(int index) {
    return FutureBuilder<Uint8List?>(
      future: ImageStorage.instance.getBytes(widget.images[index].imgPath),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Center(
            child: loading
                ? const CircularProgressIndicator(color: Colors.white54)
                : const Icon(Icons.broken_image_rounded,
                    color: Colors.white38, size: 56),
          );
        }
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xE6000000),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => _buildPage(index),
          ),
          // 左上角关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 0.8),
                  ),
                  child: IconButton(
                    iconSize: 22,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          // 右上角计数
          if (widget.images.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 22,
              right: 24,
              child: Text(
                '${_current + 1}/${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
