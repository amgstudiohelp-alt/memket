import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WebSessionPersistence {
  static const MethodChannel _channel = MethodChannel(
    'com.uygaria.memket/web_session',
  );

  static Future<void> restore() => _invoke('restoreCookies');

  static Future<void> save() => _invoke('saveCookies');

  static Future<void> _invoke(String method) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // The native helper is only available on iOS release builds.
    } on PlatformException catch (error) {
      debugPrint('Web session persistence failed: ${error.message}');
    }
  }
}
