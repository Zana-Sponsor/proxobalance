import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdBrandLogo extends StatelessWidget {
  const AdBrandLogo(this.brand, {super.key, this.size = 22});
  final String brand;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size,
    child: SvgPicture.asset('assets/logos/ads/$brand.svg', fit: BoxFit.contain,
          matchTextDirection: false, excludeFromSemantics: true));
}
