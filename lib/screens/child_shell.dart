import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../models/app_models.dart';
import 'child_dashboard_screen.dart';
import 'rewards_screen.dart';
import 'child_profile_screen.dart';

/// The child's main navigation shell.
/// Tabs: My Time · Rewards · Virtual Pet · My Profile
/// No parent management tabs (controls, location, settings) shown here.
class ChildShell extends StatefulWidget {
  const ChildShell({super.key});

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChildDashboardScreen(),
    RewardsScreen(),
    _VirtualPetScreen(),
    ChildProfileScreen(),
  ];

  static const _navItems = [
    {'icon': Icons.phone_android_rounded, 'label': 'My Time', 'color': AppTheme.accentCyan},
    {'icon': Icons.stars_rounded, 'label': 'Rewards', 'color': AppTheme.accentOrange},
    {'icon': Icons.pets_rounded, 'label': 'Pet', 'color': AppTheme.accentGreen},
    {'icon': Icons.face_rounded, 'label': 'Profile', 'color': AppTheme.accentPurple},
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
      SampleData.children[0].name = child.name;
      SampleData.children[0].avatarEmoji = child.avatarEmoji;
      SampleData.children[0].age = child.age;
      SampleData.children[0].dailyLimitMinutes = child.dailyLimitMins;
      SampleData.children[0].rewardPoints = child.rewardPoints;

      // Load app limits for this child
      final limits = await DbHelper().getAppLimits(child.id!);
      SampleData.recentApps.clear();
      for (final limit in limits) {
        if (limit.isActive) {
          SampleData.recentApps.add(AppUsage(
            appName: limit.appName,
            packageName: limit.packageName,
            minutesUsed: 0,
            iconEmoji: '',
            limitMinutes: limit.limitMinutes,
          ));
        }
      }
    }

    if (mounted) setState(() {});
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
              final itemColor = _navItems[i]['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          color: isSelected ? itemColor : AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
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

// ─── Virtual Pet Screen (Placeholder with fun UI) ─────────────────────────────

class _VirtualPetScreen extends StatefulWidget {
  const _VirtualPetScreen();

  @override
  State<_VirtualPetScreen> createState() => _VirtualPetScreenState();
}

class _VirtualPetScreenState extends State<_VirtualPetScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  int _happiness = 70;
  String _petEmoji = '🐱';
  String _petName = 'Whiskers';
  String _mood = 'Happy';

  static const _petOptions = ['🐱', '🐶', '🐰', '🐼', '🦊', '🐸'];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Happiness is tied to reward points
    final points = SampleData.children[0].rewardPoints;
    _happiness = (points.clamp(0, 100));
    _updateMood();
  }

  void _updateMood() {
    if (_happiness >= 80) {
      _mood = 'Ecstatic! 🌟';
    } else if (_happiness >= 50) {
      _mood = 'Happy 😊';
    } else if (_happiness >= 30) {
      _mood = 'Okay 😐';
    } else {
      _mood = 'Sad 😢';
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _feedPet() {
    if (SampleData.children[0].rewardPoints >= 5) {
      setState(() {
        SampleData.children[0].rewardPoints -= 5;
        _happiness = (_happiness + 10).clamp(0, 100);
        _updateMood();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🍖 Yum! Your pet loves it! -5 points'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points to feed your pet!'),
          backgroundColor: AppTheme.accentOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Text('Virtual Pet',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Take care of your pet by staying under your screen time limit!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Pet display
              AnimatedBuilder(
                animation: _bounceAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_bounceAnim.value),
                    child: child,
                  );
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    border: Border.all(
                        color: AppTheme.accentGreen.withOpacity(0.3),
                        width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGreen.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(_petEmoji,
                        style: const TextStyle(fontSize: 64)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pet name & mood
              Text(
                _petName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _mood,
                style: const TextStyle(
                    color: AppTheme.accentGreen, fontSize: 14),
              ),

              const SizedBox(height: 24),

              // Happiness bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.surfaceMid,
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Happiness',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                        Text('$_happiness%',
                            style: const TextStyle(
                                color: AppTheme.accentGreen,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _happiness / 100.0,
                        backgroundColor: AppTheme.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _happiness >= 50
                              ? AppTheme.accentGreen
                              : AppTheme.accentOrange,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _feedPet,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.surfaceMid,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Column(
                          children: [
                            Text('🍖', style: TextStyle(fontSize: 28)),
                            SizedBox(height: 6),
                            Text('Feed',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text('5 pts',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _happiness = (_happiness + 5).clamp(0, 100);
                          _updateMood();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎾 Your pet loved playing!'),
                            backgroundColor: AppTheme.accentCyan,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.surfaceMid,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Column(
                          children: [
                            Text('🎾', style: TextStyle(fontSize: 28)),
                            SizedBox(height: 6),
                            Text('Play',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text('Free',
                                style: TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Choose pet
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose Your Pet',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: _petOptions.map((emoji) {
                  final selected = emoji == _petEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _petEmoji = emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected
                            ? AppTheme.accentGreen.withOpacity(0.15)
                            : AppTheme.surfaceMid,
                        border: Border.all(
                          color: selected
                              ? AppTheme.accentGreen
                              : AppTheme.borderColor,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 26))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
