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

/// 分享用的日记卡片：布局与首页玻璃卡片一致（原模原样），
/// 正文全文展示（高度自适应，不截断），背景为固定浅色宣纸（图片不可透明）。
///
/// 注意：不指定自定义字体，沿用全局主题字体栈（与 app 内渲染完全一致），
/// 避免 fallback 到手写体出现意外下划线。
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
    const ink = Color(0xFF2C2A29);
    const inkSoft = Color(0xFF7A7266);
    final theme = Theme.of(context);
    final showTitle = entry.title != null && entry.title!.isNotEmpty;

    return Container(
      width: width,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        // 浅色宣纸底（与 app 亮色主题一致）
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F4ED), Color(0xFFEDE5D2)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: ink.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _dateString(entry.timeCreate),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: inkSoft,
            ),
          ),
          if (showTitle) ...[
            const SizedBox(height: 14),
            Text(
              entry.title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 正文：全文展示，不限制高度（分享图为长图）
          Text(
            entry.text.trim(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: ink,
              height: 1.8,
            ),
          ),
          if (imageBytes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final bytes in imageBytes.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        bytes,
                        width: 90,
                        height: 110,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
