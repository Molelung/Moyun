/// 「字数」统计工具。
///
/// 口径与常用中文输入法/Word 一致：
/// - 汉字、日文假名、谚文等 CJK 字符：每字记 1；
/// - 连续的字母/数字串（词内允许撇号 `'`、`’` 与连字符 `-`）：每个词记 1；
/// - 其余标点、符号、空白：只作为分隔符，不计入。
///
/// 修正了 word_count 包在英文场景下的问题：标点不再粘连英文单词，
/// 例如 `hello,world` → 2，`email@test.com` → 3，`U.S.A.` → 3；
/// 同时保留词内撇号/连字符，如 `don't` → 1、`multi-word` → 1。
int textWordCount(String text) {
  if (text.isEmpty) return 0;
  int count = 0;
  bool inWord = false;
  for (final rune in text.runes) {
    if (_isCjkRune(rune)) {
      if (inWord) {
        count++;
        inWord = false;
      }
      count++;
    } else if (_isWordCharRune(rune)) {
      inWord = true;
    } else if (_isIntraWordRune(rune)) {
      // 撇号/连字符只在词中才有意义，不改变状态（孤立的 `-` 不计）。
    } else {
      if (inWord) {
        count++;
        inWord = false;
      }
    }
  }
  if (inWord) count++;
  return count;
}

/// CJK 字符（每个记 1 字）：汉字（含扩展区）、假名、谚文。
bool _isCjkRune(int r) {
  if (r >= 0x3400 && r <= 0x9FFF) return true; // CJK + 扩展 A
  if (r >= 0x20000 && r <= 0x2EBEF) return true; // 扩展 B-F
  if (r >= 0x30000 && r <= 0x323AF) return true; // 扩展 G-H
  if (r >= 0xF900 && r <= 0xFAFF) return true; // 兼容汉字
  if (r >= 0x2F800 && r <= 0x2FA1F) return true; // 兼容汉字增补
  if (r >= 0x3040 && r <= 0x30FF) return true; // 假名
  if (r >= 0x31F0 && r <= 0x31FF) return true; // 片假名扩展
  if (r >= 0x1100 && r <= 0x11FF) return true; // 谚文字母
  if (r >= 0x3130 && r <= 0x318F) return true; // 谚文兼容
  if (r >= 0xA960 && r <= 0xA97F) return true; // 谚文扩展 A
  if (r >= 0xAC00 && r <= 0xD7AF) return true; // 谚文音节
  if (r >= 0xD7B0 && r <= 0xD7FF) return true; // 谚文扩展 B
  return false;
}

/// 文字字符（构成英文/数字词）：拉丁、西里尔、希腊、阿拉伯、希伯来、
/// 天城文等印度系文字、泰文等东南亚文字，以及常见补充区。
bool _isWordCharRune(int r) {
  if (r >= 0x30 && r <= 0x39) return true; // 0-9
  if (r >= 0x41 && r <= 0x5A) return true; // A-Z
  if (r >= 0x61 && r <= 0x7A) return true; // a-z
  if (r >= 0x00C0 && r <= 0x02AF) return true; // 拉丁扩展、IPA
  if (r >= 0x1E00 && r <= 0x1EFF) return true; // 拉丁扩展增补
  if (r >= 0x0370 && r <= 0x03FF) return true; // 希腊
  if (r >= 0x0400 && r <= 0x052F) return true; // 西里尔
  if (r >= 0x0530 && r <= 0x058F) return true; // 亚美尼亚
  if (r >= 0x0590 && r <= 0x05FF) return true; // 希伯来
  if (r >= 0x0600 && r <= 0x06FF) return true; // 阿拉伯
  if (r >= 0x0750 && r <= 0x077F) return true; // 阿拉伯增补
  if (r >= 0x08A0 && r <= 0x08FF) return true; // 阿拉伯扩展 A
  if (r >= 0x0900 && r <= 0x109F) return true; // 天城文等印度系、泰文、缅文
  if (r >= 0x10A0 && r <= 0x10FF) return true; // 格鲁吉亚
  if (r >= 0x1200 && r <= 0x137F) return true; // 埃塞俄比亚
  if (r >= 0x13A0 && r <= 0x13FF) return true; // 切罗基
  if (r >= 0x1400 && r <= 0x167F) return true; // 加拿大音节
  if (r >= 0x1680 && r <= 0x169F) return true; // 欧甘
  if (r >= 0x16A0 && r <= 0x16FF) return true; // 如尼文
  if (r >= 0x1700 && r <= 0x177F) return true; // 塔加拉等菲律宾文字
  return false;
}

/// 词内字符：撇号（don't）与连字符（multi-word）不切断单词。
bool _isIntraWordRune(int r) =>
    r == 0x27 || r == 0x2019 || r == 0x2D || r == 0x2010 || r == 0x2011;
