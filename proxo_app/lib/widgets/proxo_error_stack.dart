import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart' show kAppFont;
import 'package:proxo_app/widgets/proxo_text.dart';

// ═════════════════════════════════════════════════════════════════════════════
// ProxoErrorStack — کارتی هەڵەی سپی، دەقی ڕەش، کۆبووە وەک ستاکێکی 3D
// ═════════════════════════════════════════════════════════════════════════════
//
//   ┌──────────────────────────────┐   ← نوێترین (پێشەوە)
//   │ نەتوانرا PDF دروست بکرێت      │
//   └┬────────────────────────────┬┘   ← پشتی: بچووکتر، کەمێک خوارتر، کاڵتر
//    └┬──────────────────────────┬┘
//     └──────────────────────────┘
//
// • هەر هەڵەیەکی نوێ دەکەوێتە سەر ستاکەکە؛ ئەوانی تر بە نەرمی دەچنە دواوە.
// • تەنها کارتی پێشەوە کاتی خۆی دەژمێرێت؛ کاتێک تەواو بوو بە نەرمی
//   دەڕوات و کارتی دواتر دێتە پێشەوە — دانە دانە.
// • داگرتن یان ڕاکێشان بۆ لا = لابردنی کارتی پێشەوە.
// • گۆشەی تیژ (0)، بێ سنوور، سێبەری نەرم، w500، بێ Bold.
// ═════════════════════════════════════════════════════════════════════════════

abstract final class _T {
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111827);
  static const Color action = Color(0xFF046CFA);

  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const EdgeInsets pad = EdgeInsets.symmetric(horizontal: 18, vertical: 16);
  static const double gutter = 16;
  static const double top = 12;
  static const double maxWidth = 398;

  // ── قووڵایی ستاک ──────────────────────────────────────────────────────
  static const int visible = 3; // چەند کارت لە پشتەوە دەبینرێن
  static const int maxQueued = 10;
  /// هەموو کارتەکان ڕێک هەمان قەبارەن — هیچ بچووکبوونەوەیەک نییە.
  static const double cardHeight = 74; // دوو دێڕی 14sp + پەدینگ
  static const double depthOffset = 8; // هەر کارتێکی پشتەوە 8px دەردەکەوێت
  static const double depthFade = 0.12; // کاڵبوونەوەیەکی سووک بۆ قووڵایی

  static const Duration restack = Duration(milliseconds: 380);
  static const Duration enter = Duration(milliseconds: 420);
  static const Duration exit = Duration(milliseconds: 460);

  /// ڕۆیشتن بۆ لا: چەند هێندەی پانی کارتەکە دەجوڵێت و چەند دەسوڕێتەوە.
  static const double exitTravel = 1.15;
  static const double exitTurn = 0.10; // radian
  static const Duration nextHold = Duration(milliseconds: 2600);

  static const TextStyle text = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: ink,
    decoration: TextDecoration.none,
  );
  static const TextStyle actionText = TextStyle(
    fontFamily: kAppFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: action,
    decoration: TextDecoration.none,
  );
}

class _StackItem {
  final int id;
  final String message;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final TextDirection direction;
  bool leaving = false;

  _StackItem({
    required this.id,
    required this.message,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
    required this.direction,
  });
}

class ProxoErrorStack {
  ProxoErrorStack._();

  static final ValueNotifier<List<_StackItem>> _items =
      ValueNotifier<List<_StackItem>>(<_StackItem>[]);
  static OverlayEntry? _entry;
  static int _seq = 0;
  static Timer? _timer;
  static int? _timedId;

