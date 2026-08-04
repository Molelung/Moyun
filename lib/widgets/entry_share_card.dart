import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:daily_you/models/entry.dart';

/// 中文小写数字：一、二、三…（用于日期）
String _toChineseNumber(int num, {bool isYear = false}) {
  const digits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  if (isYear) {
    return num.toString().split('').map((e) => digits[int.parse(e)]).join('');
  }
  if (num < 10) return digits[num];
  if (num < 20) return '十${num % 10 == 0 ? '' : digits[num % 10]}';
  if (num < 100) {
    return '${digits[num ~/ 10]}十${num % 10 == 0 ? '' : digits[num % 10]}';
  }
  return num.toString();
}

String _dateString(DateTime date) =>
    "${_toChineseNumber(date.year, isYear: true)}年${_toChineseNumber(date.month)}月${_toChineseNumber(date.day)}日";

/// 分享用的日记卡片：固定浅色宣纸风格（不受应用主题影响），
/// 供 RepaintBoundary 渲染成图片后分享到微信/QQ/WhatsApp 等。
class EntryShareCard extends StatelessWidget {
  final Entry entry;
  final List<Uint8List> imageBytes;
  final double width;

  const EntryShareCard({
    super.key,
    required this.entry,
    required this.imageBytes,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    const bgTop = Color(0xFFFBF8F1);
    const bgBottom = Color(0xFFF0E9D8);
    const ink = Color(0xFF2C2A29);
    const inkSoft = Color(0xFF8A8177);
    const accent = Color(0xFF5A4D41);
    final showTitle = entry.title != null && entry.title!.isNotEmpty;

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _dateString(entry.timeCreate),
              style: const TextStyle(
                color: accent,
                fontSize: 15,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              width: 56,
              height: 2,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          if (showTitle) ...[
            const SizedBox(height: 22),
            Center(
              child: Text(
                entry.title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SotyrFangsong',
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: SingleChildScrollView(
              child: Text(
                entry.text.trim(),
                style: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  height: 1.9,
                  fontFamily: 'SotyrFangsong',
                ),
              ),
            ),
          ),
          if (imageBytes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final bytes in imageBytes.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        bytes,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              '墨云 · Moyun',
              style: TextStyle(
                color: inkSoft.withValues(alpha: 0.8),
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
