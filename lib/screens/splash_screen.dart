import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import 'role_picker_screen.dart';
import 'main_shell.dart';
import 'child_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final loggedIn = await SessionService.isLoggedIn();

    if (!loggedIn) {
      // No Firebase session → show role picker (Parent / Child choice)
      _go(const RolePickerScreen());
      return;
    }

    // Logged in → check which mode was last used
    final role = await SessionService.getRole();

    if (role == 'child') {
      _go(const ChildShell());
    } else {
      // parent or null (default to parent)
      _go(const MainShell());
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, __, ___) => screen,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: Stack(children: [
          Positioned(top: -80, right: -60,
            child: Container(width: 250, height: 250,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.accentCyan.withOpacity(0.15), Colors.transparent])))),
          Positioned(bottom: -60, left: -40,
            child: Container(width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.accentPurple.withOpacity(0.15), Colors.transparent])))),
          Center(
            child: FadeTransition(opacity: _fadeAnim,
              child: ScaleTransition(scale: _scaleAnim,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: AppGradients.cyanGlow,
                      boxShadow: [BoxShadow(
                        color: AppTheme.accentCyan.withOpacity(0.5),
                        blurRadius: 30, spreadRadius: 5)]),
                    child: const Center(child: Text('🛡️',
                        style: TextStyle(fontSize: 48)))),
                  const SizedBox(height: 24),
                  const Text('SafeScreen', style: TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary, letterSpacing: -1,
                      fontFamily: 'Poppins')),
                  const SizedBox(height: 8),
                  const Text('Smart Parental Control', style: TextStyle(
                      fontSize: 15, color: AppTheme.textSecondary,
                      letterSpacing: 1.5, fontFamily: 'Poppins')),
                  const SizedBox(height: 60),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) => AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) {
                        final val = (_controller.value - i * 0.2).clamp(0.0, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8 + (val * 4), height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: AppTheme.accentCyan.withOpacity(0.3 + val * 0.7)));
                      }))),
                ]))),
          ),
        ]),
      ),
    );
  }
}