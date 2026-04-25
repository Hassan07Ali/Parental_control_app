import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';
import '../models/user_models.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import 'parent_shell.dart';

class SetupScreen extends StatefulWidget {
  final int parentId;
  const SetupScreen({super.key, required this.parentId});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form data — parent name step is removed; name was collected during signup
  final _childNameController = TextEditingController(text: '');
  final _childAgeController = TextEditingController(text: '');
  String _selectedChildEmoji = '👧';
  
  // Global Device Limit
  int _dailyLimitHours = 2;
  int _dailyLimitMinutes = 0;
  
  final List<String> _pin = ['', '', '', ''];
  int _pinIndex = 0;

  final List<String> _childEmojis = ['👧', '👦', '🧒', '👶'];

  @override
  void dispose() {
    _childNameController.dispose();
    _childAgeController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      // After child info step, compute suggested limit
      int age = int.tryParse(_childAgeController.text) ?? 8;
      int suggestedMins = 120;
      if (age < 6) { suggestedMins = 60; }
      else if (age <= 10) { suggestedMins = 120; }
      else if (age <= 14) { suggestedMins = 180; }
      else { suggestedMins = 240; }
      
      setState(() {
         _dailyLimitHours = suggestedMins ~/ 60;
         _dailyLimitMinutes = suggestedMins % 60;
         _currentStep++;
      });
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else if (_currentStep < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      // Final Step: Save child to SQLite and navigate
      if (mounted) {
        final pinStr = _pin.join();
        if (pinStr.length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a 4-digit PIN.'),
              backgroundColor: AppTheme.accentOrange,
            ),
          );
          return;
        }

        final int totalGlobalLimitMinutes = (_dailyLimitHours * 60) + _dailyLimitMinutes;
        
        final childName = _childNameController.text.isNotEmpty ? _childNameController.text : 'Emma';
        final childAge = int.tryParse(_childAgeController.text) ?? 8;

        // Insert child into DB
        final childUser = ChildUser(
          parentId: widget.parentId,
          name: childName,
          avatarEmoji: _selectedChildEmoji,
          age: childAge,
          dailyLimitMins: totalGlobalLimitMinutes,
          rewardPoints: 0,
          pin: pinStr.isNotEmpty ? pinStr : '1234',
        );
        final childId = await DbHelper().insertChild(childUser);

        // Save active child in session
        await SessionService.saveActiveChild(childId);

        // Sync to in-memory SampleData for immediate use
        SampleData.children[0].name = childName;
        SampleData.children[0].age = childAge;
        SampleData.children[0].avatarEmoji = _selectedChildEmoji;
        SampleData.children[0].dailyLimitMinutes = totalGlobalLimitMinutes;
        SampleData.children[0].usedMinutes = 0;
        SampleData.children[0].rewardPoints = 0;

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
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      GestureDetector(
                        onTap: _prevStep,
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
                    const Spacer(),
                    Text('Step ${_currentStep + 1} of 3', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                    minHeight: 4,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep0(),
                    _buildStep1(),
                    _buildStep2(),
                  ],
                ),
              ),

