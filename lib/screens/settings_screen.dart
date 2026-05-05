import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import 'role_picker_screen.dart';
import 'setup_screen.dart';
import 'parent_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings Screen — fully wired backend
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _limitWarnings     = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushNotifications = prefs.getBool('pref_push_notifications') ?? true;
        _limitWarnings     = prefs.getBool('pref_limit_warnings') ?? true;
      });
    }
  }

  Future<void> _saveNotificationPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ── Snackbar helpers ───────────────────────────────────────────────────────
  void _success(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppTheme.accentGreen));
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppTheme.accentOrange));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROFILE SETTINGS dialog — edit parent name & email
  // ══════════════════════════════════════════════════════════════════════════
  void _showProfileSettings() {
    final nameCtrl  = TextEditingController(text: SampleData.parentProfile.name);
    final emailCtrl = TextEditingController(); // don't pre-fill email for security
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Profile Settings',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Name field
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Display Name', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 14),
            // New email field (optional — blank = keep current)
            TextFormField(
              controller: emailCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('New Email (leave blank to keep)', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // optional
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final parentId = await SessionService.getParentId();
              if (parentId == null) return;

              // Update name
              final newName = nameCtrl.text.trim();
              await DbHelper().updateParentName(parentId, newName);
              setState(() => SampleData.parentProfile.name = newName);

              // Update email if provided
              final newEmail = emailCtrl.text.trim();
              if (newEmail.isNotEmpty) {
                final ok = await DbHelper().updateParentEmail(parentId, newEmail);
                if (ok) {
                  _success('Profile updated successfully');
                } else {
                  _error('That email is already in use');
                  return;
                }
              } else {
                _success('Name updated successfully');
              }
            },
            child: const Text('Save', style: TextStyle(
                color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHANGE PIN dialog — verify old PIN then set new one
  // ══════════════════════════════════════════════════════════════════════════
  void _showChangePIN() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Child PIN',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This is the PIN your child uses to access the device.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            TextFormField(
              controller: oldCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Current PIN', Icons.lock_outline),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter current PIN' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: newCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('New PIN (4–6 digits)', Icons.pin_outlined),
              validator: (v) {
                if (v == null || v.length < 4) return 'PIN must be at least 4 digits';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: confCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Confirm New PIN', Icons.pin_outlined),
              validator: (v) => v != newCtrl.text ? 'PINs do not match' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final childId = await SessionService.getActiveChildId();
              if (childId == null) return;

              // Verify old PIN
              final storedPin = await DbHelper().getChildPin(childId);
              if (storedPin != oldCtrl.text) {
                _error('Current PIN is incorrect');
                return;
              }
              Navigator.pop(ctx);
              await DbHelper().updateChildPin(childId, newCtrl.text);
              _success('PIN changed successfully');
            },
            child: const Text('Change PIN', style: TextStyle(
                color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MANAGE CHILDREN dialog — edit child name, avatar, age, daily limit
  // ══════════════════════════════════════════════════════════════════════════
  void _showManageChildren() {
    final child     = SampleData.children[0];
    final nameCtrl  = TextEditingController(text: child.name);
    final ageCtrl   = TextEditingController(text: child.age.toString());
    final formKey   = GlobalKey<FormState>();

    // Available avatars
    const avatars = ['👦', '👧', '🧒', '👶', '🧑', '👩', '👨', '🐣'];
    String selectedAvatar = child.avatarEmoji;

    // Daily limit slider value (in minutes)
    double limitMins = child.dailyLimitMinutes.toDouble().clamp(15, 480);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Manage Child Profile',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Avatar picker
                const Text('Choose Avatar',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: avatars.map((e) => GestureDetector(
                    onTap: () => setDialogState(() => selectedAvatar = e),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedAvatar == e
                            ? AppTheme.accentCyan.withOpacity(0.25)
                            : AppTheme.surfaceLight,
                        border: Border.all(
                          color: selectedAvatar == e
                              ? AppTheme.accentCyan : Colors.transparent,
                          width: 2),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),

                // Child name
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _inputDeco("Child's Name", Icons.child_care),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),

                // Age
                TextFormField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _inputDeco('Age', Icons.cake_outlined),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 18) return 'Enter age between 1 and 18';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Daily limit slider
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Daily Screen Limit',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text(
                    '${limitMins.toInt() ~/ 60}h ${limitMins.toInt() % 60}m',
                    style: const TextStyle(
                        color: AppTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                Slider(
                  value: limitMins,
                  min: 15, max: 480, divisions: 31,
                  activeColor: AppTheme.accentCyan,
                  inactiveColor: AppTheme.surfaceLight,
                  onChanged: (v) => setDialogState(() => limitMins = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final childId = await SessionService.getActiveChildId();
                if (childId == null) return;

                final newName   = nameCtrl.text.trim();
                final newAge    = int.parse(ageCtrl.text.trim());
                final newLimit  = limitMins.toInt();

                // Update DB
                await DbHelper().updateChildProfile(
                    childId, newName, selectedAvatar, newAge);
                await DbHelper().updateDailyLimit(childId, newLimit);

                // Update in-memory SampleData so rest of app sees changes immediately
                setState(() {
                  SampleData.children[0].name              = newName;
                  SampleData.children[0].avatarEmoji       = selectedAvatar;
                  SampleData.children[0].age               = newAge;
                  SampleData.children[0].dailyLimitMinutes = newLimit;
                });

                _success('Child profile updated');
              },
              child: const Text('Save', style: TextStyle(
                  color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHANGE PASSWORD dialog — separate from profile for security
  // ══════════════════════════════════════════════════════════════════════════
  void _showChangePassword() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey  = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: oldCtrl, obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Current Password', Icons.lock_outline),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: newCtrl, obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('New Password', Icons.lock_open_outlined),
              validator: (v) {
                if (v == null || v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confCtrl, obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: _inputDeco('Confirm New Password', Icons.lock_open_outlined),
              validator: (v) => v != newCtrl.text ? 'Passwords do not match' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final parentId = await SessionService.getParentId();
              if (parentId == null) return;
              final ok = await DbHelper().updateParentPassword(
                  parentId, oldCtrl.text, newCtrl.text);
              Navigator.pop(ctx);
              if (ok) {
                _success('Password changed successfully');
              } else {
                _error('Current password is incorrect');
              }
            },
            child: const Text('Change', style: TextStyle(
                color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SWITCH CHILD & ADD CHILD
  // ══════════════════════════════════════════════════════════════════════════
  void _navigateToAddChild() async {
    final parentId = await SessionService.getParentId();
    if (parentId == null) return;
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SetupScreen(parentId: parentId, isAddingChild: true),
        ),
      );
    }
  }

  void _showSwitchChild() async {
    final parentId = await SessionService.getParentId();
    if (parentId == null) return;
    final children = await DbHelper().getChildrenForParent(parentId);
    if (children.isEmpty) return;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Switch Child', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children.map((c) => ListTile(
              leading: Text(c.avatarEmoji, style: const TextStyle(fontSize: 24)),
              title: Text(c.name, style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () async {
                Navigator.pop(ctx);
                await SessionService.saveActiveChild(c.id!);
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ParentShell()),
                    (route) => false,
                  );
                }
              },
            )).toList(),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ABOUT dialog
  // ══════════════════════════════════════════════════════════════════════════
  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('🔒 ', style: TextStyle(fontSize: 22)),
          Text('SafeScreen', style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        ]),
        content: const Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            Text(
              'SafeScreen is a parental control application that helps parents manage '
              'their children\'s screen time, set per-app limits, and monitor daily '
              'device usage — all stored locally on your device with no cloud account required.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
            SizedBox(height: 14),
            Text('Built with Flutter & Kotlin',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppTheme.accentCyan))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELP dialog
  // ══════════════════════════════════════════════════════════════════════════
  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpItem(q: 'How do I set app limits?',
                a: 'Go to the Controls tab, toggle an app on, tap it to set the time limit, then press Save & Apply.'),
            _HelpItem(q: 'Why is screen time showing 0?',
                a: 'Go to Settings → Apps → Special Access → Usage Access and enable it for SafeScreen.'),
            _HelpItem(q: 'The block screen is not appearing.',
                a: 'Go to Settings → Apps → Other Permissions → Display pop-up windows while running in background → enable for SafeScreen.'),
            _HelpItem(q: 'How do reward points work?',
                a: 'If your child stays under their daily limit, they earn 10 stars the next day. Stars can be redeemed for bonus screen time in the Rewards tab.'),
          ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppTheme.accentCyan))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGOUT
  // ══════════════════════════════════════════════════════════════════════════
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionService.clearSession();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder:        (_, __, ___) => const RolePickerScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(
                color: AppTheme.accentPink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INPUT DECORATION helper
  // ══════════════════════════════════════════════════════════════════════════
  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
    prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
    filled: true,
    fillColor: AppTheme.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5)),
    errorStyle: const TextStyle(color: AppTheme.accentOrange, fontSize: 11),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final parent = SampleData.parentProfile;
    final child  = SampleData.children[0];

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text('Settings',
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
          ),

          // Parent card — tap to open profile settings
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: GestureDetector(
                onTap: _showProfileSettings,
                child: GlassCard(
                  child: Row(children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentCyan, width: 2),
                        gradient: const RadialGradient(
                          colors: [Color(0xFF1E2D45), Color(0xFF0A0E1A)]),
                      ),
                      child: const Center(
                          child: Text('👨', style: TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parent.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Text('Parent Account',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.surfaceLight),
                      child: const Icon(Icons.edit_outlined,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // Child card — tap to manage child
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: GestureDetector(
                onTap: _showManageChildren,
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Text(child.avatarEmoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name, style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          'Age ${child.age} · Limit: ${child.dailyLimitMinutes ~/ 60}h ${child.dailyLimitMinutes % 60}m',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    )),
                    const Icon(Icons.edit_outlined,
                        color: AppTheme.textMuted, size: 16),
                  ]),
                ),
              ),
            ),
          ),

          // Settings groups
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Account ────────────────────────────────────────────────
                _sectionLabel('Account'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _tile(Icons.person_outline,   'Profile Settings', AppTheme.accentCyan,
                        onTap: _showProfileSettings),
                    _divider(),
                    _tile(Icons.lock_outline,     'Change PIN',       AppTheme.accentPurple,
                        onTap: _showChangePIN),
                    _divider(),
                    _tile(Icons.key_outlined,     'Change Password',  AppTheme.accentOrange,
                        onTap: _showChangePassword),
                    _divider(),
                    _tile(Icons.child_care,       'Manage Children',  AppTheme.accentGreen,
                        onTap: _showManageChildren),
                    _divider(),
                    _tile(Icons.swap_horiz,       'Switch Child',     AppTheme.accentCyan,
                        onTap: _showSwitchChild),
                    _divider(),
                    _tile(Icons.person_add_alt_1_outlined, 'Add New Child', AppTheme.accentPink,
                        onTap: _navigateToAddChild),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Notifications ──────────────────────────────────────────
                _sectionLabel('Notifications'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _toggleTile(
                      Icons.notifications_outlined, 'Push Notifications',
                      AppTheme.accentOrange, _pushNotifications,
                      (v) {
                        setState(() => _pushNotifications = v);
                        _saveNotificationPref('pref_push_notifications', v);
                      },
                    ),
                    _divider(),
                    _toggleTile(
                      Icons.warning_amber_outlined, 'Limit Warnings',
                      AppTheme.accentPink, _limitWarnings,
                      (v) {
                        setState(() => _limitWarnings = v);
                        _saveNotificationPref('pref_limit_warnings', v);
                      },
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── App ────────────────────────────────────────────────────
                _sectionLabel('App'),
                const SizedBox(height: 10),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _tile(Icons.info_outline,  'About SafeScreen', AppTheme.accentCyan,
                        onTap: _showAbout),
                    _divider(),
                    _tile(Icons.help_outline,  'Help & Support',   AppTheme.textSecondary,
                        onTap: _showHelp),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Log Out ────────────────────────────────────────────────
                GestureDetector(
                  onTap: _handleLogout,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppTheme.accentPink.withOpacity(0.15)),
                          child: const Icon(Icons.logout,
                              color: AppTheme.accentPink, size: 18),
                        ),
                        const SizedBox(width: 14),
                        const Text('Log Out', style: TextStyle(
                            color: AppTheme.accentPink, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.textMuted, size: 20),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Small widget helpers ───────────────────────────────────────────────────

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _divider() => const Divider(
      color: AppTheme.borderColor, height: 1, indent: 56);

  Widget _tile(IconData icon, String label, Color color,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withOpacity(0.15)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _toggleTile(IconData icon, String label, Color color,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.15)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w500))),
        Switch(
          value: value, onChanged: onChanged,
          activeThumbColor: AppTheme.accentCyan,
          activeTrackColor: AppTheme.accentCyan.withOpacity(0.3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ── Help item widget ──────────────────────────────────────────────────────────
class _HelpItem extends StatelessWidget {
  final String q, a;
  const _HelpItem({required this.q, required this.a});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(q, style: const TextStyle(
          color: AppTheme.accentCyan, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 4),
      Text(a, style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 12, height: 1.5)),
    ]),
  );
}