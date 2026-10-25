import 'package:flutter/material.dart';

import '../theme/proxo_surface.dart';
import '../theme/proxo_design_tokens.dart';
import 'proxo_png_icon.dart';
import 'auth/auth_design.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// One content-sized empty/error surface. The surrounding screen owns scrolling
/// and state; no fixed height or text truncation can hide its primary action.
class ProxoEmptyState extends StatelessWidget {
  const ProxoEmptyState({
    super.key,
    required this.symbol,
    required this.title,
    required this.body,
    required this.action,
    this.details,
    this.isError = false,
  });

  final ProxoSymbolName symbol;
  final String title;
  final String body;
  final Widget action;
  final Widget? details;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.symmetric(
            horizontal: ProxoSurface.padding, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      isError ? AuthTokens.dangerBg : ProxoSurface.accentSoft,
                  borderRadius:
                      BorderRadius.circular(ProxoSurface.controlRadius),
                ),
                child: ProxoPngIcon(symbol,
                    size: 24,
                    color: isError ? AuthTokens.danger : ProxoSurface.accent),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: ProxoText(title,
                  translate: true,
                  textAlign: TextAlign.center,
                  style: ProxoDesign.emptyTitle),
            ),
            const SizedBox(height: 8),
            ProxoText(body,
                translate: true,
                textAlign: TextAlign.center,
                style: ProxoDesign.emptyDescription),
            if (details != null) ...[
              const SizedBox(height: 16),
              details!,
            ],
            const SizedBox(height: 20),
            action,
          ],
        ),
      );
}
