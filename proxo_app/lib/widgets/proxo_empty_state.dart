import 'package:flutter/material.dart';

import '../theme/proxo_ui.dart';

/// Shared, content-sized state for genuinely empty collections.
/// Loading and retrieval errors must be handled before showing this widget.
class ProxoEmptyState extends StatelessWidget {
  const ProxoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final Widget icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProxoUi.pagePadding,
              vertical: ProxoUi.gap32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ProxoUi.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: IconTheme(
                      data: const IconThemeData(
                        color: ProxoUi.primary,
                        size: 32,
                      ),
                      child: icon,
                    ),
                  ),
                ),
                const SizedBox(height: ProxoUi.gap16),
                Semantics(
                  header: true,
                  child: Text(title,
                      textAlign: TextAlign.center, style: ProxoUi.title),
                ),
                const SizedBox(height: ProxoUi.gap8),
                Text(description,
                    textAlign: TextAlign.center, style: ProxoUi.secondary),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: ProxoUi.gap24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ProxoUi.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, ProxoUi.controlHeight),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        textStyle: ProxoUi.label,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(ProxoUi.controlRadius),
                        ),
                      ),
                      onPressed: onAction,
                      child: Text(actionLabel!, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
