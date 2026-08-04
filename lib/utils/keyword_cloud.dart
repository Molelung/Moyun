import 'package:daily_you/models/entry.dart';
import 'package:flutter/material.dart';

/// Extracts frequent keywords from journal entries.
///
/// Latin words are matched whole (lowercased, common stop words removed).
/// Chinese text is segmented into character bigrams, which approximates
/// word boundaries without a full segmentation dictionary.
Map<String, int> extractKeywords(
  Iterable<Entry> entries, {
  int limit = 40,
}) {
  final counts = <String, int>{};

  void add(String word, int weight) {
    counts.update(word, (value) => value + weight, ifAbsent: () => weight);
  }

  for (final entry in entries) {
    final text = entry.text;

    // Latin words.
    for (final match in RegExp(r'[A-Za-z]+').allMatches(text)) {
      final word = match.group(0)!.toLowerCase();
      if (word.length < 2 || _englishStopWords.contains(word)) continue;
      add(word, 1);
    }

    // Chinese character bigrams. A bigram is kept when both characters are
    // CJK and neither is a common function character.
    final cjkRuns = RegExp(r'[\u3400-\u9FFF\uF900-\uFAFF]+')
        .allMatches(text)
        .toList();
    for (final run in cjkRuns) {
      final chars = run.group(0)!.characters;
      for (var i = 0; i + 1 < chars.length; i++) {
        final first = chars.elementAt(i);
        final second = chars.elementAt(i + 1);
        if (_chineseStopChars.contains(first) ||
            _chineseStopChars.contains(second)) {
          continue;
        }
        add('$first$second', 1);
      }
    }
  }

  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {
    for (final entry in sorted.take(limit)) entry.key: entry.value,
  };
}

const _englishStopWords = {
  'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'any', 'can',
  'her', 'was', 'one', 'our', 'out', 'day', 'got', 'get', 'did', 'now',
  'see', 'she', 'who', 'why', 'yes', 'his', 'its', 'has', 'had', 'him',
  'this', 'that', 'with', 'from', 'have', 'they', 'them', 'into',
  'what', 'when', 'where', 'which', 'will', 'your', 'about', 'after',
  'been', 'before', 'being', 'more', 'most', 'some', 'such', 'than',
  'there', 'these', 'those', 'through', 'very', 'were', 'would', 'make',
  'made', 'like', 'just', 'because', 'could', 'should', 'also', 'over',
  'back', 'even', 'still', 'really', 'today', 'time', 'things',
};

const _chineseStopChars = '的了是我在有和就不人都一这那也个上为很到说要去会好么你他她它小大中学出过年月日天新旧美还好';
