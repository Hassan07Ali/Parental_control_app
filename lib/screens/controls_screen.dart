import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../models/user_models.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';

class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  static const platform = MethodChannel('com.example.safescreen/usage_control');

  List<AppInfo> _installedApps = [];
  bool _isLoading = true;

  final Map<String, bool> _appToggles = {};
  final Map<String, int> _appLimits = {};

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );

      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Load saved limits from DB
      final child = await SessionService.getActiveChild();
      final childId = child?.id; // real Firestore doc ID e.g. "uid_child"
      List<AppLimitEntry> savedLimits = [];
      if (childId != null) {
        savedLimits = await DbHelper().getAppLimits(childId);
      }
      final savedMap = { for (var l in savedLimits) l.packageName : l };

      if (mounted) {
        setState(() {
          _installedApps = apps;
          for (var app in apps) {
            final pkg = app.packageName;
            if (savedMap.containsKey(pkg) && savedMap[pkg]!.isActive) {
              _appToggles[pkg] = true;
              _appLimits[pkg] = savedMap[pkg]!.limitMinutes;
              
              if (!SampleData.recentApps.any((a) => a.packageName == pkg)) {
                SampleData.recentApps.add(AppUsage(
                  appName: app.name,
                  packageName: pkg,
                  category: CategoryClassifier.classify(pkg),
                  minutesUsed: 0,
                  iconEmoji: '',
                  limitMinutes: savedMap[pkg]!.limitMinutes,
                  iconBytes: app.icon,
                ));
              }
            } else {
              _appToggles[pkg] = false;
              _appLimits[pkg] = 60;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading installed apps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyLimitsToBackend() async {
    Map<String, int> activeLimits = {};
    SampleData.recentApps.clear();
    
    List<AppLimitEntry> dbLimits = [];
    final activeChild = await SessionService.getActiveChild();
    final childId = activeChild?.id; // real Firestore doc ID

    for (String pkg in _appToggles.keys) {
      if (_appToggles[pkg] == true) {
        activeLimits[pkg] = _appLimits[pkg] ?? 60;
        
        final app = _installedApps.firstWhere((a) => a.packageName == pkg);
        SampleData.recentApps.add(AppUsage(
          appName: app.name,
          packageName: pkg,
          category: CategoryClassifier.classify(pkg),
          minutesUsed: 0, 
          iconEmoji: '', 
          limitMinutes: activeLimits[pkg]!,
          iconBytes: app.icon, 
        ));

        if (childId != null) {
          dbLimits.add(AppLimitEntry(
            childId: childId,
            packageName: pkg,
            appName: app.name,
            limitMinutes: activeLimits[pkg]!,
            isActive: true,
          ));
        }
      }
    }

    // Save to DB
    if (childId != null) {
      await DbHelper().saveAppLimits(childId, dbLimits);
    }

    try {
      final result = await platform.invokeMethod('configureUsageLimit', {
        'appLimits': activeLimits,
        'globalLimit': SampleData.children[0].dailyLimitMinutes, 
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.toString()), backgroundColor: AppTheme.accentGreen)
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.message}'), backgroundColor: AppTheme.accentOrange)
        );
      }
    }
  }

  void _showRestrictedAppsDialog() {
    // Filter the global state for apps that have hit or exceeded their limit
    final lockedApps = SampleData.recentApps.where((app) => 
      app.limitMinutes > 0 && app.minutesUsed >= app.limitMinutes
    ).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.block, color: AppTheme.accentOrange),
              SizedBox(width: 8),
              Text('Restricted Apps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            ],
          ),
          content: lockedApps.isEmpty
              ? const Text(
                  'No apps have reached their time limit yet.',
                  style: TextStyle(color: AppTheme.textSecondary),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lockedApps.length,
                    itemBuilder: (context, index) {
                      final app = lockedApps[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: app.iconBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(app.iconBytes!, width: 40, height: 40, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.android, color: AppTheme.textMuted),
                        title: Text(app.appName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text('Time limit reached (${app.limitMinutes}m)', style: const TextStyle(color: AppTheme.accentOrange, fontSize: 12)),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppTheme.accentCyan)),
            ),
          ],
        );
      },
    );
  }

  void _showTimePicker(String packageName, String appName) {
    int tempLimit = _appLimits[packageName] ?? 60;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              title: Text('Set limit for $appName', style: const TextStyle(color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${tempLimit ~/ 60} hr ${tempLimit % 60} min',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                  ),
                  Slider(
                    value: tempLimit.toDouble(),
                    min: 15, max: 240, divisions: 15,
                    activeColor: AppTheme.accentCyan,
                    onChanged: (val) {
                      setDialogState(() { tempLimit = val.toInt(); });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _appLimits[packageName] = tempLimit;
                      _appToggles[packageName] = true;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: AppTheme.accentCyan)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final childProfile = SampleData.children[0];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('App Control',
                                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                                Text("${childProfile.name}'s device",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                              ],
                            ),
                            const Spacer(),
                            CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.surfaceMid,
                                child: Text(childProfile.avatarEmoji, style: const TextStyle(fontSize: 18))),
                          ],
                        ),
                      ),
                    ),
                    
                    // Button Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          children: [
                            // Primary Save Button
                            GestureDetector(
                              onTap: _applyLimitsToBackend,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.accentCyan),
                                ),
                                child: const Center(
                                  child: Text('Save & Apply Restrictions 🚀',
                                    style: TextStyle(color: AppTheme.accentCyan, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // NEW: Restricted Apps Dialog Button
                            GestureDetector(
                              onTap: _showRestrictedAppsDialog,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceMid,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.accentOrange.withOpacity(0.5)),
                                ),
                                child: const Center(
                                  child: Text('View Restricted Apps 🚫',
                                    style: TextStyle(color: AppTheme.accentOrange, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Installed Apps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${_installedApps.length} Apps Found', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final app = _installedApps[i];
                          final isEnabled = _appToggles[app.packageName] ?? false;
                          final limit = _appLimits[app.packageName] ?? 60;

                          return Padding(
                            padding: EdgeInsets.fromLTRB(24, i == 0 ? 0 : 10, 24, i == _installedApps.length - 1 ? 32 : 0),
                            child: _RealAppLimitRow(
                              app: app,
                              isEnabled: isEnabled,
                              limitMinutes: limit,
                              onToggle: (val) {
                                setState(() { _appToggles[app.packageName] = val; });
                              },
                              onTap: () => _showTimePicker(app.packageName, app.name),
                            ),
                          );
                        },
                        childCount: _installedApps.length,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RealAppLimitRow extends StatelessWidget {
  final AppInfo app;
  final bool isEnabled;
  final int limitMinutes;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  const _RealAppLimitRow({
    required this.app,
    required this.isEnabled,
    required this.limitMinutes,
    required this.onToggle,
    required this.onTap,
  });

  Color get _categoryColor {
    switch (CategoryClassifier.classify(app.packageName)) {
      case AppCategory.education: return AppTheme.accentGreen;
      case AppCategory.socialMedia: return AppTheme.accentPink;
      case AppCategory.gaming: return AppTheme.accentOrange;
      case AppCategory.productivity: return AppTheme.accentCyan;
      case AppCategory.others: return AppTheme.accentPurple;
    }
  }

  String _formatLimit(int minutes) {
    if (minutes >= 60) return '${minutes ~/ 60}hr ${minutes % 60 > 0 ? '${minutes % 60}m' : ''}';
    return '${minutes}mins';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: isEnabled ? AppTheme.accentCyan.withOpacity(0.4) : AppTheme.borderColor,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.surfaceLight),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: app.icon != null 
                    ? Image.memory(app.icon!, fit: BoxFit.cover)
                    : const Icon(Icons.android, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name,
                      style: TextStyle(color: isEnabled ? AppTheme.accentCyan : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: _categoryColor.withOpacity(0.15),
                        ),
                        child: Text(
                          CategoryClassifier.classify(app.packageName).displayName,
                          style: TextStyle(color: _categoryColor, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(isEnabled ? 'Limit: ${_formatLimit(limitMinutes)}' : 'Tap to set limit',
                            style: TextStyle(color: isEnabled ? AppTheme.textSecondary : AppTheme.textMuted, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled, onChanged: onToggle,
              activeColor: AppTheme.accentCyan, activeTrackColor: AppTheme.accentCyan.withOpacity(0.3),
              inactiveThumbColor: AppTheme.textMuted, inactiveTrackColor: AppTheme.surfaceLight,
            ),
          ],
        ),
      ),
    );
  }
}