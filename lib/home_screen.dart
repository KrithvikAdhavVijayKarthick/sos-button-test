import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'background_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum AppState { armed, countdown, triggered }

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _service = FlutterBackgroundService();

  AppState _state     = AppState.armed;
  int      _countdown = 10;
  double?  _lat, _lng;
  String?  _mapURL;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  StreamSubscription? _shakeSub;
  StreamSubscription? _tickSub;
  StreamSubscription? _cancelSub;
  StreamSubscription? _triggeredSub;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _requestPermissions();
    _listenToService();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  void _listenToService() {
    _shakeSub = _service.on('shakeDetected').listen((data) {
      HapticFeedback.heavyImpact();
      setState(() {
        _state     = AppState.countdown;
        _countdown = data?['countdown'] ?? 10;
      });
    });

    _tickSub = _service.on('countdownTick').listen((data) {
      HapticFeedback.lightImpact();
      setState(() => _countdown = data?['value'] ?? _countdown);
    });

    _cancelSub = _service.on('emergencyCancelled').listen((_) {
      setState(() => _state = AppState.armed);
    });

    _triggeredSub = _service.on('emergencyTriggered').listen((data) {
      setState(() {
        _state  = AppState.triggered;
        _lat    = data?['lat'];
        _lng    = data?['lng'];
        _mapURL = data?['mapURL'];
      });
      _openWhatsAppCall();
    });
  }

  // Opens WhatsApp call to emergency number
  Future<void> _openWhatsAppCall() async {
    await Future.delayed(const Duration(milliseconds: 600));

    // First send WhatsApp message with location
    final locLine = _mapURL != null
        ? '📍 Live Location: $_mapURL'
        : '📍 Location unavailable.';

    final msg = '🚨 EMERGENCY ALERT 🚨\n\n'
        'The owner of this phone is in DANGER and needs immediate help.\n\n'
        '$locLine\n\n'
        'Please respond immediately!';

    // Send WhatsApp message with location first
    final msgURL = Uri.parse(
      'https://wa.me/$kEmergencyWANumber?text=${Uri.encodeComponent(msg)}',
    );
    await launchUrl(msgURL, mode: LaunchMode.externalApplication);

    // Then after 3 seconds open WhatsApp call
    await Future.delayed(const Duration(seconds: 3));
    final callURL = Uri.parse('whatsapp://call?phone=$kEmergencyWANumber');
    if (await canLaunchUrl(callURL)) {
      await launchUrl(callURL, mode: LaunchMode.externalApplication);
    }
  }

  void _cancelEmergency() {
    HapticFeedback.mediumImpact();
    _service.invoke('cancelEmergency');
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shakeSub?.cancel();
    _tickSub?.cancel();
    _cancelSub?.cancel();
    _triggeredSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF07080D),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_state) {
            AppState.armed     => _buildArmed(),
            AppState.countdown => _buildCountdown(),
            AppState.triggered => _buildTriggered(),
          },
        ),
      ),
    );
  }

  // ── ARMED ─────────────────────────────────────────────
  Widget _buildArmed() {
    return SafeArea(
      key: const ValueKey('armed'),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Text('🛡️', style: TextStyle(fontSize: 80)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'GUARDIAN',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 6,
                color: Color(0xFF6B7399),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Always\nWatching',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEEF0FF),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: const Color(0xFF22C55E).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BlinkDot(color: const Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  const Text(
                    'SHAKE DETECTION ACTIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            const Text(
              '📳  Shake your phone hard\nto trigger emergency call',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7399),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COUNTDOWN ─────────────────────────────────────────
  Widget _buildCountdown() {
    return SafeArea(
      key: const ValueKey('countdown'),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: _countdown / 10.0,
                      strokeWidth: 6,
                      backgroundColor:
                          const Color(0xFFFF3B3B).withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFF3B3B),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF3B3B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'EMERGENCY ALERT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 4,
                color: Color(0xFFFF3B3B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'WhatsApp call in…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEEF0FF),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap Cancel to abort',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7399)),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _cancelEmergency,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1118),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFF3B3B).withOpacity(0.4),
                  ),
                ),
                child: const Text(
                  '✕  CANCEL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Color(0xFFFF3B3B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TRIGGERED ─────────────────────────────────────────
  Widget _buildTriggered() {
    return SafeArea(
      key: const ValueKey('triggered'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // WhatsApp icon with rings
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(3, (i) => _WARing(delay: i * 600)),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF25D366),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('📞', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'EMERGENCY TRIGGERED',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 4,
                  color: Color(0xFF25D366),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Opening WhatsApp…',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEEF0FF),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '+91 78458 85284',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF6B7399),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 28),
              // Location
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1118),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF6B7399).withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📍 '),
                    Text(
                      _lat != null
                          ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                          : 'Fetching location…',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7399),
                      ),
                    ),
                  ],
                ),
              ),
              if (_mapURL != null) ...[
                const SizedBox(height: 10),
                Text(
                  _mapURL!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF25D366),
                  ),
                ),
              ],
              const SizedBox(height: 36),
              const Text(
                '📩 WhatsApp message sent with location\n📞 WhatsApp call opening now',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7399),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BLINK DOT ─────────────────────────────────────────────
class _BlinkDot extends StatefulWidget {
  final Color color;
  const _BlinkDot({required this.color});
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    ),
  );
}

// ── WA RING ───────────────────────────────────────────────
class _WARing extends StatefulWidget {
  final int delay;
  const _WARing({required this.delay});
  @override
  State<_WARing> createState() => _WARingState();
}

class _WARingState extends State<_WARing> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale, _opacity;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scale   = Tween<double>(begin: 0.8, end: 2.0).animate(_c);
    _opacity = Tween<double>(begin: 0.7, end: 0.0).animate(_c);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat();
    });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Transform.scale(
      scale: _scale.value,
      child: Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF25D366), width: 2),
          ),
        ),
      ),
    ),
  );
}
