import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../services/session_service.dart';
import 'auth_screen.dart';

// ─── Settings Screen ──────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionService.clearSession();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AuthScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: AppTheme.accentPink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = SampleData.parentProfile;
    final child = SampleData.children[0];

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text('Settings',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),

            // Profile card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.accentCyan, width: 2),
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF1E2D45),
                              Color(0xFF0A0E1A),
                            ],
                          ),
                        ),
                        child: const Center(
                            child: Text('👨', style: TextStyle(fontSize: 28))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(parent.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const Text('Parent Account',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.surfaceLight,
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: AppTheme.textSecondary, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Child info card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(child.avatarEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.name,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          Text('Age ${child.age} · Limit: ${child.dailyLimitMinutes ~/ 60}h ${child.dailyLimitMinutes % 60}m',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Settings groups
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsGroup(
                      title: 'Account',
                      items: [
                        _SettingsItem(
                            icon: Icons.person_outline,
                            label: 'Profile Settings',
                            color: AppTheme.accentCyan),
                        _SettingsItem(
                            icon: Icons.lock_outline,
                            label: 'Change PIN',
                            color: AppTheme.accentPurple),
                        _SettingsItem(
                            icon: Icons.child_care,
                            label: 'Manage Children',
                            color: AppTheme.accentGreen),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsGroup(
                      title: 'Notifications',
                      items: [
                        _SettingsItem(
                            icon: Icons.notifications_outlined,
                            label: 'Push Notifications',
                            color: AppTheme.accentOrange,
                            hasToggle: true,
                            toggleValue: true),
                        _SettingsItem(
                            icon: Icons.warning_amber_outlined,
                            label: 'Limit Warnings',
                            color: AppTheme.accentPink,
                            hasToggle: true,
                            toggleValue: true),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsGroup(
                      title: 'App',
                      items: [
                        _SettingsItem(
                            icon: Icons.info_outline,
                            label: 'About SafeScreen',
                            color: AppTheme.accentCyan),
                        _SettingsItem(
                            icon: Icons.help_outline,
                            label: 'Help & Support',
                            color: AppTheme.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Logout button
                    GestureDetector(
                      onTap: () => _handleLogout(context),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: AppTheme.accentPink.withOpacity(0.15),
                                ),
                                child: const Icon(Icons.logout, color: AppTheme.accentPink, size: 18),
                              ),
                              const SizedBox(width: 14),
                              const Text('Log Out',
                                  style: TextStyle(
                                      color: AppTheme.accentPink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const Spacer(),
                              const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: items[i].color.withOpacity(0.15),
                          ),
                          child: Icon(items[i].icon,
                              color: items[i].color, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(items[i].label,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        if (items[i].hasToggle)
                          Switch(
                            value: items[i].toggleValue,
                            onChanged: (_) {},
                            activeColor: AppTheme.accentCyan,
                            activeTrackColor:
                                AppTheme.accentCyan.withOpacity(0.3),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          )
                        else
                          const Icon(Icons.chevron_right,
                              color: AppTheme.textMuted, size: 20),
                      ],
                    ),
                  ),
                  if (i < items.length - 1)
                    const Divider(
                        color: AppTheme.borderColor,
                        height: 1,
                        indent: 56),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final Color color;
  final bool hasToggle;
  final bool toggleValue;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.color,
    this.hasToggle = false,
    this.toggleValue = false,
  });
}
