import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import '../../theme/proxo_surface.dart';
import '../proxo_symbol.dart';
import '../proxo_text.dart';

/// One accessible selection geometry for checkout and balance providers.
class PaymentOption extends StatelessWidget {
  const PaymentOption({
    super.key,
    required this.label,
    this.subtitle,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.tapKey,
  });

  final String label;
  final String? subtitle;
  final Widget leading;
  final bool selected;
  final VoidCallback? onTap;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        child: Material(
          color: selected ? AppColors.accentSoft : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProxoSurface.controlRadius),
            side: BorderSide(
              color: selected ? AppColors.accent : ProxoSurface.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: tapKey,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  SizedBox(
                      width: 56, height: 32, child: Center(child: leading)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProxoText(label,
                            translate: true, style: ProxoSurface.body),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          ProxoText(subtitle!,
                              translate: true, style: ProxoSurface.secondary),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 24,
                    child: Center(
                      child: selected
                          ? const ProxoSymbol(ProxoSymbolName.check,
                              size: 22, color: AppColors.accent)
                          : Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: ProxoSurface.line, width: 1.5),
                              ),
                            ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Original provider artwork, never tinted or stretched.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo(
      {super.key, required this.provider, this.width = 56, this.height = 28})
      : assert(provider == 'fib' || provider == 'fastpay');
  final String provider;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: provider == 'fib'
            ? SvgPicture.asset('assets/logos/providers/fib.svg',
                fit: BoxFit.contain)
            : Image.asset('assets/logos/providers/fastpay.png',
                fit: BoxFit.contain,
                cacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context)).ceil()),
      );
}
