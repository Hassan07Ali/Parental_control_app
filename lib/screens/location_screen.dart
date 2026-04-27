import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/app_models.dart';

// ─── Location Screen ──────────────────────────────────────────────────────────
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _locationName = 'Locating...';
  String _timeString = 'Waiting for GPS';
  
  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _locationName = 'GPS is disabled');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationName = 'Permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationName = 'Permission permanently denied');
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
      );
      if (mounted) {
        setState(() {
          _locationName = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          _timeString = 'Live · Accurate to ${position.accuracy.toStringAsFixed(0)}m';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationName = 'Error getting location');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.backgroundGradient),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text('Location',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      border: Border.all(
                          color: AppTheme.accentGreen.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: AppTheme.accentGreen, size: 8),
                        SizedBox(width: 6),
                        Text('Live',
                            style: TextStyle(
                                color: AppTheme.accentGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Map area
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Map bg
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0D1B2E),
                                Color(0xFF0A2540),
                                Color(0xFF0D1B2E)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        // Grid
                        CustomPaint(
                          size: const Size(double.infinity, double.infinity),
                          painter: _FullMapPainter(),
                        ),
                        // Accuracy circle
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accentCyan.withOpacity(0.08),
                              border: Border.all(
                                  color: AppTheme.accentCyan.withOpacity(0.2),
                                  width: 1),
                            ),
                          ),
                        ),
                        // Location pin
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('📍', style: TextStyle(fontSize: 36)),
                              SizedBox(height: 4),
                              Text('Emma',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        // Address overlay
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: GlassCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: AppTheme.accentCyan.withOpacity(0.15),
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: AppTheme.accentCyan, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_locationName,
                                          style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(_timeString,
                                          style: const TextStyle(
                                              color: AppTheme.textMuted,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Children list
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Children',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _LocationChildCard(
                            name: SampleData.activeChild.name,
                            emoji: SampleData.activeChild.avatarEmoji,
                            location: _locationName,
                            time: _timeString,
                            color: AppTheme.accentCyan,
                            isSelected: true,
                          ),
                          const SizedBox(height: 10),
                          const _LocationChildCard(
                            name: 'Liam',
                            emoji: '👦',
                            location: 'Home',
                            time: 'Just now',
                            color: AppTheme.accentGreen,
                            isSelected: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LocationChildCard extends StatelessWidget {
  final String name;
  final String emoji;
  final String location;
  final String time;
  final Color color;
  final bool isSelected;

  const _LocationChildCard({
    required this.name,
    required this.emoji,
    required this.location,
    required this.time,
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: isSelected ? color.withOpacity(0.4) : AppTheme.borderColor,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4), width: 2),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(location,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                Text(time,
                    style:
                        const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.my_location_rounded, color: color, size: 20),
        ],
      ),
    );
  }
}

class _FullMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final roadPaint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.12)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.4),
        roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.45, 0),
        Offset(size.width * 0.5, size.height),
        roadPaint);
    canvas.drawLine(
        Offset(0, size.height * 0.65),
        Offset(size.width, size.height * 0.65),
        roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

