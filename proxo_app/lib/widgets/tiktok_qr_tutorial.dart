import 'package:flutter/material.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Original, locally bundled vector animation; no TikTok screenshots, network
/// artwork or authorization payload is used in this instructional illustration.
class TikTokQrTutorial extends StatefulWidget {
  const TikTokQrTutorial({super.key});
  @override
  State<TikTokQrTutorial> createState() => _TikTokQrTutorialState();
}

class _TikTokQrTutorialState extends State<TikTokQrTutorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .5;
    } else if (!_animation.isAnimating) {
      _animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
            width: 60,
            height: 84,
            child: AnimatedBuilder(
                animation: _animation,
                builder: (_, __) =>
                    CustomPaint(painter: _ScanPainter(_animation.value)))),
        const SizedBox(width: 12),
        Expanded(
            child: ProxoText(
                'تیک تۆک بکەرەوە، QR سکەن بکە، ڕەزامەندی بدە و بگەڕێوە بۆ پڕۆکسۆ.',
                style: AdUi.text(context, color: AdUi.secondary))),
      ]);
}

class _ScanPainter extends CustomPainter {
  final double progress;
  const _ScanPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = AdUi.selectedLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(8, 2, size.width - 16, size.height - 4),
            const Radius.circular(9)),
        outline);
    final ink = Paint()
      ..color = AdUi.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final box = Rect.fromLTWH(18, 26, size.width - 36, 28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)), outline);
    final y = box.top + box.height * progress;
    canvas.drawLine(Offset(box.left - 4, y), Offset(box.right + 4, y), ink);
    canvas.drawLine(const Offset(25, 72), Offset(size.width - 25, 72), outline);
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
