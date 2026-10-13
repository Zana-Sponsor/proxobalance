import 'package:flutter/material.dart';

import 'tools_screen.dart';

/// All entry points share one canonical card list and URL preview flow.
class ProxoCardsListScreen extends StatelessWidget {
  final VoidCallback? onCreateTap;
  const ProxoCardsListScreen({super.key, this.onCreateTap});
  @override
  Widget build(BuildContext context) => const ToolsScreen();
}
