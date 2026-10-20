import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';

import '../theme/proxo_ui.dart';
import 'proxo_text.dart';

/// Three equal actions; narrow screens and large text use compact rows.
class HomeQuickActions extends StatelessWidget {
  final VoidCallback? onCreateTap;
  final VoidCallback? onToolsTap;
  final VoidCallback? onFaqTap;

  const HomeQuickActions(
      {super.key, this.onCreateTap, this.onToolsTap, this.onFaqTap});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(builder: (context, constraints) {
              final rows = constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final actions = <Widget>[
                _QuickActionCard(
                    key: const ValueKey('home-create-ad'),
                    icon: SolarIcons.target,
                    title: 'کەمپەینی نوێ',
                    onTap: onCreateTap,
                    row: rows),
                _QuickActionCard(
                    key: const ValueKey('home-contact-tools'),
                    icon: SolarIcons.link,
                    title: 'ئامرازی پەیوەندی',
                    onTap: onToolsTap,
                    row: rows),
                _QuickActionCard(
                    key: const ValueKey('home-faq'),
                    icon: SolarIcons.questionCircle,
                    title: 'پرسیارەکان',
                    onTap: onFaqTap,
                    row: rows),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProxoText('کردارە خێراکان',
                      style: ProxoUi.sectionTitle),
                  const SizedBox(height: ProxoUi.gap12),
                  if (rows)
                    Column(children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: ProxoUi.gap8),
                        actions[i],
                      ]
                    ])
                  else
                    IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: ProxoUi.gap8),
                            Expanded(child: actions[i]),
                          ]
                        ])),
                ],
              );
            }),
          ),
        ),
      );
}

class _QuickActionCard extends StatelessWidget {
  final String icon, title;
  final VoidCallback? onTap;
  final bool row;
  const _QuickActionCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.onTap,
      required this.row});

  @override
  Widget build(BuildContext context) {
    final iconWell = Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius)),
        child: SolarIcon(icon,
            style: SolarIconStyle.linear,
            size: ProxoUi.iconSize,
            color: const Color(0xFF046CFA)));
    final label = ProxoText(title,
        textAlign: row ? TextAlign.start : TextAlign.center,
        style: ProxoUi.label);
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ProxoUi.radius),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(ProxoUi.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ProxoUi.radius),
          child: Padding(
              padding: const EdgeInsets.all(ProxoUi.gap12),
              child: row
                  ? Row(children: [
                      iconWell,
                      const SizedBox(width: ProxoUi.gap12),
                      Expanded(child: label)
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                          iconWell,
                          const SizedBox(height: ProxoUi.gap8),
                          label
                        ])),
        ),
      ),
    );
  }
}
