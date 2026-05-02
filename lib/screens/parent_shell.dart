import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../models/app_models.dart';
import 'home_screen.dart';
import 'controls_screen.dart';
import 'activity_screen.dart';
import 'location_screen.dart';
import 'settings_screen.dart';

/// The parent's main navigation shell.
/// Tabs: Dashboard · Controls · Activity · Location · Settings
class ParentShell extends StatefulWidget {
  const ParentShell({super.key});

  @override
  State<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends State<ParentShell> {

  // ── MethodChannel — same channel used by MainActivity.kt ─────────────────
  static const _platform = MethodChannel('com.example.safescreen/usage_control');

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ControlsScreen(),
    ActivityScreen(),
    LocationScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    {'icon': Icons.home_rounded,        'label': 'Dashboard'},
    {'icon': Icons.tune_rounded,        'label': 'Controls'},
    {'icon': Icons.bar_chart_rounded,   'label': 'Activity'},
    {'icon': Icons.location_on_rounded, 'label': 'Location'},
    {'icon': Icons.settings_rounded,    'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    
    await _stopUsageService();
    // ── END FIX ───────────────────────────────────────────────────────────────

    final parentId = await SessionService.getParentId();
    if (parentId == null) return;

    // Load parent profile
    final parent = await DbHelper().getParentById(parentId);
    if (parent != null) {
      SampleData.parentProfile.name = parent.name;
    }

    // Load children
    final children = await DbHelper().getChildrenForParent(parentId);
    if (children.isNotEmpty) {
      final child = children.first;
      await SessionService.saveActiveChild(child.id!);

      SampleData.activeChild.name              = child.name;
      SampleData.activeChild.avatarEmoji       = child.avatarEmoji;
      SampleData.activeChild.age               = child.age;
      SampleData.activeChild.dailyLimitMinutes = child.dailyLimitMins;
      SampleData.activeChild.rewardPoints      = child.rewardPoints;

      // Load app limits
      final limits = await DbHelper().getAppLimits(child.id!);
      SampleData.recentApps.clear();
      for (final limit in limits) {
        if (limit.isActive) {
          SampleData.recentApps.add(AppUsage(
            appName:      limit.appName,
            packageName:  limit.packageName,
            minutesUsed:  0,
            iconEmoji:    '',
            limitMinutes: limit.limitMinutes,
          ));
        }
      }
    }

    if (mounted) setState(() {});
  }

  // ── Stops the UsageService so it never runs in parent mode ───────────────
  Future<void> _stopUsageService() async {
    try {
      // Passing empty appLimits tells MainActivity to stopService()
      await _platform.invokeMethod('configureUsageLimit', {
        'appLimits':   <String, int>{},
        'globalLimit': 0,
      });
      debugPrint('[ParentShell] UsageService stopped — parent mode active');
    } catch (e) {
      // Permissions not granted yet — service wasn't running anyway
      debugPrint('[ParentShell] UsageService stop skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: const Border(
            top: BorderSide(color: AppTheme.borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final isSelected = i == _currentIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? AppTheme.accentCyan.withOpacity(0.12)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navItems[i]['icon'] as IconData,
                        color: isSelected
                            ? AppTheme.accentCyan
                            : AppTheme.textMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _navItems[i]['label'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.accentCyan
                              : AppTheme.textMuted,
                          fontSize:   10,
                          fontWeight: isSelected
                              ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}