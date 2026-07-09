import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:ardahan_kulubu/services/connection_service.dart';
import 'package:ardahan_kulubu/services/start_url_service.dart';
import 'package:ardahan_kulubu/services/web_session_persistence.dart';
import 'package:ardahan_kulubu/screens/webview_screen.dart';
import 'package:ardahan_kulubu/screens/offline_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  }

  OneSignal.initialize("0fba3b02-97b1-4a98-a113-98938958ec6f");

  OneSignal.Notifications.addClickListener((event) {
    if (event.notification.additionalData != null) {}
  });

  await WebSessionPersistence.restore();
  runApp(const MyApp());
  await _requestStartupPermissions();
}

Future<void> _requestStartupPermissions() async {
  await _requestNotificationPermission();
  await WebSessionPersistence.requestMediaPermissions();
}

Future<void> _requestNotificationPermission() async {
  try {
    await OneSignal.Notifications.requestPermission(true);
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
  final String _targetUrl = StartUrlService.loginUrl;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _initConnectionListener();
  }

  void _initConnectionListener() {
    _connectionSubscription = connectionService.connectionChange.listen(
      _setConnectionState,
    );
    unawaited(_refreshConnectionState());
  }

  Future<void> _refreshConnectionState() async {
    final bool initialConnection = await connectionService.checkConnection();
    if (mounted) {
      _setConnectionState(initialConnection);
    }
  }

  void _setConnectionState(bool hasConnection) {
    if (!mounted || _isConnected == hasConnection) {
      return;
    }

    setState(() {
      _isConnected = hasConnection;
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
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
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
      home: Stack(
        children: [
          WebViewScreen(url: _targetUrl, isConnected: _isConnected),
          if (!_isConnected) OfflineScreen(onRetry: _refreshConnectionState),
        ],
      ),
    );
  }
}
