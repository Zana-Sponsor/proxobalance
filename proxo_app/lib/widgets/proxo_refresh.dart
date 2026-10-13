import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProxoRefresh — programmatic pull-to-refresh for bottom-tab re-selection
//
// ── WHY THIS ISN'T CupertinoSliverRefreshControl ────────────────────────────
// The obvious pick has no programmatic trigger. It is driven entirely by the
// enclosing ScrollPosition overscrolling past zero: it reads the negative
// extent during layout and decides for itself when to arm and fire. There is
// no `.show()`, and the usual workaround — `controller.jumpTo(-100)` — is
// clamped straight back to 0 by the position's `applyBoundaryConditions`
// before a frame is ever drawn. It also requires a CustomScrollView, which
// only AdScreen has: HomeScreen is a SingleChildScrollView, ToolsScreen and
// ProxoProfilePage are ListViews.
//
// `pull_to_refresh_flutter3` does expose `RefreshController.requestRefresh()`,
// so it would work — but it means a new dependency plus converting all four
// tab bodies to `SmartRefresher`, and AdScreen's scroll body is load-bearing
// (see the long comment above `_buildBody`, and `_scrollCtrl` being shared
// between two CustomScrollViews).
//
// So this widget owns the offset itself instead of borrowing the scrollable's.
// It translates whatever child it is given downward on its own
// AnimationController + SpringSimulation and paints the spinner in the strip
// that opens up. Consequences worth knowing:
//
//   • it wraps ANY scrollable — no restructuring of the four tab bodies
//   • it is genuinely programmatic: `controller.refresh()`
//   • the existing `RefreshIndicator` on each screen keeps working untouched,
//     because this never touches the ScrollPosition. Pull-down stays Material,
//     tab re-tap gets this. They cannot both run: `_busy` gates re-entry, and
//     a pull gesture can't start while the viewport is translated away from
//     the finger.
//   • it does NOT overscroll the list itself, so a list already scrolled to
//     the middle would drop 60px with its middle showing. That's why
//     `scrollController` exists — pass one and it animates to the top first.
// ─────────────────────────────────────────────────────────────────────────────

/// Handle for firing a refresh from outside the screen that owns the list —
/// `MainShell` holds one per tab and calls [refresh] when the active tab is
/// tapped again.
///
/// Safe to call at any time: it is a no-op when nothing is attached (the tab
/// has never been opened, so there is nothing to refresh) and a no-op while a
/// refresh is already running, so leaning on the tab button cannot queue up a
/// stack of fetches.
class ProxoRefreshController {
  _ProxoRefreshState? _state;

  bool get isAttached => _state != null;
  bool get isRefreshing => _state?._busy ?? false;

  /// Completes when the drop, the fetch and the settle have all finished.
  Future<void> refresh() async {
    final _ProxoRefreshState? s = _state;
    if (s == null) return;
    await s._run();
  }

  void _attach(_ProxoRefreshState s) => _state = s;

  void _detach(_ProxoRefreshState s) {
    if (identical(_state, s)) _state = null;
  }

  void dispose() => _state = null;
}

// ── Motion tokens ───────────────────────────────────────────────────────────
class _RM {
  /// How far the viewport drops. 60dp is enough to seat a 22dp spinner with
  /// breathing room above and below without hiding a whole list row.
  static const double dropExtent = 60;

  /// Opening spring: ζ = 0.68, ωn = 16.1 rad/s → settles in ~360ms with a 5%
  /// overshoot (≈3px at 60dp). The overshoot is the point — it reads as the
  /// content *dropping* and catching, not sliding to a stop.
  static const SpringDescription openSpring =
      SpringDescription(mass: 1, stiffness: 260, damping: 22);

  /// Closing spring: ζ = 0.87, ωn = 17.3 rad/s → ~270ms, 0.4% overshoot.
  /// Deliberately tighter than the opening one. A bouncy close reads as the
  /// list rejecting the new data; a tight one reads as it being absorbed.
  static const SpringDescription closeSpring =
      SpringDescription(mass: 1, stiffness: 300, damping: 30);

  /// Springs are asymptotic, so stop the ticker once the residual is under a
  /// tenth of a pixel rather than letting it chase Flutter's default 1e-3.
  static const Tolerance tolerance =
      Tolerance(distance: 0.05, velocity: 0.5);

