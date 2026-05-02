import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/common_widgets.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../models/user_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pet Screen — Virtual Pet with egg → 6 growth levels
// Points earned from rewards_screen feed pet level automatically
// ─────────────────────────────────────────────────────────────────────────────

class PetScreen extends StatefulWidget {
  const PetScreen({super.key});
  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen>
    with TickerProviderStateMixin {

  // Pet data
  String  _petName      = 'Buddy';
  String  _petSpecies   = 'cat';
  int     _happiness    = 50;
  int     _petLevel     = 0;
  int     _lifetimePoints = 0;
  int     _rewardPoints   = 0;
  int     _streakDays     = 0;
  bool    _isLoading    = true;

  // Animation
  late AnimationController _bounceController;
  late Animation<double>   _bounceAnim;
  late AnimationController _glowController;
  late Animation<double>   _glowAnim;

  // ── Pet species catalogue ─────────────────────────────────────────────────
  static const Map<String, String> _speciesEmoji = {
    'cat':   '🐱',
    'dog':   '🐶',
    'bunny': '🐰',
    'panda': '🐼',
    'fox':   '🦊',
    'frog':  '🐸',
  };

  // ── Level definitions (thresholds lowered to 1-6 for testing) ────────────
  static const List<Map<String, dynamic>> _levels = [
    {'level': 0, 'name': 'Egg',      'emoji': '🥚', 'pts': 0, 'desc': 'Waiting to hatch...'},
    {'level': 1, 'name': 'Hatchling','emoji': null,  'pts': 1, 'desc': 'Just hatched! So tiny!'},
    {'level': 2, 'name': 'Baby',     'emoji': null,  'pts': 2, 'desc': 'Growing fast!'},
    {'level': 3, 'name': 'Child',    'emoji': null,  'pts': 3, 'desc': 'Learning and exploring!'},
    {'level': 4, 'name': 'Teen',     'emoji': null,  'pts': 4, 'desc': 'Full of energy!'},
    {'level': 5, 'name': 'Adult',    'emoji': null,  'pts': 5, 'desc': 'Majestic and strong!'},
    {'level': 6, 'name': 'Legend',   'emoji': '👑',  'pts': 6, 'desc': 'Legendary status achieved!'},
  ];

  // Level-specific emoji suffix to layer on pet
  static const List<String> _levelSuffix = ['','','🎀','🎒','🏅','✨','👑'];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    _loadPet();
  }

  Future<void> _loadPet() async {
    await DbHelper().migratePetColumns();
    final child = await SessionService.getActiveChild();
    if (child != null && mounted) {
      setState(() {
        _petName        = child.petName;
        _petSpecies     = child.petSpecies;
        _happiness      = child.petHappiness;
        _petLevel       = child.petLevel;
        _lifetimePoints = child.lifetimePoints;
        _rewardPoints   = child.rewardPoints;
        _streakDays     = child.streakDays;
        _isLoading      = false;
      });
    }
  }

