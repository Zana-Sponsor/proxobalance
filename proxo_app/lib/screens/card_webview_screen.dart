import 'package:flutter/material.dart';
  import 'package:webview_flutter/webview_flutter.dart';

  import '../theme/app_theme.dart';
  import '../widgets/proxo_error_ui.dart';

  /// Renders [htmlContent] inside a full-screen WebView.
  /// Used for the card Preview button.
  class CardWebViewScreen extends StatefulWidget {
    final String title;
    final String htmlContent;

    const CardWebViewScreen({
      super.key,
      required this.title,
      required this.htmlContent,
    });

    @override
    State<CardWebViewScreen> createState() => _CardWebViewScreenState();
  }

  class _CardWebViewScreenState extends State<CardWebViewScreen> {
    late final WebViewController _controller;
    bool _loading = true;
    bool _failed  = false;

    @override
    void initState() {
      super.initState();
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            // Without this the preview sat on a spinner forever when the card
            // markup failed to render. The resource error itself is logged,
            // never shown.
            onWebResourceError: (error) {
              debugPrint('CardWebView: ${error.errorCode} ${error.description}');
              if (mounted) setState(() { _loading = false; _failed = true; });
            },
          ),
        )
        ..loadHtmlString(widget.htmlContent);
    }

    void _retry() {
      setState(() { _loading = true; _failed = false; });
      _controller.loadHtmlString(widget.htmlContent);
    }

    @override
    Widget build(BuildContext context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.ink,
          appBar: AppBar(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            title: Text(
              widget.title,
              // Was missing `fontFamily: kAppFont` entirely (silently fell
              // back to the platform default font) and used Bold where the
              // AppBar-title role calls for SemiBold.
              style: AppTypography.appBarTitle(color: Colors.white),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            elevation: 0,
          ),
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                // Covers the WebView only once it has actually failed, so a
                // working preview is never obscured.
                if (_failed)
                  Positioned.fill(
                    // The app's light surface, not the dark preview chrome:
                    // the shared error view is designed on light, and dark ink
                    // on a dark backdrop would be unreadable.
                    child: ColoredBox(
                      color: AppColors.bg,
                      child: ProxoErrorView(
                        title: 'پێشبینین نەکرایەوە',
                        message: 'نەتوانرا کارتەکە پیشان بدرێت.\n'
                            'تکایە دووبارە هەوڵ بدەرەوە.',
                        actionLabel: 'دووبارە هەوڵ بدەرەوە',
                        onAction: _retry,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }
  