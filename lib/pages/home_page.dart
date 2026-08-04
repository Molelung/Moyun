import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/widgets/glass_container.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:daily_you/widgets/local_image_loader.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/pages/edit_entry_page.dart';
import 'package:daily_you/pages/settings_page.dart';
import 'package:daily_you/pages/timeline_page.dart';
import 'package:daily_you/pages/statistics_page.dart';
import 'package:daily_you/pages/wander_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 中文小写数字：一、二、三…（用于日期）
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

/// 中文大写（财务）数字：壹、贰、叁…（用于卡片编号，最新的数字最大）
String _toFinancialNumber(int num) {
  const digits = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖'];
  if (num < 10) return digits[num - 1];
  if (num < 20) return '拾${num % 10 == 0 ? '' : digits[num % 10 - 1]}';
  if (num < 100) {
    return '${digits[num ~/ 10 - 1]}拾${num % 10 == 0 ? '' : digits[num % 10 - 1]}';
  }
  return num.toString();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPanEnd(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < -300) {
      // Swipe up -> Timeline (enters sliding up from the bottom)
      _pushFromBottom(const TimelinePage());
    } else if (details.primaryVelocity! > 300) {
      // Swipe down -> Statistics (enters sliding down from the top)
      _pushFromTop(const StatsPage());
    }
  }

  void _pushFromBottom(Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => page,
      transitionsBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    ));
  }

  void _pushFromTop(Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => page,
      transitionsBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const SettingsPage(),
    ));
  }

  void _addNewEntry() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const AddEditEntryPage(
        entry: null,
        openCamera: false,
        images: [],
      ),
    ));
  }

  void _openEntry(Entry entry, List<EntryImage> images) {
    // 与添加日记共用同一个编辑界面
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => AddEditEntryPage(
        entry: entry,
        openCamera: false,
        images: images,
      ),
    ));
  }

  Widget _buildTopButton(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          ),
          child: IconButton(
            iconSize: 22,
            padding: const EdgeInsets.all(9),
            icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      radius: 24,
      blur: 8,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          // 防抖：停止输入 250ms 后才重建结果
          EasyDebounce.debounce(
              "home-search", const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _searchQuery = value);
          });
        },
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: "寻觅往昔……",
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          icon: Icon(Icons.search_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// 一张完整的磨砂玻璃卡片
  Widget _buildCard(
      BuildContext context, Entry entry, List<EntryImage> images, int number) {
    final theme = Theme.of(context);
    final dateStr =
        "${_toChineseNumber(entry.timeCreate.year, isYear: true)}年${_toChineseNumber(entry.timeCreate.month)}月${_toChineseNumber(entry.timeCreate.day)}日";
    final showTitle = entry.title != null && entry.title!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openEntry(entry, images),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
                  dateStr,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                if (showTitle) ...[
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
                // 正文：文字少时靠上，文字多时可滚动
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
                // 图片放在文字下面
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
                                child: LocalImageLoader(
                                    imagePath: image.imgPath),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (number > 0)
                  Text(
                    _toFinancialNumber(number),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesProvider = Provider.of<EntriesProvider>(context);
    final entryImagesProvider = Provider.of<EntryImagesProvider>(context);

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final todays = entriesProvider.entries.where((e) {
      return "${e.timeCreate.year}-${e.timeCreate.month}-${e.timeCreate.day}" ==
          todayStr;
    }).toList();
    // 按时间倒序：最新在前
    todays.sort((a, b) => b.timeCreate.compareTo(a.timeCreate));

    final l10n = AppLocalizations.of(context);

    // 搜索模式：命中所有日记；否则展示今日日记
    final List<Entry> deck;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      deck = entriesProvider.entries
          .where((e) =>
              e.text.toLowerCase().contains(query) ||
              (e.title?.toLowerCase().contains(query) ?? false))
          .toList()
        ..sort((a, b) => b.timeCreate.compareTo(a.timeCreate));
    } else {
      deck = todays;
    }

    // 无今日记录时的随机回退
    Entry? fallbackEntry;
    if (todays.isEmpty && entriesProvider.entries.isNotEmpty) {
      final seed = now.year * 10000 + now.month * 100 + now.day;
      fallbackEntry = entriesProvider
          .entries[Random(seed).nextInt(entriesProvider.entries.length)];
    }
    final fallbackImages = fallbackEntry != null
        ? entryImagesProvider.getForEntry(fallbackEntry)
        : <EntryImage>[];

    final cardHeight =
        (MediaQuery.of(context).size.height * 0.62).clamp(400.0, 600.0);

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: _onPanEnd,
        child: Stack(
          children: [
            const RicePaperBackground(),

            // Top Left: 漫游模式
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: _buildTopButton(Icons.explore_rounded, () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const WanderPage(),
                ));
              }),
            ),

            // Top Right: [＋][⚙]
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopButton(Icons.add_rounded, _addNewEntry),
                  const SizedBox(width: 8),
                  _buildTopButton(Icons.settings_rounded, _openSettings),
                ],
              ),
            ),

            // Center Card(s)：PageView 支持跟手滑动动画
            // 搜索时展示匹配的日记，否则展示今日日记
            Center(
              child: deck.isNotEmpty
                  ? SizedBox(
                      height: cardHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: deck.length,
                        itemBuilder: (context, index) {
                          final entry = deck[index];
                          final images =
                              entryImagesProvider.getForEntry(entry);
                          // 编号：今日模式 最新=最大；搜索模式按命中顺序
                          return _buildCard(
                              context, entry, images, deck.length - index);
                        },
                      ),
                    )
                  : SizedBox(
                      height: cardHeight,
                      child: _buildCard(
                        context,
                        fallbackEntry ??
                            Entry(
                              text: l10n?.pageHomeTitle ??
                                  "今日无事，唯有清风。",
                              timeCreate: now,
                              timeModified: now,
                            ),
                        fallbackImages,
                        0,
                      ),
                    ),
            ),

            // 底部搜索框（卡片下方的空白处）
            Positioned(
              left: 28,
              right: 28,
              bottom: 28,
              child: _buildSearchField(),
            ),
          ],
        ),
      ),
    );
  }
}
