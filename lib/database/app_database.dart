import 'dart:io';

import 'package:daily_you/config_provider.dart';
import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/utils/file_layer.dart';
import 'package:daily_you/utils/keyword_cloud.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';

import 'package:daily_you/utils/locale_helper.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:encrypt/encrypt.dart' as enc;
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  AppDatabase._init();

  final Logger _logger = Logger('AppDatabase');

  /// True when a migration from external storage was attempted on the last
  /// [init] but failed.
  bool migrationFailed = false;

  static Database? _database;
  Database? get database => _database;

  String? _internalPath;

  Future<bool> init(
      {bool forceWithoutSync = false, bool allowMigration = true}) async {
    _internalPath = await getInternalPath();
    migrationFailed = false;
    bool success = true;

    if (Platform.isAndroid && allowMigration) {
      final migrated = await _migrateDbFromExternalStorage();
      if (!migrated && !forceWithoutSync) {
        // Migration was attempted but failed
        migrationFailed = true;
        return false;
      }
    }

    // Migration is foreground-only. A background task (allowMigration: false)
    // must never create a fresh database before the user has migrated their
    // data, so bail if there is nothing to open yet.
    if (!allowMigration && !await File(_internalPath!).exists()) {
      return false;
    }

    if (usingExternalLocation() && !forceWithoutSync) {
      if (await hasExternalLocationPermission()) {
        await _syncWithExternalDatabase();
      } else {
        success = false;
      }
    }

    await AppDatabase.instance.open();
    return success;
  }

  /// Returns whether it is safe to open the internal database. False means a
  /// migration was needed but failed, so the caller must not create a fresh
  /// database over the still-intact external copy.
  Future<bool> _migrateDbFromExternalStorage() async {
    if (await File(_internalPath!).exists()) return true;

    final oldDir = await getExternalStorageDirectory();
    if (oldDir == null) return true;
    final oldPath = join(oldDir.path, 'daily_you.db');
    if (!await File(oldPath).exists()) return true;

    _logger.info('Database migration started: $oldPath -> $_internalPath');
    try {
      await File(oldPath).copy(_internalPath!);
      if (await _validateSqliteDatabase(_internalPath!)) {
        await File(oldPath).delete();
        _logger.info('Database migration finished successfully');
        return true;
      }
      // Integrity check failed: discard the bad copy and keep the external
      // original so the migration can be retried instead of proceeding.
      await File(_internalPath!).delete();
      _logger.severe(
          'Database migration failed: integrity check failed, kept original external database');
      return false;
    } catch (error, stackTrace) {
      // Remove any partial copy so the migration is retried on relaunch.
      if (await File(_internalPath!).exists()) {
        await File(_internalPath!).delete();
      }
      _logger.severe('Database migration failed', error, stackTrace);
      return false;
    }
  }

  Future<void> open() async {
    // 防丢保护：sqflite 可写模式打开时，Android 默认 DatabaseErrorHandler
    // 会在检测到损坏时直接删除数据库文件。这里先用只读校验（readOnly 模式
    // 不会删除文件）探测内部库，损坏则先从外部备份恢复，绝不直接删库。
    if (await File(_internalPath!).exists() &&
        !await _validateSqliteDatabase(_internalPath!)) {
      _logger.severe(
          'Internal database corrupted on open. Attempting recovery.');
      final recovered = await _restoreFromExternalBackup();
      if (!recovered) {
        // 外部备份不可用：保留损坏文件（改名），避免被 sqflite 删掉，
        // 同时让 onCreate 重建一个可用库。
        await _preserveCorruptedDatabase();
      }
    }

    _database = await openDatabase(_internalPath!,
        version: 6, onCreate: _createDatabase, onUpgrade: _onUpgrade);

    await EntriesProvider.instance.load();
    await EntryImagesProvider.instance.load();
  }

  /// 把损坏的内部库改名为 .corrupt 保留（绝不直接删除），以便数据抢救。
  Future<void> _preserveCorruptedDatabase() async {
    try {
      final corruptPath =
          '${_internalPath!}.corrupt_${DateTime.now().millisecondsSinceEpoch}';
      if (await File(_internalPath!).exists()) {
        await File(_internalPath!).rename(corruptPath);
      }
      // 连带清理 WAL/SHM，避免残留文件干扰后续新库
      for (final suffix in ['-wal', '-shm']) {
        final leftover = File('$_internalPath$suffix');
        if (await leftover.exists()) {
          try {
            await leftover.delete();
          } catch (_) {}
        }
      }
      _logger.warning('Corrupted database preserved at $corruptPath');
    } catch (e) {
      _logger.warning('Failed to preserve corrupted database: $e');
    }
  }

  /// 从外部备份恢复内部库。先校验外部备份有效，覆盖前保留现有内部文件。
  /// 返回是否恢复成功。
  Future<bool> _restoreFromExternalBackup() async {
    try {
      if (!usingExternalLocation() ||
          !await hasExternalLocationPermission()) {
        return false;
      }
      if (!await FileLayer.exists(
          getExternalPath(), name: "daily_you.db")) {
        return false;
      }
      var externalBytes = await FileLayer.getFileBytes(
          getExternalPath(), name: "daily_you.db");
      if (externalBytes == null) return false;
      final decryptedBytes = _decryptBytes(externalBytes);
      if (decryptedBytes == null) {
        _logger.severe('Failed to decrypt external database backup.');
        return false;
      }

      final temporaryInternalPath =
          "${_internalPath!}.recover_${DateTime.now().millisecondsSinceEpoch}.tmp";
      final internalDirectory = dirname(temporaryInternalPath);
      final temporaryFileName = basename(temporaryInternalPath);
      await FileLayer.createFile(internalDirectory, temporaryFileName,
          decryptedBytes,
          useExternalPath: false);
      if (!await _validateSqliteDatabase(temporaryInternalPath)) {
        await FileLayer.deleteFile(temporaryInternalPath,
            useExternalPath: false);
        _logger.warning(
            'External backup failed validation, restore aborted');
        return false;
      }

      // 覆盖前保留现有内部文件（损坏的也保留）
      if (await File(_internalPath!).exists()) {
        await _preserveCorruptedDatabase();
      }
      await File(temporaryInternalPath).rename(_internalPath!);

      // 清理可能残留的 WAL/SHM 文件，避免与新库错配
      for (final suffix in ['-wal', '-shm']) {
        final leftover = File('$_internalPath$suffix');
        if (await leftover.exists()) {
          try {
            await leftover.delete();
          } catch (_) {}
        }
      }

      _logger.info('Database restored from external backup');
      return true;
    } catch (e) {
      _logger.warning('External backup restore failed: $e');
      return false;
    }
  }

  Future<void> close() async {
    final db = _database!;
    _database = null;
    db.close();
  }

  Future<bool> _validateSqliteDatabase(String path) async {
    try {
      final db = await openDatabase(path, readOnly: true);
      final result = await db.rawQuery("PRAGMA integrity_check;");
      await db.close();

      return result.first.values.first == "ok";
    } catch (_) {
      return false;
    }
  }

  bool usingExternalLocation() {
    return ConfigProvider.instance.get(ConfigKey.useExternalDb) ?? false;
  }

  Future<String> getInternalPath() async {
    final basePath = await getApplicationSupportDirectory();
    if (!basePath.existsSync()) basePath.createSync(recursive: true);
    return join(basePath.path, 'daily_you.db');
  }

  String getExternalPath() {
    return ConfigProvider.instance.get(ConfigKey.externalDbUri);
  }

  /// Return whether the app has permission to access the external location
  Future<bool> hasExternalLocationPermission() async {
    return FileLayer.hasPermission(getExternalPath());
  }

  /// Select an external database location. Returns whether a new location was set successfully.
  Future<bool> selectExternalLocation(void Function(String) updateStatus) async {
    bool databaseUpdated = false;

    // Save old external path
    var oldExternalPath = getExternalPath();
    var oldUseExternalPath = usingExternalLocation();
    await _database!.close();

    try {
      var selectedDirectory = await FileLayer.pickDirectory();
      if (selectedDirectory != null) {
        await ConfigProvider.instance
            .set(ConfigKey.externalDbUri, selectedDirectory);
        await ConfigProvider.instance.set(ConfigKey.useExternalDb, true);

        // Sync with external folder（安全方向：内部完好时只导出，不反向覆盖）
        databaseUpdated = await _syncWithExternalDatabase();
      }
    } catch (_) {
      // Do nothing
    }

    // Cleanup
    await open();
    if (!databaseUpdated) {
      // Restore state after failure
      await ConfigProvider.instance
          .set(ConfigKey.externalDbUri, oldExternalPath);
      await ConfigProvider.instance
          .set(ConfigKey.useExternalDb, oldUseExternalPath);
    } else {
      try {
        if (ImageStorage.instance.usingExternalLocation() &&
            await ImageStorage.instance.hasExternalLocationPermission()) {
          await ImageStorage.instance
              .syncImageFolder(true, updateStatus: updateStatus);
        }
      } catch (_) {
        // Do nothing
      }
    }
    return databaseUpdated;
  }

  Future<void> resetExternalLocation() async {
    await ConfigProvider.instance.set(ConfigKey.useExternalDb, false);
  }

  Uint8List? _encryptBytes(Uint8List data) {
    if (ConfigProvider.instance.get(ConfigKey.encryptBackup) != true) return data;
    final pwdHash = ConfigProvider.instance.get(ConfigKey.backupPassword) as String?;
    if (pwdHash == null || pwdHash.isEmpty) return data;

    // Use first 32 chars of the hex hash as the 32-byte AES key
    final keyStr = pwdHash.length >= 32 ? pwdHash.substring(0, 32) : pwdHash.padRight(32, '0');
    final key = enc.Key.fromUtf8(keyStr);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    // Prepend IV to the encrypted data
    final result = BytesBuilder();
    result.add(iv.bytes);
    result.add(encrypted.bytes);
    return result.toBytes();
  }

  Uint8List? _decryptBytes(Uint8List data) {
    if (ConfigProvider.instance.get(ConfigKey.encryptBackup) != true) return data;
    final pwdHash = ConfigProvider.instance.get(ConfigKey.backupPassword) as String?;
    if (pwdHash == null || pwdHash.isEmpty) return data;

    // The data must be at least 16 bytes for the IV
    if (data.length < 16) return data;

    final keyStr = pwdHash.length >= 32 ? pwdHash.substring(0, 32) : pwdHash.padRight(32, '0');
    final key = enc.Key.fromUtf8(keyStr);
    
    final ivBytes = data.sublist(0, 16);
    final encryptedBytes = data.sublist(16);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key));

    try {
      final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (_) {
      // If decryption fails, return null to indicate failure
      return null;
    }
  }

  /// Overwrite the external database with local changes
  /// If an external database is not in use, no action is taken
  Future<void> updateExternalDatabase() async {
    if (usingExternalLocation()) {
      EasyDebounce.debounce("update-remote-database", Duration(seconds: 1),
          _writeExternalBackup);
    }
  }

  /// 立即执行一次备份（切后台/锁屏时调用），不做防抖
  Future<void> backupNow() async {
    if (!usingExternalLocation()) return;
    EasyDebounce.cancel("update-remote-database");
    try {
      await _writeExternalBackup();
      _logger.info('Auto backup written to external location');
    } catch (e, st) {
      _logger.warning('Auto backup failed: $e\n$st');
    }
  }

  Future<void> _writeExternalBackup() async {
    final db = database;
    if (db == null) return;
    try {
      // 清理上次异常残留的导出文件，避免内部目录堆积
      final internalDir = dirname(_internalPath!);
      try {
        final dir = Directory(internalDir);
        if (await dir.exists()) {
          await for (final f in dir.list()) {
            if (f is File &&
                f.path.startsWith('$_internalPath.export_')) {
              try {
                await f.delete();
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Create temporary export copy
      final tmpExport =
          "${_internalPath!}.export_${DateTime.now().millisecondsSinceEpoch}";
      await db.execute("VACUUM INTO '$tmpExport'");

      // Ensure export copy is valid
      if (!await _validateSqliteDatabase(tmpExport)) {
        await File(tmpExport).delete();
        return;
      }

      // Read + optional encrypt
      var bytes =
          await FileLayer.getFileBytes(tmpExport, useExternalPath: false);
      if (bytes == null) return;

      final encryptedBytes = _encryptBytes(bytes);
      if (encryptedBytes == null) return;

      // 目标文件不存在时先创建，避免向空对象写入导致静默失败
      final externalDbUri = getExternalPath();
      if (await FileLayer.exists(externalDbUri, name: "daily_you.db")) {
        await FileLayer.writeFileBytes(externalDbUri, encryptedBytes,
            name: "daily_you.db");
      } else {
        await FileLayer.createFile(
            externalDbUri, "daily_you.db", encryptedBytes);
      }

      // 回读校验：确认备份真的写成功且完整，防止半写/空备份污染外部文件。
      // （半写的外部备份曾是内部库被错误覆盖的隐患来源）
      final verifyBytes =
          await FileLayer.getFileBytes(externalDbUri, name: "daily_you.db");
      if (verifyBytes == null || verifyBytes.length != encryptedBytes.length) {
        _logger.severe(
            'External backup verification failed: written bytes do not match');
      }

      await FileLayer.deleteFile(tmpExport, useExternalPath: false);
    } catch (e) {
      _logger.warning('External database backup failed: $e');
    }
  }

  /// 数据同步策略（防丢优先）：
  /// - 内部库完好时，绝不用外部备份覆盖内部（外部 mtime 更新不代表内容更好）
  /// - 仅当内部库缺失或损坏时才从外部备份恢复
  /// - 外部备份不存在时，把内部库导出到外部（首次备份）
  Future<bool> _syncWithExternalDatabase({bool forceOverwrite = false}) async {
    var externalExists =
        await FileLayer.exists(getExternalPath(), name: "daily_you.db");

    final internalExists = await File(_internalPath!).exists();
    final internalHealthy = internalExists &&
        await _validateSqliteDatabase(_internalPath!);

    if (!externalExists) {
      // 外部无备份 → 把内部备份过去（首次备份）。内部损坏时绝不导出坏库。
      if (!internalExists || !internalHealthy) return true;
      var bytes =
          await FileLayer.getFileBytes(_internalPath!, useExternalPath: false);
      if (bytes == null) return false;

      // Export internal DB
      var externalDbPath =
          await FileLayer.createFile(getExternalPath(), "daily_you.db", bytes);
      return externalDbPath != null;
    }

    // 外部存在：仅当内部缺失/损坏（或用户强制）时用外部恢复内部
    if (!internalExists || !internalHealthy || forceOverwrite) {
      final restored = await _restoreFromExternalBackup();
      return restored || internalExists || !internalHealthy;
    }

    return true;
  }

  // SQLite Database Actions

  Future _createDatabase(Database db, int version) async {
    _database = db;
    await db.execute('''
CREATE TABLE $entriesTable (
  ${EntryFields.id} INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  ${EntryFields.title} TEXT,
  ${EntryFields.text} TEXT NOT NULL,
  ${EntryFields.mood} INTEGER,
  ${EntryFields.timeCreate} DATETIME NOT NULL DEFAULT (DATETIME('now')),
  ${EntryFields.timeModified} DATETIME NOT NULL DEFAULT (DATETIME('now'))
)
''');


    await db.execute('''
CREATE TABLE $imagesTable (
    ${EntryImageFields.id} INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    ${EntryImageFields.entryId} INTEGER NOT NULL,
    ${EntryImageFields.imgPath} TEXT NOT NULL,
    ${EntryImageFields.imgRank} INTEGER NOT NULL,
    ${EntryImageFields.timeCreate} DATETIME NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (${EntryImageFields.entryId}) REFERENCES $entriesTable (id)
)
''');

    await _createKeywordFrequencyTable(db);
    await _backfillKeywordFrequencies(db);

    await _createWelcomeEntry();
  }

  /// 词云词频缓存表：日记增删改时增量维护，统计页零延迟读取。
  Future<void> _createKeywordFrequencyTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS keyword_frequencies (
  word TEXT PRIMARY KEY,
  term_count INTEGER NOT NULL DEFAULT 0,
  doc_count INTEGER NOT NULL DEFAULT 0
)
''');
  }

  /// 升级/新建后一次性回填词频（幂等：表已有数据且条目数足够时跳过）
  Future<void> _backfillKeywordFrequencies(Database db) async {
    final freqCount =
        Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM keyword_frequencies')) ??
        0;
    final entryCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $entriesTable')) ??
        0;

    // v5 已建表并回填过的库（如升级到 v0.1.6 的正常用户）不能重复累加，
    // 否则词频翻倍；只在表缺失/为空（旧库直升 v6）时重建。
    if (freqCount > 0 && freqCount >= entryCount) return;

    await db.delete('keyword_frequencies');

    final rows = await db.query(entriesTable, columns: [EntryFields.text]);
    if (rows.isEmpty) return;
    for (final row in rows) {
      final text = row[EntryFields.text] as String;
      if (text.trim().isEmpty) continue;
      final keywords = extractKeywordsFromText(text);
      for (final kv in keywords.entries) {
        await db.execute(
            'INSERT OR IGNORE INTO keyword_frequencies (word, term_count, doc_count) VALUES (?, 0, 0)',
            [kv.key]);
        await db.execute(
            'UPDATE keyword_frequencies SET term_count = term_count + ?, doc_count = doc_count + 1 WHERE word = ?',
            [kv.value, kv.key]);
      }
    }
  }

  Future<void> _createWelcomeEntry() async {
    final l10n = await loadDeviceLocalizations();
    final now = DateTime.now();

    final welcomeEntry = await EntriesProvider.instance.add(
      Entry(
        text: l10n.welcomeLogBodyText,
        mood: 1,
        timeCreate: now,
        timeModified: now,
      ),
      skipUpdate: true,
    );

    final imageBytes =
        await rootBundle.load('assets/daily_you_First_Steps.webp');
    final imageName = await ImageStorage.instance.create(
      'daily_you_First_Steps.webp',
      imageBytes.buffer.asUint8List(),
      currTime: now,
    );
    if (imageName != null) {
      await EntryImagesProvider.instance.add(
        EntryImage(
          entryId: welcomeEntry.id,
          imgPath: imageName,
          imgRank: 0,
          timeCreate: now,
        ),
        skipUpdate: true,
      );
    }


  }



  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _database = db;
    // In this case, oldVersion is 1, newVersion is 2
    if (oldVersion == 1) {

    }
    if (oldVersion <= 2) {
      await db.execute('''
CREATE TABLE $imagesTable (
    ${EntryImageFields.id} INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    ${EntryImageFields.entryId} INTEGER NOT NULL,
    ${EntryImageFields.imgPath} TEXT NOT NULL,
    ${EntryImageFields.imgRank} INTEGER NOT NULL,
    ${EntryImageFields.timeCreate} DATETIME NOT NULL DEFAULT (DATETIME('now')),
    FOREIGN KEY (${EntryImageFields.entryId}) REFERENCES $entriesTable (id)
)
''');
      await db.transaction((txn) async {
        await txn.execute('''
-- Step 1: Insert the non-null imgPath entries into the imagesTable
INSERT INTO $imagesTable (${EntryImageFields.entryId}, ${EntryImageFields.imgPath}, ${EntryImageFields.imgRank}, ${EntryImageFields.timeCreate})
SELECT ${EntryFields.id}, $deprecatedImgPath, 0, ${EntryFields.timeCreate}
FROM $entriesTable
WHERE $deprecatedImgPath IS NOT NULL;
    ''');

        await txn.execute('''
-- Step 2: Rename the old entries table
ALTER TABLE $entriesTable RENAME TO old_entries;
    ''');

        await txn.execute('''
-- Step 3: Create a new entries table without the imgPath field
CREATE TABLE $entriesTable (
  ${EntryFields.id} INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  ${EntryFields.text} TEXT NOT NULL,
  ${EntryFields.mood} INTEGER,
  ${EntryFields.timeCreate} DATETIME NOT NULL DEFAULT (DATETIME('now')),
  ${EntryFields.timeModified} DATETIME NOT NULL DEFAULT (DATETIME('now'))
);
    ''');

        await txn.execute('''
-- Step 4: Copy data from the old entries table to the new one
INSERT INTO $entriesTable (${EntryFields.id}, ${EntryFields.text}, ${EntryFields.mood}, ${EntryFields.timeCreate}, ${EntryFields.timeModified})
SELECT ${EntryFields.id}, ${EntryFields.text}, ${EntryFields.mood}, ${EntryFields.timeCreate}, ${EntryFields.timeModified}
FROM old_entries;
    ''');

        await txn.execute('''
-- Step 5: Drop the old entries table
DROP TABLE old_entries;
    ''');
      });
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $entriesTable ADD COLUMN ${EntryFields.title} TEXT;');
    }

    if (oldVersion < 5) {
      await _createKeywordFrequencyTable(db);
      await _backfillKeywordFrequencies(db);
    }

    // v6：v0.1.3 已把库迁到 v5，v0.1.6 的建表代码因此从未执行过，
    // 老库缺少 keyword_frequencies 导致统计页/写日记抛错。无条件补建。
    if (oldVersion < 6) {
      await _createKeywordFrequencyTable(db);
      await _backfillKeywordFrequencies(db);
    }
  }
}
