import 'package:flutter/material.dart';

/// 从单篇日记文本中提取关键词。
///
/// 英文按单词切分（小写、去停用词）；中文按双字 bigram 近似分词。
Map<String, int> extractKeywordsFromText(String text) {
  final counts = <String, int>{};
  if (text.trim().isEmpty) return counts;

  void add(String word) {
    counts.update(word, (value) => value + 1, ifAbsent: () => 1);
  }

  // 英文单词
  for (final match in RegExp(r'[A-Za-z]+').allMatches(text)) {
    final word = match.group(0)!.toLowerCase();
    if (word.length < 3 || _englishStopWords.contains(word)) continue;
    add(word);
  }

  // 中文双字 bigram
  final cjkRuns =
      RegExp(r'[\u3400-\u9FFF\uF900-\uFAFF]+').allMatches(text).toList();
  for (final run in cjkRuns) {
    final chars = run.group(0)!.characters;
    for (var i = 0; i + 1 < chars.length; i++) {
      final first = chars.elementAt(i);
      final second = chars.elementAt(i + 1);
      if (_chineseStopChars.contains(first) ||
          _chineseStopChars.contains(second)) {
        continue;
      }
      final bigram = '$first$second';
      add(bigram);
    }
  }

  return counts;
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
  'back', 'even', 'still', 'really', 'today', 'time', 'things', 'every',
  'much', 'many', 'then', 'here',
};

const _chineseStopChars =
    '的了是我在有和就不人都一这那也个上为很到说要去会好么你他她它小大中学出过年月日天新旧美还好又再'
    '与或但而于之其们把被让给向对从到里中上下左右前后内外面子点来去能会可要正再已将却并';
