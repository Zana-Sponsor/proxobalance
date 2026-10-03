import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// The existing Home destinations, styled with the Create Ad card system.
class HomeQuickActions extends StatelessWidget {
  final VoidCallback? onCreateTap;
  final VoidCallback? onToolsTap;
  final VoidCallback? onFaqTap;

  const HomeQuickActions({
    super.key,
    this.onCreateTap,
    this.onToolsTap,
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
                _QuickActionCard(
                  key: const ValueKey('home-create-ad'),
                  icon: Icons.add_rounded,
                  title: 'کەمپەینی نوێ',
                  subtitle: 'کەمپەینێکی نوێ دروست بکە!',
                  onTap: onCreateTap,
                ),
                const SizedBox(height: 16),
                _QuickActionCard(
                  key: const ValueKey('home-contact-tools'),
                  icon: Icons.link_rounded,
                  title: 'ئامرازی پەیوەندی',
                  subtitle: 'لاندینگ پەیجێکی پەیوەندی دروست بکە!',
                  onTap: onToolsTap,
                ),
                const SizedBox(height: 16),
                _QuickActionCard(
                  key: const ValueKey('home-faq'),
                  icon: Icons.question_mark_rounded,
                  title: 'پرسیارە دووبارەکان',
                  subtitle: 'وەڵامی پرسیارە باوەکان ببینە!',
                  onTap: onFaqTap,
                ),
              ],
            ),
          ),
        ),
      );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  const _QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final iconWell = Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: AdUi.controlRadius,
                    ),
                    child: Icon(icon, color: AdUi.blue),
                  );
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProxoText(title, style: AdUi.text(context)),
                      const SizedBox(height: 6),
                      ProxoText(
                        subtitle,
                        style: AdUi.text(context, color: AdUi.secondary),
                      ),
                    ],
                  );
                  const chevron = Directionality(
                    textDirection: TextDirection.ltr,
                    child:
                        Icon(Icons.chevron_left_rounded, color: AdUi.secondary),
                  );
                  double minimumWidth(String text) {
                    final painter = TextPainter(
                      text: TextSpan(text: text, style: AdUi.text(context)),
                      textDirection: ProxoTextDirection.of(text),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final width = painter.minIntrinsicWidth;
                    painter.dispose();
                    return width;
                  }

                  final textWidth = constraints.maxWidth -
                      48 -
                      16 -
                      8 -
                      (IconTheme.of(context).size ?? 24);
                  if (textWidth < minimumWidth(title) ||
                      textWidth < minimumWidth(subtitle)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [iconWell, const Spacer(), chevron]),
                        const SizedBox(height: 16),
                        copy,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      iconWell,
                      const SizedBox(width: 16),
                      Expanded(child: copy),
                      const SizedBox(width: 8),
                      chevron,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
}
