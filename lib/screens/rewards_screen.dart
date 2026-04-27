import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _pointsAnimController;
  late Animation<double> _pointsScaleAnim;

  @override
  void initState() {
    super.initState();
    _pointsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pointsScaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pointsAnimController, curve: Curves.easeOutBack),
    );
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final child = await SessionService.getActiveChild();
    if (child != null && mounted) {
      setState(() {
        SampleData.activeChild.rewardPoints = child.rewardPoints;
      });
    }
  }

  Future<void> _redeemReward(RewardOption reward) async {
    final child = SampleData.activeChild;
    if (child.rewardPoints < reward.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points!'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
      return;
    }

    setState(() {
      child.rewardPoints -= reward.cost;
      child.dailyLimitMinutes += reward.bonusMinutes;
    });

    final childId = await SessionService.getActiveChildId();
    if (childId != null) {
      await DbHelper().updateRewardPoints(childId, child.rewardPoints);
      await DbHelper().updateDailyLimit(childId, child.dailyLimitMinutes);

      // Sync new limit to native background service
      const platform = MethodChannel('com.example.safescreen/usage_control');
      try {
        final activeLimits = await DbHelper().getAppLimits(childId);
        final mapLimits = { for (var l in activeLimits) if (l.isActive) l.packageName: l.limitMinutes };
        await platform.invokeMethod('configureUsageLimit', {
          'appLimits': mapLimits,
          'globalLimit': child.dailyLimitMinutes,
        });
      } catch (e) {
        debugPrint("Failed to sync limit to Android: \$e");
      }
    }

    // Animate the points counter
    _pointsAnimController.forward().then((_) {
      _pointsAnimController.reverse();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🎉 Redeemed! +${reward.bonusMinutes} minutes added. New limit: ${child.dailyLimitMinutes}m'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pointsAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = SampleData.activeChild;

    return Container(
      decoration:
          const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text('Rewards',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),

            // Points Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(28),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accentPurple.withOpacity(0.2),
                      AppTheme.surfaceCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: AppTheme.accentPurple.withOpacity(0.3),
                  child: Column(
                    children: [
                      const Text('Your Points',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      ScaleTransition(
                        scale: _pointsScaleAnim,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('⭐ ',
                                style: TextStyle(fontSize: 36)),
                            Text(
                              '${child.rewardPoints}',
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accentPurple,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        child.rewardPoints >= 90
                            ? '🎉 You can redeem a reward!'
                            : '📈 Keep staying under your limit to earn more!',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // How Points Work
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.accentGreen.withOpacity(0.15),
                        ),
                        child: const Icon(Icons.lightbulb_outline,
                            color: AppTheme.accentGreen, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How to Earn Points',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            SizedBox(height: 2),
                            Text(
                              'Stay within your daily screen time limit and earn 10 points automatically!',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Redeem Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text('Redeem Rewards',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),

            // Reward Options
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final reward = SampleData.rewardOptions[i];
                  final canAfford = child.rewardPoints >= reward.cost;
                  return Padding(
                    padding:
                        EdgeInsets.fromLTRB(24, i == 0 ? 12 : 8, 24, 0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderColor: canAfford
                          ? AppTheme.accentGreen.withOpacity(0.3)
                          : AppTheme.borderColor,
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: canAfford
                                  ? AppTheme.accentGreen.withOpacity(0.15)
                                  : AppTheme.surfaceLight,
                            ),
                            child: Center(
                                child: Text(reward.emoji,
                                    style: const TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reward.title,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(reward.description,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${reward.cost} points',
                                    style: TextStyle(
                                        color: canAfford
                                            ? AppTheme.accentGreen
                                            : AppTheme.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: canAfford
                                ? () => _redeemReward(reward)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: canAfford
                                    ? AppTheme.accentGreen
                                    : AppTheme.surfaceLight,
                              ),
                              child: Text(
                                canAfford ? 'Redeem' : 'Locked',
                                style: TextStyle(
                                    color: canAfford
                                        ? Colors.black
                                        : AppTheme.textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: SampleData.rewardOptions.length,
              ),
            ),

            // Current Limit Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: AppTheme.accentCyan, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        "Current daily limit: ${child.dailyLimitMinutes ~/ 60}h ${child.dailyLimitMinutes % 60}m",
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
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
