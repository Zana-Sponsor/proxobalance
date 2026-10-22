import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Offline Auth SVGs. Existing filled symbols retain their source/license;
/// the *_outline assets are original 24px drawings with a shared 1.7px stroke.
class AuthIcon extends StatelessWidget {
  const AuthIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color = const Color(0xFF046CFA),
    this.directional = false,
  });
  final String name;
  final double size;
  final Color color;
  final bool directional;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/icons/auth/$name.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        matchTextDirection: directional,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    ),
  );
}
