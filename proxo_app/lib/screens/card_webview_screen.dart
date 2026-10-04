import 'package:flutter/material.dart';

import '../widgets/ad_form_components.dart';
import '../widgets/proxo_text.dart';
import '../widgets/proxolink_preview.dart';

class CardWebViewScreen extends StatelessWidget {
  final String title;
  final Future<Uri> Function() loadUrl;
  final bool allowContactActions;
  const CardWebViewScreen({
    super.key,
    required this.title,
    required this.loadUrl,
    this.allowContactActions = true,
  });
  @override
  Widget build(BuildContext context) => Theme(
    data: AdUi.theme(context),
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: ProxoText(title, style: AdUi.heading(context)),
      ),
      body: SafeArea(
        child: ProxoLinkPreview(
          loadUrl: loadUrl,
          allowContactActions: allowContactActions,
        ),
      ),
    ),
  );
}
