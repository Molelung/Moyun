import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/models/entry.dart';
import 'package:daily_you/models/image.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/providers/entry_images_provider.dart';
import 'package:daily_you/widgets/glass_container.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:daily_you/app_text.dart';
import 'package:daily_you/config_provider.dart';
import 'package:daily_you/database/app_database.dart';
import 'package:daily_you/database/entry_dao.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
  // 布局常量：卡片高度占屏比、缩略图尺寸、单卡最多图片数
  static const double _cardHeightFactor = 0.62;
  static const double _cardMinHeight = 400;
  static const double _cardMaxHeight = 600;
  static const double _thumbSize = 110;
  static const double _thumbWidth = 90;
  static const int _maxCardImages = 4;
  static const int _infiniteInitialPage = 10000;
  static const double _pageViewportFraction = 0.88;
  PageController? _pageController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<Entry>? _searchResults;
  int _lastDeckLength = -1;
  Entry? _fallbackEntry;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isSearching = _searchFocusNode.hasFocus;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoBackupPermission();
      _loadFallbackEntry();
    });
  }

  /// 无今日记录时，从全库加载「那年今日」或随机一篇（不依赖分页内存列表）
  Future<void> _loadFallbackEntry() async {
    final now = DateTime.now();
    final entry = await EntryDao.getOnThisDayEntry(now.month, now.day) ??
        await EntryDao.getRandomEntry();
    if (mounted && entry != null) {
      setState(() => _fallbackEntry = entry);
    }
  }

  Future<void> _checkAutoBackupPermission() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    bool useExternalDb = configProvider.get(ConfigKey.useExternalDb) ?? false;
    
    // 如果没有开启外部备份，且之前没有拒绝过（这里简单处理为只要没开就弹，或者通过另一个标识位记录）
    // 为了防止每次启动都弹窗烦人，可以使用一个标识位。
    bool hasPrompted = configProvider.get(ConfigKey.hasPromptedAutoBackup) ?? false;
    if (!useExternalDb && !hasPrompted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(AppText.backupDialogTitle),
            content: const Text(AppText.backupDialogContent),
            actions: [
              TextButton(
                onPressed: () async {
                  await configProvider.set(ConfigKey.hasPromptedAutoBackup, true);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text(AppText.backupLater,
                    style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  if (context.mounted) Navigator.of(context).pop();
                  // 目录选择/备份配置成功后才记录已提示，
                  // 失败时保留标志，下次启动仍会引导
                  final ok = await AppDatabase.instance
                      .selectExternalLocation((status) {});
                  if (ok) {
                    await configProvider
                        .set(ConfigKey.hasPromptedAutoBackup, true);
                  }
                },
                child: const Text(AppText.backupChoose),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onPanEnd(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    
    if (_isSearching) {
      if (details.primaryVelocity!.abs() > 300) {
        _searchFocusNode.unfocus();
      }
      return;
    }

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

  /// 执行搜索并更新结果
  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (!mounted) return;
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchResults = null;
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearchLoading = true);
    final entriesProvider =
        Provider.of<EntriesProvider>(context, listen: false);
    final results = await entriesProvider.search(query);
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _searchResults = results;
        _isSearchLoading = false;
      });
    }
  }

  /// 点击确认：立刻完成搜索并退回主界面展示结果
  void _confirmSearch() {
    EasyDebounce.cancel("home-search");
    _searchFocusNode.unfocus();
    _runSearch(_searchController.text);
    setState(() => _isSearching = false);
  }



  Widget _buildSearchField() {
    final theme = Theme.of(context);
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      radius: 24,
      blur: 8,
      child: TextField(
        focusNode: _searchFocusNode,
        controller: _searchController,
        onChanged: (value) {
          if (mounted) setState(() => _isSearchLoading = true);
          // 防抖：停止输入 250ms 后才重建结果
          EasyDebounce.debounce(
              "home-search", const Duration(milliseconds: 250),
              () => _runSearch(value));
        },
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: AppText.searchHint,
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                    height: _thumbSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final image in images.take(_maxCardImages))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: _thumbWidth,
                                height: _thumbSize,
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

    // 搜索模式：命中所有日记；否则展示今日日记
    final List<Entry> deck;
    if (_searchQuery.trim().isNotEmpty) {
      deck = _searchResults ?? [];
    } else {
      deck = todays;
    }

    final bool isOverallLoading = entriesProvider.isLoading && entriesProvider.entries.isEmpty;
    final bool showLoading = isOverallLoading || _isSearchLoading;

    // 无今日记录时的回退（已异步从全库加载）
    final Entry? fallbackEntry = _fallbackEntry;
    final fallbackImages = fallbackEntry != null
        ? entryImagesProvider.getForEntry(fallbackEntry)
        : <EntryImage>[];

    final cardHeight = (MediaQuery.of(context).size.height * _cardHeightFactor)
        .clamp(_cardMinHeight, _cardMaxHeight);

    if (_pageController == null || _lastDeckLength != deck.length) {
      _lastDeckLength = deck.length;
      int initial = _infiniteInitialPage;
      if (deck.isNotEmpty) {
        initial = _infiniteInitialPage - (_infiniteInitialPage % deck.length);
      }
      _pageController?.dispose();
      _pageController = PageController(
          initialPage: initial, viewportFraction: _pageViewportFraction);
    }

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
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSearching ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: GlassActionButton(
                    icon: Icons.explore_rounded,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const WanderPage(),
                      ));
                    },
                  ),
                ),
              ),
            ),

            // Top Right: [＋][⚙]
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSearching ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassActionButton(
                        icon: Icons.add_rounded,
                        onTap: _addNewEntry,
                      ),
                      const SizedBox(width: 8),
                      GlassActionButton(
                        icon: Icons.settings_rounded,
                        onTap: _openSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Center Card(s)：PageView 支持跟手滑动动画
            // 搜索时展示匹配的日记，否则展示今日日记
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSearching ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isSearching,
                  child: showLoading 
                  ? SizedBox(
                      height: cardHeight,
                      child: Center(
                        child: SpinKitPouringHourGlassRefined(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 60.0,
                        ),
                      ),
                    )
                  : deck.isNotEmpty
                  ? SizedBox(
                      height: cardHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        itemBuilder: (context, index) {
                          final realIndex = index % deck.length;
                          final entry = deck[realIndex];
                          final images =
                              entryImagesProvider.getForEntry(entry);
                          // 编号：今日模式 最新=最大；搜索模式按命中顺序
                          return _buildCard(
                              context, entry, images, deck.length - realIndex);
                        },
                      ),
                    )
                  : SizedBox(
                      height: cardHeight,
                      child: _buildCard(
                        context,
                        fallbackEntry ??
                            Entry(
                              text: AppText.emptyDiary,
                              timeCreate: now,
                              timeModified: now,
                            ),
                        fallbackImages,
                        0,
                      ),
                    ),
              ),
            ),
          ),

            // 底部搜索框（卡片下方的空白处）
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: _isSearching ? Alignment.center : Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  padding: _isSearching
                      ? const EdgeInsets.symmetric(horizontal: 32.0)
                      : const EdgeInsets.only(left: 28.0, right: 28.0, bottom: 28.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(child: _buildSearchField()),
                      if (_isSearching) ...[
                        const SizedBox(width: 10),
                        GlassActionButton(
                          icon: Icons.check_rounded,
                          onTap: _confirmSearch,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
