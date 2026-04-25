import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/user_models.dart';
import '../models/app_models.dart';
import '../services/session_service.dart';
import 'child_shell.dart';

/// PIN entry screen for child login.
/// Shows the child's avatar + name, a 4-dot indicator, and a number pad.
/// After 3 wrong attempts → 30-second lockout.
class ChildPinScreen extends StatefulWidget {
  final ChildUser child;

  const ChildPinScreen({super.key, required this.child});

  @override
  State<ChildPinScreen> createState() => _ChildPinScreenState();
}

class _ChildPinScreenState extends State<ChildPinScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _pin = ['', '', '', ''];
  int _pinIndex = 0;
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockSecondsLeft = 0;
  Timer? _lockTimer;
  String? _errorMessage;

  // Shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_isLocked) return;

    if (key == '⌫') {
      if (_pinIndex > 0) {
        setState(() {
          _pinIndex--;
          _pin[_pinIndex] = '';
          _errorMessage = null;
        });
      }
    } else if (key.isNotEmpty && _pinIndex < 4) {
      setState(() {
        _pin[_pinIndex] = key;
        _pinIndex++;
        _errorMessage = null;
      });

      // Auto-submit when 4 digits entered
      if (_pinIndex == 4) {
        _verifyPin();
      }
    }
  }

  Future<void> _verifyPin() async {
    final enteredPin = _pin.join();
    final result =
        await DbHelper().loginChildByPin(widget.child.id!, enteredPin);

    if (result != null) {
      // ── Success ──
      await SessionService.saveChildSession(result.id!);

      // Sync to in-memory SampleData
      SampleData.children[0].name = result.name;
      SampleData.children[0].avatarEmoji = result.avatarEmoji;
      SampleData.children[0].age = result.age;
      SampleData.children[0].dailyLimitMinutes = result.dailyLimitMins;
      SampleData.children[0].rewardPoints = result.rewardPoints;

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ChildShell(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    } else {
      // ── Failure ──
      _failedAttempts++;
      _shakeController.forward(from: 0);

      setState(() {
        _pin.fillRange(0, 4, '');
        _pinIndex = 0;
      });

      if (_failedAttempts >= 3) {
        _startLockout();
      } else {
        setState(() {
          _errorMessage =
              'Wrong PIN! ${3 - _failedAttempts} attempt${3 - _failedAttempts > 1 ? 's' : ''} left.';
        });
      }
    }
  }

  void _startLockout() {
    setState(() {
      _isLocked = true;
      _lockSecondsLeft = 30;
      _errorMessage = null;
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _isLocked = false;
          _lockSecondsLeft = 0;
          _failedAttempts = 0;
        });
      } else {
        setState(() => _lockSecondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Back button ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.surfaceMid,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            size: 16, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Avatar + Name ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentPurple.withOpacity(0.12),
                  border: Border.all(
                      color: AppTheme.accentPurple.withOpacity(0.4), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentPurple.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(widget.child.avatarEmoji,
                      style: const TextStyle(fontSize: 42)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hi, ${widget.child.name}!',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLocked
                    ? '🔒 Too many attempts'
                    : 'Enter your 4-digit PIN',
                style: TextStyle(
                  color: _isLocked
                      ? AppTheme.accentOrange
                      : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 32),

              // ── PIN Dots (with shake) ──
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  final shakeOffset =
                      _shakeAnim.value * 12 * ((_shakeAnim.value * 8).round() % 2 == 0 ? 1 : -1);
                  return Transform.translate(
                    offset: Offset(shakeOffset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = _pin[i].isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: filled
                            ? AppTheme.accentPurple.withOpacity(0.15)
                            : AppTheme.surfaceMid,
                        border: Border.all(
                          color: filled
                              ? AppTheme.accentPurple
                              : _isLocked
                                  ? AppTheme.accentOrange.withOpacity(0.3)
                                  : AppTheme.borderColor,
                          width: filled ? 2 : 1,
                        ),
                        boxShadow: filled
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.accentPurple.withOpacity(0.15),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          filled ? '●' : '',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── Error Message ──
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.accentPink.withOpacity(0.1),
                    border: Border.all(
                        color: AppTheme.accentPink.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.accentPink, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.accentPink, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Lockout Timer ──
              if (_isLocked) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    border: Border.all(
                        color: AppTheme.accentOrange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_lockSecondsLeft}s',
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please wait before trying again',
                        style: TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // ── Number Pad ──
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    _buildNumRow(['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildNumRow(['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildNumRow(['7', '8', '9']),
                    const SizedBox(height: 12),
                    _buildNumRow(['', '0', '⌫']),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumRow(List<String> nums) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: nums.map((n) {
        return GestureDetector(
          onTap: () => _onKeyTap(n),
          child: Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: n.isEmpty
                  ? Colors.transparent
                  : _isLocked
                      ? AppTheme.surfaceMid.withOpacity(0.5)
                      : AppTheme.surfaceMid,
              border: n.isEmpty
                  ? null
                  : Border.all(
                      color: _isLocked
                          ? AppTheme.borderColor.withOpacity(0.3)
                          : AppTheme.borderColor,
                    ),
            ),
            child: Center(
              child: Text(
                n,
                style: TextStyle(
                  fontSize: n == '⌫' ? 22 : 28,
                  fontWeight: FontWeight.w600,
                  color: _isLocked
                      ? AppTheme.textMuted.withOpacity(0.5)
                      : n == '⌫'
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
