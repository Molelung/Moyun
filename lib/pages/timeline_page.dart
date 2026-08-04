import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/time_manager.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/app_text.dart';
import 'package:daily_you/pages/edit_entry_page.dart';

class TimelineGroup {
  final DateTime date;
  final List<Entry> entries;

  TimelineGroup(this.date, this.entries);
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  List<TimelineGroup> _groups = [];

  /// 一次手势只能触发一次返回：过滚通知会在同一拖拽中多次触发，
  /// 若不守卫会连续 pop 多个路由直到黑屏。
  bool _popTriggered = false;

  @override
  void initState() {
    super.initState();
    _buildGroups();

    itemPositionsListener.itemPositions.addListener(_scrollListener);
  }

  void _triggerPop() {
    if (_popTriggered || !mounted) return;
    _popTriggered = true;
    Navigator.of(context).pop();
  }

  void _scrollListener() {
    final positions = itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final last = positions.last.index;
      if (last >= _groups.length - 2) {
        final provider = Provider.of<EntriesProvider>(context, listen: false);
        if (!provider.isLoading && !provider.isAllLoaded) {
          provider.loadMore().then((_) {
            if (mounted) {
              setState(() {
                _buildGroups();
              });
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    itemPositionsListener.itemPositions.removeListener(_scrollListener);
    super.dispose();
  }

  void _buildGroups() {
    final entries =
        Provider.of<EntriesProvider>(context, listen: false).entries;
    final Map<String, List<Entry>> grouped = {};

    for (var entry in entries) {
      final key =
          "${entry.timeCreate.year}-${entry.timeCreate.month}-${entry.timeCreate.day}";
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    _groups = grouped.values.map((list) {
      // sort entries in same day (latest first)
      list.sort((a, b) => b.timeCreate.compareTo(a.timeCreate));
      final date = DateTime(list.first.timeCreate.year,
          list.first.timeCreate.month, list.first.timeCreate.day);
      return TimelineGroup(date, list);
    }).toList();

    // sort groups by date descending
    _groups.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _jumpToDate(DateTime target) async {
    if (_groups.isEmpty) return;

    final provider = Provider.of<EntriesProvider>(context, listen: false);
    await provider.jumpToDate(target);
    
    if (!mounted) return;
    
    setState(() {
      _buildGroups();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      int closestIndex = -1;
      Duration minDiff = const Duration(days: 99999);

      for (int i = 0; i < _groups.length; i++) {
        final diff = _groups[i].date.difference(target).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestIndex = i;
        }
      }

      if (closestIndex != -1) {
        itemScrollController.jumpTo(index: closestIndex);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await TimeManager.pickDate(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _jumpToDate(picked);
    }
  }

  double? _dragStartX;

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Android 风格返回手势：从屏幕左缘向右滑
    final start = _dragStartX;
    _dragStartX = null;
    if (start != null && start < 32 && (details.primaryVelocity ?? 0) > 300) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entryImagesProvider = Provider.of<EntryImagesProvider>(context);

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          children: [
            const RicePaperBackground(),

            // Main List
            _groups.isEmpty
                ? const Center(child: Text(AppText.timelineEmpty))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification) {
                        // 浏览到时间轴最末端（拉到底）后，继续下滑 = 返回主界面
                        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent + 80) {
                          _triggerPop();
                          return true;
                        }
                        // 滑到最顶端，继续下拉 = 返回主界面
                        if (notification.metrics.pixels <= -80) {
                          _triggerPop();
                          return true;
                        }
                      }
                      return false;
                    },
                    child: ScrollablePositionedList.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return _buildGroupItem(
                            context, theme, group, entryImagesProvider, index);
                      },
                      itemScrollController: itemScrollController,
                      itemPositionsListener: itemPositionsListener,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      // 贴左缘，下方留出跳转胶囊的空间
                      padding: const EdgeInsets.only(
                          top: 80, bottom: 120, left: 4, right: 16),
                    ),
                  ),

            // Top Bar：统一玻璃返回按钮
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: GlassActionButton(
                icon: Icons.arrow_downward_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),

            // Jump Buttons (Bottom Bar)
            Positioned(
              left: 28,
              right: 28,
              bottom: 28,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildJumpBtn(AppText.jumpToday, () => _jumpToDate(DateTime.now())),
                        _buildJumpBtn(
                            AppText.jumpMonth,
                            () => _jumpToDate(
                                DateTime.now().subtract(const Duration(days: 30)))),
                        _buildJumpBtn(
                            AppText.jumpThreeMonths,
                            () => _jumpToDate(
                                DateTime.now().subtract(const Duration(days: 90)))),
                        _buildJumpBtn(
                            AppText.jumpYear,
                            () => _jumpToDate(
                                DateTime.now().subtract(const Duration(days: 365)))),
                        IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, size: 20),
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          onPressed: _pickDate,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildJumpBtn(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildGroupItem(BuildContext context, ThemeData theme,
      TimelineGroup group, EntryImagesProvider imageProvider, int index) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date Column
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 16),
                Text(
                  "${group.date.month}月",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${group.date.day}日",
                  style: theme.textTheme.bodyMedium,
                ),
                if (group.date.year != DateTime.now().year)
                  Text(
                    "${group.date.year}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Timeline Node
          SizedBox(
            width: 22,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Line
                Container(
                  width: 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                // Dot
                Positioned(
                  top: 24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Entries
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: group.entries
                    .map((e) => _buildEntryCard(context, theme, e, imageProvider))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, ThemeData theme, Entry entry,
      EntryImagesProvider imageProvider) {
    final images = imageProvider.getForEntry(entry);

    return GestureDetector(
      onTap: () {
        // 与添加日记共用同一个编辑界面
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => AddEditEntryPage(
            entry: entry,
            openCamera: false,
            images: images,
          ),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${entry.timeCreate.hour.toString().padLeft(2, '0')}:${entry.timeCreate.minute.toString().padLeft(2, '0')}",
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
            Text(
              entry.text.trim(),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 16, height: 1.65),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.image_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    "${images.length}",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
