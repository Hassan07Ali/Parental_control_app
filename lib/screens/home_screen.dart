import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import '../services/session_service.dart';
import '../database/db_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.example.safescreen/usage_control');
  Timer? _pollingTimer;
  Map<AppCategory, int> _categoryBreakdown = {};
  bool _hasLoadedPoints = false;

  @override
  void initState() {
    super.initState();
    _loadRewardPoints();

    // FIX: Wait 2 s so MainShell._loadSessionData() can finish reading DB
    // and populate SampleData.recentApps before the first poll fires.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _fetchBatchTimes();
        _fetchCategorizedUsage();
      }
    });

    // After the initial delay, keep polling every 5 seconds for live data.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchBatchTimes();
      _fetchCategorizedUsage();
    });
  }

  Future<void> _loadRewardPoints() async {
    if (_hasLoadedPoints) return;
    final child = await SessionService.getActiveChild();
    if (child != null && mounted) {
      setState(() {
        SampleData.children[0].rewardPoints = child.rewardPoints;
        _hasLoadedPoints = true;
      });
    }
  }

  int _todayMidnightMs() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  Future<void> _fetchBatchTimes() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) {
      if (mounted) {
        setState(() {
          SampleData.children[0].usedMinutes = 45; // Mock data for parent view
          for (final app in SampleData.recentApps) {
            app.minutesUsed = (app.limitMinutes * 0.4).toInt();
          }
        });
      }
      return;
    }

    // 1. Total device screen time — FIX: pass startTime so Android side
    //    queries only from today's midnight, not from an undefined point.
    try {
      final totalResult = await platform.invokeMethod(
        'getDeviceTotalUsage',
        {'startTime': _todayMidnightMs()}, // <-- FIX: was called with no arguments
      );
      if (totalResult != null && mounted) {
        setState(() {
          SampleData.children[0].usedMinutes = (totalResult as num).toInt();
        });
        await _checkAndAwardDailyPoints();
      }
    } catch (e) {
      debugPrint('Global usage error: $e');
    }

    // 2. Per-app remaining times
    if (SampleData.recentApps.isEmpty) return;

    final Map<String, int> activeLimits = {
      for (final app in SampleData.recentApps) app.packageName: app.limitMinutes
    };

    try {
      final result = await platform.invokeMethod(
          'getBatchRemainingTime', {'appLimits': activeLimits});

      if (result != null && mounted) {
        final Map<dynamic, dynamic> resultMap = result as Map<dynamic, dynamic>;
        setState(() {
          for (final app in SampleData.recentApps) {
            final raw = resultMap[app.packageName];
            if (raw != null) {
              final remaining      = (raw as num).toInt();
              final calculatedUsed = app.limitMinutes - remaining;
              app.minutesUsed      = calculatedUsed.clamp(0, app.limitMinutes);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Batch polling error: $e');
    }
  }

  Future<void> _fetchCategorizedUsage() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) {
      if (mounted) {
        setState(() {
          _categoryBreakdown = {
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
        final List<dynamic> appList = result as List<dynamic>;
        final Map<AppCategory, int> breakdown = {};

        for (final item in appList) {
          final map      = item as Map<dynamic, dynamic>;
          final pkg      = map['packageName'] as String;
          final mins     = (map['minutes'] as num).toInt();
          final category = CategoryClassifier.classify(pkg);
          breakdown[category] = (breakdown[category] ?? 0) + mins;
        }

        if (mounted) setState(() => _categoryBreakdown = breakdown);
      }
    } catch (e) {
      debugPrint('Categorized usage error: $e');
    }
  }

  Future<void> _checkAndAwardDailyPoints() async {
    final isParent = await SessionService.isParentLoggedIn();
    if (isParent) return; // Don't award points based on mock/parent data

    final child   = SampleData.children[0];
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;
    if (SampleData.recentApps.isEmpty) return;

    final prefs          = await SharedPreferences.getInstance();
    final lastCreditDate = prefs.getString('last_award_date');
    final yesterday      = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr   =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (lastCreditDate == yesterdayStr) return;

    try {
      final weeklyData = await platform.invokeMethod('getWeeklyUsage');
      if (weeklyData != null && weeklyData[yesterdayStr] != null) {
        final yesterdayMins = (weeklyData[yesterdayStr] as num).toInt();
        if (yesterdayMins <= child.dailyLimitMinutes && yesterdayMins > 0) {
          setState(() => child.rewardPoints += 10);
          await DbHelper().updateRewardPoints(childId, child.rewardPoints);
          await prefs.setString('last_award_date', yesterdayStr);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('⭐ Stayed under limit yesterday! +10 Points'),
              backgroundColor: AppTheme.accentGreen,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Award check error: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  int get _productiveMinutes =>
      (_categoryBreakdown[AppCategory.education] ?? 0) +
      (_categoryBreakdown[AppCategory.productivity] ?? 0);

  int get _totalCategorizedMinutes =>
      _categoryBreakdown.values.fold(0, (a, b) => a + b);

  String _formatTime(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final child  = SampleData.children[0];
    final parent = SampleData.parentProfile;
    final pct    = child.usagePercentage;
    final progressColor = pct > 0.8
        ? AppTheme.accentOrange
        : pct > 0.6
            ? AppTheme.accentCyan
            : AppTheme.accentGreen;
    final productivityScore = ChildProfile.computeProductivityScore(
        _productiveMinutes, _totalCategorizedMinutes);

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello,',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary)),
                        Text(parent.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppTheme.surfaceMid,
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_outlined,
                              color: AppTheme.textPrimary, size: 22),
                          Positioned(
                            top: -3, right: -3,
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentCyan, width: 2),
                      ),
                      child: const Center(
                          child: Text('👨', style: TextStyle(fontSize: 22))),
                    ),
                  ],
                ),
              ),
            ),

            // Main Screen Time Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircularProgressRing(
                        progress: pct,
                        size: 100,
                        color: progressColor,
                        strokeWidth: 10,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(child.avatarEmoji,
                                style: const TextStyle(fontSize: 24)),
                            Text('${(pct * 100).toInt()}%',
                                style: TextStyle(
                                    color: progressColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(child.name,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: _formatTime(child.usedMinutes),
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      fontFamily: 'Poppins'),
                                ),
                                const TextSpan(
                                  text: ' used',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 6),
                            Text('${_formatTime(child.remainingMinutes)} remaining',
                                style: TextStyle(
                                    color: progressColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4 Stat Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatMiniCard(
                        value: _formatTime(child.usedMinutes),
                        label: 'Screen Time',
                        icon: Icons.phone_android_rounded,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatMiniCard(
                        value: _formatTime(child.remainingMinutes),
                        label: 'Remaining',
                        icon: Icons.hourglass_bottom_rounded,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: StatMiniCard(
                        value: '${productivityScore.toInt()}%',
                        label: 'Productivity',
                        icon: Icons.trending_up_rounded,
                        color: AppTheme.accentPurple,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatMiniCard(
                        value: '${child.rewardPoints} ⭐',
                        label: 'Reward Points',
                        icon: Icons.stars_rounded,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active Restrictions header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: SectionHeader(title: 'Active Restrictions'),
              ),
            ),

            if (SampleData.recentApps.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No apps are currently restricted.\nNavigate to Controls to set limits.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: EdgeInsets.fromLTRB(24, i == 0 ? 16 : 8, 24, 0),
                    child: _AppUsageRow(app: SampleData.recentApps[i]),
                  ),
                  childCount: SampleData.recentApps.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  final AppUsage app;
  const _AppUsageRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final pct = app.limitMinutes > 0
        ? (app.minutesUsed / app.limitMinutes).clamp(0.0, 1.0)
        : 0.0;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.surfaceLight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: app.iconBytes != null
                  ? Image.memory(app.iconBytes!, fit: BoxFit.cover)
                  : const Center(
                      child: Text('📱', style: TextStyle(fontSize: 22))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(app.appName,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${app.minutesUsed} / ${app.limitMinutes} m',
                        style: const TextStyle(
                            color: AppTheme.accentCyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.accentCyan),
                      minHeight: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}