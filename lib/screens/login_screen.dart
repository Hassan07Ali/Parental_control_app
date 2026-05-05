import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../models/app_models.dart';
import 'parent_shell.dart';
import 'setup_screen.dart';
/// Email + password login form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (!email.toLowerCase().endsWith('@gmail.com')) {
      setState(() => _errorMessage = 'Only @gmail.com email addresses are allowed.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parent = await DbHelper().loginParent(email, password);

      if (parent == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid email or password.';
        });
        return;
      }

      // Save session
      await SessionService.saveParentSession(parent.id!);

      // Load children
      final children = await DbHelper().getChildrenForParent(parent.id!);

      // Sync to in-memory SampleData
      SampleData.parentProfile.name = parent.name;

      if (children.isNotEmpty) {
        final child = children.first;
        await SessionService.saveActiveChild(child.id!);
        SampleData.activeChild.name = child.name;
        SampleData.activeChild.avatarEmoji = child.avatarEmoji;
        SampleData.activeChild.age = child.age;
        SampleData.activeChild.dailyLimitMinutes = child.dailyLimitMins;
        SampleData.activeChild.rewardPoints = child.rewardPoints;

        // Load app limits
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

      // FIX 1.7: Removed duplicate saveActiveChild call that was here

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (children.isEmpty) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SetupScreen(parentId: parent.id!),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ParentShell(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
      debugPrint('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.surfaceMid,
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.textPrimary),
                  ),
                ),

                const SizedBox(height: 40),
                const Text('🔐', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('Welcome Back',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Log in to your SafeScreen account.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),

                const SizedBox(height: 40),

                // Email
                _buildLabel('Email'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _emailController,
                  hint: 'you@gmail.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 20),

                // Password
                _buildLabel('Password'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _passwordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.accentPink.withOpacity(0.1),
                      border: Border.all(color: AppTheme.accentPink.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.accentPink, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(color: AppTheme.accentPink, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Login Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
                    : GlowButton(
                        label: 'Log In',
                        onTap: _login,
                        width: double.infinity,
                      ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surfaceMid,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted),
          prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
