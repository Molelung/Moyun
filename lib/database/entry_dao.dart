import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/models/entry.dart';

class EntryDao {
  static Future<List<Entry>> getAll() async {
    final result = await AppDatabase.instance.database!
        .query(entriesTable, orderBy: '${EntryFields.timeCreate} DESC');

    return result.map((json) => Entry.fromJson(json)).toList();
  }

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

  static Future<List<String>> getAllTexts() async {
    final result = await AppDatabase.instance.database!.query(
      entriesTable,
      columns: [EntryFields.text],
    );
    return result.map((json) => json[EntryFields.text] as String).toList();
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
    final id = await AppDatabase.instance.database!
        .insert(entriesTable, entry.toJson());

    return entry.copy(id: id);
  }

  static Future<void> update(Entry entry) async {
    await AppDatabase.instance.database!.update(
      entriesTable,
      entry.toJson(),
      where: '${EntryFields.id} = ?',
      whereArgs: [entry.id],
    );
  }

  static Future<void> remove(int id) async {
    await AppDatabase.instance.database!.delete(
      entriesTable,
      where: '${EntryFields.id} = ?',
      whereArgs: [id],
    );
  }
}
