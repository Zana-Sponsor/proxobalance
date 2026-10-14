import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/proxo_icons.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Three primary destinations. Native icons and scalable Sorani labels follow
/// the user's latest instruction; tools/help remain secondary destinations.
class HomeQuickActions extends StatelessWidget {
  final VoidCallback? onCreateTap,
      onAddBalanceTap,
      onToolsTap,
      onCreatePageTap,
      onFaqTap;
  const HomeQuickActions({
    super.key,
    this.onCreateTap,
    this.onAddBalanceTap,
    this.onToolsTap,
    this.onCreatePageTap,
    this.onFaqTap,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProxoText('کردارە خێراکان', style: AdUi.heading(context)),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = [
                  _QuickActionCard(
                    key: const ValueKey('home-create-ad'),
                    icon: ProxoIcons.createAd,
                    title: 'دروستکردنی ڕیکلام',
                    onTap: onCreateTap,
                  ),
                  _QuickActionCard(
                    key: const ValueKey('home-add-balance'),
                    icon: ProxoIcons.wallet,
                    title: 'زیادکردنی باڵانس',
                    onTap: onAddBalanceTap,
                  ),
                  _QuickActionCard(
                    key: const ValueKey('home-create-page'),
                    icon: ProxoIcons.createPage,
                    title: 'دروستکردنی پەڕە',
                    onTap: onCreatePageTap,
                  ),
                ];
                // Fit complete words using the real font and system text scale.
                // Narrow devices/large text reflow instead of shrinking the labels.
                double widestWord = 0;
                for (final card in cards) {
                  final painter = TextPainter(
                    text: TextSpan(text: card.title, style: AdUi.text(context)),
                    textDirection: TextDirection.rtl,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  if (painter.minIntrinsicWidth > widestWord)
                    widestWord = painter.minIntrinsicWidth;
                  painter.dispose();
                }
                const gap = 12.0; // Existing control spacing.
                final tileWidth = (constraints.maxWidth - gap * 2) / 3;
                if (tileWidth - AdUi.cardPadding.horizontal < widestWord) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: gap),
                        cards[i],
                      ],
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const ValueKey('home-contact-tools'),
                    style: TextButton.styleFrom(foregroundColor: AdUi.blue),
                    onPressed: onToolsTap,
                    icon: const Icon(ProxoIcons.pages),
                    label: ProxoText(
                      'ProxoLink — پەڕەکانم',
                      style: AdUi.text(context),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('home-faq'),
                    style: TextButton.styleFrom(foregroundColor: AdUi.blue),
                    onPressed: onFaqTap,
                    icon: const Icon(ProxoIcons.help),
                    label: ProxoText(
                      'پرسیارە دووبارەکان',
                      style: AdUi.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const _QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AdUi.secondary : AdUi.blue;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AdUi.radius,
            boxShadow: AdUi.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: AdUi.radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: AdUi.radius,
              child: Padding(
                padding: AdUi.cardPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: AdUi.controlRadius,
                      ),
                      child: Icon(icon, size: 24, color: color),
                    ),
                    const SizedBox(height: 12),
                    ProxoText(
                      title,
                      textAlign: TextAlign.center,
                      style: AdUi.text(
                        context,
                        color: onTap == null ? AdUi.secondary : AdUi.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
