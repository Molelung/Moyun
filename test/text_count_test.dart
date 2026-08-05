import 'package:daily_you/utils/text_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('textWordCount 中文', () {
    test('纯中文逐字计数', () {
      expect(textWordCount('今天天气很好'), 6);
    });
    test('中文加标点不计标点', () {
      expect(textWordCount('你好，世界！'), 4);
    });
  });

  group('textWordCount 英文', () {
    test('英文按单词计数', () {
      expect(textWordCount('I love you'), 3);
      expect(textWordCount('Hello World'), 2);
    });
    test('标点不粘连英文单词', () {
      expect(textWordCount('hello,world'), 2);
      expect(textWordCount('email@test.com'), 3);
      expect(textWordCount('U.S.A. is great'), 5);
    });
    test('词内撇号与连字符不切断', () {
      expect(textWordCount("don't stop"), 2);
      expect(textWordCount('multi-word text'), 2);
    });
  });

  group('textWordCount 中英混合', () {
    test('混合按 CJK 逐字 + 英文按词', () {
      expect(textWordCount('你好hello世界'), 5);
      expect(textWordCount('3个苹果'), 4);
    });
  });

  group('textWordCount 边界', () {
    test('空串与纯空白为 0', () {
      expect(textWordCount(''), 0);
      expect(textWordCount('   '), 0);
    });
    test('纯标点与孤立连字符为 0', () {
      expect(textWordCount('...'), 0);
      expect(textWordCount('-'), 0);
    });
    test('数字按串计数', () {
      expect(textWordCount('2024 2025'), 2);
    });
  });
}
