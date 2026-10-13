import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:clock/clock.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

class _ValidationNotice {
  final String field, message;
  DateTime entryStart;
  bool leaving = false, armed = false, queued = false;
  _ValidationNotice(this.field, this.message, this.entryStart);
}

/// Scoped to form validation. Backend/payment errors use the confirmation UI.
class AdValidationController extends ChangeNotifier {
  final List<_ValidationNotice> _items = [];
  final List<Timer> _timers = [];
  bool _disposed = false;
  void show(Map<String, String> errors) {
    var stagger = 0;
    final requestedAt = clock.now();
    for (final entry in errors.entries) {
      if (_items.any((n) => n.field == entry.key)) continue;
      final delay = Duration(milliseconds: stagger++ * 90);
      _timers.add(Timer(delay, () {
        if (_disposed || _items.any((n) => n.field == entry.key)) return;
        _items.add(_ValidationNotice(entry.key, entry.value, requestedAt.add(delay))
          ..queued = _items.length >= 3);
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
      // A hidden queued notice gets a fresh timeline when its slot opens.
      if (item.queued) {
        item.entryStart = clock.now();
        item.queued = false;
      }
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
    with TickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  late final Ticker _entry = createTicker((_) => _advanceEntry());

  @override
  void initState() {
    super.initState();
    _advanceEntry();
    if (_life.value < 1) _entry.start();
  }

  void _advanceEntry() {
    // Entry and expiry must not acquire different start times when a busy
    // frame mounts the widget after its scheduled notification insertion.
    final elapsed = clock.now().difference(widget.item.entryStart);
    _life.value = (elapsed.inMicroseconds / 240000).clamp(0.0, 1.0);
    if (_life.value == 1 && _entry.isActive) _entry.stop();
  }
  @override
  void didUpdateWidget(covariant _NoticeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.leaving && _life.status != AnimationStatus.reverse) {
      _entry.stop();
      _life.reverse();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
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
