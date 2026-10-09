import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/proxo_card.dart';
import '../models/proxolink_design.dart';
import '../models/proxolink_page_type.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Raster captures of the private server renderer. No WebViews, capabilities,
/// provider handlers or network requests are created by this chooser.
class ProxoLinkDesignSelector extends StatelessWidget {
  final List<ProxoTemplate> templates;
  final ProxoPageType pageType;
  final String selectedKey;
  final ValueChanged<ProxoTemplate> onSelected;

  const ProxoLinkDesignSelector({
    super.key,
    required this.templates,
    required this.pageType,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 432),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 260 ? 2 : 1;
        final width = math.min(210.0,
            (constraints.maxWidth - (columns - 1) * 12) / columns);
        final textStyle = AdUi.text(context);
        var labelHeight = 0.0;
        for (final label in ProxoLinkDesign.labels.values) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: textStyle),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout(maxWidth: math.max(0, width - 16));
          labelHeight = math.max(labelHeight, painter.height);
          painter.dispose();
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final template in templates.where(
                (t) => t.version == 6 && ProxoLinkDesign.labels.containsKey(t.key)))
              SizedBox(
                width: width,
                child: _DesignCard(
                  template: template,
                  pageType: pageType,
                  selected: selectedKey == template.key,
                  labelHeight: labelHeight,
                  width: width,
                  onTap: () => onSelected(template),
                ),
              ),
          ],
        );
      }),
    ),
  );
}

class _DesignCard extends StatelessWidget {
  final ProxoTemplate template;
  final ProxoPageType pageType;
  final bool selected;
  final double labelHeight;
  final double width;
  final VoidCallback onTap;
  const _DesignCard({required this.template, required this.pageType,
    required this.selected, required this.labelHeight, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = ProxoLinkDesign.label(template.key);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: AdUi.controlRadius,
          boxShadow: AdUi.cardShadow,
        ),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AdUi.controlRadius,
            side: BorderSide(color: selected ? AdUi.blue : AdUi.controlLine,
                width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('proxolink-design-${template.key}'),
            onTap: onTap,
            excludeFromSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 393 / 1040,
                      child: Image.asset(
                        ProxoLinkDesign.thumbnail(template.key, pageType),
                        key: ValueKey('proxolink-thumbnail-${pageType.key}-${template.key}'),
                        fit: BoxFit.contain,
                        cacheWidth: math.min(1179, ((width - 16) * MediaQuery.devicePixelRatioOf(context)).ceil()),
                        excludeFromSemantics: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  if (selected)
                    PositionedDirectional(top: 6, end: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AdUi.blue, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  height: labelHeight,
                  child: Center(
                    child: ProxoText(label, textAlign: TextAlign.center,
                        style: AdUi.text(context,
                            color: selected ? AdUi.blue : AdUi.ink)),
                  ),
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
