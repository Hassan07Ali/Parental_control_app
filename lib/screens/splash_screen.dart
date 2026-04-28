import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'role_picker_screen.dart';
import 'parent_shell.dart';
import 'child_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // ── Role-aware routing ──
    final role = await SessionService.getRole();

    if (mounted) {
      Widget destination;

      if (!hasSeenOnboarding) {
        destination = const OnboardingScreen();
      } else if (role == 'parent') {
        destination = const ParentShell();
      } else if (role == 'child') {
        destination = const ChildShell();
      } else {
        // No session → show role picker
        destination = const RolePickerScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: Stack(
          children: [
            // Glow circles in bg
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentCyan.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentPurple.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo container
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: AppGradients.cyanGlow,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentCyan.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🛡️', style: TextStyle(fontSize: 48)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SafeScreen',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Smart Parental Control',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 60),
                      // Loading dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (_, __) {
                              final delay = i * 0.2;
                              final val = (_controller.value - delay).clamp(0.0, 1.0);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 8 + (val * 4),
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: AppTheme.accentCyan.withOpacity(0.3 + val * 0.7),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
