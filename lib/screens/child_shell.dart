import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../models/app_models.dart';
import 'child_dashboard_screen.dart';
import 'rewards_screen.dart';
import 'child_profile_screen.dart';
import 'pet_screen.dart';

/// The child's main navigation shell.
/// Tabs: My Time · Rewards · Virtual Pet · My Profile
class ChildShell extends StatefulWidget {
  const ChildShell({super.key});

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> {

  // ── MethodChannel — same channel used by MainActivity.kt ─────────────────
  static const _platform = MethodChannel('com.example.safescreen/usage_control');

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChildDashboardScreen(),
    RewardsScreen(),
    PetScreen(),
    ChildProfileScreen(),
  ];

  static const _navItems = [
    {'icon': Icons.phone_android_rounded, 'label': 'My Time',  'color': AppTheme.accentCyan},
    {'icon': Icons.stars_rounded,         'label': 'Rewards',  'color': AppTheme.accentOrange},
    {'icon': Icons.pets_rounded,          'label': 'Pet',      'color': AppTheme.accentGreen},
    {'icon': Icons.face_rounded,          'label': 'Profile',  'color': AppTheme.accentPurple},
  ];

  @override
  void initState() {
    super.initState();
    _loadChildData();
  }

  Future<void> _loadChildData() async {
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;

    final child = await DbHelper().getChildById(childId);
    if (child != null) {
      SampleData.activeChild.name              = child.name;
      SampleData.activeChild.avatarEmoji       = child.avatarEmoji;
      SampleData.activeChild.age               = child.age;
      SampleData.activeChild.dailyLimitMinutes = child.dailyLimitMins;
      SampleData.activeChild.rewardPoints      = child.rewardPoints;

      // Load app limits for this child
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

      
      await _startUsageService(child.dailyLimitMins);
     
    }

    if (mounted) setState(() {});
  }

  // ── Starts the background UsageService with the child's limits ────────────
  Future<void> _startUsageService(int globalLimitMins) async {
    try {
      final Map<String, int> appLimits = {
        for (final app in SampleData.recentApps)
          app.packageName: app.limitMinutes
      };

      // Even if no per-app limits, still start with global limit only
      await _platform.invokeMethod('configureUsageLimit', {
        'appLimits':   appLimits,
        'globalLimit': globalLimitMins,
      });

      debugPrint('[ChildShell] UsageService started — '
          '${appLimits.length} app limits, global: ${globalLimitMins}m');
    } catch (e) {
      // Permissions not yet granted — user will be prompted by MainActivity
      debugPrint('[ChildShell] UsageService start failed '
          '(permissions may be missing): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildChildNav(),
    );
  }

  Widget _buildChildNav() {
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
              final itemColor  = _navItems[i]['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected
                        ? itemColor.withOpacity(0.12)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navItems[i]['icon'] as IconData,
                        color: isSelected ? itemColor : AppTheme.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _navItems[i]['label'] as String,
                        style: TextStyle(
                          color:      isSelected ? itemColor : AppTheme.textMuted,
                          fontSize:   10,
                          fontWeight: isSelected
                              ? FontWeight.w700 : FontWeight.w400,
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