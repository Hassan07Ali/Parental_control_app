import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import '../services/session_service.dart';

/// A child-friendly version of the home screen.
/// Shows only the child's own usage, motivational messages, and
/// a simplified view with no admin controls.
class ChildDashboardScreen extends StatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const platform =
      MethodChannel('com.example.safescreen/usage_control');
  Timer? _pollingTimer;
  bool _hasLoadedPoints = false;

  // Motivational message animation
  late AnimationController _motivationController;
  late Animation<double> _motivationFade;

  @override
  void initState() {
    super.initState();

    _motivationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _motivationFade = CurvedAnimation(
      parent: _motivationController,
      curve: Curves.easeOut,
    );
    _motivationController.forward();

    _loadRewardPoints();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _fetchUsage();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchUsage();
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

  Future<void> _fetchUsage() async {
    try {
      final totalResult = await platform.invokeMethod(
        'getDeviceTotalUsage',
        {'startTime': _todayMidnightMs()},
      );
      if (totalResult != null && mounted) {
        setState(() {
          SampleData.children[0].usedMinutes = (totalResult as num).toInt();
        });
      }
    } catch (e) {
      debugPrint('Child dashboard usage error: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _motivationController.dispose();
    super.dispose();
  }

  String _formatTime(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }

  String _getMotivationalMessage(double pct) {
    if (pct <= 0.3) return '🌟 You\'re doing amazing! Keep it up!';
    if (pct <= 0.5) return '👍 Great balance today! Stay mindful!';
    if (pct <= 0.7) return '⏳ Over halfway — time for a break?';
    if (pct <= 0.9) return '⚡ Almost at your limit! Wind down.';
    return '🛑 You\'ve reached your daily limit!';
  }

  Color _getProgressColor(double pct) {
    if (pct <= 0.5) return AppTheme.accentGreen;
    if (pct <= 0.8) return AppTheme.accentCyan;
    return AppTheme.accentOrange;
  }

  @override
  Widget build(BuildContext context) {
    final child = SampleData.children[0];
    final pct = child.usagePercentage;
    final progressColor = _getProgressColor(pct);

    return Container(
      decoration:
          const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.accentPurple, width: 2),
                      ),
                      child: Center(
                          child: Text(child.avatarEmoji,
                              style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hey there!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary)),
                        Text(child.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppTheme.accentOrange.withOpacity(0.12),
                        border: Border.all(
                            color: AppTheme.accentOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Text('⭐ ',
                              style: TextStyle(fontSize: 14)),
                          Text(
                            '${child.rewardPoints}',
                            style: const TextStyle(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Motivational Message ──
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _motivationFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          progressColor.withOpacity(0.1),
                          AppTheme.surfaceMid,
                        ],
                      ),
                      border: Border.all(
                          color: progressColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: progressColor.withOpacity(0.15),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              color: AppTheme.textPrimary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getMotivationalMessage(pct),
                            style: TextStyle(
                              color: progressColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Main Usage Ring ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      CircularProgressRing(
                        progress: pct,
                        size: 160,
                        color: progressColor,
                        strokeWidth: 14,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(child.avatarEmoji,
                                style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: TextStyle(
                                color: progressColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(children: [
                          TextSpan(
                            text: _formatTime(child.usedMinutes),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const TextSpan(
                            text: ' used today',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatTime(child.remainingMinutes)} remaining out of ${_formatTime(child.dailyLimitMinutes)}',
                        style: TextStyle(
                          color: progressColor.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Stat Cards ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.timer_outlined,
                        label: 'Daily Limit',
                        value: _formatTime(child.dailyLimitMinutes),
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        icon: Icons.stars_rounded,
                        label: 'Points',
                        value: '${child.rewardPoints} ⭐',
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Daily Login Streak ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPurple.withOpacity(0.1),
                      AppTheme.surfaceCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: AppTheme.accentPurple.withOpacity(0.2),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppTheme.accentPurple.withOpacity(0.15),
                        ),
                        child: const Center(
                            child: Text('🔥', style: TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Login Streak',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Log in every day to build your streak!',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: AppGradients.purpleGlow,
                        ),
                        child: const Text(
                          '1 🔥',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Tips Section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: const SectionHeader(title: 'Tips for You'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _TipCard(
                  emoji: '📚',
                  title: 'Read a book!',
                  subtitle: 'Earn bonus points by reading instead of scrolling.',
                  color: AppTheme.accentGreen,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: _TipCard(
                  emoji: '🏃',
                  title: 'Go play outside!',
                  subtitle: 'Fresh air boosts your mood and earns you more pet happiness.',
                  color: AppTheme.accentCyan,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ─── Mini Stat Card ───────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.surfaceMid,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Tip Card ─────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _TipCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surfaceMid,
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.12),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
