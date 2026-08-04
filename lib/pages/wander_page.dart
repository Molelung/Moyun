import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/database/entry_dao.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/app_text.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/widgets/local_image_loader.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/glass_action_button.dart';

/// 漫游模式：界面与首页一致，但可以无限左滑/右滑，
/// 每次滑动随机展示某一天的日记。
class WanderPage extends StatefulWidget {
  const WanderPage({super.key});

  @override
  State<WanderPage> createState() => _WanderPageState();
}

class _WanderPageState extends State<WanderPage> {
  final PageController _pageController = PageController();
  // 已展示过的条目 id，避免短时间内重复
  final Set<int> _recent = {};
  final List<Entry> _deck = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final entries = <Entry>[];
    for (var i = 0; i < 3; i++) {
      final entry = await _pickFromDb();
      if (entry != null) entries.add(entry);
    }
    if (mounted && entries.isNotEmpty) {
      setState(() => _deck.addAll(entries));
    } else if (mounted) {
      setState(() => _deck.add(_emptyEntry()));
    }
  }

  /// 从全库随机抽取一条（不依赖分页加载的内存列表）
  Future<Entry?> _pickFromDb() async {
    for (var guard = 0; guard < 10; guard++) {
      final entry = await EntryDao.getRandomEntry();
      if (entry == null) return null;
      if (_recent.add(entry.id ?? -1)) {
        if (_recent.length > 8) _recent.remove(_recent.first);
        return entry;
      }
    }
    return await EntryDao.getRandomEntry();
  }

  Entry _emptyEntry() => Entry(
        text: AppText.emptyDiary,
        timeCreate: DateTime.now(),
        timeModified: DateTime.now(),
      );

  void _onPageChanged(int index) {
    // 向左滑到末尾时追加新的随机条目
    if (index >= _deck.length - 1) {
      _pickFromDb().then((entry) {
        if (mounted && entry != null) {
          setState(() => _deck.add(entry));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entryImagesProvider = Provider.of<EntryImagesProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const RicePaperBackground(),
          SafeArea(
            child            : _deck.isEmpty
                ? const Center(child: Text(AppText.wanderEmpty))
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _deck.length,
                    itemBuilder: (context, index) {
                      final entry = _deck[index];
                      final images =
                          entryImagesProvider.getForEntry(entry);
                      return _buildWanderCard(context, theme, entry, images);
                    },
                  ),
          ),
          // 左上角返回
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GlassActionButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWanderCard(
      BuildContext context, ThemeData theme, Entry entry, List<EntryImage> images) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 0.5),
            ),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dateString(entry.timeCreate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                if (entry.title != null && entry.title!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    entry.title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      entry.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final image in images.take(4))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 90,
                                height: 110,
                                child: LocalImageLoader(imagePath: image.imgPath),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _toChineseNumber(int num, {bool isYear = false}) {
    const digits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (isYear) {
      return num.toString().split('').map((e) => digits[int.parse(e)]).join('');
    }
    if (num < 10) return digits[num];
    if (num < 20) return '十${num % 10 == 0 ? '' : digits[num % 10]}';
    if (num < 100) {
      return '${digits[num ~/ 10]}十${num % 10 == 0 ? '' : digits[num % 10]}';
    }
    return num.toString();
  }

  String _dateString(DateTime date) =>
      "${_toChineseNumber(date.year, isYear: true)}年${_toChineseNumber(date.month)}月${_toChineseNumber(date.day)}日";
}
