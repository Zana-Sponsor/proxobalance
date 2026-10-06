import 'dart:async';
import 'dart:convert';

import '../models/proxolink_template_meta.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/proxolink_service.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

class ProxoLinkPreview extends StatefulWidget {
  final Future<Uri> Function() loadUrl;
  final bool allowContactActions;

  /// Initial request headers for access-controlled preview environments.
  /// Production callers use the empty default; values are never logged.
  final Map<String, String> requestHeaders;
  final ValueChanged<WebViewController>? onControllerCreated;
  final Duration loadTimeout;
  const ProxoLinkPreview({
    super.key,
    required this.loadUrl,
    this.allowContactActions = false,
    this.requestHeaders = const {},
    this.onControllerCreated,
    this.loadTimeout = const Duration(seconds: 45),
  });
  @override
  State<ProxoLinkPreview> createState() => _ProxoLinkPreviewState();
}

class _ProxoLinkPreviewState extends State<ProxoLinkPreview> {
  WebViewController? _controller;
  Uri? _page;
  bool _loading = true, _failed = false;
  int _request = 0;
  Timer? _watchdog;

  bool _current(int request) => mounted && request == _request;

  void _fail(int request) {
    if (!_current(request)) return;
    _watchdog?.cancel();
    _request++;
    setState(() {
      _page = null;
      _controller = null;
      _failed = true;
      _loading = false;
    });
  }
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProxoLinkPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent keys this widget by card/template identity. A new closure on
    // an unrelated form rebuild must not restart the real WebView.
  }

  Future<void> _load() async {
    final request = ++_request;
    _watchdog?.cancel();
    _watchdog = Timer(widget.loadTimeout, () => _fail(request));
    if (mounted)
      setState(() {
        _loading = true;
        _failed = false;
        _page = null;
        _controller = null;
      });
    try {
      final page = await widget.loadUrl();
      if (!mounted || request != _request) return;
      final base = Uri.parse(ProxoLinkService.publicBase);
      if (page.scheme != 'https' ||
          page.origin != base.origin ||
          !(page.path.startsWith('/contact/') ||
              page.path == '/contact-preview')) {
        throw const ProxoLinkFailure('invalid_request');
      }
      _page = page;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel('ProxoLinkNavigation', onMessageReceived: (message) {
          if (!_current(request) || !widget.allowContactActions || message.message.length > 5000) return;
          try {
            final data = jsonDecode(message.message);
            if (data is! Map || data['type'] != 'openExternal' || data['url'] is! String) return;
            final url = Uri.tryParse(data['url'] as String);
            if (url != null && allowedProxoExternal(url)) unawaited(_openExternal(url));
          } catch (_) { /* Reject malformed messages without navigating. */ }
        })
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (navigation) => _current(request)
                ? _navigation(navigation)
                : Future.value(NavigationDecision.prevent),
            onPageStarted: (_) {
              if (_current(request)) {
                _watchdog?.cancel();
                _watchdog = Timer(widget.loadTimeout, () => _fail(request));
                setState(() => _loading = true);
              }
            },
            onPageFinished: (_) {
              if (_current(request)) {
                _watchdog?.cancel();
                setState(() => _loading = false);
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true) _fail(request);
            },
            onHttpError: (error) {
              if (error.request?.uri == page) _fail(request);
            },
          ),
        );
      if (!mounted || request != _request) return;
      setState(() => _controller = controller);
      widget.onControllerCreated?.call(controller);
      await controller.loadRequest(page, headers: widget.requestHeaders);
    } catch (_) {
      _fail(request);
    }
  }

  Future<NavigationDecision> _navigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null || _page == null) return NavigationDecision.prevent;
    if (uri.scheme == 'https' &&
        uri.origin == _page!.origin &&
        uri.path == _page!.path &&
        uri.query == _page!.query)
      return NavigationDecision.navigate;
    if (!widget.allowContactActions) return NavigationDecision.prevent;
    if (allowedProxoExternal(uri)) await _openExternal(uri);

    return NavigationDecision.prevent;
  }

  Future<void> _openExternal(Uri uri) async {
    if (!widget.allowContactActions || !allowedProxoExternal(uri)) return;
    var opened = false;
    try { opened = await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
    if (!opened && uri.scheme == 'viber') {
      try { opened = await launchUrl(Uri.https('www.viber.com', '/en/download/'), mode: LaunchMode.externalApplication); } catch (_) {}
    }
    if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: ProxoText('نەتوانرا ئەپەکە بکرێتەوە.')),
    );
  }

  @override
  void dispose() {
    _request++;
    _watchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_controller != null && !_failed)
        WebViewWidget(
          controller: _controller!,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_failed)
        ColoredBox(
          color: Colors.white,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProxoText('پێشبینین نەکرایەوە', style: AdUi.heading(context)),
                  const SizedBox(height: 12),
                  ProxoText(
                    'تکایە پەیوەندی ئینتەرنێتەکەت بپشکنە.',
                    style: AdUi.text(context, color: AdUi.secondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _load,
                    child: const ProxoText('دووبارە هەوڵبدەرەوە'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