  // ── Interact — Feed (costs 5 points, gives +15 happiness) ────────────────
  Future<void> _feedPet() async {
    if (_rewardPoints < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Need 5 points to feed your pet!'),
        backgroundColor: AppTheme.accentOrange));
      return;
    }
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;
    final newHappiness = (_happiness + 15).clamp(0, 100);
    final newPoints    = _rewardPoints - 5;
    await DbHelper().updatePetHappiness(childId, newHappiness);
    await DbHelper().updateRewardPoints(childId, newPoints);
    setState(() {
      _happiness    = newHappiness;
      _rewardPoints = newPoints;
      SampleData.children[0].rewardPoints = newPoints;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🍖 Fed! +15 happiness'),
      backgroundColor: AppTheme.accentGreen));
  }

  // ── Interact — Play (free, gives +10 happiness) ───────────────────────────
  Future<void> _playWithPet() async {
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;
    final newHappiness = (_happiness + 10).clamp(0, 100);
    await DbHelper().updatePetHappiness(childId, newHappiness);
    setState(() => _happiness = newHappiness);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🎾 Played! +10 happiness'),
      backgroundColor: AppTheme.accentCyan));
  }

  // ── Change pet species ────────────────────────────────────────────────────
  Future<void> _changePetSpecies(String species) async {
    if (_petLevel == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Hatch your egg first! Earn 1 point.'),
        backgroundColor: AppTheme.accentOrange));
      return;
    }
    final childId = await SessionService.getActiveChildId();
    if (childId == null) return;
    await DbHelper().updatePet(childId, _petName, species);
    setState(() => _petSpecies = species);
  }

  // ── Rename pet ────────────────────────────────────────────────────────────
  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _petName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Rename Your Pet',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppTheme.textPrimary),
        maxLength: 12,
        decoration: InputDecoration(
          hintText: 'Pet name',
          hintStyle: const TextStyle(color: AppTheme.textMuted),
          filled: true, fillColor: AppTheme.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
        TextButton(
          onPressed: () async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            final childId = await SessionService.getActiveChildId();
            if (childId == null) return;
            await DbHelper().updatePet(childId, name, _petSpecies);
            setState(() => _petName = name);
          },
          child: const Text('Save', style: TextStyle(
              color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color get _happinessColor {
    if (_happiness >= 70) return AppTheme.accentGreen;
    if (_happiness >= 40) return AppTheme.accentCyan;
    return AppTheme.accentOrange;
  }

  String get _moodText {
    if (_happiness >= 80) return 'Ecstatic 🤩';
    if (_happiness >= 60) return 'Happy 😊';
    if (_happiness >= 40) return 'Content 🙂';
    if (_happiness >= 20) return 'Sad 😢';
    return 'Very Sad 😭';
  }

  String get _petDisplay {
    if (_petLevel == 0) return '🥚'; // egg
    final species = _speciesEmoji[_petSpecies] ?? '🐱';
    final suffix  = _levelSuffix[_petLevel.clamp(0, 6)];
    return '$species$suffix';
  }

  // ── Level progress (thresholds lowered to 1-6 for testing) ───────────────
  double get _levelProgress {
    if (_petLevel >= 6) return 1.0;
    final thresholds = [1, 2, 3, 4, 5, 6];
    final prev = _petLevel > 0 ? thresholds[_petLevel - 1] : 0;
    final next = thresholds[_petLevel];
    return ((_lifetimePoints - prev) / (next - prev)).clamp(0.0, 1.0);
  }

  String get _nextLevelPts {
    if (_petLevel >= 6) return 'MAX LEVEL';
    final thresholds = [1, 2, 3, 4, 5, 6];
    final needed = thresholds[_petLevel] - _lifetimePoints;
    return '$needed pts to next level';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)));
    }

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(slivers: [

          // Header
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Virtual Pet', style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
                const Text('Take care of your pet by staying under your limit!',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
              const Spacer(),
              // Points chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppTheme.accentPurple.withOpacity(0.15),
                  border: Border.all(color: AppTheme.accentPurple.withOpacity(0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⭐ ', style: TextStyle(fontSize: 14)),
                  Text('$_rewardPoints', style: const TextStyle(
                      color: AppTheme.accentPurple, fontWeight: FontWeight.w700, fontSize: 14)),
                ])),
            ]),
          )),

          // Pet display card
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [
                      AppTheme.accentCyan.withOpacity(0.2),
                      AppTheme.accentPurple.withOpacity(0.2)]),
                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4))),
                  child: Text('Level $_petLevel · ${_levels[_petLevel.clamp(0,6)]['name']}',
                      style: const TextStyle(color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 16),

                // Animated pet
                AnimatedBuilder(animation: _bounceAnim, builder: (_, __) =>
                  Transform.translate(
                    offset: Offset(0, _bounceAnim.value),
                    child: AnimatedBuilder(animation: _glowAnim, builder: (_, __) =>
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentGreen.withOpacity(0.1),
                          boxShadow: [BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(_glowAnim.value * 0.4),
                            blurRadius: 30, spreadRadius: 10)]),
                        child: Center(child: Text(_petDisplay,
                            style: const TextStyle(fontSize: 64))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Pet name (tap to rename)
                GestureDetector(
                  onTap: _showRenameDialog,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_petName, style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 24,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined,
                        color: AppTheme.textMuted, size: 16),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(_moodText, style: TextStyle(
                    color: _happinessColor, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 16),

                // Happiness bar
                _labeledBar('Happiness', _happiness / 100, _happinessColor),
                const SizedBox(height: 10),
                // Level progress bar
                _labeledBar('Level Progress', _levelProgress, AppTheme.accentCyan,
                    label2: _nextLevelPts),

                const SizedBox(height: 16),
                // Streak
                if (_streakDays > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.accentOrange.withOpacity(0.1)),
                  child: Text('🔥 $_streakDays day streak',
                      style: const TextStyle(color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
            ),
          )),

          // Interact buttons
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              Expanded(child: _interactButton('🍖', 'Feed', '5 pts', AppTheme.accentOrange, _feedPet)),
              const SizedBox(width: 12),
              Expanded(child: _interactButton('🎾', 'Play', 'Free', AppTheme.accentCyan, _playWithPet)),
            ]),
          )),

          // Level guide
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text('Level Guide', style: Theme.of(context)
                .textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          )),

          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final lvl       = _levels[i];
            final lvlNum    = lvl['level'] as int;
            final isReached = _petLevel >= lvlNum;
            final isCurrent = _petLevel == lvlNum;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, i == 0 ? 12 : 6, 24, 0),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                borderColor: isCurrent
                    ? AppTheme.accentCyan.withOpacity(0.5) : AppTheme.borderColor,
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isReached
                          ? AppTheme.accentCyan.withOpacity(0.15)
                          : AppTheme.surfaceLight),
                    child: Center(child: Text(
                      lvlNum == 0 ? '🥚' :
                      lvlNum == 6 ? '👑' : _speciesEmoji[_petSpecies] ?? '🐱',
                      style: TextStyle(fontSize: 22,
                          color: isReached ? null : const Color(0x44FFFFFF))))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Level $lvlNum · ${lvl['name']}',
                          style: TextStyle(
                              color: isReached ? AppTheme.textPrimary : AppTheme.textMuted,
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppTheme.accentCyan.withOpacity(0.2)),
                          child: const Text('Current', style: TextStyle(
                              color: AppTheme.accentCyan, fontSize: 10))),
                      ],
                    ]),
                    Text(lvl['desc'] as String, style: TextStyle(
                        color: isReached ? AppTheme.textSecondary : AppTheme.textMuted,
                        fontSize: 11)),
                  ])),
                  Text(lvlNum == 0 ? 'Start' : '${lvl['pts']} pts',
                      style: TextStyle(
                          color: isReached ? AppTheme.accentGreen : AppTheme.textMuted,
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  if (isReached) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 16),
                  ],
                ]),
              ),
            );
          }, childCount: _levels.length)),

          // Choose pet
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text('Choose Your Pet', style: Theme.of(context)
                .textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          )),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Wrap(spacing: 12, runSpacing: 12,
              children: _speciesEmoji.entries.map((e) {
                final selected = _petSpecies == e.key;
                final locked   = _petLevel == 0;
                return GestureDetector(
                  onTap: () => _changePetSpecies(e.key),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: selected
                          ? AppTheme.accentCyan.withOpacity(0.15)
                          : AppTheme.surfaceMid,
                      border: Border.all(
                        color: selected ? AppTheme.accentCyan : AppTheme.borderColor,
                        width: selected ? 2 : 1),
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      Text(e.value, style: TextStyle(
                          fontSize: 32,
                          color: locked ? const Color(0x55FFFFFF) : null)),
                      if (locked) const Positioned(bottom: 4, right: 4,
                        child: Icon(Icons.lock, color: AppTheme.textMuted, size: 12)),
                    ]),
                  ),
                );
              }).toList()),
          )),
        ]),
      ),
    );
  }

  Widget _labeledBar(String label, double value, Color color, {String? label2}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(label2 ?? '${(value * 100).toInt()}%',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value, minHeight: 8,
          backgroundColor: AppTheme.surfaceLight,
          valueColor: AlwaysStoppedAnimation<Color>(color))),
    ]);

  Widget _interactButton(String emoji, String label, String sub, Color color,
      VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: GlassCard(padding: const EdgeInsets.all(16),
        borderColor: color.withOpacity(0.3),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(sub, style: const TextStyle(
              color: AppTheme.textMuted, fontSize: 11)),
        ])),
    );

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }
}