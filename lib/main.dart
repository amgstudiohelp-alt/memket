import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:ardahan_kulubu/services/connection_service.dart';
import 'package:ardahan_kulubu/services/web_session_persistence.dart';
import 'package:ardahan_kulubu/screens/webview_screen.dart';
import 'package:ardahan_kulubu/screens/offline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

  OneSignal.initialize("0fba3b02-97b1-4a98-a113-98938958ec6f");

  OneSignal.Notifications.addClickListener((event) {
    if (event.notification.additionalData != null) {}
  });

  await WebSessionPersistence.restore();
  await _requestNotificationPermission();

  runApp(const MyApp());
}

Future<void> _requestNotificationPermission() async {
  try {
    final bool canRequest = await OneSignal.Notifications.canRequest();
    if (canRequest) {
      await OneSignal.Notifications.requestPermission(true);
    }
  } catch (e) {
    debugPrint("Notification permission request failed: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isConnected = true;
  final String _targetUrl = "http://uygaria.com/memket.php";

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _initConnectionListener();
  }

  void _initConnectionListener() async {
    bool initialConnection = await connectionService.checkConnection();
    if (mounted) {
      setState(() {
        _isConnected = initialConnection;
      });
    }

    connectionService.connectionChange.listen((hasConnection) {
      if (mounted) {
        setState(() {
          _isConnected = hasConnection;
        });
      }
    });
  }

  Future<void> _checkUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memket',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isConnected
          ? WebViewScreen(url: _targetUrl)
          : const OfflineScreen(),
    );
  }
}