  /// Floor on how long the spinner stays visible. Without it a warm Supabase
  /// response (~80ms) makes the strip open and shut in one flinch, which reads
  /// as a glitch rather than a refresh.
  static const Duration minVisible = Duration(milliseconds: 450);

  /// One full turn of the spinner arc.
  static const Duration spinPeriod = Duration(milliseconds: 900);

  /// Scroll-to-top before dropping, when a ScrollController is supplied.
  static const Duration scrollToTop = Duration(milliseconds: 260);
}

/// Wraps a scrollable and drops it down to reveal a loading strip when
/// [ProxoRefreshController.refresh] is called.
///
/// Give it bounded constraints — it fills them, the same as the scroll view
/// it wraps.
class ProxoRefresh extends StatefulWidget {
  /// The work to run while the strip is open. Errors are caught and logged
  /// rather than rethrown: [ProxoRefreshController.refresh] is normally
  /// launched fire-and-forget from a tab tap, so an escaping error would be an
  /// unhandled async exception with no one to catch it. Each screen already
  /// surfaces its own failures (AdScreen's `_syncAdsSilently` takes
  /// `announceErrors`), and this must never leave the spinner stranded open.
  final Future<void> Function() onRefresh;

  /// Fired once, after the fetch has completed and while the strip is still
  /// open, immediately before the settle begins.
  ///
  /// This is the hook for screens that ALREADY own a list-entrance animation —
  /// both wired screens do, and reusing theirs is strictly better than layering
  /// [ProxoArrival] on top:
  ///
  ///   AdScreen   `_entranceCtrl` + `_AdcListEntrance` (40ms stagger, 240ms,
  ///              capped at 6 rows)
  ///   HomeScreen `_intro` + `_Reveal` (fade + 6% slide, per-section intervals)
  ///
  /// Pass `() => controller.forward(from: 0)` and the rows animate in under the
  /// closing strip. Screens with no such mechanism should leave this null and
  /// wrap their rows in [ProxoArrival] instead.
  final VoidCallback? onArrive;

  /// Optional — omit it and the widget is inert until something attaches.
  final ProxoRefreshController? controller;

  /// Supply the list's controller and the viewport animates to the top before
  /// dropping, so the revealed strip sits above the first row rather than
  /// above whatever happened to be in view.
  ///
  /// Skipped safely when the controller has no clients, or more than one — the
  /// two-position case AdScreen can hit while its skeleton overlay is
  /// cross-fading, where `animateTo` would assert.
  final ScrollController? scrollController;

  final Widget child;
  final double dropExtent;
  final bool pullToRefresh;

  const ProxoRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.onArrive,
    this.controller,
    this.scrollController,
    this.dropExtent = _RM.dropExtent,
    this.pullToRefresh = false,
  });

  @override
  State<ProxoRefresh> createState() => _ProxoRefreshState();
}

