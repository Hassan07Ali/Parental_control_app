import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const platform = MethodChannel('com.example.safescreen/usage_control');

  bool _isLoading = true;
  List<DailyUsageEntry>    _weeklyData              = [];
  Map<AppCategory, int>    _todayCategoryBreakdown  = {};
  int                      _todayUsedMinutes        = 0;
  Timer?                   _liveTimer;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    // Refresh today's screen time every 30 seconds so the card stays live
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchTodayUsage();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchWeeklyData(),
      _fetchCategorizedUsage(),
      _fetchTodayUsage(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchWeeklyData() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) {
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _weeklyData = List.generate(7, (i) {
            final date = now.subtract(Duration(days: 6 - i));
            return DailyUsageEntry(date: date, totalMinutes: 30 + (i * 10)); // Mock trend
          });
        });
      }
      return;
    }

    try {
      final result = await platform.invokeMethod('getWeeklyUsage');
      if (result != null && mounted) {
        final data       = result as Map<dynamic, dynamic>;
        final sortedKeys = data.keys.toList()..sort();
        final entries    = <DailyUsageEntry>[];

        for (final key in sortedKeys) {
          final parts   = (key as String).split('-');
          final date    = DateTime(int.parse(parts[0]),
                                   int.parse(parts[1]),
                                   int.parse(parts[2]));
          final minutes = (data[key] as num).toInt();
          entries.add(DailyUsageEntry(date: date, totalMinutes: minutes));
        }

        if (mounted) {
          setState(() {
            _weeklyData           = entries;
            SampleData.weeklyHistory = entries;
          });
        }
      }
    } catch (e) {
      debugPrint('Weekly usage error: $e');
    }
  }

  Future<void> _fetchCategorizedUsage() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) {
      if (mounted) {
        setState(() {
          _todayCategoryBreakdown = {
            AppCategory.education: 20,
            AppCategory.gaming: 15,
            AppCategory.socialMedia: 10,
          };
        });
      }
      return;
    }

    try {
      final result = await platform.invokeMethod('getCategorizedUsage');
      if (result != null && mounted) {
        final appList   = result as List<dynamic>;
        final breakdown = <AppCategory, int>{};

        for (final item in appList) {
          final map      = item as Map<dynamic, dynamic>;
          final pkg      = map['packageName'] as String;
          final mins     = (map['minutes'] as num).toInt();
          final category = CategoryClassifier.classify(pkg);
          breakdown[category] = (breakdown[category] ?? 0) + mins;
        }

        if (mounted) setState(() => _todayCategoryBreakdown = breakdown);
      }
    } catch (e) {
      debugPrint('Categorized usage error: $e');
    }
  }

  /// Fetches today's total device screen time directly from Android
  /// so the "Today's Screen Time" card is always accurate.
  Future<void> _fetchTodayUsage() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) {
      if (mounted) {
        setState(() {
          _todayUsedMinutes = 45;
          SampleData.children[0].usedMinutes = 45;
        });
      }
      return;
    }

    try {
      final result = await platform.invokeMethod('getDeviceTotalUsage');
      if (result != null && mounted) {
        final mins = (result as num).toInt();
        setState(() {
          _todayUsedMinutes                    = mins;
          SampleData.children[0].usedMinutes   = mins;
        });
      }
    } catch (e) {
      debugPrint('Today usage error: $e');
      // Fallback: use whatever HomeScreen already put in SampleData
      if (mounted) {
        setState(() => _todayUsedMinutes = SampleData.children[0].usedMinutes);
      }
    }
  }

  // ── Stats (skip zero-days so they don't skew average / lowest) ────────────

  List<DailyUsageEntry> get _activeDays =>
      _weeklyData.where((e) => e.totalMinutes > 0).toList();

  int _averageMinutes() {
    final active = _activeDays;
    if (active.isEmpty) return 0;
    return active.fold(0, (s, e) => s + e.totalMinutes) ~/ active.length;
  }

  int _highestMinutes() {
    if (_weeklyData.isEmpty) return 0;
    return _weeklyData
        .map((e) => e.totalMinutes)
        .reduce((a, b) => a > b ? a : b);
  }

  int _lowestMinutes() {
    final active = _activeDays;
    if (active.isEmpty) return 0;
    return active
        .map((e) => e.totalMinutes)
        .reduce((a, b) => a < b ? a : b);
  }

  String _fmt(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final child = SampleData.children[0];

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
            : CustomScrollView(
                slivers: [

                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Activity',
                                  style: Theme.of(context).textTheme.headlineLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text("${child.name}'s Weekly Report",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.textSecondary)),
                            ],
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _fetchAll,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.surfaceMid,
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Icon(Icons.refresh,
                                  color: AppTheme.accentCyan, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bar Chart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Screen Time (Last 7 Days)',
                                style: TextStyle(color: AppTheme.textPrimary,
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            // Colour legend
                            const Wrap(spacing: 12, runSpacing: 4,
                              children: [
                                _LegendDot(color: AppTheme.accentOrange, label: 'Highest'),
                                _LegendDot(color: AppTheme.accentGreen,  label: 'Lowest'),
                                _LegendDot(color: AppTheme.accentCyan,   label: 'Today'),
                                _LegendDot(color: AppTheme.accentPurple, label: 'Other'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: _weeklyData.isEmpty
                                  ? const Center(child: Text(
                                      'No usage data yet.\n'
                                      'Grant Usage Access permission on your device.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppTheme.textMuted)))
                                  : _buildBarChart(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Summary stats
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(children: [
                        Expanded(child: _summaryCard('Average',
                            _weeklyData.isEmpty ? '0m' : _fmt(_averageMinutes()),
                            Icons.trending_up_rounded, AppTheme.accentCyan)),
                        const SizedBox(width: 12),
                        Expanded(child: _summaryCard('Highest',
                            _weeklyData.isEmpty ? '0m' : _fmt(_highestMinutes()),
                            Icons.arrow_upward_rounded, AppTheme.accentOrange)),
                        const SizedBox(width: 12),
                        Expanded(child: _summaryCard('Lowest',
                            _weeklyData.isEmpty ? '0m' : _fmt(_lowestMinutes()),
                            Icons.arrow_downward_rounded, AppTheme.accentGreen)),
                      ]),
                    ),
                  ),

                  // Today's screen time vs daily limit (live)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _buildTodayCard(child),
                    ),
                  ),

                  // Category breakdown header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Text("Today's Category Breakdown",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),

                  if (_todayCategoryBreakdown.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(padding: EdgeInsets.all(24),
                        child: Center(child: Text(
                          'No categorized usage data yet.\n'
                          'Use your device to generate data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted))),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        // Sort biggest first
                        final sorted = _todayCategoryBreakdown.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final entry      = sorted[i];
                        final totalToday = _todayCategoryBreakdown.values
                            .fold(0, (a, b) => a + b);
                        final pct = totalToday > 0
                            ? entry.value / totalToday : 0.0;
                        return Padding(
                          padding: EdgeInsets.fromLTRB(24, i == 0 ? 12 : 8, 24, 0),
                          child: _CategoryRow(
                              category:   entry.key,
                              minutes:    entry.value,
                              percentage: pct),
                        );
                      }, childCount: _todayCategoryBreakdown.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────────────

  Widget _buildBarChart() {
    final highest = _highestMinutes();
    final lowest  = _lowestMinutes();
    final maxVal  = highest.toDouble();
    final today   = DateTime.now();

    return BarChart(BarChartData(
      maxY: maxVal > 0 ? maxVal * 1.25 : 120,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
            rod.toY.toInt() == 0 ? 'No data' : _fmt(rod.toY.toInt()),
            const TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, _) {
            final i       = value.toInt();
            if (i < 0 || i >= _weeklyData.length) return const SizedBox.shrink();
            final day     = _weeklyData[i].date;
            final isToday = day.year  == today.year &&
                            day.month == today.month &&
                            day.day   == today.day;
            const names   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(names[day.weekday - 1],
                style: TextStyle(
                  color:      isToday ? AppTheme.accentCyan : AppTheme.textMuted,
                  fontSize:   11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
            );
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData:   const FlGridData(show: false),
      barGroups: List.generate(_weeklyData.length, (i) {
        final entry   = _weeklyData[i];
        final mins    = entry.totalMinutes;
        final isToday = entry.date.year  == today.year &&
                        entry.date.month == today.month &&
                        entry.date.day   == today.day;

        Color barColor;
        if (mins == 0) {
          barColor = AppTheme.surfaceLight;
        } else if (mins == highest && highest > 0) {
          barColor = AppTheme.accentOrange;
        } else if (mins == lowest && lowest > 0 && mins != highest) {
          barColor = AppTheme.accentGreen;
        } else if (isToday) {
          barColor = AppTheme.accentCyan;
        } else {
          barColor = AppTheme.accentPurple;
        }

        return BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY:   mins.toDouble(),
            color: barColor,
            width: 28,
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(6),
              topRight: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show:  true,
              toY:   maxVal > 0 ? maxVal * 1.25 : 120,
              color: AppTheme.surfaceLight),
          ),
        ]);
      }),
    ));
  }

  // ── Today's limit progress card ───────────────────────────────────────────

  Widget _buildTodayCard(ChildProfile child) {
    final used      = _todayUsedMinutes;
    final limit     = child.dailyLimitMinutes;
    final pct       = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = (limit - used).clamp(0, limit);
    final color     = pct > 0.85 ? AppTheme.accentOrange
                    : pct > 0.60 ? AppTheme.accentCyan
                    : AppTheme.accentGreen;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Today's Screen Time",
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          Text('${(pct * 100).toInt()}%',
              style: TextStyle(color: color, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:      pct,
            backgroundColor: AppTheme.surfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight:  8),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_fmt(used)} used',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text('${_fmt(remaining)} left of ${_fmt(limit)}',
              style: TextStyle(color: color, fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Summary stat card ─────────────────────────────────────────────────────

  Widget _summaryCard(String label, String value, IconData icon, Color color) =>
      GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(color: color, fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ]),
      );
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w600)),
    ]);
}

// ── Category row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  final AppCategory category;
  final int         minutes;
  final double      percentage;
  const _CategoryRow({required this.category, required this.minutes,
      required this.percentage});

  String _fmt(int m) {
    if (m >= 60) { final h = m ~/ 60; final r = m % 60;
      return r > 0 ? '${h}h ${r}m' : '${h}h'; }
    return '${m}m';
  }

  Color get _color {
    switch (category) {
      case AppCategory.education:    return AppTheme.accentGreen;
      case AppCategory.socialMedia:  return AppTheme.accentPink;
      case AppCategory.gaming:       return AppTheme.accentOrange;
      case AppCategory.productivity: return AppTheme.accentCyan;
      case AppCategory.others:       return AppTheme.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            color: _color.withOpacity(0.15)),
        child: Center(child: Text(category.emoji,
            style: const TextStyle(fontSize: 20)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(category.displayName,
                style: const TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            Text(_fmt(minutes),
                style: TextStyle(color: _color, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:      percentage.clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(_color),
              minHeight:  4)),
        ])),
    ]),
  );
}