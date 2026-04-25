import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'child_selector_screen.dart';

/// The first screen after splash for unauthenticated users.
/// Shows two large animated cards: Parent vs Child login.
class RolePickerScreen extends StatefulWidget {
  const RolePickerScreen({super.key});

  @override
  State<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends State<RolePickerScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _particleController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    // Particle animation loops forever
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _navigateToParent() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToChild() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ChildSelectorScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SignupScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: Stack(
          children: [
            // ── Floating Particles Background ──
            ...List.generate(12, (i) => _FloatingParticle(
              controller: _particleController,
              index: i,
            )),

            // ── Glow circles ──
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
                      AppTheme.accentCyan.withOpacity(0.12),
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
                      AppTheme.accentPurple.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Main Content ──
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),

                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: AppGradients.cyanGlow,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentCyan.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🛡️', style: TextStyle(fontSize: 38)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'SafeScreen',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -1,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Who is using this device?',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ── Two Role Cards ──
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              emoji: '🛡️',
                              label: 'Parent',
                              subtitle: 'Manage & Monitor',
                              glowColor: AppTheme.accentCyan,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentCyan.withOpacity(0.12),
                                  AppTheme.surfaceCard,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: _navigateToParent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _RoleCard(
                              emoji: '🧒',
                              label: 'Child',
                              subtitle: 'My Device',
                              glowColor: AppTheme.accentPurple,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentPurple.withOpacity(0.12),
                                  AppTheme.surfaceCard,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              onTap: _navigateToChild,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(flex: 2),

                      // ── Bottom: Create Account ──
                      GestureDetector(
                        onTap: _navigateToSignup,
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
                            children: [
                              TextSpan(
                                text: 'First time? ',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              TextSpan(
                                text: 'Create a parent account',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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

// ─── Role Card Widget ─────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final Color glowColor;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.glowColor,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _hoverController.forward();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        _hoverController.reverse();
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _hoverController.reverse();
        setState(() => _isPressed = false);
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: widget.gradient,
            border: Border.all(
              color: _isPressed
                  ? widget.glowColor.withOpacity(0.6)
                  : widget.glowColor.withOpacity(0.2),
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? widget.glowColor.withOpacity(0.25)
                    : Colors.black.withOpacity(0.3),
                blurRadius: _isPressed ? 25 : 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji with glow
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.glowColor.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: widget.glowColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Floating Particle (background effect) ────────────────────────────────────

class _FloatingParticle extends StatelessWidget {
  final AnimationController controller;
  final int index;

  const _FloatingParticle({required this.controller, required this.index});

  @override
  Widget build(BuildContext context) {
    final random = Random(index * 42);
    final size = 4.0 + random.nextDouble() * 6;
    final startX = random.nextDouble();
    final startY = random.nextDouble();
    final driftX = (random.nextDouble() - 0.5) * 0.15;
    final driftY = (random.nextDouble() - 0.5) * 0.15;
    final opacity = 0.1 + random.nextDouble() * 0.25;
    final color = random.nextBool() ? AppTheme.accentCyan : AppTheme.accentPurple;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final x = startX + sin(t * 2 * pi + index) * driftX;
        final y = startY + cos(t * 2 * pi + index * 0.7) * driftY;
        final screenSize = MediaQuery.of(context).size;

        return Positioned(
          left: x * screenSize.width,
          top: y * screenSize.height,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(opacity),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(opacity * 0.5),
                  blurRadius: size * 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
