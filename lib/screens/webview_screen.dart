import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

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

    final XFile? file = await openFile(
      acceptedTypeGroups: acceptedTypeGroups,
    );
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

      if (acceptType.isEmpty ||
          acceptType == '*' ||
          acceptType == '*/*') {
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {
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
          },
          onPageFinished: (String url) {
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
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
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

    controller.loadRequest(Uri.parse(widget.url));

    _controller = controller;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: SafeArea(child: WebViewWidget(controller: _controller)),
      ),
    );
  }
}
