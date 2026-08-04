import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/database/entry_dao.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:word_count/word_count.dart';

class EntriesProvider with ChangeNotifier {
  static final EntriesProvider instance = EntriesProvider._init();

  EntriesProvider._init();

  List<Entry> entries = List.empty(growable: true);
  Map<DateTime, List<Entry>> _entriesByDay = {};

  int _wordCount = 0;
  int get wordCount => _wordCount;

  bool isLoading = false;
  bool isAllLoaded = false;
  int _offset = 0;
  static const int _limit = 50;

  /// Load the provider's data from the app database
  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    _offset = 0;
    entries = await EntryDao.getPage(_limit, _offset);
    isAllLoaded = entries.length < _limit;
    
    await _calculateWordCount();
    _calculateEntriesByDay();
    
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoading || isAllLoaded) return;
    isLoading = true;
    notifyListeners();

    _offset += _limit;
    final moreEntries = await EntryDao.getPage(_limit, _offset);
    if (moreEntries.isEmpty) {
      isAllLoaded = true;
    } else {
      entries.addAll(moreEntries);
      if (moreEntries.length < _limit) {
        isAllLoaded = true;
      }
      _calculateEntriesByDay();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<List<Entry>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return await EntryDao.search(query.trim());
  }

  // CRUD operations

  Future<Entry> add(Entry entry, {bool skipUpdate = false}) async {
    // Insert the entry into the database so that it has an ID
    final entryWithId = await EntryDao.add(entry);
    entries.add(entryWithId);
    await AppDatabase.instance.updateExternalDatabase();

    if (!skipUpdate) {
      // Reverse chronological order such that the most recent day is first
      entries.sort((a, b) => compareByTime(b.timeCreate, a.timeCreate));
      await _calculateWordCount();
      _calculateEntriesByDay();
      notifyListeners();
    }
    return entryWithId;
  }

  Future<void> update(Entry entry) async {
    await EntryDao.update(entry);
    final index = entries.indexWhere((x) => x.id == entry.id);
    entries[index] = entry;
    // Reverse chronological order such that the most recent day is first
    entries.sort((a, b) => compareByTime(b.timeCreate, a.timeCreate));
    await AppDatabase.instance.updateExternalDatabase();

    await _calculateWordCount();
    _calculateEntriesByDay();
    notifyListeners();
  }

  Future<void> remove(Entry entry) async {
    await EntryDao.remove(entry.id!);
    entries.removeWhere((x) => x.id == entry.id);
    await AppDatabase.instance.updateExternalDatabase();

    await _calculateWordCount();
    _calculateEntriesByDay();
    notifyListeners();
  }

  /// Deletes every entry (and its images), then reloads the provider.
  Future<void> deleteAll(void Function(String) updateStatus) async {
    updateStatus("0%");
    var processedEntries = 0;
    for (Entry entry in entries) {
      for (final image in EntryImagesProvider.instance.getForEntry(entry)) {
        await EntryImagesProvider.instance.remove(image);
      }
      processedEntries += 1;
      // The provider's remove function is not used to avoid editing the
      // entries list while iterating over it.
      await EntryDao.remove(entry.id!);
      updateStatus("${((processedEntries / entries.length) * 100).round()}%");
    }

    // Reload the provider since all entries have been deleted
    await load();
    await AppDatabase.instance.updateExternalDatabase();
  }

  /// Compares two [DateTime]s by calendar date and time of day.
  int compareByTime(DateTime a, DateTime b) {
    if (a.year != b.year) return a.year.compareTo(b.year);
    if (a.month != b.month) return a.month.compareTo(b.month);
    if (a.day != b.day) return a.day.compareTo(b.day);
    if (a.hour != b.hour) return a.hour.compareTo(b.hour);
    return a.minute.compareTo(b.minute);
  }

  /// Return the number of days with entries
  int getEntryDayCount() {
    return _entriesByDay.length;
  }

  Entry? getEntryForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return _entriesByDay[target]?.first;
  }

  bool hasEntryAtTimestamp(DateTime timestamp) {
    return entries.any((e) => e.timeCreate == timestamp);
  }

  Future<void> _calculateWordCount() async {
    _wordCount = 0;
    final texts = await EntryDao.getAllTexts();
    for (var text in texts) {
      _wordCount += wordsCount(text);
    }
  }

  void _calculateEntriesByDay() {
    final map = <DateTime, List<Entry>>{};
    for (final e in entries) {
      final key =
          DateTime(e.timeCreate.year, e.timeCreate.month, e.timeCreate.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    _entriesByDay = map;
  }
}
