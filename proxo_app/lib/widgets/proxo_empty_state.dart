import 'package:flutter/material.dart';

import '../theme/proxo_surface.dart';
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
        constraints: const BoxConstraints(maxWidth: ProxoSurface.maxWidth),
        padding: const EdgeInsets.fromLTRB(ProxoSurface.padding, 24,
            ProxoSurface.padding, ProxoSurface.padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ProxoSurface.radius),
          border: Border.all(color: ProxoSurface.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      isError ? AuthTokens.dangerBg : ProxoSurface.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ProxoSymbol(symbol,
                    size: 30,
                    color: isError ? AuthTokens.danger : ProxoSurface.accent),
              ),
            ),
            const SizedBox(height: ProxoSurface.sectionGap),
            Semantics(
              header: true,
              child: ProxoText(title,
                  translate: true,
                  textAlign: TextAlign.center,
                  style: ProxoSurface.title),
            ),
            const SizedBox(height: 8),
            ProxoText(body,
                translate: true,
                textAlign: TextAlign.center,
                style: ProxoSurface.body.copyWith(color: ProxoSurface.muted)),
            if (details != null) ...[
              const SizedBox(height: ProxoSurface.sectionGap),
              details!,
            ],
            const SizedBox(height: ProxoSurface.sectionGap),
            action,
          ],
        ),
      );
}
