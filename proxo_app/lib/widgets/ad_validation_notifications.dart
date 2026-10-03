import 'dart:async';
import 'package:flutter/material.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

class _ValidationNotice {
  final String field, message;
  bool leaving = false, armed = false;
  _ValidationNotice(this.field, this.message);
}

/// Scoped to form validation. Backend/payment errors use the confirmation UI.
class AdValidationController extends ChangeNotifier {
  final List<_ValidationNotice> _items = [];
  final List<Timer> _timers = [];
  bool _disposed = false;
  void show(Map<String, String> errors) {
    var stagger = 0;
    for (final entry in errors.entries) {
      if (_items.any((n) => n.field == entry.key)) continue;
      _timers.add(Timer(Duration(milliseconds: stagger++ * 90), () {
        if (_disposed || _items.any((n) => n.field == entry.key)) return;
        _items.add(_ValidationNotice(entry.key, entry.value));
        _armVisible();
        notifyListeners();
      }));
    }
  }

  void _armVisible() {
    // Only three readable cards cover the form. Queued cards receive their
    // own full five seconds when they become visible, not while hidden.
    for (final item in _items.take(3)) {
      if (item.armed) continue;
      item.armed = true;
      _timers.add(Timer(const Duration(seconds: 5), () {
        if (_disposed) return;
        item.leaving = true;
        notifyListeners();
        _timers.add(Timer(const Duration(milliseconds: 240), () {
          if (_disposed) return;
          _items.remove(item);
          _armVisible();
          notifyListeners();
        }));
      }));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

class AdValidationNotifications extends StatelessWidget {
  final AdValidationController controller;
  const AdValidationNotifications({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 240),
            alignment: Alignment.topCenter,
            curve: Curves.easeOutCubic,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < controller._items.length.clamp(0, 3); i++)
                _NoticeCard(
                    key: ObjectKey(controller._items[i]),
                    item: controller._items[i],
                    depth: i % 3),
            ]),
          ),
        ),
      );
}

class _NoticeCard extends StatefulWidget {
  final _ValidationNotice item;
  final int depth;
  const _NoticeCard({super.key, required this.item, required this.depth});
  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240))
    ..forward();
  @override
  void didUpdateWidget(covariant _NoticeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.leaving && _life.status != AnimationStatus.reverse) {
      _life.reverse();
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
        sizeFactor: _life,
        alignment: Alignment.topCenter,
        child: FadeTransition(
            opacity: _life,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  widget.depth * 3, 0, (2 - widget.depth) * 3, 7),
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, -0.15), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: _life, curve: Curves.easeOutCubic)),
                child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(-0.025),
                    alignment: Alignment.topCenter,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: BorderDirectional(
                              start: BorderSide(
                                  color: Color(0xFFB74956), width: 3)),
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x180F172A),
                                blurRadius: 14,
                                offset: Offset(0, 7)),
                            BoxShadow(
                                color: Color(0x0C0F172A),
                                blurRadius: 1,
                                spreadRadius: 1,
                                offset: Offset(2, 3)),
                          ]),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xFFB74956)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: ProxoText(widget.item.message,
                                    style: AdUi.text(context))),
                          ])),
                    )),
              ),
            )),
      );
}
