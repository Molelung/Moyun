import 'package:flutter/material.dart';

/// Renders keyword frequencies as a word cloud: the more frequent a word,
/// the larger and darker it appears. Layout is deterministic (words are
/// placed in frequency order) so the cloud does not reshuffle on rebuild.
class WordCloud extends StatelessWidget {
  const WordCloud({
    super.key,
    required this.keywords,
    this.maxFontSize = 34,
    this.minFontSize = 14,
  });

  final Map<String, int> keywords;
  final double maxFontSize;
  final double minFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var sortedEntries = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Interleave large and small words to make it look more organic
    final entries = <MapEntry<String, int>>[];
    int left = 0;
    int right = sortedEntries.length - 1;
    while (left <= right) {
      if (left == right) {
        entries.add(sortedEntries[left]);
        break;
      }
      entries.add(sortedEntries[left]);
      entries.add(sortedEntries[right]);
      left++;
      right--;
    }
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '暂无词云',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final maxCount = entries.first.value;
    final minCount = entries.last.value;
    final range = maxCount == minCount ? 1 : (maxCount - minCount);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          Text(
            entry.key,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: minFontSize +
                  (entry.value - minCount) /
                      range *
                      (maxFontSize - minFontSize),
              fontWeight:
                  entry.value == maxCount ? FontWeight.w700 : FontWeight.w400,
              color: Color.lerp(
                theme.colorScheme.onSurfaceVariant,
                theme.colorScheme.onSurface,
                (entry.value - minCount) / range,
              ),
            ),
          ),
      ],
    );
  }
}
