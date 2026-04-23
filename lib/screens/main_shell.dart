import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../services/session_service.dart';
import '../database/db_helper.dart';
import 'home_screen.dart';
import 'controls_screen.dart';
import 'activity_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _platform = MethodChannel('com.example.safescreen/usage_control');

  int _currentIndex = 0;
  late List<Widget> _screens;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ControlsScreen(),
      const ActivityScreen(),
      const RewardsScreen(),
      const SettingsScreen(),
    ];
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    if (_initialized) return;

    final parent = await SessionService.getCurrentParent();
    final child  = await SessionService.getActiveChild();

    if (parent != null) {
      SampleData.parentProfile.name = parent.name;
    }

    if (child != null) {
      SampleData.children[0].name             = child.name;
      SampleData.children[0].avatarEmoji      = child.avatarEmoji;
      SampleData.children[0].age              = child.age;
      SampleData.children[0].dailyLimitMinutes = child.dailyLimitMins;
      SampleData.children[0].rewardPoints     = child.rewardPoints;

      // Reload app limits from DB into in-memory list
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

      // Auto-restart UsageService every time the app opens so MIUI cannot
      // permanently kill monitoring. Errors are silently swallowed here;
      // the user will be prompted for permissions if missing when they tap
      // "Save & Apply" in the Controls screen.
      if (SampleData.recentApps.isNotEmpty) {
        await _restartUsageService(child.dailyLimitMins);
      }
    }

    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _restartUsageService(int globalLimitMins) async {
    try {
      final Map<String, int> appLimits = {
        for (final app in SampleData.recentApps)
          app.packageName: app.limitMinutes
      };
      if (appLimits.isEmpty) return;

      await _platform.invokeMethod('configureUsageLimit', {
        'appLimits':   appLimits,
        'globalLimit': globalLimitMins,
      });
      debugPrint('[MainShell] UsageService restarted — ${appLimits.length} limits active');
    } catch (e) {
      debugPrint('[MainShell] UsageService restart skipped (permissions not yet granted): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // AppTheme colors are all const so this is fine inside a non-const widget
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accentCyan),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}