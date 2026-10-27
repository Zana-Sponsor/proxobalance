import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/proxo_strings.dart';
import '../services/context_help_service.dart';
import '../theme/app_theme.dart';
import '../theme/ad_form_colors.dart';
import 'proxo_text.dart';
import 'proxo_toast.dart';
import 'proxo_symbol.dart';

class FormHelpActions extends StatefulWidget {
  const FormHelpActions(
      {super.key,
      required this.helpKey,
      this.exampleAsset,
      this.exampleCaption,
      this.sampleValue,
      this.loadTutorial,
      this.openUrl});
  final String helpKey;
  final String? exampleAsset, exampleCaption, sampleValue;
  final Future<Uri?> Function(String)? loadTutorial;
  final Future<bool> Function(Uri)? openUrl;
  @override
  State<FormHelpActions> createState() => _FormHelpActionsState();
}

class _FormHelpActionsState extends State<FormHelpActions> {
  bool _opening = false;
  String? _cachedExample;
  ImageProvider _exampleImage(String asset) =>
      ResizeImage.resizeIfNeeded(720, null, AssetImage(asset));

  void _warmExample() {
    final asset = widget.exampleAsset;
    if (asset == null || asset.endsWith('.svg') || _cachedExample == asset)
      return;
    _cachedExample = asset;
    precacheImage(_exampleImage(asset), context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warmExample();
  }

  @override
  void didUpdateWidget(covariant FormHelpActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _warmExample();
  }

  String tr(String text) => ProxoStrings.text(text);
  void _message(String text) {
    if (mounted) showProxoToast(context, tr(text));
  }

  Future<void> _tutorial() async {
    if (_opening) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = true);
    try {
      final uri = await (widget.loadTutorial ??
          ContextHelpService().tutorialFor)(widget.helpKey);
      if (!mounted) return;
      if (uri == null) {
        _message('فێرکاری ئەم بەشە هێشتا زیاد نەکراوە');
        return;
      }
      final valid = ContextHelpService.validVideoUrl(uri.toString());
      if (valid == null) {
        _message('نەتوانرا فێرکاری بکرێتەوە');
        return;
      }
      final opened = await (widget.openUrl ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(valid);
      if (!opened) _message('نەتوانرا فێرکاری بکرێتەوە');
    } catch (_) {
      _message('نەتوانرا فێرکاری بکرێتەوە');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _example() {
    FocusManager.instance.primaryFocus?.unfocus();
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: 440,
                      maxHeight: MediaQuery.sizeOf(context).height * .85),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          Expanded(
                              child: ProxoText(tr('بینینی نمونە'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400))),
                          IconButton(
                              tooltip: tr('داخستن'),
                              onPressed: () => Navigator.pop(context),
                              icon: const ProxoSymbol(ProxoSymbolName.close,
                                  size: 20))
                        ]),
                        const SizedBox(height: 12),
                        if (widget.exampleAsset!.endsWith('.svg'))
                          SvgPicture.asset(widget.exampleAsset!,
                              semanticsLabel:
                                  tr(widget.exampleCaption ?? 'بینینی نمونە'))
                        else
                          ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image(
                                  image: _exampleImage(widget.exampleAsset!),
                                  fit: BoxFit.contain,
                                  semanticLabel: tr(widget.exampleCaption ??
                                      'بینینی نمونە'))),
                        if (widget.exampleCaption != null) ...[
                          const SizedBox(height: 16),
                          ProxoText(tr(widget.exampleCaption!),
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400))
                        ],
                        if (widget.sampleValue != null) ...[
                          const SizedBox(height: 12),
                          Directionality(
                              textDirection: TextDirection.ltr,
                              child: SelectableText(widget.sampleValue!,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          AdFormColors.of(context)?.primary ??
                                              AppColors.primary,
                                      fontWeight: FontWeight.w400)))
                        ],
                      ]))),
            ));
  }

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 4, children: [
        if (widget.exampleAsset != null)
          TextButton.icon(
              key: ValueKey('help-example-${widget.helpKey}'),
              onPressed: _example,
              icon: const ProxoSymbol(ProxoSymbolName.gallery, size: 18),
              label: ProxoText(tr('بینینی نمونە'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w400))),
        TextButton.icon(
            key: ValueKey('help-tutorial-${widget.helpKey}'),
            onPressed: _opening ? null : _tutorial,
            icon: _opening
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const ProxoSymbol(ProxoSymbolName.play, size: 18),
            label: ProxoText(tr('بینینی فێرکاری'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w400))),
      ]);
}
