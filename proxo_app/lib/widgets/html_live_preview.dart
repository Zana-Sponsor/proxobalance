// ═══════════════════════════════════════════════════════════════════════
// HTML LIVE PREVIEW — the ONE real-time preview area for the Tools screen.
//
// Renders the exact same HTML that buildCardHtml() will save/send (no
// separate "mock" preview markup, and no remote proxopages.com URL —
// fully local, via webview_flutter's loadHtmlString/runJavaScript).
//
// Update strategy:
//   • First load, style switch, theme switch, language switch, logo
//     change, or a platform being toggled on/off, or TikTok flipping
//     between empty <-> non-empty (its badge is only present in the DOM
//     when non-empty, so that's a structural change too) -> full reload.
//   • Editing existing text (name / bio / an already-visible TikTok
//     handle) -> a small injected JS patch updates just the text nodes,
//     debounced, instead of reloading the whole page on every keystroke.
//
// NOTE: this widget depends on the `webview_flutter` and `url_launcher`
// packages. Add both to pubspec.yaml if the project doesn't already have
// them:
//   webview_flutter: ^4.7.0
//   url_launcher: ^6.3.2
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/html_generator.dart';

// ═══════════════════════════════════════════════════════════════════════
// NAVIGATION HANDLING — shared by every preview WebView (live + static).
//
// The generated card HTML (buildCardHtml() below / buildPLCardHTML() in
// proxo-tools.js on the website) drives its contact buttons by setting
// `window.location.href` to an app-scheme or external URL — e.g.
// `whatsapp://send?phone=…`, `viber://chat?number=…`, `tel:…`,
// `https://t.me/…`, `https://instagram.com/…`. A bare WebView has nowhere
// to send that: there's no browser chrome and no app *inside* the
// WebView, so without interception the navigation just fails silently and
// the button appears to do nothing.
//
// This delegate intercepts every non-trivial navigation attempt and hands
// it to the OS via url_launcher, which opens the real WhatsApp/Viber/
// Telegram app (or the device browser for https links) exactly as if the
// same link had been tapped outside the app. The preview itself never
// navigates away from the card.
// ═══════════════════════════════════════════════════════════════════════

Future<NavigationDecision> _handleCardNavigation(NavigationRequest request) async {
  final url = request.url;
  if (url.isEmpty || url == 'about:blank') return NavigationDecision.navigate;
  final uri = Uri.tryParse(url);
  if (uri == null) return NavigationDecision.prevent;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Nothing installed to handle it (or a malformed URL) — swallow it
    // rather than let the preview crash or show a broken-navigation page.
  }
  return NavigationDecision.prevent;
}

/// Everything the live preview needs to render one frame of the card.
@immutable
class LivePreviewData {
  final String name;
  final String bio;
  final String tiktok;
  final String logoB64;
  final PlStyle style;
  final String themeKey;
  final CardLang lang;
  final List<bool> checked;
  final Map<int, String> contacts;

  const LivePreviewData({
    required this.name,
    required this.bio,
    required this.tiktok,
    required this.logoB64,
    required this.style,
    required this.themeKey,
    required this.lang,
    required this.checked,
    required this.contacts,
  });

  bool get _hasTt => tiktok.trim().isNotEmpty;

  /// Anything that changes which DOM elements exist (not just their text).
  bool isStructurallyDifferentFrom(LivePreviewData other) {
    if (style != other.style) return true;
    if (themeKey != other.themeKey) return true;
    if (lang != other.lang) return true;
    if (logoB64 != other.logoB64) return true;
    if (_hasTt != other._hasTt) return true;
    if (checked.length != other.checked.length) return true;
    for (int i = 0; i < checked.length; i++) {
      if (checked[i] != other.checked[i]) return true;
    }
    // A contact value flipping empty <-> non-empty changes whether that
    // platform's button exists at all — structural. Editing an already
    // non-empty value is text-only (the button already exists; only its
    // click-handler target changes, which doesn't need a live visual
    // update since it isn't visible until tapped).
    for (final i in contacts.keys) {
      final a = (contacts[i] ?? '').trim().isNotEmpty;
      final b = (other.contacts[i] ?? '').trim().isNotEmpty;
      if (a != b) return true;
    }
    return false;
  }

  bool isTextDifferentFrom(LivePreviewData other) =>
      name != other.name || bio != other.bio || tiktok != other.tiktok;
}

class HtmlLivePreview extends StatefulWidget {
  final LivePreviewData data;
  final double height;
  /// True for the edge-to-edge full-screen preview route: fills all
  /// available space with no border/radius/shadow, so the card renders at
  /// its real intended size (fixing styles that use `100vh` sections,
  /// which look compressed/"distorted" inside the small inline box).
  final bool fullScreen;
  const HtmlLivePreview({
    required this.data,
    this.height = 420,
    this.fullScreen = false,
    super.key,
  });

  @override
  State<HtmlLivePreview> createState() => _HtmlLivePreviewState();
}