  /// کارتێکی نوێ دەخاتە سەر ستاکەکە.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    TextDirection direction = TextDirection.rtl,
  }) {
    final String text = message.trim();
    if (text.isEmpty) return;

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final List<_StackItem> list = List<_StackItem>.of(_items.value);

    // هەمان پەیام کە ئێستا لە پێشەوەیە → دووبارە ناکرێتەوە، تەنها کاتەکەی
    // نوێ دەبێتەوە.
    final _StackItem? front = _front(list);
    if (front != null && front.message == text) {
      _restartTimer(front);
      return;
    }

    list.add(_StackItem(
      id: ++_seq,
      message: text,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      direction: direction,
    ));
    // تەنها نوێترینەکان دەمێننەوە.
    while (list.where((e) => !e.leaving).length > _T.maxQueued) {
      list.remove(list.firstWhere((e) => !e.leaving));
    }
    _items.value = list;

    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _ErrorStackView());
      overlay.insert(_entry!);
    }
    _restartTimer(_front(list)!);
  }

  /// هەموو کارتەکان لادەبات.
  static void clear() {
    _timer?.cancel();
    _timer = null;
    _timedId = null;
    for (final _StackItem e in _items.value) {
      e.leaving = true;
    }
    _items.value = List<_StackItem>.of(_items.value);
  }

  static _StackItem? _front(List<_StackItem> list) {
    for (int i = list.length - 1; i >= 0; i--) {
      if (!list[i].leaving) return list[i];
    }
    return null;
  }

  static void _restartTimer(_StackItem item, {Duration? hold}) {
    _timer?.cancel();
    _timedId = item.id;
    _timer = Timer(hold ?? item.duration, () => _dismiss(item.id));
  }

  static void _dismiss(int id) {
    final List<_StackItem> list = List<_StackItem>.of(_items.value);
    final int i = list.indexWhere((e) => e.id == id);
    if (i < 0 || list[i].leaving) return;
    list[i].leaving = true;
    _items.value = list;

    if (_timedId == id) {
      _timer?.cancel();
      _timer = null;
      _timedId = null;
    }
    // کارتی دواتر دێتە پێشەوە و کاتی خۆی دەست پێدەکات — دانە دانە.
    final _StackItem? next = _front(list);
    if (next != null) _restartTimer(next, hold: _T.nextHold);
  }

  /// دوای تەواوبوونی ئەنیمەیشنی ڕۆیشتن.
  static void _remove(int id) {
    final List<_StackItem> list = List<_StackItem>.of(_items.value)
      ..removeWhere((e) => e.id == id);
    _items.value = list;
    if (list.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _entry?.remove();
      _entry = null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// دیمەنی ستاک
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorStackView extends StatelessWidget {
  const _ErrorStackView();

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top + _T.top;

    return Positioned(
      top: top,
      left: _T.gutter,
      right: _T.gutter,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _T.maxWidth),
          child: ValueListenableBuilder<List<_StackItem>>(
            valueListenable: ProxoErrorStack._items,
            builder: (BuildContext _, List<_StackItem> items, Widget? __) {
              // قووڵایی: 0 = پێشەوە. کارتە ڕۆیشتووەکان قووڵایی خۆیان
              // دەپارێزن تا ئەنیمەیشنەکەیان تەواو دەبێت.
              final List<_StackItem> live =
                  items.where((e) => !e.leaving).toList();
              final List<Widget> children = <Widget>[];
              // دواوە سەرەتا دەکێشرێت، پێشەوە لە کۆتایی.
              for (final _StackItem item in items) {
                final int depth = item.leaving
                    ? 0
                    : (live.length - 1 - live.indexOf(item));
                if (depth > _T.visible) continue;
                children.add(_StackCard(
                  key: ValueKey<int>(item.id),
                  item: item,
                  depth: depth,
                ));
              }
              // کارتی ڕۆیشتوو لەسەرەوەی هەموو شتێک بێت.
              children.sort((Widget a, Widget b) {
                final _StackCard ca = a as _StackCard;
                final _StackCard cb = b as _StackCard;
                if (ca.item.leaving != cb.item.leaving) {
                  return ca.item.leaving ? 1 : -1;
                }
                return cb.depth.compareTo(ca.depth);
              });
              return Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: children,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// یەک کارت
// ─────────────────────────────────────────────────────────────────────────────

class _StackCard extends StatefulWidget {
  final _StackItem item;
  final int depth;

  const _StackCard({super.key, required this.item, required this.depth});

  @override
  State<_StackCard> createState() => _StackCardState();
}

class _StackCardState extends State<_StackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: _T.enter,
    reverseDuration: _T.exit,
  )..forward();

  bool _exiting = false;

  @override
  void didUpdateWidget(covariant _StackCard old) {
    super.didUpdateWidget(old);
    if (widget.item.leaving && !_exiting) {
      _exiting = true;
      _life.reverse().whenComplete(
            () => ProxoErrorStack._remove(widget.item.id),
          );
    }
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _tapDismiss() => ProxoErrorStack._dismiss(widget.item.id);

  @override
  Widget build(BuildContext context) {
    final _StackItem item = widget.item;
    final bool front = widget.depth == 0 && !item.leaving;

    final Widget card = Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
      decoration: const BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.zero, // گۆشەی تیژ
        boxShadow: _T.shadow,
      ),
      child: Container(
        height: _T.cardHeight,
        padding: _T.pad,
        alignment: Alignment.center,
        child: Directionality(
          textDirection: item.direction,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: ProxoText(
                  item.message,
                  style: _T.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (front && item.actionLabel != null && item.onAction != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 14),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _tapDismiss();
                      item.onAction!();
                    },
                    child: ProxoText(item.actionLabel!, style: _T.actionText),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );

    // ── قووڵایی — کارتەکان لەسەر یەکتری، هەمان قەبارە، بە نەرمی جێگۆڕکێ ──
    final Widget depthed = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.depth.toDouble()),
      duration: _T.restack,
      curve: Curves.easeOutCubic,
      child: card,
      builder: (BuildContext _, double d, Widget? child) {
        final double opacity =
            (1 - _T.depthFade * d).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, _T.depthOffset * d),
            child: child,
          ),
        );
      },
    );

    // ── هاتن: لە سەرەوە بە نەرمی دادەبەزێت.
    // ── ڕۆیشتن: بە نەرمی بۆ لا دەخلیسکێت و کەمێک دەسوڕێتەوە — نەک یەکسەر
    //    ون ببێت. کاڵبوونەوە تەنها لە کۆتایی ڕێگاکەدایە.
    final Widget animated = AnimatedBuilder(
      animation: _life,
      child: depthed,
      builder: (BuildContext _, Widget? child) {
        if (_exiting) {
          final double p = Curves.easeInOutCubic.transform(1 - _life.value);
          final double sign =
              Directionality.of(context) == TextDirection.rtl ? 1 : -1;
          final double fade = p < 0.55 ? 1 : 1 - (p - 0.55) / 0.45;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0).toDouble(),
            child: FractionalTranslation(
              translation: Offset(_T.exitTravel * p * sign, 0),
              child: Transform.rotate(
                angle: _T.exitTurn * p * sign,
                child: child,
              ),
            ),
          );
        }
        final double t = Curves.easeOutCubic.transform(_life.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -18),
            child: child,
          ),
        );
      },
    );

    if (!front) return IgnorePointer(child: animated);

    return Dismissible(
      key: ValueKey<String>('dismiss_${item.id}'),
      direction: DismissDirection.horizontal,
      movementDuration: const Duration(milliseconds: 340),
      resizeDuration: null,
      onDismissed: (_) {
        ProxoErrorStack._dismiss(item.id);
        ProxoErrorStack._remove(item.id);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapDismiss,
        child: animated,
      ),
    );
  }
}
