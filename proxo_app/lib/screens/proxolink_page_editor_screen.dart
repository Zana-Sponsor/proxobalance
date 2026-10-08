import 'package:flutter/material.dart';

import '../models/proxo_card.dart';
import '../services/proxolink_service.dart';
import '../widgets/ad_form_components.dart';
import '../widgets/receipt/receipt_kit.dart';
import 'proxolink_page_editor.dart';

class ProxoLinkPageEditorScreen extends StatefulWidget {
  final ProxoLinkRepository repository;
  final ProxoCard? existing;
  const ProxoLinkPageEditorScreen({
    super.key,
    required this.repository,
    this.existing,
  });
  @override
  State<ProxoLinkPageEditorScreen> createState() =>
      _ProxoLinkPageEditorScreenState();
}

class _ProxoLinkPageEditorScreenState extends State<ProxoLinkPageEditorScreen> {
  final _editor = GlobalKey<ProxoLinkPageEditorState>();
  bool _leaving = false;
  Future<void> _back() async {
    if (_leaving ||
        !await (_editor.currentState?.requestClose() ?? Future.value(true)) ||
        !mounted)
      return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AdUi.theme(context),
    child: PopScope<ProxoCard>(
      canPop: _leaving,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ReceiptAppBar(
                title: widget.existing == null
                    ? 'دروستکردنی پەڕە'
                    : 'دەستکاریکردنی پەڕە',
                onBack: _back,
              ),
              Expanded(
                child: ProxoLinkPageEditor(
                  key: _editor,
                  repository: widget.repository,
                  existing: widget.existing,
                  onSaved: (page) async {
                    setState(() => _leaving = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.pop(context, page);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
