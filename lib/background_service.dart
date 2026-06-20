import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ── CONFIG ────────────────────────────────────────────────
const String kEmergencyWANumber = '917845885284'; // WhatsApp number with country code
const double kShakeThreshold    = 18.0;
const int    kShakeCooldownMs   = 5000;
const int    kCountdownSec      = 10;
// ─────────────────────────────────────────────────────────

Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'guardian_foreground',
    'Guardian Protection',
    description: 'Guardian is monitoring for shake emergencies.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'guardian_foreground',
      initialNotificationTitle: '🛡️ Guardian Active',
      initialNotificationContent: 'Shake detection is running.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  double lx = 0, ly = 0, lz = 0;
  int    lastShakeMs = 0;
  bool   isCounting  = false;
  int    countdown   = kCountdownSec;
  Timer? cdTimer;

  accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((AccelerometerEvent e) {
    final dx    = (e.x - lx).abs();
    final dy    = (e.y - ly).abs();
    final dz    = (e.z - lz).abs();
    final delta = max(dx, max(dy, dz));
    final now   = DateTime.now().millisecondsSinceEpoch;

    lx = e.x; ly = e.y; lz = e.z;

    if (delta > kShakeThreshold &&
        now - lastShakeMs > kShakeCooldownMs &&
        !isCounting) {
      lastShakeMs = now;
      isCounting  = true;
      countdown   = kCountdownSec;

      service.invoke('shakeDetected', {'countdown': countdown});
      _showCountdownNotification(countdown);

      cdTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        countdown--;
        service.invoke('countdownTick', {'value': countdown});
        _showCountdownNotification(countdown);

        if (countdown <= 0) {
          t.cancel();
          isCounting = false;
          await _triggerEmergency(service);
        }
      });
    }
  });

  service.on('cancelEmergency').listen((_) {
    cdTimer?.cancel();
    isCounting = false;
    countdown  = kCountdownSec;
    _clearNotification();
    service.invoke('emergencyCancelled', {});
  });
}

Future<void> _triggerEmergency(ServiceInstance service) async {
  _clearNotification();

  Position? pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  } catch (_) {}

  final mapURL = pos != null
      ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
      : null;

  service.invoke('emergencyTriggered', {
    'lat':    pos?.latitude,
    'lng':    pos?.longitude,
    'mapURL': mapURL,
  });

  await _showEmergencyNotification(mapURL);
}

final _notifPlugin = FlutterLocalNotificationsPlugin();

Future<void> _showCountdownNotification(int sec) async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit     = DarwinInitializationSettings();
  await _notifPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  await _notifPlugin.show(
    888,
    '🚨 EMERGENCY IN $sec SECONDS',
    'Shake detected! Tap to open app and cancel.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'guardian_emergency',
        'Guardian Emergency',
        channelDescription: 'Emergency alerts',
        importance:       Importance.max,
        priority:         Priority.max,
        ongoing:          true,
        autoCancel:       false,
        color:            Color(0xFFFF3B3B),
        enableVibration:  true,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    ),
  );
}

Future<void> _showEmergencyNotification(String? mapURL) async {
  final body = mapURL != null
      ? 'Opening WhatsApp call. Location: $mapURL'
      : 'Opening WhatsApp call. Location unavailable.';

  await _notifPlugin.show(
    889,
    '🚨 Emergency — Opening WhatsApp Call',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'guardian_emergency',
        'Guardian Emergency',
        importance:       Importance.max,
        priority:         Priority.max,
        color:            Color(0xFFFF3B3B),
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert:      true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    ),
  );
}

Future<void> _clearNotification() async {
  await _notifPlugin.cancel(888);
}
