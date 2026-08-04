import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/database/entry_dao.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/widgets/glass_action_button.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/word_cloud.dart';
import 'package:daily_you/app_text.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final Future<Map<String, dynamic>> _statsFuture;

  double _dragUpDistance = 0;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  /// 统计信息在后台加载：全量聚合直查数据库，不受分页加载影响
  Future<Map<String, dynamic>> _loadStats() async {
    final totalEntries = await EntryDao.getCount();
    final entryDays = await EntryDao.getUniqueDaysCount();
    final keywords = await EntryDao.getTopKeywords(totalEntries, limit: 40);
    return {
      'totalEntries': totalEntries,
      'entryDays': entryDays,
      'keywords': keywords,
    };
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragUpDistance += details.delta.dy;
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // 上滑返回主界面：快速上滑或明确的上拉
    if (velocity < -250 || (velocity.abs() < 250 && _dragUpDistance < -120)) {
      Navigator.of(context).pop();
    }
    _dragUpDistance = 0;
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
    final totalWords = Provider.of<EntriesProvider>(context).wordCount;
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            );
          }

          final stats = snapshot.data!;
          final totalEntries = stats['totalEntries'] as int;
          final entryDays = stats['entryDays'] as int;
          final keywords = stats['keywords'] as Map<String, int>;
          final avgWords = entryDays > 0 ? (totalWords / entryDays).round() : 0;

          return GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onPanEnd,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Stack(
              children: [
                const RicePaperBackground(),

                // Top Bar：统一玻璃返回按钮
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  child: GlassActionButton(
                    icon: Icons.arrow_upward_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),

                // Back hint (bottom)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        AppText.backHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 48.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppText.statsTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ).animate().fadeIn(
                            duration: 600.ms, curve: Curves.easeOutQuart)
                          .slideY(begin: -0.2, end: 0,
                              duration: 600.ms, curve: Curves.easeOutQuart),
                        const SizedBox(height: 48),

                        // Simple Stats
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 0.5),
                          ),
                          child: Column(
                            children: [
                              _buildStatRow(theme, AppText.statEntries,
                                  "$totalEntries", AppText.unitEntries),
                              const SizedBox(height: 16),
                              _buildStatRow(theme, AppText.statWords,
                                  "$totalWords", AppText.unitWords),
                              const SizedBox(height: 16),
                              _buildStatRow(theme, AppText.statDays,
                                  "$entryDays", AppText.unitDays),
                              const SizedBox(height: 16),
                              _buildStatRow(theme, AppText.statDaily,
                                  "$avgWords", AppText.unitDaily),
                            ],
                          ),
                        ).animate().fadeIn(
                            delay: 150.ms,
                            duration: 600.ms,
                            curve: Curves.easeOutQuart)
                          .slideY(begin: 0.1, end: 0,
                              duration: 600.ms, curve: Curves.easeOutQuart),

                        const SizedBox(height: 48),

                        // Word Cloud
                        Expanded(
                          child: SingleChildScrollView(
                            child: WordCloud(
                              keywords: keywords,
                              maxFontSize: 42,
                              minFontSize: 16,
                            ),
                          ),
                        ).animate().fadeIn(
                            delay: 300.ms,
                            duration: 600.ms,
                            curve: Curves.easeOutQuart)
                          .slideY(begin: 0.1, end: 0,
                              duration: 600.ms, curve: Curves.easeOutQuart)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(
      ThemeData theme, String label, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