class _ProxoRefreshState extends State<ProxoRefresh>
    with TickerProviderStateMixin {
  /// Vertical offset in logical pixels. Unbounded because the opening spring
  /// overshoots past `dropExtent`, and clamping would flatten exactly the part
  /// of the motion that sells the drop.
  late final AnimationController _drop =
      AnimationController.unbounded(vsync: this);

  late final AnimationController _spin =
      AnimationController(vsync: this, duration: _RM.spinPeriod);

  bool _busy = false;
  double _pull = 0;
  bool _onScroll(ScrollNotification notice) {
    if (!widget.pullToRefresh || _busy || notice.depth != 0) return false;
    if (notice is ScrollStartNotification) _pull = 0;
    if (notice is OverscrollNotification && notice.metrics.pixels <= notice.metrics.minScrollExtent) {
      _pull += math.max(0, -notice.overscroll);
    }
    if (notice is ScrollUpdateNotification && notice.dragDetails != null && notice.metrics.pixels < notice.metrics.minScrollExtent) {
      _pull = math.max(_pull, notice.metrics.minScrollExtent - notice.metrics.pixels);
    }
    if (notice is ScrollEndNotification) {
      final armed = _pull >= widget.dropExtent; _pull = 0;
      if (armed) unawaited(_run());
    }
    return false;
  }

  /// Bumped once per completed refresh. [ProxoArrival] watches this to know
  /// when to replay its entrance — see the note on that class for why it is a
  /// counter rather than a bool.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ProxoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _drop.dispose();
    _spin.dispose();
    super.dispose();
  }

  Future<void> _settleTo(double target, SpringDescription spring) {
    // `.orCancel` so a dispose mid-flight surfaces as a TickerCanceled we can
    // swallow. A bare TickerFuture never completes when cancelled, which would
    // hang `_run` and leave `_busy` true forever.
    return _drop
        .animateWith(SpringSimulation(
          spring,
          _drop.value,
          target,
          0,
          tolerance: _RM.tolerance,
        ))
        .orCancel
        .catchError((Object _) {});
  }

  Future<void> _scrollToTop() async {
    final ScrollController? c = widget.scrollController;
    if (c == null || !c.hasClients || c.positions.length != 1) return;
    if (c.offset <= 0.5) return;
    try {
      await c.animateTo(
        0,
        duration: _RM.scrollToTop,
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // The position can be detached out from under us mid-flight (tab swap,
      // list rebuild). Not worth failing the refresh over.
    }
  }

  Future<void> _run() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      await _scrollToTop();
      if (!mounted) return;

      _spin.repeat();

      // Fetch and drop run CONCURRENTLY. Awaiting the drop first would add its
      // full 360ms to every refresh for no reason — the network doesn't care
      // that the strip is open yet.
      final Future<void> work = widget.onRefresh().catchError(
        (Object e, StackTrace s) {
          debugPrint('[PROXO][REFRESH] $e\n$s');
        },
      );

      await Future.wait<void>([
        work,
        Future<void>.delayed(_RM.minVisible),
        _settleTo(widget.dropExtent, _RM.openSpring),
      ]);
      if (!mounted) return;

      // Both fire BEFORE the close so the arrival plays as the strip shuts.
      // Doing it after leaves a beat where the new data is on screen sitting
      // perfectly still, which looks like a hard swap.
      setState(() => _generation++);
      widget.onArrive?.call();

      await _settleTo(0, _RM.closeSpring);
    } finally {
      _spin.stop();
      if (mounted) {
        _drop.value = 0;
      }
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProxoRefreshScope(
      generation: _generation,
      child: AnimatedBuilder(
        animation: _drop,
        builder: (context, child) {
          final double d = _drop.value;

          // Keep the content at the same element path while the strip opens
          // and settles. Conditional wrappers remount a loaded scrollable.

          final double strip = math.max(d, 0.0);
          final double reveal =
              (d / widget.dropExtent).clamp(0.0, 1.0).toDouble();

          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, d),
                    child: child,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: strip,
                  child: Center(
                    child: _ProxoSpinner(spin: _spin, reveal: reveal),
                  ),
                ),
              ],
            ),
          );
        },
        child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spinner
// ─────────────────────────────────────────────────────────────────────────────

/// A thin sweeping arc. Deliberately not a `CircularProgressIndicator`: that
/// one is 4dp of Material-blue at 36dp and dominates a 60dp strip.
///
/// [reveal] (0→1, how far the strip has opened) drives opacity, scale and the
/// arc's sweep, so the spinner appears to be drawn INTO existence as the space
/// for it opens rather than popping in at full size on frame one.
class _ProxoSpinner extends StatelessWidget {
  final Animation<double> spin;
  final double reveal;

  const _ProxoSpinner({required this.spin, required this.reveal});

  static const double _size = 22;
  static const double _stroke = 2;

