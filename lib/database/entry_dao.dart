import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/models/entry.dart';
import 'package:sqflite/sqflite.dart';
import 'package:daily_you/utils/keyword_cloud.dart';

class EntryDao {
  static Future<List<Entry>> getPage(int limit, int offset) async {
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      orderBy: '${EntryFields.timeCreate} DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((json) => Entry.fromJson(json)).toList();
  }

  static Future<List<Entry>> search(String query) async {
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      where: '${EntryFields.text} LIKE ? OR ${EntryFields.title} LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: '${EntryFields.timeCreate} DESC',
    );
    return result.map((json) => Entry.fromJson(json)).toList();
  }

  /// 全量文本（统计页惰性计算字数时使用）
  static Future<List<String>> getAllTexts() async {
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      columns: [EntryFields.text],
    );
    return result.map((json) => json[EntryFields.text] as String).toList();
  }

  static Future<int> getCount() async {
    final result = await AppDatabase.instance.database!
        .rawQuery('SELECT COUNT(*) FROM $entriesTable');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<int> getUniqueDaysCount() async {
    final result = await AppDatabase.instance.database!.rawQuery(
        "SELECT COUNT(DISTINCT date(${EntryFields.timeCreate})) FROM $entriesTable");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<Entry?> getRandomEntry() async {
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      orderBy: 'RANDOM()',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Entry.fromJson(result.first);
    }
    return null;
  }

  /// 「那年今日」：返回往年同月同日里最新的一篇（全库查询）
  static Future<Entry?> getOnThisDayEntry(int month, int day) async {
    final now = DateTime.now();
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      where:
          "strftime('%m', ${EntryFields.timeCreate}) = ? AND strftime('%d', ${EntryFields.timeCreate}) = ? AND strftime('%Y', ${EntryFields.timeCreate}) < ?",
      whereArgs: [
        month.toString().padLeft(2, '0'),
        day.toString().padLeft(2, '0'),
        now.year.toString(),
      ],
      orderBy: '${EntryFields.timeCreate} DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Entry.fromJson(result.first);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getIdsAndDates() async {
    return await AppDatabase.instance.database!.query(
      entriesTable,
      columns: [EntryFields.id, EntryFields.timeCreate],
      orderBy: '${EntryFields.timeCreate} DESC',
    );
  }

  static Future<Entry?> get(int id) async {
    final maps = await AppDatabase.instance.database!.query(
      entriesTable,
      columns: EntryFields.values,
      where: '${EntryFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Entry.fromJson(maps.first);
    } else {
      return null;
    }
  }

  static Future<Entry> add(Entry entry) async {
    final db = AppDatabase.instance.database!;
    int id = 0;
    await db.transaction((txn) async {
      id = await txn.insert(entriesTable, entry.toJson());

      // 增量更新词云词频
      final keywords = extractKeywordsFromText(entry.text);
      for (final kv in keywords.entries) {
        await txn.execute(
            'INSERT OR IGNORE INTO keyword_frequencies (word, term_count, doc_count) VALUES (?, 0, 0)',
            [kv.key]);
        await txn.execute(
            'UPDATE keyword_frequencies SET term_count = term_count + ?, doc_count = doc_count + 1 WHERE word = ?',
            [kv.value, kv.key]);
      }
    });
    return entry.copy(id: id);
  }

  static Future<void> update(Entry entry) async {
    final db = AppDatabase.instance.database!;
    await db.transaction((txn) async {
      // 获取旧文本
      final oldRow = await txn.query(entriesTable,
          columns: [EntryFields.text],
          where: '${EntryFields.id} = ?',
          whereArgs: [entry.id]);
      if (oldRow.isNotEmpty) {
        final oldText = oldRow.first[EntryFields.text] as String;
        final oldKeywords = extractKeywordsFromText(oldText);
        for (final kv in oldKeywords.entries) {
          await txn.execute(
              'UPDATE keyword_frequencies SET term_count = MAX(0, term_count - ?), doc_count = MAX(0, doc_count - 1) WHERE word = ?',
              [kv.value, kv.key]);
        }
      }

      await txn.update(
        entriesTable,
        entry.toJson(),
        where: '${EntryFields.id} = ?',
        whereArgs: [entry.id],
      );

      // 增加新文本
      final newKeywords = extractKeywordsFromText(entry.text);
      for (final kv in newKeywords.entries) {
        await txn.execute(
            'INSERT OR IGNORE INTO keyword_frequencies (word, term_count, doc_count) VALUES (?, 0, 0)',
            [kv.key]);
        await txn.execute(
            'UPDATE keyword_frequencies SET term_count = term_count + ?, doc_count = doc_count + 1 WHERE word = ?',
            [kv.value, kv.key]);
      }
    });
  }

  static Future<void> remove(int id) async {
    final db = AppDatabase.instance.database!;
    await db.transaction((txn) async {
      final oldRow = await txn.query(entriesTable,
          columns: [EntryFields.text],
          where: '${EntryFields.id} = ?',
          whereArgs: [id]);
      if (oldRow.isNotEmpty) {
        final oldText = oldRow.first[EntryFields.text] as String;
        final oldKeywords = extractKeywordsFromText(oldText);
        for (final kv in oldKeywords.entries) {
          await txn.execute(
              'UPDATE keyword_frequencies SET term_count = MAX(0, term_count - ?), doc_count = MAX(0, doc_count - 1) WHERE word = ?',
              [kv.value, kv.key]);
        }
      }

      await txn.delete(
        entriesTable,
        where: '${EntryFields.id} = ?',
        whereArgs: [id],
      );
    });
  }

  static Future<Map<String, int>> getTopKeywords(int totalDocCount, {int limit = 40}) async {
    final threshold = (totalDocCount / 2).ceil();
    final result = await AppDatabase.instance.database!.query(
      'keyword_frequencies',
      columns: ['word', 'term_count'],
      where: 'doc_count < ? AND term_count > 0',
      whereArgs: [threshold],
      orderBy: 'term_count DESC',
      limit: limit,
    );
    return {
      for (final row in result)
        row['word'] as String: row['term_count'] as int
    };
  }
}
