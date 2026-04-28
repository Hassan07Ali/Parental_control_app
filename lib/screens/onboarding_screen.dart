import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'role_picker_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'emoji': '📊',
      'title': 'Monitor Screen Time',
      'subtitle': 'Track daily device usage and set healthy limits for your children.',
      'color': AppTheme.accentCyan,
    },
    {
      'emoji': '📱',
      'title': 'App Usage Insights',
      'subtitle': 'See exactly which apps your child uses and for how long each day.',
      'color': AppTheme.accentGreen,
    },
    {
      'emoji': '🎮',
      'title': 'Reward Good Habits',
      'subtitle': 'Earn points and grow a virtual pet by staying within screen limits.',
      'color': AppTheme.accentPurple,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: _goToSetup,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPage(
                      emoji: page['emoji'] as String,
                      title: page['title'] as String,
                      subtitle: page['subtitle'] as String,
                      color: page['color'] as Color,
                    );
                  },
                ),
              ),

              // Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == i
                          ? AppTheme.accentCyan
                          : AppTheme.textMuted,
                    ),
                  );
                }),
              ),

              const SizedBox(height: 40),

              // Action button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlowButton(
                  label: _currentPage == _pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onTap: () {
                    if (_currentPage == _pages.length - 1) {
                      _goToSetup();
                    } else {
                      _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    }
                  },
                  width: double.infinity,
                  icon: _currentPage == _pages.length - 1
                      ? Icons.arrow_forward
                      : null,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _goToSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const RolePickerScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }
}

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big icon container
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 5),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 72)),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
