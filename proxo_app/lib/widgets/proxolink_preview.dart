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
  const ProxoLinkPreview({
    super.key,
    required this.loadUrl,
    this.allowContactActions = false,
    this.requestHeaders = const {},
  });
  @override
  State<ProxoLinkPreview> createState() => _ProxoLinkPreviewState();
}

class _ProxoLinkPreviewState extends State<ProxoLinkPreview> {
  WebViewController? _controller;
  Uri? _page;
  bool _loading = true, _failed = false;
  int _request = 0;
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
    if (mounted)
      setState(() {
        _loading = true;
        _failed = false;
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
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _navigation,
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted)
                setState(() {
                  _failed = true;
                  _loading = false;
                });
            },
            onHttpError: (error) {
              if (error.request?.uri == page && mounted)
                setState(() {
                  _failed = true;
                  _loading = false;
                });
            },
          ),
        );
      if (!mounted || request != _request) return;
      setState(() => _controller = controller);
      await controller.loadRequest(page, headers: widget.requestHeaders);
    } catch (_) {
      if (mounted && request == _request)
        setState(() {
          _failed = true;
          _loading = false;
        });
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
    const hosts = {
      'wa.me',
      't.me',
      'instagram.com',
      'www.instagram.com',
      'tiktok.com',
      'www.tiktok.com',
      'vm.tiktok.com',
      'vt.tiktok.com',
    };
    final allowed =
        {'whatsapp', 'viber', 'tel', 'mailto'}.contains(uri.scheme) ||
        (uri.scheme == 'https' && hosts.contains(uri.host.toLowerCase()));
    if (allowed) {
      bool opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // A missing native app may throw instead of returning false.
      }
      if (!opened && uri.scheme == 'whatsapp') {
        try {
          final phone = uri.queryParameters['phone'];
          if (phone != null && RegExp(r'^\d{8,15}$').hasMatch(phone)) {
            opened = await launchUrl(
              Uri.https('wa.me', '/$phone'),
              mode: LaunchMode.externalApplication,
            );
          }
        } catch (_) {}
      }
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: ProxoText('نەتوانرا ئەپەکە بکرێتەوە.')),
        );
      }
    }
    return NavigationDecision.prevent;
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_controller != null && !_failed)
        WebViewWidget(controller: _controller!),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_failed)
        ColoredBox(
          color: Colors.white,
          child: Center(
            child: Padding(
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