  @override
  Widget build(BuildContext context) {
    // Ease the reveal so the spinner is essentially formed by the time the
    // strip is two-thirds open, rather than still assembling at the bottom of
    // the drop.
    final double r = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));

    return Opacity(
      opacity: r,
      child: Transform.scale(
        // 0.7 → 1.0. Never starts at 0: a spinner scaling from nothing reads
        // as a popup, not as a reveal.
        scale: 0.7 + 0.3 * r,
        child: SizedBox(
          width: _size,
          height: _size,
          child: AnimatedBuilder(
            animation: spin,
            builder: (context, _) => CustomPaint(
              painter: _ArcPainter(
                turns: spin.value,
                // 0.15 → 0.75 of the circle as it opens.
                sweep: 0.15 + 0.60 * r,
                color: AppColors.navIdle,
                stroke: _stroke,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double turns;
  final double sweep;
  final Color color;
  final double stroke;

  const _ArcPainter({
    required this.turns,
    required this.sweep,
    required this.color,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the arc's outer edge lands exactly on the
    // box rather than being clipped by it.
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (math.min(size.width, size.height) - stroke) / 2,
    );

    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      rect,
      turns * 2 * math.pi,
      sweep * 2 * math.pi,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.turns != turns ||
      old.sweep != sweep ||
      old.color != color ||
      old.stroke != stroke;
}

// ─────────────────────────────────────────────────────────────────────────────
// Content transition
// ─────────────────────────────────────────────────────────────────────────────

/// Publishes the enclosing [ProxoRefresh]'s refresh counter to descendants.
class ProxoRefreshScope extends InheritedWidget {
  final int generation;

  const ProxoRefreshScope({
    super.key,
    required this.generation,
    required super.child,
  });

  /// 0 when there is no [ProxoRefresh] above — [ProxoArrival] then simply
  /// never replays, which is the right no-op.
  static int generationOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ProxoRefreshScope>()
          ?.generation ??
      0;

  @override
  bool updateShouldNotify(ProxoRefreshScope oldWidget) =>
      oldWidget.generation != generation;
}

/// Fade + slide-in entrance for a list row, replayed ONLY when a refresh
/// completes.
///
/// ── Why not an AnimatedSwitcher ─────────────────────────────────────────────
/// An AnimatedSwitcher around the list is what AdScreen already tried and
/// removed — the reasoning is written out above its `_buildBody`. In short it
/// keeps both the outgoing and incoming subtree alive in a Stack that sizes to
/// its children, so total height jumps when the row count changes; and both
/// CustomScrollViews attach to the same `_scrollCtrl` during the crossfade,
/// giving one controller two ScrollPositions. Wrapping rows individually
/// animates the same pixels without ever duplicating the list.
///
/// ── Why a generation counter, not `isRefreshing` ───────────────────────────
/// The old `_AdCardReveal` replayed whenever the list rebuilt, so every filter
/// tap re-animated every card — the exact jump that got it deleted. Keying on
/// a counter that only advances when a refresh COMPLETES means filtering,
/// scrolling and silent background syncs rebuild rows with no animation at
/// all. Only an actual refresh moves anything.
///
/// A row built for the first time never animates — it just appears. That
/// covers rows scrolled into view later by the lazy sliver delegate, which
/// would otherwise each play an entrance on arrival at the viewport edge.
class ProxoArrival extends StatefulWidget {
  final Widget child;

  /// Position in the list, for the stagger. Capped internally, so passing a
  /// raw index from a 500-row list is fine.
  final int index;

  final Duration duration;

  /// Vertical travel. Small on purpose — this should read as the row settling,
  /// not flying in.
  final double offset;
  final bool animateOnRefresh;

  const ProxoArrival({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 250),
    this.offset = 12,
    this.animateOnRefresh = true,
  });

  @override
  State<ProxoArrival> createState() => _ProxoArrivalState();
}

class _ProxoArrivalState extends State<ProxoArrival>
    with SingleTickerProviderStateMixin {
  /// Per-row delay, capped at 6 rows so the last visible row starts a quarter
  /// second after the first rather than after two.
  static const int _maxStaggered = 6;
  static const Duration _stagger = Duration(milliseconds: 40);

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1.0, // built = already arrived; only a refresh animates
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  Timer? _delay;
  int? _seen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final int gen = ProxoRefreshScope.generationOf(context);
    if (_seen == null) {
      _seen = gen; // first attach — no animation
      return;
    }
    if (gen != _seen) {
      _seen = gen;
      if (widget.animateOnRefresh) _play();
    }
  }

  void _play() {
    _delay?.cancel();
    _ctrl.value = 0;
    final int steps = math.min(widget.index, _maxStaggered);
    if (steps == 0) {
      _ctrl.forward();
      return;
    }
    _delay = Timer(_stagger * steps, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final double v = _t.value;
        if (v >= 1.0) return child!; // resting rows cost nothing
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - v)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