class _HtmlLivePreviewState extends State<HtmlLivePreview> {
  late final WebViewController _controller;
  bool _ready = false;
  bool _pendingPatch = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _ready = true);
          if (_pendingPatch) {
            _pendingPatch = false;
            _patchText();
          }
        },
        onNavigationRequest: _handleCardNavigation,
      ));
    _fullReload();
  }

  @override
  void didUpdateWidget(covariant HtmlLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.isStructurallyDifferentFrom(oldWidget.data)) {
      _debounce?.cancel();
      _fullReload();
    } else if (widget.data.isTextDifferentFrom(oldWidget.data)) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), _patchText);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _fullReload() {
    final d = widget.data;
    final html = buildCardHtml(
      name: d.name,
      bio: d.bio,
      tt: d.tiktok,
      logoB64: d.logoB64,
      themeKey: d.themeKey,
      style: d.style,
      checked: d.checked,
      contacts: d.contacts,
      lang: d.lang,
    );
    setState(() => _ready = false);
    _controller.loadHtmlString(html);
  }

  void _patchText() {
    if (!mounted) return;
    if (!_ready) { _pendingPatch = true; return; }
    final d = widget.data;
    final name = _jsStr(d.name);
    final bio = _jsStr(d.bio);
    final ttText = d._hasTt ? _jsStr('@' + d.tiktok.trim()) : "''";
    final avatarLetter =
        _jsStr(d.name.trim().isNotEmpty ? d.name.trim()[0].toUpperCase() : 'P');
    // Note: `.tt-inline`/`.tt-badge`/`.tt-sm`/`.tt-classic` only exist in
    // the DOM at all when TikTok is non-empty (see _buildTtInline/etc in
    // html_generator.dart) — and any empty<->non-empty transition is
    // already routed to _fullReload() via isStructurallyDifferentFrom(),
    // so by the time we get here these elements' *presence* hasn't
    // changed, only their text needs updating.
    final js = '''
(function(){
  var nameEl = document.querySelector('.name,.uname,.hdr-name');
  if (nameEl) nameEl.textContent = $name;

  var bioEl = document.querySelector('.desc,.ubio,.hdr-bio');
  if (bioEl) bioEl.textContent = $bio;

  var ttSpans = document.querySelectorAll('.tt-badge span, .tt-sm span, .tt-classic span');
  ttSpans.forEach(function(el){ el.textContent = $ttText; });

  var ttInline = document.querySelector('.tt-inline');
  if (ttInline) {
    var icon = ttInline.querySelector('i');
    ttInline.innerHTML = '';
    if (icon) ttInline.appendChild(icon);
    ttInline.appendChild(document.createTextNode($ttText));
  }

  var avatarSpan = document.querySelector('.avatar span, .av span, .hdr-av span');
  if (avatarSpan && !document.querySelector('.avatar img, .av img, .hdr-av img')) {
    avatarSpan.textContent = $avatarLetter;
  }
})();
''';
    _controller.runJavaScript(js);
  }

  String _jsStr(String s) {
    final escaped = s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    return "'$escaped'";
  }

  @override
  Widget build(BuildContext context) {
    final webview = Stack(fit: StackFit.expand, children: [
      WebViewWidget(controller: _controller),
      if (!_ready)
        Container(
          color: const Color(0xFFF5F6FB),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 26, height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
    ]);

    if (widget.fullScreen) {
      // No fixed height, no border/radius/shadow — fills whatever the
      // parent (a full-screen route) gives it, exactly like a real
      // browser tab showing the card.
      return SizedBox.expand(child: webview);
    }

    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5D9E8), width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: webview,
    );
  }
}

/// A plain, non-reactive WebView that just renders one fixed HTML string
/// once. Used to preview an *already-generated* card (e.g. the
/// `html_content` already saved for an existing ProxoLink card in the
/// list), as opposed to [HtmlLivePreview], which regenerates and patches
/// itself continuously from live form data. Local only — never loads a
/// proxopages.com (or any other) URL.
class StaticHtmlPreview extends StatefulWidget {
  final String html;
  const StaticHtmlPreview({required this.html, super.key});

  @override
  State<StaticHtmlPreview> createState() => _StaticHtmlPreviewState();
}

class _StaticHtmlPreviewState extends State<StaticHtmlPreview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _handleCardNavigation,
      ))
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}

// ═══════════════════════════════════════════════════════════════════════
// FULL-SCREEN PREVIEW PAGE — a chrome-free, edge-to-edge route for
// viewing a card exactly as a real visitor would. [preview] is expected
// to already be reactive (e.g. the same `AnimatedBuilder`-wrapped
// [HtmlLivePreview] the inline preview uses) so the page keeps updating
// live if it's pushed on top of the create/edit form.
// ═══════════════════════════════════════════════════════════════════════

class FullScreenCardPreviewPage extends StatelessWidget {
  final Widget preview;
  const FullScreenCardPreviewPage({required this.preview, super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: preview),
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 14,
          child: _ClosePreviewButton(onTap: () => Navigator.of(context).pop()),
        ),
      ]),
    ),
  );
}

class _ClosePreviewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClosePreviewButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withOpacity(0.45),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
      ),
    ),
  );
}
