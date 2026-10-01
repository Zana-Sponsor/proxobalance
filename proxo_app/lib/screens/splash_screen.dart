import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Proxo splash screen.
///
/// Logo-only, the way most major apps (Instagram, Uber, X, ...) do it:
/// no tagline, no progress bar — just the mark, centred, with a quiet
/// fade + scale entrance. Total time on screen ≈ 1.1s (was ≈ 6.4s).
///
/// Public API unchanged: SplashScreen(nextScreen: ...)
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Same background as the native launch_background.xml — no flash.
  static const Color _kBg = AppColors.page;

  // Transparent PNG. The previous asset was a .jpg, which has no alpha
  // channel — the mark shipped baked onto a solid #FFFFFF square, so the
  // splash showed a white box sitting on the #F7F8FA background. The PNG is
  // also tightly cropped: the .jpg was a 3264x3264 canvas whose wordmark
  // filled only 64% of the width and 18% of the height, so `logoWidth` was
  // sizing mostly empty padding and the mark rendered far smaller than the
  // clamp below implies.
  static const String _kLogoAsset = 'assets/images/proxo_logo.png';

  // ── Timing ────────────────────────────────────────────────────────────────
  static const int _kEntranceMs = 450;
  static const int _kHoldMs = 500; // logo sits on screen, fully visible
  static const int _kExitMs = 320;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kEntranceMs),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _run();
  }

  Future<void> _run() async {
    await _ctrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: _kHoldMs));
    _goNext();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: _kExitMs),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive logo width, verified 320 → 430 dp.
            final double logoWidth = (constraints.maxWidth * 0.42)
                .clamp(140.0, 220.0);

            return Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Image.asset(
                    _kLogoAsset,
                    width: logoWidth,
                    fit: BoxFit.contain,
                    // The asset is 1200 px wide and paints at ~140-220 dp, so
                    // it is always downscaled; high filtering keeps the
                    // wordmark's curves clean at every density.
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
