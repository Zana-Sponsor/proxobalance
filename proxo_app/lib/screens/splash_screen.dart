import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Native and Flutter launch surfaces share white and the Proxo brand mark.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextScreen});
  final Widget nextScreen;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  Future<void> _run() async {
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _entrance.value = 1;
      } else {
        await _entrance.forward().orCancel;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          ProxoPageRoute<void>(builder: (_) => widget.nextScreen));
    } on TickerCanceled {/* App closed during the entrance. */}
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: FadeTransition(
            opacity: _entrance,
            child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(
                    CurvedAnimation(
                        parent: _entrance, curve: Curves.easeOutCubic)),
                child: const SplashArtwork())),
      );
}

/// Shared production artwork, also used by the screenshot harness.
class SplashArtwork extends StatelessWidget {
  const SplashArtwork({super.key});
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: SafeArea(
            child: Center(child: LayoutBuilder(builder: (context, constraints) {
          final size = (constraints.maxWidth * .82).clamp(180.0, 336.0);
          return SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                              colors: [Color(0xFFE3EFFF), Color(0x00FFFFFF)]))),
                  Container(
                      width: size * .84,
                      height: size * .84,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFEAF2FF)))),
                  Container(
                      width: size * .64,
                      height: size * .64,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFDDEBFF)))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: size * .66,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 30),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFF1F6FF)),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x17046CFA),
                                  blurRadius: 34,
                                  offset: Offset(0, 12))
                            ]),
                        child: Image.asset('assets/images/proxo_logo.png',
                            semanticLabel: 'Proxo',
                            filterQuality: FilterQuality.high)),
                    const SizedBox(height: 28),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final opacity in [.24, .70, .24])
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: opacity),
                                    shape: BoxShape.circle))),
                    ]),
                  ]),
                ],
              ));
        }))),
      );
}