              // Next Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: GlowButton(
                  label: _currentStep == 2 ? 'Finish Setup' : 'Continue',
                  onTap: _nextStep,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('👶', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text("Add Your Child", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("Tell us about the child you want to monitor.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          _buildLabel("Choose Avatar"),
          const SizedBox(height: 12),
          Row(
            children: _childEmojis.map((e) {
              final isSelected = e == _selectedChildEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedChildEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 12),
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected ? AppTheme.accentCyan.withOpacity(0.15) : AppTheme.surfaceMid,
                    border: Border.all(color: isSelected ? AppTheme.accentCyan : AppTheme.borderColor, width: isSelected ? 2 : 1),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 28))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildLabel("Child's Name"),
          const SizedBox(height: 8),
          _buildTextField(controller: _childNameController, hint: 'e.g. Emma', icon: Icons.child_care),
          const SizedBox(height: 24),
          _buildLabel("Child's Age"),
          const SizedBox(height: 8),
          _buildTextField(controller: _childAgeController, hint: 'e.g. 8', icon: Icons.cake, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final totalMinutes = _dailyLimitHours * 60 + _dailyLimitMinutes;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('⏱️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text("Global Device Limit", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("We've set a recommended healthy limit based on your child's age. You can adjust this below.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 40),
          Center(
            child: GlassCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_dailyLimitHours', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: AppTheme.accentCyan, fontFamily: 'Poppins')),
                      const Padding(padding: EdgeInsets.only(bottom: 12), child: Text(' hr  ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 20))),
                      Text(_dailyLimitMinutes.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: AppTheme.accentCyan, fontFamily: 'Poppins')),
                      const Padding(padding: EdgeInsets.only(bottom: 12), child: Text(' min', style: TextStyle(color: AppTheme.textSecondary, fontSize: 20))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalMinutes <= 120 ? '✅ Excellent limit for children' : totalMinutes <= 240 ? '👍 Acceptable for school-age children' : '⚠️ Consider a lower limit',
                    style: TextStyle(color: totalMinutes <= 240 ? AppTheme.accentGreen : AppTheme.accentOrange, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildLabel('Hours (0–8)'),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: AppTheme.accentCyan, inactiveTrackColor: AppTheme.surfaceLight, thumbColor: AppTheme.accentCyan, overlayColor: AppTheme.accentCyan.withOpacity(0.2)),
            child: Slider(value: _dailyLimitHours.toDouble(), min: 0, max: 8, divisions: 8, label: '$_dailyLimitHours hr', onChanged: (v) => setState(() => _dailyLimitHours = v.round())),
          ),
          _buildLabel('Extra Minutes'),
          SliderTheme(
            data: SliderThemeData(activeTrackColor: AppTheme.accentGreen, inactiveTrackColor: AppTheme.surfaceLight, thumbColor: AppTheme.accentGreen, overlayColor: AppTheme.accentGreen.withOpacity(0.2)),
            child: Slider(value: _dailyLimitMinutes.toDouble(), min: 0, max: 55, divisions: 11, label: '$_dailyLimitMinutes min', onChanged: (v) => setState(() => _dailyLimitMinutes = (v / 5).round() * 5)),
          ),
          const SizedBox(height: 16),
          _buildLabel('Quick Presets'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: ['1 hr', '2 hr', '4 hr', '6 hr'].map((preset) {
              return GestureDetector(
                onTap: () {
                  final mins = {'1 hr': 60, '2 hr': 120, '4 hr': 240, '6 hr': 360}[preset]!;
                  setState(() { _dailyLimitHours = mins ~/ 60; _dailyLimitMinutes = mins % 60; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppTheme.surfaceMid, border: Border.all(color: AppTheme.borderColor)),
                  child: Text(preset, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('🔐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text("Set Security PIN", style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text("This PIN protects your parent settings from your child.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = _pin[i].isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 60, height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: filled ? AppTheme.accentCyan.withOpacity(0.15) : AppTheme.surfaceMid,
                  border: Border.all(color: filled ? AppTheme.accentCyan : AppTheme.borderColor, width: filled ? 2 : 1),
                ),
                child: Center(child: Text(filled ? '●' : '', style: const TextStyle(color: AppTheme.accentCyan, fontSize: 24))),
              );
            }),
          ),
          const SizedBox(height: 40),
          Center(
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
    );
  }

  Widget _buildNumRow(List<String> nums) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: nums.map((n) {
        return GestureDetector(
          onTap: () {
            if (n == '⌫') {
              if (_pinIndex > 0) { setState(() { _pinIndex--; _pin[_pinIndex] = ''; }); }
            } else if (n.isNotEmpty && _pinIndex < 4) {
              setState(() { _pin[_pinIndex] = n; _pinIndex++; });
            }
          },
          child: Container(
            width: 72, height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: n.isEmpty ? Colors.transparent : AppTheme.surfaceMid,
              border: n.isEmpty ? null : Border.all(color: AppTheme.borderColor),
            ),
            child: Center(child: Text(n, style: TextStyle(fontSize: n == '⌫' ? 22 : 28, fontWeight: FontWeight.w600, color: n == '⌫' ? AppTheme.textSecondary : AppTheme.textPrimary))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppTheme.surfaceMid, border: Border.all(color: AppTheme.borderColor)),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: AppTheme.textMuted),
          prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}