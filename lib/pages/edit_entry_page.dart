import 'dart:async';
import 'dart:io';

import 'package:word_count/word_count.dart';
import 'package:daily_you/database/image_storage.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/notification_manager.dart';
import 'package:daily_you/time_manager.dart';
import 'package:daily_you/pages/full_screen_text_editor_page.dart';
import 'package:daily_you/widgets/edit_toolbar.dart';
import 'package:daily_you/widgets/entry_image_editable_list.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/widgets/entry_image_picker.dart';
import 'package:daily_you/widgets/entry_text_edit.dart';
import 'package:daily_you/utils/share_utils.dart';

class AddEditEntryPage extends StatefulWidget {
  final Entry? entry;
  final DateTime? overrideCreateDate;
  final bool openCamera;
  final List<EntryImage> images;

  const AddEditEntryPage({
    super.key,
    this.entry,
    this.overrideCreateDate,
    this.openCamera = false,
    this.images = const <EntryImage>[],
  });
  @override
  State<AddEditEntryPage> createState() => _AddEditEntryPageState();
}

class _AddEditEntryPageState extends State<AddEditEntryPage>
    with WidgetsBindingObserver {
  late Entry _entry;
  int id = -1;
  String _lastText = "";
  String text = "";
  String _lastTitle = "";
  String _title = "";
  DateTime? _lastEntryDate;
  DateTime? entryDate;
  late List<EntryImage> _currentImages;
  bool _loadingEntry = true;
  bool _openedCamera = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  final TextEditingController _titleEditingController = TextEditingController();
  final UndoHistoryController _undoController = UndoHistoryController();
  bool _deletingEntry = false;
  bool _savingEntry = false;
  bool _newEntry = false;
  bool _creatingNewEntry = false;
  Timer? _debounceTimer;

  Future<void> _initEntry() async {
    if (widget.entry == null) {
      var createTime =
          (TimeManager.isToday(widget.overrideCreateDate ?? DateTime.now()))
              ? DateTime.now()
              : (widget.overrideCreateDate ?? DateTime.now());
      var text = "";
      _entry = Entry(
        text: text,
        mood: null,
        timeCreate: createTime,
        timeModified: DateTime.now(),
      );
      _newEntry = true;
      _creatingNewEntry = true;
      id = -1;
    } else {
      _entry = widget.entry!;
      id = _entry.id ?? -1;
    }
    _lastEntryDate = _entry.timeCreate;
    entryDate = _entry.timeCreate;
    _lastText = _entry.text;
    text = _entry.text;
    _lastTitle = _entry.title ?? "";
    _title = _entry.title ?? "";
    _titleEditingController.text = _title;
    _textEditingController.addListener(() {
      text = _textEditingController.text;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 5), () {
        _saveEntry();
      });
    });
    _titleEditingController.addListener(() {
      _title = _titleEditingController.text;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 5), () {
        _saveEntry();
      });
    });
    setState(() {
      _loadingEntry = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentImages = List.empty(growable: true);
    for (var image in widget.images) {
      _currentImages.add(image.copy());
    }
    _initEntry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _focusNode.dispose();
    _textEditingController.dispose();
    _titleEditingController.dispose();
    _undoController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) {
      _saveEntry();
    }
  }

  Future<void> _openFullScreenEditor() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (context) => FullScreenTextEditorPage(
          initialText: _textEditingController.text,
        ),
      ),
    );
    if (result != null) {
      _textEditingController.text = result;
    }
  }

  void _showDeleteEntryPopup() {
    if (_newEntry) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteLogTitle),
          actions: [
            TextButton(
              child:
                  Text(MaterialLocalizations.of(context).deleteButtonTooltip),
              onPressed: () async {
                _deletingEntry = true;
                // Pop dialog
                Navigator.of(context).pop();
                // Pop edit page
                Navigator.of(context).pop();
                if (!_creatingNewEntry && Navigator.of(context).canPop()) {
                  // Pop view page
                  Navigator.of(context).pop();
                }
                await _deleteEntry(_entry);
              },
            ),
            TextButton(
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
              onPressed: () async {
                Navigator.pop(context);
              },
            )
          ],
          content: Text(AppLocalizations.of(context)!.deleteLogDescription),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _loadingEntry
        ? Scaffold()
        : PopScope(
            onPopInvokedWithResult: (didPop, result) async {
              if (!_deletingEntry) {
                await _saveEntry();
              }
            },
            child: Stack(
              children: [
                const RicePaperBackground(),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Center(
                          child: GlassActionButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            iconSize: 20,
                            onTap: () {
                              // Pop edit page
                              Navigator.of(context).pop();
                              if (!_creatingNewEntry &&
                                  Navigator.of(context).canPop()) {
                                // Pop view page
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                      ),
                      actions: [
                        Center(
                          child: GlassActionButton(
                            icon: Icons.share_rounded,
                            onTap: () {
                              // 分享当前（含未保存）内容为图片
                              final shareEntry = _entry.copy(
                                title: _title.isEmpty ? null : _title,
                                text: _textEditingController.text,
                                timeCreate: entryDate ?? _entry.timeCreate,
                              );
                              showShareMenu(
                                  context, shareEntry, _currentImages);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Center(child: _deleteButton()),
                        const SizedBox(width: 8),
                        Center(child: _saveButton()),
                        const SizedBox(width: 16),
                      ]),
                  body: Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            if (_currentImages.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: EntryImageEditableList(
                                      images: _currentImages,
                                      onImagesChanged: (images) async {
                                        _currentImages = images;
                                        await _saveEntry();
                                      }),
                                ),
                              ),
                            _buildTextEditorSliver(theme, AppLocalizations.of(context)),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: EditToolbar(
                          controller: _textEditingController,
                          undoController: _undoController,
                          focusNode: _focusNode,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  // The row showing entry date/time and image actions.
  // setLocalState is the StatefulBuilder's setter.
  Widget _buildMetadataRow(
    BuildContext context,
    ThemeData theme,
    StateSetter setLocalState,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8.0,
        children: [
          _buildDateTimeButtons(context, theme),
          _buildImageButton(context, theme),
        ],
      ),
    );
  }

  Widget _buildDateTimeButtons(BuildContext context, ThemeData theme) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                _chooseDate();
              },
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(6)),
              child: Text(
                TimeManager.formatDateWithWeekday(entryDate!, context),
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
            VerticalDivider(
              width: 6,
              indent: 8,
              endIndent: 8,
              thickness: 2,
              radius: BorderRadius.circular(4),
            ),
            TextButton(
              onPressed: () async {
                _chooseTime();
              },
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(6)),
              child: Text(
                TimeManager.localizedTimeFormat(
                        TimeManager.currentLocale(context))
                    .format(entryDate!),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageButton(BuildContext context, ThemeData theme) {
    return EntryImagePicker(
      onChangedImage: (newImages) {
        _openedCamera = true;
        _addImage(newImages);
      },
      openCamera: widget.openCamera && !_openedCamera,
    );
  }


  Widget _buildTextEditorSliver(ThemeData theme, AppLocalizations? l10n) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _focusNode.requestFocus(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatefulBuilder(
                      builder: (context, setLocalState) =>
                          _buildMetadataRow(context, theme, setLocalState),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleEditingController,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n?.titleHint ?? '标题...',
                        hintStyle: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StatefulBuilder(
                        builder: (context, setState) => EntryTextEditor(
                          text: text,
                          focusNode: _focusNode,
                          textEditingController: _textEditingController,
                          undoHistoryController: _undoController,
                          onExpand: _openFullScreenEditor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 实时字数显示
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _textEditingController,
                        builder: (context, value, _) {
                          return Text(
                            '${wordsCount(value.text)} 字',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteButton() => GlassActionButton(
        icon: Icons.delete_rounded,
        onTap: _showDeleteEntryPopup,
      );

  Widget _saveButton() => GlassActionButton(
        icon: Icons.check_rounded,
        onTap: () => Navigator.of(context).pop(),
      );

  Future<void> _chooseDate() async {
    DateTime? pickedDate = await TimeManager.pickDate(
      context,
      initialDate: entryDate!,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;

    entryDate = entryDate!.copyWith(
      year: pickedDate.year,
      month: pickedDate.month,
      day: pickedDate.day,
    );
    await _saveEntry();
  }

  Future<void> _chooseTime() async {
    final pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(entryDate!));
    if (pickedTime == null) return;

    entryDate = entryDate!.copyWith(
      hour: pickedTime.hour,
      minute: pickedTime.minute,
    );
    await _saveEntry();
  }

  Future<void> _saveEntry({bool forceCreate = false}) async {
    // Saving is guarded since quickly entering and exiting the app could trigger
    // multiple async saves.
    if (_savingEntry == false) {
      _savingEntry = true;

      final updatedEntry = _entry.copy(
        title: _title.isEmpty ? null : _title,
        text: text,
        timeCreate: entryDate,
        timeModified: DateTime.now(),
      );

      final hasTextChange = updatedEntry.text != _lastText || (updatedEntry.title ?? "") != _lastTitle;
      final hasDateChange = updatedEntry.timeCreate != _lastEntryDate;

      if (_newEntry) {
        if (forceCreate ||
            hasTextChange ||
            hasDateChange ||
            _currentImages.isNotEmpty) {
          if (Platform.isAndroid &&
              TimeManager.isSameDay(DateTime.now(), updatedEntry.timeCreate)) {
            await NotificationManager.instance.dismissReminderNotification();
          }
          _entry = await EntriesProvider.instance.add(updatedEntry);
          id = _entry.id!;
          _newEntry = false;
          _lastText = _entry.text;
          _lastTitle = _entry.title ?? "";
          _lastEntryDate = _entry.timeCreate;
        }
      } else {
        if (hasTextChange || hasDateChange) {
          if (Platform.isAndroid &&
              TimeManager.isSameDay(DateTime.now(), updatedEntry.timeCreate)) {
            await NotificationManager.instance.dismissReminderNotification();
          }
          _lastText = updatedEntry.text;
          _lastTitle = updatedEntry.title ?? "";
          _lastEntryDate = updatedEntry.timeCreate;
          await EntriesProvider.instance.update(updatedEntry);
        }
      }
      // Images will update if they changed
      await _saveOrUpdateImage(id);
      _savingEntry = false;
    }
  }

  Future _deleteEntry(Entry entry) async {
    var entryImages = EntryImagesProvider.instance.getForEntry(entry);
    for (EntryImage image in entryImages) {
      await ImageStorage.instance.delete(image.imgPath);
      await EntryImagesProvider.instance.remove(image);
      }
      await EntriesProvider.instance.remove(entry);
  }

  Future _saveOrUpdateImage(int entryId) async {
    if (entryId == -1 || _entry.id == null) return;
    final savedImages = EntryImagesProvider.instance.getForEntry(_entry);
    // Add images
    for (EntryImage currentImage in _currentImages) {
      currentImage.entryId = entryId;
      if (currentImage.id == null ||
          savedImages.where((image) => image.id == currentImage.id!).isEmpty) {
        await EntryImagesProvider.instance.add(currentImage);
      }
    }
    // Update images
    for (EntryImage existingImage in savedImages) {
      EntryImage? matchingImage = _currentImages
          .where((image) => image.id == existingImage.id!)
          .firstOrNull;
      if (matchingImage == null) {
        // Delete image
        await ImageStorage.instance.delete(existingImage.imgPath);
        await EntryImagesProvider.instance.remove(existingImage);
      } else if (matchingImage.imgRank != existingImage.imgRank) {
        await EntryImagesProvider.instance.update(matchingImage);
      }
    }
    // Set current images to match saved state. Note: the entry images
    // are copied to avoid editing the originals in the provider.
    _currentImages.clear();
    for (var image in EntryImagesProvider.instance.getForEntry(_entry)) {
      _currentImages.add(image.copy());
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addImage(List<String> imgPaths) async {
    for (var imgPath in imgPaths) {
      // Add image to the end by giving it the lowest rank
      for (var image in _currentImages) {
        image.imgRank += 1;
      }
      _currentImages.add(EntryImage(
          entryId: id,
          imgPath: imgPath,
          imgRank: 0,
          timeCreate: DateTime.now()));
    }
    await _saveEntry();
  }
}
