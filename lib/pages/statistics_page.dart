import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:daily_you/providers/entries_provider.dart';
import 'package:daily_you/widgets/paper_texture.dart';
import 'package:daily_you/widgets/word_cloud.dart';
import 'package:daily_you/utils/keyword_cloud.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  double _dragUpDistance = 0;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _dragUpDistance += details.delta.dy;
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Swipe up to return to home page: either a fast flick or a clear,
    // sustained upward drag.
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
    final entriesProvider = Provider.of<EntriesProvider>(context);
    final entries = entriesProvider.entries;

    final totalEntries = entries.length;
    final totalWords = entriesProvider.wordCount;
    final entryDays = entriesProvider.getEntryDayCount();
    final avgWords = entryDays > 0 ? (totalWords / entryDays).round() : 0;

    // Extract text for word cloud
    final keywords = extractKeywords(entries, limit: 40);

    final theme = Theme.of(context);

    return Scaffold(
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onPanEnd,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          children: [
            const RicePaperBackground(),

            // Top Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                onPressed: () => Navigator.of(context).pop(),
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
                    '上滑返回',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '文辞',
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
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 0.5),
                      ),
                      child: Column(
                        children: [
                          _buildStatRow(theme, "篇数", "$totalEntries", "篇"),
                          const SizedBox(height: 16),
                          _buildStatRow(theme, "字数", "$totalWords", "字"),
                          const SizedBox(height: 16),
                          _buildStatRow(theme, "天数", "$entryDays", "天"),
                          const SizedBox(height: 16),
                          _buildStatRow(theme, "日均", "$avgWords", "字/天"),
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
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
