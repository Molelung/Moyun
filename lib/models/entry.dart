const String entriesTable = 'entries';

const String deprecatedImgPath = 'img_path';

class EntryFields {
  static const List<String> values = [id, title, text, mood, timeCreate, timeModified];
  static const String id = 'id';
  static const String title = 'title';
  static const String text = 'text';
  static const String mood = 'mood';
  static const String timeCreate = 'time_create';
  static const String timeModified = 'time_modified';
}

class Entry {
  final int? id;
  final String? title;
  final String text;
  final int? mood;
  final DateTime timeCreate;
  final DateTime timeModified;

  const Entry({
    this.id,
    this.title,
    required this.text,
    this.mood,
    required this.timeCreate,
    required this.timeModified,
  });

  static const _unset = Object();

  Entry copy({
    int? id,
    Object? title = _unset,
    String? text,
    Object? mood = _unset,
    DateTime? timeCreate,
    DateTime? timeModified,
  }) =>
      Entry(
        id: id ?? this.id,
        title: title == _unset ? this.title : title as String?,
        text: text ?? this.text,
        mood: mood == _unset ? this.mood : mood as int?,
        timeCreate: timeCreate ?? this.timeCreate,
        timeModified: timeModified ?? this.timeModified,
      );

  static Entry fromJson(Map<String, Object?> json) => Entry(
        id: json[EntryFields.id] as int?,
        title: json[EntryFields.title] as String?,
        text: json[EntryFields.text] as String,
        mood: json[EntryFields.mood] as int?,
        timeCreate: DateTime.parse(json[EntryFields.timeCreate] as String),
        timeModified: DateTime.parse(json[EntryFields.timeModified] as String),
      );

  Map<String, Object?> toJson() => {
        EntryFields.id: id,
        EntryFields.title: title,
        EntryFields.text: text,
        EntryFields.mood: mood,
        EntryFields.timeCreate: timeCreate.toIso8601String(),
        EntryFields.timeModified: timeModified.toIso8601String(),
      };
}
