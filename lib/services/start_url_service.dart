import 'package:shared_preferences/shared_preferences.dart';

class StartUrlService {
  static const String loginUrl = 'http://uygaria.com/memket.php';
  static const String loggedInUrl = 'https://ardahanli.com/index.php?m=logok';

  static const String _hasLoggedInKey = 'has_logged_in_route';

  static Future<String> getInitialUrl({String fallbackUrl = loginUrl}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool hasLoggedIn = preferences.getBool(_hasLoggedInKey) ?? false;
    return hasLoggedIn ? loggedInUrl : fallbackUrl;
  }

  static Future<void> markLoggedInIfNeeded(String url) async {
    if (!isLoggedInUrl(url)) {
      return;
    }

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_hasLoggedInKey, true);
  }

  static bool isLoggedInUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    final String host = uri.host.toLowerCase();
    return (host == 'ardahanli.com' || host.endsWith('.ardahanli.com')) &&
        uri.path == '/index.php' &&
        uri.queryParameters['m'] == 'logok';
  }
}
