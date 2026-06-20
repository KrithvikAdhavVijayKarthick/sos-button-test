import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'background_service.dart';
import 'home_screen.dart';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init local notifications
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios     = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await notifications.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  // Init and start background service
  await initBackgroundService();
  await FlutterBackgroundService().startService();

  runApp(const GuardianApp());
}

class GuardianApp extends StatelessWidget {
  const GuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080D),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF22C55E),
          secondary: Color(0xFFFF3B3B),
          surface:   Color(0xFF0F1118),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
