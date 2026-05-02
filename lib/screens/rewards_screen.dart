import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _scaleAnim;
  int  _streakDays     = 0;
  int  _petHappiness   = 50;
  bool _showLevelUp    = false;
  int  _prevPetLevel   = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _loadData();
  }

  Future<void> _loadData() async {
    await DbHelper().migratePetColumns();
    final child = await SessionService.getActiveChild();
    if (child != null && mounted) {
      setState(() {
        SampleData.children[0].rewardPoints  = child.rewardPoints;
        SampleData.children[0].dailyLimitMinutes = child.dailyLimitMins;
        _streakDays   = child.streakDays;
        _petHappiness = child.petHappiness;
        _prevPetLevel = child.petLevel;
      });
      // Check if daily points should be awarded today
      await _checkDailyReward(child);
    }
  }

  Future<void> _checkDailyReward(child) async {
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;
    final today = _todayStr();
    final platform = const MethodChannel('com.example.safescreen/usage_control');
    int usedMins = 0;
    int eduMins  = 0;
    try {
      final total = await platform.invokeMethod('getDeviceTotalUsage');
      usedMins = (total as num).toInt();
      final cats  = await platform.invokeMethod('getCategorizedUsage') as List;
      for (final item in cats) {
        final m   = item as Map;
        final pkg = m['packageName'] as String;
        final min = (m['minutes'] as num).toInt();
        final cat = CategoryClassifier.classify(pkg);
        if (cat == AppCategory.education || cat == AppCategory.productivity) {
          eduMins += min;
        }
      }
    } catch (_) {}

    final result = await DbHelper().checkAndAwardDailyPoints(
      childId, usedMins, SampleData.children[0].dailyLimitMinutes, eduMins, today);
    final awarded = (result['awarded'] as int?) ?? 0;
    if (awarded > 0 && mounted) {
      // Reload child to get updated values
      final updated = await SessionService.getActiveChild();
      if (updated != null && mounted) {
        final newLevel = updated.petLevel;
        setState(() {
          SampleData.children[0].rewardPoints = updated.rewardPoints;
          _streakDays   = updated.streakDays;
          _petHappiness = updated.petHappiness;
          if (newLevel > _prevPetLevel) _showLevelUp = true;
          _prevPetLevel = newLevel;
        });
        _animController.forward().then((_) => _animController.reverse());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('⭐ +$awarded points! ${result['message']}'),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    }
  }

  Future<void> _redeemReward(RewardOption reward) async {
    final child = SampleData.children[0];
    if (child.rewardPoints < reward.cost) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not enough points!'),
        backgroundColor: AppTheme.accentOrange));
      return;
    }
    setState(() {
      child.rewardPoints    -= reward.cost;
      child.dailyLimitMinutes += reward.bonusMinutes;
    });
    final childId = await SessionService.getActiveChildId();
    if (childId != null) {
      await DbHelper().updateRewardPoints(childId, child.rewardPoints);
      await DbHelper().updateDailyLimit(childId, child.dailyLimitMinutes);
      const platform = MethodChannel('com.example.safescreen/usage_control');
      try {
        final limits = await DbHelper().getAppLimits(childId);
        final map    = {for (var l in limits) if (l.isActive) l.packageName: l.limitMinutes};
        await platform.invokeMethod('configureUsageLimit',
            {'appLimits': map, 'globalLimit': child.dailyLimitMinutes});
      } catch (_) {}
    }
    _animController.forward().then((_) => _animController.reverse());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🎉 +${reward.bonusMinutes} min added! Limit now ${child.dailyLimitMinutes}m'),
        backgroundColor: AppTheme.accentGreen));
    }
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final child = SampleData.children[0];
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(slivers: [

          // Header
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text('Rewards',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          )),

          // Points card
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              gradient: LinearGradient(
                colors: [AppTheme.accentPurple.withOpacity(0.2), AppTheme.surfaceCard],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderColor: AppTheme.accentPurple.withOpacity(0.3),
              child: Column(children: [
                const Text('Your Points', style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                ScaleTransition(scale: _scaleAnim,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('⭐ ', style: TextStyle(fontSize: 32)),
                      Text('${child.rewardPoints}', style: const TextStyle(
                          fontSize: 52, fontWeight: FontWeight.w800,
                          color: AppTheme.accentPurple)),
                    ])),
                const SizedBox(height: 8),
                // Streak badge
                if (_streakDays > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppTheme.accentOrange.withOpacity(0.15),
                    border: Border.all(color: AppTheme.accentOrange.withOpacity(0.4))),
                  child: Text('🔥 $_streakDays day streak!', style: const TextStyle(
                      color: AppTheme.accentOrange, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(height: 6),
                Text(child.rewardPoints >= 50
                    ? '🎉 You can redeem a reward!'
                    : '📈 Stay under your limit to earn points!',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ),
          )),

          // How to earn
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                        color: AppTheme.accentGreen.withOpacity(0.15)),
                    child: const Icon(Icons.lightbulb_outline,
                        color: AppTheme.accentGreen, size: 18)),
                  const SizedBox(width: 12),
                  const Text('How to Earn Points', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                ]),
                const SizedBox(height: 10),
                _earnRow('✅', '+10 pts', 'Stay under daily limit'),
                _earnRow('⚡', '+10 pts', 'Use less than 50% of your limit'),
                _earnRow('📚', '+5 pts', 'Per 15 min of education/productivity apps'),
                _earnRow('🔥', '+15/50/120', '3 / 7 / 14 day streaks'),
                const SizedBox(height: 4),
                const Text('Max 100 points per day',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ]),
            ),
          )),

          // Redeem header
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text('Redeem Rewards', style: Theme.of(context)
                .textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          )),

          // Reward options
          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final reward    = SampleData.rewardOptions[i];
            final canAfford = child.rewardPoints >= reward.cost;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, i == 0 ? 12 : 8, 24, 0),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                borderColor: canAfford
                    ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderColor,
                child: Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                        color: canAfford
                            ? AppTheme.accentGreen.withOpacity(0.15)
                            : AppTheme.surfaceLight),
                    child: Center(child: Text(reward.emoji,
                        style: const TextStyle(fontSize: 22)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(reward.title, style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(reward.description, style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${reward.cost} points', style: TextStyle(
                        color: canAfford ? AppTheme.accentGreen : AppTheme.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ])),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: canAfford ? () => _redeemReward(reward) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                          color: canAfford ? AppTheme.accentGreen : AppTheme.surfaceLight),
                      child: Text(canAfford ? 'Redeem' : 'Locked',
                          style: TextStyle(
                              color: canAfford ? Colors.black : AppTheme.textMuted,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ]),
              ),
            );
          }, childCount: SampleData.rewardOptions.length)),

          // Current limit
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: GlassCard(padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.timer_outlined, color: AppTheme.accentCyan, size: 20),
                const SizedBox(width: 12),
                Text('Daily limit: ${child.dailyLimitMinutes ~/ 60}h ${child.dailyLimitMinutes % 60}m',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ])),
          )),
        ]),
      ),
    );
  }

  Widget _earnRow(String emoji, String pts, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Text(pts, style: const TextStyle(
          color: AppTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(width: 6),
      Expanded(child: Text(label, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 12))),
    ]),
  );
}