import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../services/session_service.dart';
import 'role_picker_screen.dart';

/// Child's own profile screen — view-only info + logout.
/// Shows avatar, name, age, stats, and a switch-profile / logout button.
class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final child = SampleData.activeChild;

    return Container(
      decoration:
          const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text('My Profile',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 28),

              // ── Avatar Card ──
              GlassCard(
                padding: const EdgeInsets.all(28),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPurple.withOpacity(0.12),
                    AppTheme.surfaceCard,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderColor: AppTheme.accentPurple.withOpacity(0.25),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPurple.withOpacity(0.12),
                        border: Border.all(
                            color: AppTheme.accentPurple.withOpacity(0.4),
                            width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPurple.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(child.avatarEmoji,
                            style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      child.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.accentPurple.withOpacity(0.1),
                      ),
                      child: Text(
                        'Age ${child.age}',
                        style: const TextStyle(
                          color: AppTheme.accentPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Stats Grid ──
              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.timer_outlined,
                      label: 'Daily Limit',
                      value:
                          '${child.dailyLimitMinutes ~/ 60}h ${child.dailyLimitMinutes % 60}m',
                      color: AppTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.stars_rounded,
                      label: 'Total Points',
                      value: '${child.rewardPoints}',
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.phone_android_rounded,
                      label: 'Used Today',
                      value:
                          '${child.usedMinutes ~/ 60}h ${child.usedMinutes % 60}m',
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileStat(
                      icon: Icons.emoji_events_rounded,
                      label: 'Status',
                      value: child.rewardPoints >= 100
                          ? '🏆 Champion'
                          : child.rewardPoints >= 50
                              ? '⭐ Rising'
                              : '🌱 Starter',
                      color: AppTheme.accentPurple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Achievements preview ──
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Achievements',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              _AchievementRow(),

              const SizedBox(height: 32),

              // ── Switch Profile / Log Out ──
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Switch Profile?',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700)),
                      content: const Text(
                        'You will be taken back to the role selection screen.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: AppTheme.textMuted)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SessionService.clearSession();
                            SampleData.reset();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) =>
                                      const RolePickerScreen(),
                                  transitionsBuilder:
                                      (_, anim, __, child) =>
                                          FadeTransition(
                                              opacity: anim, child: child),
                                  transitionDuration:
                                      const Duration(milliseconds: 400),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Switch',
                              style: TextStyle(
                                  color: AppTheme.accentPurple,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                },
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppTheme.accentPink.withOpacity(0.15),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded,
                              color: AppTheme.accentPink, size: 18),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Switch Profile',
                          style: TextStyle(
                            color: AppTheme.accentPink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textMuted, size: 20),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Stat Widget ──────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStat({
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins')),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Achievement Row ──────────────────────────────────────────────────────────

class _AchievementRow extends StatelessWidget {
  final List<Map<String, dynamic>> _achievements = const [
    {'emoji': '🌟', 'label': 'First Day', 'unlocked': true},
    {'emoji': '🔥', 'label': '3-Day Streak', 'unlocked': false},
    {'emoji': '🏆', 'label': '100 Points', 'unlocked': false},
    {'emoji': '📚', 'label': 'Bookworm', 'unlocked': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _achievements.map((a) {
        final unlocked = a['unlocked'] as bool;
        return Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: unlocked
                    ? AppTheme.accentPurple.withOpacity(0.12)
                    : AppTheme.surfaceMid,
                border: Border.all(
                  color: unlocked
                      ? AppTheme.accentPurple.withOpacity(0.3)
                      : AppTheme.borderColor,
                ),
              ),
              child: Center(
                child: Text(
                  a['emoji'] as String,
                  style: TextStyle(
                    fontSize: 24,
                    color:
                        unlocked ? null : AppTheme.textMuted.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              a['label'] as String,
              style: TextStyle(
                color: unlocked ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
