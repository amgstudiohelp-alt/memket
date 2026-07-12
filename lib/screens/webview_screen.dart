import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:ardahan_kulubu/services/start_url_service.dart';
import 'package:ardahan_kulubu/services/web_session_persistence.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final bool isConnected;
  const WebViewScreen({super.key, required this.url, this.isConnected = true});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const Duration _cookieSaveDebounce = Duration(seconds: 1);
  static const Duration _periodicCookieSaveInterval = Duration(seconds: 5);
  static const Color _fallbackTopChromeColor = Color(0xFF0B6595);
  static final RegExp _hexColorPattern = RegExp(
    r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$',
  );
  static final RegExp _numberPattern = RegExp(r'[\d.]+');
  static const String _topChromeColorSyncScript = r'''
    (function() {
      var channel = window.MemketChrome;
      if (!channel || !channel.postMessage) {
        return;
      }

      function hasVisibleBackground(color) {
        if (!color || color === 'transparent') {
          return false;
        }

        var rgba = color.match(/rgba?\(([^)]+)\)/i);
        if (!rgba) {
          return true;
        }

        var parts = rgba[1].split(',').map(function(part) {
          return part.trim();
        });

        return parts.length < 4 || parseFloat(parts[3]) > 0;
      }

      function backgroundFrom(element) {
        while (element && element !== document) {
          var style = window.getComputedStyle(element);
          if (style && hasVisibleBackground(style.backgroundColor)) {
            return style.backgroundColor;
          }
          element = element.parentElement;
        }

        return null;
      }

      function firstMatchingElement(selectors) {
        for (var i = 0; i < selectors.length; i++) {
          var element = document.querySelector(selectors[i]);
          if (element) {
            return element;
          }
        }

        return null;
      }

      function sendTopColor() {
        var x = Math.max(1, Math.floor(window.innerWidth / 2));
        var y = Math.max(1, Math.min(24, window.innerHeight - 1));
        var probe = document.elementFromPoint(x, y);
        var header = firstMatchingElement([
          'header',
          'nav',
          '.navbar',
          '.topbar',
          '.top-bar',
          '.appbar',
          '.app-bar',
          '#header',
          '#navbar',
          '#topbar'
        ]);
        var color =
          backgroundFrom(probe) ||
          backgroundFrom(header) ||
          backgroundFrom(document.body) ||
          backgroundFrom(document.documentElement);

        if (color) {
          channel.postMessage(color);
        }
      }

      sendTopColor();
      window.setTimeout(sendTopColor, 250);
      window.setTimeout(sendTopColor, 1000);

      if (!window.__memketChromeColorSyncInstalled) {
        window.__memketChromeColorSyncInstalled = true;
        window.addEventListener('resize', sendTopColor);
        window.addEventListener('scroll', sendTopColor, { passive: true });
      }
    })();
  ''';
  late final WebViewController _controller;
  late final _WebViewLifecycleObserver _lifecycleObserver;
  Timer? _sessionSaveTimer;
  Color _topChromeColor = _fallbackTopChromeColor;
  bool _saveScheduled = false;
  bool _lastMainFrameLoadFailed = false;

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    if (params.mode == FileSelectorMode.save) {
      return <String>[];
    }

    final List<XTypeGroup> acceptedTypeGroups = _acceptedTypeGroups(
      params.acceptTypes,
    );

    if (params.mode == FileSelectorMode.openMultiple) {
      final List<XFile> files = await openFiles(
        acceptedTypeGroups: acceptedTypeGroups,
      );
      return files.map(_toWebViewFileUri).toList();
    }

    final XFile? file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
    return file == null ? <String>[] : <String>[_toWebViewFileUri(file)];
  }

  List<XTypeGroup> _acceptedTypeGroups(List<String> acceptTypes) {
    final Set<String> mimeTypes = <String>{};
    final Set<String> extensions = <String>{};

    for (final String rawAcceptType in acceptTypes.expand(
      (String value) => value.split(','),
    )) {
      final String acceptType = rawAcceptType
          .trim()
          .toLowerCase()
          .split(';')
          .first;

      if (acceptType.isEmpty || acceptType == '*' || acceptType == '*/*') {
        return const <XTypeGroup>[];
      }

      if (acceptType.startsWith('.')) {
        extensions.add(acceptType.substring(1));
      } else if (acceptType.contains('/')) {
        mimeTypes.add(acceptType);
      } else {
        extensions.add(acceptType);
      }
    }

    if (mimeTypes.isEmpty && extensions.isEmpty) {
      return const <XTypeGroup>[];
    }

    return <XTypeGroup>[
      XTypeGroup(
        label: 'accepted files',
        mimeTypes: mimeTypes.toList(),
        extensions: extensions.toList(),
      ),
    ];
  }

  String _toWebViewFileUri(XFile file) {
    final Uri? uri = Uri.tryParse(file.path);
    if (uri != null && uri.hasScheme) {
      return uri.toString();
    }

    return Uri.file(file.path).toString();
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _WebViewLifecycleObserver(_saveSession);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _sessionSaveTimer = Timer.periodic(
      _periodicCookieSaveInterval,
      (_) => unawaited(_saveSession()),
    );

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'MemketChrome',
        onMessageReceived: _handleChromeColorMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {
            _lastMainFrameLoadFailed = false;
            _syncAuthenticationRoute(url);
            controller.runJavaScript('''
              (function() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                  meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no');
                } else {
                  meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
                  document.getElementsByTagName('head')[0].appendChild(meta);
                }
                
                var lastTouchEnd = 0;
                document.addEventListener('touchend', function(e) {
                  var now = (new Date()).getTime();
                  if (now - lastTouchEnd <= 300) {
                    e.preventDefault();
                  }
                  lastTouchEnd = now;
                }, { passive: false });
                
                document.addEventListener('gesturestart', function(e) {
                  e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gesturechange', function(e) {
                  e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gestureend', function(e) {
                  e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('touchstart', function(e) {
                  if (e.touches.length > 1) {
                    e.preventDefault();
                  }
                }, { passive: false });
                
                document.addEventListener('touchmove', function(e) {
                  if (e.touches.length > 1 || (e.scale && e.scale !== 1)) {
                    e.preventDefault();
                  }
                }, { passive: false });
                
                document.addEventListener('dblclick', function(e) {
                  e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('mousewheel', function(e) {
                  if (e.ctrlKey) {
                    e.preventDefault();
                  }
                }, { passive: false });
                
                document.addEventListener('wheel', function(e) {
                  if (e.ctrlKey) {
                    e.preventDefault();
                  }
                }, { passive: false });
                
                document.body.style.touchAction = 'pan-x pan-y';
                document.documentElement.style.touchAction = 'pan-x pan-y';
              })();
            ''');
            unawaited(_syncTopChromeColor(controller));
          },
          onPageFinished: (String url) {
            _lastMainFrameLoadFailed = false;
            _syncAuthenticationRoute(url);
            controller.runJavaScript('''
              (function() {
                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                  meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no');
                }
                document.body.style.touchAction = 'pan-x pan-y';
                document.documentElement.style.touchAction = 'pan-x pan-y';
              })();
            ''');
            unawaited(_syncTopChromeColor(controller));
            _scheduleSessionSave();
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              _lastMainFrameLoadFailed = true;
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            _syncAuthenticationRoute(request.url);
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;
      androidController
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setAllowFileAccess(true)
        ..setAllowContentAccess(true)
        ..setOnShowFileSelector(_androidFilePicker);
    }

    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    _controller = controller;
    unawaited(_loadInitialRequest());
  }

  @override
  void didUpdateWidget(covariant WebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isConnected &&
        widget.isConnected &&
        _lastMainFrameLoadFailed) {
      unawaited(_reloadFailedMainFrame());
    }
  }

  Future<void> _reloadFailedMainFrame() async {
    _lastMainFrameLoadFailed = false;
    await _controller.reload();
  }

  Future<void> _loadInitialRequest() async {
    await WebSessionPersistence.restore();
    final String initialUrl = await StartUrlService.getInitialUrl(
      fallbackUrl: widget.url,
    );

    if (!mounted) {
      return;
    }

    await _controller.loadRequest(Uri.parse(initialUrl));
  }

  void _syncAuthenticationRoute(String url) {
    unawaited(StartUrlService.syncAuthenticationStateForUrl(url));
  }

  Future<void> _syncTopChromeColor(WebViewController controller) async {
    try {
      await controller.runJavaScript(_topChromeColorSyncScript);
    } catch (e) {
      debugPrint("Top chrome color sync failed: $e");
    }
  }

  void _handleChromeColorMessage(JavaScriptMessage message) {
    final Color? color = _parseCssColor(message.message);
    if (!mounted || color == null || color == _topChromeColor) {
      return;
    }

    setState(() {
      _topChromeColor = color;
    });
  }

  Color? _parseCssColor(String value) {
    final String color = value.trim();
    if (color.isEmpty || color.toLowerCase() == 'transparent') {
      return null;
    }

    final RegExpMatch? hexMatch = _hexColorPattern.firstMatch(color);
    if (hexMatch != null) {
      return _parseHexColor(hexMatch.group(1)!);
    }

    final List<double> channels = _numberPattern
        .allMatches(color)
        .map((RegExpMatch match) => double.parse(match.group(0)!))
        .toList();

    if (channels.length < 3 || (channels.length >= 4 && channels[3] == 0)) {
      return null;
    }

    return Color.fromARGB(
      255,
      channels[0].round().clamp(0, 255),
      channels[1].round().clamp(0, 255),
      channels[2].round().clamp(0, 255),
    );
  }

  Color _parseHexColor(String hexColor) {
    final String normalized = hexColor.length == 3
        ? hexColor.split('').map((String char) => '$char$char').join()
        : hexColor;

    return Color(int.parse('FF$normalized', radix: 16));
  }

  SystemUiOverlayStyle get _systemUiOverlayStyle {
    final Brightness backgroundBrightness =
        ThemeData.estimateBrightnessForColor(_topChromeColor);
    final SystemUiOverlayStyle baseStyle =
        backgroundBrightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return baseStyle.copyWith(
      statusBarColor: _topChromeColor,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
  }

  void _scheduleSessionSave() {
    if (_saveScheduled) {
      return;
    }

    _saveScheduled = true;
    Future<void>.delayed(_cookieSaveDebounce, () async {
      _saveScheduled = false;
      await _saveSession();
    });
  }

  Future<void> _saveSession() {
    return WebSessionPersistence.save();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _sessionSaveTimer?.cancel();
    unawaited(WebSessionPersistence.save());
    super.dispose();
  }

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }

    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: _handlePopInvoked,
        child: Scaffold(
          backgroundColor: _topChromeColor,
          body: ColoredBox(
            color: _topChromeColor,
            child: SafeArea(
              bottom: Theme.of(context).platform != TargetPlatform.iOS,
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebViewLifecycleObserver extends WidgetsBindingObserver {
  _WebViewLifecycleObserver(this.onShouldSave);

  final Future<void> Function() onShouldSave;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(onShouldSave());
    }
  }
}
