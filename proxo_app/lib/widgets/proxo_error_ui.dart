import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'proxo_error_stack.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Proxo Error UI — SHARED VISUAL LANGUAGE ONLY
// ─────────────────────────────────────────────────────────────────────────────
//
// ⚠️  READ THIS BEFORE ADDING ANYTHING TO THIS FILE.
//
// This file is a *style kit*, not an error system. It owns nothing except how
// an error LOOKS: colors, icon style, typography, spacing, radii, shadows,
// buttons and motion.
//
// It deliberately contains NO:
//   • exception → message mapping
//   • retry / navigation / recovery behaviour
//   • knowledge of Supabase, HTTP, connectivity, or any screen
//   • copy (every string is passed in by the caller)
//
// Every screen and widget keeps its own `try/catch`, its own conditions and
// its own wording, right next to the code that can fail. They only borrow the
// paint. If you ever feel like adding `String friendlyMessage(Object e)` here,
// don't — that belongs in the screen that threw it, where the context lives.
//
// ── Which surface to use ─────────────────────────────────────────────────────
//   ProxoFieldError      inline, under a single form field
//   ProxoInlineError     inline banner inside a form, card or sheet
//   showProxoErrorSnack  temporary failure, self-dismissing
//   showProxoErrorSheet  contextual error that offers actions
//   showProxoErrorDialog blocking error the user must acknowledge
//   ProxoErrorView       whole screen / section failed to load
//   ProxoErrorCard       a section inside an existing scroll view failed
//
// ── Safe placement ───────────────────────────────────────────────────────────
// Snacks go through `ScaffoldMessenger` with `SnackBarBehavior.floating`, so
// Flutter itself lifts them above the bottom navigation, the FAB and the
// keyboard — they can never sit under the nav pill or cover an input. Sheets
// and dialogs pad themselves with `viewInsets` and sit inside `SafeArea`, so
// notches, status bars and gesture bars stay clear.
// ─────────────────────────────────────────────────────────────────────────────

/// The visual tone of a message. This describes *severity*, not cause — the
/// screen decides which tone its own situation deserves.
enum ProxoErrorTone { danger, warning, offline, info, success }

// ─────────────────────────────────────────────────────────────────────────────
// Tokens
// ─────────────────────────────────────────────────────────────────────────────

/// Every measurement the error UI is allowed to use. Nothing in this file (or
/// in any screen that renders an error) should hard-code a radius, a duration
/// or a gap — pull it from here so the whole app stays in step.
class ProxoErrorStyle {
  const ProxoErrorStyle._();

  // ── Radii — inherited from the app's existing surfaces ──
  static const double rField  = 12; // field-level chips
  static const double rWell   = 14; // icon wells
  static const double rInline = 16; // inline banners
  static const double rButton = 16; // all buttons
  static const double rCard   = 20; // notice cards / dialogs
  static const double rSnack  = 20; // floating snack
  static const double rSheet  = 28; // bottom sheets (matches the app's sheets)

  // ── Spacing — 4/8 dp grid ──
  static const double s2  = 2;
  static const double s4  = 4;
  static const double s6  = 6;
  static const double s8  = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  // ── Icon sizing — one family (rounded outline), one scale ──
  static const double iconField  = 13;
  static const double iconInline = 18;
  static const double iconSnack  = 20;
  static const double iconSheet  = 28;
  static const double iconState  = 34;

  // ── Icon wells ──
  static const double wellInline = 34;
  static const double wellSnack  = 38;
  static const double wellSheet  = 64;
  static const double wellState  = 84;

  // ── Buttons ──
  static const double buttonHeight    = 46;
  static const double buttonHeightSm  = 40;
  static const double buttonPadH      = 22;

  // ── Motion — subtle, mobile-native, never bouncy ──
  static const Duration enter   = Duration(milliseconds: 260);
  static const Duration exit    = Duration(milliseconds: 180);
  static const Curve    curveIn  = Curves.easeOutCubic;
  static const Curve    curveOut = Curves.easeInCubic;

  /// How far content rises as it fades in. Small on purpose — big travel reads
  /// as a page transition, not as a message.
  static const double riseOffset = 8;

  // ── Elevation — the app's card shadow (#0F172A @ 8%, blur 24, y 8) ──
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> sheetShadow = [
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 28, offset: Offset(0, -6)),
  ];

  /// A tinted lift used by the floating snack so it separates from busy
  /// content without turning into a heavy Material elevation.
  static List<BoxShadow> snackShadow(Color accent) => [
        BoxShadow(
          color: accent.withOpacity(0.14),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
        const BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ];

  /// Ink used for the primary action in an error surface. Matches the retry
  /// buttons the app already uses on its empty/offline states.
  static const Color actionInk = AppColors.dark;
}

/// The resolved look of one tone. Callers never build these by hand.
@immutable
class ProxoErrorPalette {
  final Color accent;  // icon + emphasis
  final Color ink;     // body text on [surface]
  final Color surface; // banner / snack fill
  final Color well;    // icon well fill
  final Color border;  // hairline
  final IconData icon;
  final String label;  // short severity label, in the app's language

  const ProxoErrorPalette({
    required this.accent,
    required this.ink,
    required this.surface,
    required this.well,
    required this.border,
    required this.icon,
    required this.label,
  });
}

/// Tone → look. The only place these values exist.
ProxoErrorPalette proxoErrorPalette(ProxoErrorTone tone) {
  switch (tone) {
    case ProxoErrorTone.danger:
      return const ProxoErrorPalette(
        accent:  Color(0xFFDC2626),
        ink:     Color(0xFF991B1B),
        surface: Color(0xFFFEF2F2),
        well:    Color(0xFFFEE2E2),
        border:  Color(0xFFFECACA),
        icon:    Icons.error_outline_rounded,
        label:   'هەڵە',
      );
    case ProxoErrorTone.warning:
      return const ProxoErrorPalette(
        accent:  Color(0xFFD97706),
        ink:     Color(0xFF92400E),
        surface: Color(0xFFFFFBEB),
        well:    Color(0xFFFEF3C7),
        border:  Color(0xFFFDE68A),
        icon:    Icons.warning_amber_rounded,
        label:   'ئاگاداری',
      );
    case ProxoErrorTone.offline:
      return const ProxoErrorPalette(
        accent:  AppColors.accent,
        ink:     Color(0xFF1E40AF),
        surface: Color(0xFFEFF6FF),
        well:    Color(0xFFDBEAFE),
        border:  Color(0xFFBFDBFE),
        icon:    Icons.wifi_off_rounded,
        label:   'ئینتەرنێت نییە',
      );
    case ProxoErrorTone.info:
      return const ProxoErrorPalette(
        accent:  AppColors.accent,
        ink:     Color(0xFF1E40AF),
        surface: Color(0xFFEFF6FF),
        well:    Color(0xFFDBEAFE),
        border:  Color(0xFFBFDBFE),
        icon:    Icons.info_outline_rounded,
        label:   'زانیاری',
      );
    case ProxoErrorTone.success:
      return const ProxoErrorPalette(
        accent:  Color(0xFF16A34A),
        ink:     Color(0xFF166534),
        surface: Color(0xFFF0FDF4),
        well:    Color(0xFFDCFCE7),
        border:  Color(0xFFBBF7D0),
        icon:    Icons.check_circle_outline_rounded,
        label:   'سەرکەوتوو',
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography — routes through the app-wide `AppTypography` tokens in
// app_theme.dart instead of its own literal sizes, so this file's alert/
// dialog/sheet text stays on the same scale as everywhere else. `f` stays
// in every signature for call-site compatibility (~19 call sites across
// this file, proxo_banner.dart and no_internet_widget.dart) and is applied
// last via `copyWith` — in practice every caller already passes `kAppFont`
// now that the old two-family Rabar/Inter split is gone, so this is a
// no-op today and only matters if that ever changes again.
// ─────────────────────────────────────────────────────────────────────────────

class ProxoErrorType {
  const ProxoErrorType._();

  /// Field-level validation text under a form field — can run to a second
  /// line for a long message, so it keeps the relaxed (1.35) height.
  static TextStyle field(Color c, String f) =>
      AppTypography.caption(color: c, weight: FontWeight.w400, height: 1.35)
          .copyWith(fontFamily: f);

  /// Short eyebrow/kicker label above an inline banner or snack message.
  /// SemiBold, not Bold — this appears on every banner, so it's the
  /// "important" case, not the "rare" one.
  static TextStyle label(Color c, String f) => AppTypography.caption(
        color: c,
        weight: FontWeight.w600,
        height: AppTypography.lineTight,
        letterSpacing: 0.3,
      ).copyWith(fontFamily: f);

  /// The error/message body — wraps to 2–3 lines routinely.
  static TextStyle body(Color c, String f) =>
      AppTypography.body(color: c).copyWith(fontFamily: f);

  /// Same scale as [body]; kept as a separate name because callers pass a
  /// quieter/muted `c` for the modal and sheet copy.
  static TextStyle bodyQuiet(Color c, String f) =>
      AppTypography.body(color: c).copyWith(fontFamily: f);

  /// Dialog headline — same size tier as an AppBar title. Bold stays here
  /// deliberately: a blocking dialog ("errors that genuinely stop the
  /// user", per the comment below) is exactly the rare, high-priority
  /// case the weight rule reserves Bold for.
  static TextStyle title(Color c, String f) => AppTypography.appBarTitle(
        color: c,
        weight: FontWeight.w700,
        height: 1.16,
      ).copyWith(fontFamily: f);

  /// Sheet headline — a notch larger than [title] for the bigger surface.
  /// 18 sits outside the base scale on purpose (no defined role between 16
  /// and 22); same rare-emphasis Bold reasoning as [title].
  static TextStyle titleLarge(Color c, String f) => TextStyle(
        fontFamily: f,
        fontSize: 18 * kKuFontBump,
        fontWeight: FontWeight.w700,
        color: c,
        height: 1.16,
        decoration: TextDecoration.none,
      );

  /// Inline/snack action link. SemiBold, not Bold — deliberately
  /// text-weight so it never competes with the screen's real primary
  /// button (see `ProxoInlineError.actionLabel` below).
  static TextStyle button(Color c, String f) =>
      AppTypography.button(color: c, weight: FontWeight.w600)
          .copyWith(fontFamily: f);
}

// ─────────────────────────────────────────────────────────────────────────────
// Motion — the single entrance used by every error surface.
// ─────────────────────────────────────────────────────────────────────────────

/// Fades and lifts [child] in once, on first build. Stateless and
/// controller-free, so it can wrap anything without owning a ticker and
/// without risking a rebuild loop.
class ProxoErrorAppear extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double rise;

  const ProxoErrorAppear({
    super.key,
    required this.child,
    this.duration = ProxoErrorStyle.enter,
    this.rise = ProxoErrorStyle.riseOffset,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: ProxoErrorStyle.curveIn,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * rise), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

enum ProxoErrorActionKind {
  /// Dark ink pill — the app's existing retry/primary treatment.
  primary,

  /// Tinted in the tone's own color — for the destructive/affirmative choice.
  tonal,

  /// Text-weight, for "cancel" / "not now".
  quiet,
}

/// A button that matches the rest of the app's pills: 16 radius, w700 label,
/// soft press feedback, and a 46 dp (or 40 dp compact) touch height.
class ProxoErrorButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final ProxoErrorActionKind kind;
  final ProxoErrorPalette palette;
  final IconData? icon;
  final bool expand;
  final bool compact;
  final String fontFamily;

  const ProxoErrorButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.palette,
    this.kind = ProxoErrorActionKind.primary,
    this.icon,
    this.expand = false,
    this.compact = false,
    this.fontFamily = kAppFont,
  });

  @override
  State<ProxoErrorButton> createState() => _ProxoErrorButtonState();
}

class _ProxoErrorButtonState extends State<ProxoErrorButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    late final Color bg;
    late final Color fg;
    late final Color? border;
    switch (widget.kind) {
      case ProxoErrorActionKind.primary:
        bg = ProxoErrorStyle.actionInk;
        fg = Colors.white;
        border = null;
        break;
      case ProxoErrorActionKind.tonal:
        bg = p.well;
        fg = p.ink;
        border = p.border;
        break;
      case ProxoErrorActionKind.quiet:
        bg = Colors.transparent;
        fg = AppColors.muted2;
        border = AppColors.border;
        break;
    }

    final height = widget.compact
        ? ProxoErrorStyle.buttonHeightSm
        : ProxoErrorStyle.buttonHeight;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: fg),
          const SizedBox(width: ProxoErrorStyle.s8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ProxoErrorType.button(fg, widget.fontFamily),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: ProxoErrorStyle.exit,
          curve: ProxoErrorStyle.curveIn,
          child: AnimatedContainer(
            duration: ProxoErrorStyle.exit,
            height: height,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
                horizontal: ProxoErrorStyle.buttonPadH),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.onTap == null ? bg.withOpacity(0.55) : bg,
              borderRadius: BorderRadius.circular(ProxoErrorStyle.rButton),
              border: border == null ? null : Border.all(color: border),
              boxShadow: widget.kind == ProxoErrorActionKind.primary && !_down
                  ? [
                      BoxShadow(
                        color: ProxoErrorStyle.actionInk.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1 · Field-level error — under a single input
// ─────────────────────────────────────────────────────────────────────────────

/// The hairline error that sits under a text field.
///
/// Pass `null` or an empty string to clear it. Appearing and clearing are both
/// animated with a size + fade transition, so the form never jumps: the row
/// grows into place instead of snapping in and shoving the next field down.
class ProxoFieldError extends StatelessWidget {
  final String? text;
  final ProxoErrorTone tone;
  final String fontFamily;
  final EdgeInsetsGeometry padding;

  const ProxoFieldError({
    super.key,
    required this.text,
    this.tone = ProxoErrorTone.danger,
    this.fontFamily = kAppFont,
    this.padding = const EdgeInsets.only(top: ProxoErrorStyle.s6),
  });

  @override
  Widget build(BuildContext context) {
    final p = proxoErrorPalette(tone);
    final show = text != null && text!.trim().isNotEmpty;

    return AnimatedSwitcher(
      duration: ProxoErrorStyle.enter,
      reverseDuration: ProxoErrorStyle.exit,
      switchInCurve: ProxoErrorStyle.curveIn,
      switchOutCurve: ProxoErrorStyle.curveOut,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: !show
          ? const SizedBox.shrink(key: ValueKey('proxo-field-error-none'))
          : Padding(
              key: ValueKey('proxo-field-error-${text!}'),
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(p.icon,
                        size: ProxoErrorStyle.iconField, color: p.accent),
                  ),
                  const SizedBox(width: ProxoErrorStyle.s6),
                  Flexible(
                    child: Text(
                      text!,
                      style: ProxoErrorType.field(p.accent, fontFamily),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2 · Inline banner — inside a form, card or sheet
// ─────────────────────────────────────────────────────────────────────────────

/// A tinted banner that lives in the layout (not on top of it), so it can sit
/// above a submit button or under a header without covering anything.
class ProxoInlineError extends StatelessWidget {
  final String message;
  final String? title;
  final ProxoErrorTone tone;
  final IconData? icon;
  final String fontFamily;
  final TextAlign textAlign;

  /// Optional trailing affordance, e.g. a retry link. Kept text-weight so the
  /// banner never competes with the screen's real primary button.
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProxoInlineError({
    super.key,
    required this.message,
    this.title,
    this.tone = ProxoErrorTone.danger,
    this.icon,
    this.fontFamily = kAppFont,
    this.textAlign = TextAlign.start,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = proxoErrorPalette(tone);

    return ProxoErrorAppear(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: ProxoErrorStyle.s12, vertical: ProxoErrorStyle.s12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(ProxoErrorStyle.rInline),
          border: Border.all(color: p.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ProxoErrorStyle.wellInline,
              height: ProxoErrorStyle.wellInline,
              decoration: BoxDecoration(
                color: p.well,
                borderRadius: BorderRadius.circular(ProxoErrorStyle.rWell - 4),
              ),
              child: Center(
                child: Icon(icon ?? p.icon,
                    size: ProxoErrorStyle.iconInline, color: p.accent),
              ),
            ),
            const SizedBox(width: ProxoErrorStyle.s10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!,
                        textAlign: textAlign,
                        style: ProxoErrorType.label(p.accent, fontFamily)),
                    const SizedBox(height: ProxoErrorStyle.s4),
                  ],
                  Text(message,
                      textAlign: textAlign,
                      style: ProxoErrorType.body(p.ink, fontFamily)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: ProxoErrorStyle.s8),
                    GestureDetector(
                      onTap: onAction,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          actionLabel!,
                          style: ProxoErrorType.button(p.accent, fontFamily)
                              .copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 · Snack — temporary, self-dismissing
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a floating message above whatever is on screen.
///
/// Uses `ScaffoldMessenger` + `SnackBarBehavior.floating` on purpose: Flutter
/// then lays it out above the bottom navigation bar, above the FAB and above
/// an open keyboard, on every screen size, without any manual insets. That is
/// the only placement in the framework that is guaranteed never to sit under
/// the nav pill or cover the field the user is typing into.
void showProxoErrorSnack(
  BuildContext context,
  String message, {
  ProxoErrorTone tone = ProxoErrorTone.danger,

  /// Short severity label above the message. Pass `''` to hide it, or your own
  /// string to override the tone's default.
  String? label,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  String fontFamily = kAppFont,
  TextDirection textDirection = TextDirection.rtl,
}) {
  // ⚠ هەموو پەیامەکان (هەڵە، سەرکەوتن، ئاگاداری) ئێستا وەک کارتی سپیی
  // دەق-ڕەش لە ستاکی 3D ـی `ProxoErrorStack` دەردەکەون — نەک SnackBar.
  // واژۆی ئەم فەنکشنە وەک خۆی ماوەتەوە، بۆیە هیچ شوێنێکی بانگکردن
  // پێویستی بە گۆڕان نییە.
  ProxoErrorStack.show(
    context,
    message,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    direction: textDirection,
  );
}

class _ProxoSnackBody extends StatelessWidget {
  final String message;
  final String label;
  final ProxoErrorPalette palette;
  final String fontFamily;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ProxoSnackBody({
    required this.message,
    required this.label,
    required this.palette,
    required this.fontFamily,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ProxoErrorStyle.s14, vertical: ProxoErrorStyle.s12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(ProxoErrorStyle.rSnack),
        border: Border.all(color: p.border),
        boxShadow: ProxoErrorStyle.snackShadow(p.accent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: ProxoErrorStyle.wellSnack,
            height: ProxoErrorStyle.wellSnack,
            decoration: BoxDecoration(
              color: p.well,
              borderRadius: BorderRadius.circular(ProxoErrorStyle.rWell - 3),
            ),
            child: Center(
              child: Icon(p.icon,
                  size: ProxoErrorStyle.iconSnack, color: p.accent),
            ),
          ),
          const SizedBox(width: ProxoErrorStyle.s12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty) ...[
                  Text(label, style: ProxoErrorType.label(p.accent, fontFamily)),
                  const SizedBox(height: ProxoErrorStyle.s2),
                ],
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ProxoErrorType.body(p.ink, fontFamily),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: ProxoErrorStyle.s8),
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ProxoErrorStyle.s12,
                    vertical: ProxoErrorStyle.s8),
                decoration: BoxDecoration(
                  color: p.well,
                  borderRadius: BorderRadius.circular(ProxoErrorStyle.rField),
                  border: Border.all(color: p.border),
                ),
                child: Text(actionLabel!,
                    style: ProxoErrorType.button(p.accent, fontFamily)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4 · Bottom sheet — contextual error with actions
// ─────────────────────────────────────────────────────────────────────────────

/// A contextual error sheet. Returns the value the caller passes to
/// `Navigator.pop`, or `null` if it was dismissed.
///
/// The sheet pads itself with `viewInsets`, so if a keyboard is open it rides
/// above it instead of hiding behind it, and it sits inside `SafeArea` so the
/// gesture bar and notch stay clear.
Future<T?> showProxoErrorSheet<T>(
  BuildContext context, {
  required String title,
  required String message,
  ProxoErrorTone tone = ProxoErrorTone.danger,
  IconData? icon,
  String? primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  ProxoErrorActionKind primaryKind = ProxoErrorActionKind.primary,
  bool isDismissible = true,
  String fontFamily = kAppFont,
  TextDirection textDirection = TextDirection.rtl,
}) {
  final p = proxoErrorPalette(tone);

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    barrierColor: Colors.black.withOpacity(0.40),
    builder: (sheetContext) => Directionality(
      textDirection: textDirection,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(ProxoErrorStyle.s12, 0,
                ProxoErrorStyle.s12, ProxoErrorStyle.s16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ProxoErrorStyle.rSheet),
              boxShadow: ProxoErrorStyle.sheetShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(
                      top: ProxoErrorStyle.s12, bottom: ProxoErrorStyle.s4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ProxoErrorStyle.s24,
                      ProxoErrorStyle.s16,
                      ProxoErrorStyle.s24,
                      ProxoErrorStyle.s24),
                  child: ProxoErrorAppear(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: ProxoErrorStyle.wellSheet,
                          height: ProxoErrorStyle.wellSheet,
                          decoration: BoxDecoration(
                            color: p.well,
                            borderRadius:
                                BorderRadius.circular(ProxoErrorStyle.s20),
                          ),
                          child: Center(
                            child: Icon(icon ?? p.icon,
                                size: ProxoErrorStyle.iconSheet,
                                color: p.accent),
                          ),
                        ),
                        const SizedBox(height: ProxoErrorStyle.s16),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: ProxoErrorType.titleLarge(
                                AppColors.dark, fontFamily)),
                        const SizedBox(height: ProxoErrorStyle.s8),
                        Text(message,
                            textAlign: TextAlign.center,
                            style: ProxoErrorType.bodyQuiet(
                                AppColors.muted2, fontFamily)),
                        if (primaryLabel != null || secondaryLabel != null)
                          const SizedBox(height: ProxoErrorStyle.s24),
                        if (primaryLabel != null)
                          ProxoErrorButton(
                            label: primaryLabel,
                            palette: p,
                            kind: primaryKind,
                            expand: true,
                            fontFamily: fontFamily,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              onPrimary?.call();
                            },
                          ),
                        if (secondaryLabel != null) ...[
                          const SizedBox(height: ProxoErrorStyle.s10),
                          ProxoErrorButton(
                            label: secondaryLabel,
                            palette: p,
                            kind: ProxoErrorActionKind.quiet,
                            expand: true,
                            fontFamily: fontFamily,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              onSecondary?.call();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 5 · Dialog — blocking, for errors the user must acknowledge
// ─────────────────────────────────────────────────────────────────────────────

/// Reserved for errors that genuinely stop the user: anything recoverable
/// should use a snack, an inline banner or a sheet instead.
Future<T?> showProxoErrorDialog<T>(
  BuildContext context, {
  required String title,
  required String message,
  ProxoErrorTone tone = ProxoErrorTone.danger,
  IconData? icon,
  String? primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  ProxoErrorActionKind primaryKind = ProxoErrorActionKind.primary,
  bool barrierDismissible = true,
  String fontFamily = kAppFont,
  TextDirection textDirection = TextDirection.rtl,
}) {
  final p = proxoErrorPalette(tone);

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (dialogContext) => Directionality(
      textDirection: textDirection,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
            horizontal: ProxoErrorStyle.s28, vertical: ProxoErrorStyle.s24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProxoErrorStyle.rCard)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(ProxoErrorStyle.s24,
              ProxoErrorStyle.s24, ProxoErrorStyle.s24, ProxoErrorStyle.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: p.well, shape: BoxShape.circle),
                child: Center(
                  child: Icon(icon ?? p.icon,
                      size: ProxoErrorStyle.iconSheet - 2, color: p.accent),
                ),
              ),
              const SizedBox(height: ProxoErrorStyle.s16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: ProxoErrorType.title(AppColors.dark, fontFamily)),
              const SizedBox(height: ProxoErrorStyle.s8),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      ProxoErrorType.bodyQuiet(AppColors.muted2, fontFamily)),
              if (primaryLabel != null || secondaryLabel != null)
                const SizedBox(height: ProxoErrorStyle.s20),
              if (primaryLabel != null)
                ProxoErrorButton(
                  label: primaryLabel,
                  palette: p,
                  kind: primaryKind,
                  expand: true,
                  fontFamily: fontFamily,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onPrimary?.call();
                  },
                ),
              if (secondaryLabel != null) ...[
                const SizedBox(height: ProxoErrorStyle.s10),
                ProxoErrorButton(
                  label: secondaryLabel,
                  palette: p,
                  kind: ProxoErrorActionKind.quiet,
                  expand: true,
                  fontFamily: fontFamily,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onSecondary?.call();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 6 · Full error state — a screen or tab that could not load
// ─────────────────────────────────────────────────────────────────────────────

/// Fills the available space with a centered notice and a retry affordance.
///
/// It scrolls (with `AlwaysScrollableScrollPhysics`) rather than centering
/// rigidly, for two reasons: a `RefreshIndicator` above it still receives the
/// pull gesture, and on a short screen — or with a large system font — the
/// content scrolls instead of overflowing.
class ProxoErrorView extends StatelessWidget {
  final String title;
  final String message;
  final ProxoErrorTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Leading glyph on the action button. Defaults to a refresh mark because
  /// most full-screen failures offer a retry — pass `null` when the action is
  /// something else (e.g. "close").
  final IconData? actionIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String fontFamily;
  final EdgeInsets padding;

  const ProxoErrorView({
    super.key,
    required this.title,
    required this.message,
    this.tone = ProxoErrorTone.danger,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    this.secondaryLabel,
    this.onSecondary,
    this.fontFamily = kAppFont,
    this.padding = const EdgeInsets.symmetric(
        horizontal: ProxoErrorStyle.s32, vertical: ProxoErrorStyle.s24),
  });

  @override
  Widget build(BuildContext context) {
    final p = proxoErrorPalette(tone);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against an unbounded height (e.g. nested in another scroll
        // view): fall back to 0 so the ConstrainedBox can never be handed
        // `minHeight: infinity`.
        final double minH = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity)
            : 0.0;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: ProxoErrorAppear(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: ProxoErrorStyle.wellState,
                      height: ProxoErrorStyle.wellState,
                      decoration:
                          BoxDecoration(color: p.well, shape: BoxShape.circle),
                      child: Center(
                        child: Icon(icon ?? p.icon,
                            size: ProxoErrorStyle.iconState, color: p.accent),
                      ),
                    ),
                    const SizedBox(height: ProxoErrorStyle.s20),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: ProxoErrorType.titleLarge(
                            AppColors.dark, fontFamily)),
                    const SizedBox(height: ProxoErrorStyle.s8),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: ProxoErrorType.bodyQuiet(
                            AppColors.muted, fontFamily)),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: ProxoErrorStyle.s24),
                      ProxoErrorButton(
                        label: actionLabel!,
                        palette: p,
                        icon: actionIcon,
                        fontFamily: fontFamily,
                        onTap: onAction,
                      ),
                    ],
                    if (secondaryLabel != null && onSecondary != null) ...[
                      const SizedBox(height: ProxoErrorStyle.s10),
                      ProxoErrorButton(
                        label: secondaryLabel!,
                        palette: p,
                        kind: ProxoErrorActionKind.quiet,
                        compact: true,
                        fontFamily: fontFamily,
                        onTap: onSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7 · Error card — one failed section inside a working screen
// ─────────────────────────────────────────────────────────────────────────────

/// A self-contained notice card, for when only part of a screen failed and the
/// rest of the page should keep working. Shrink-wraps, so it can be dropped
/// into a `Column`, a `ListView` or a `SliverToBoxAdapter` without affecting
/// the scroll extent of anything around it.
class ProxoErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final ProxoErrorTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String fontFamily;

  const ProxoErrorCard({
    super.key,
    required this.title,
    required this.message,
    this.tone = ProxoErrorTone.danger,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.fontFamily = kAppFont,
  });

  @override
  Widget build(BuildContext context) {
    final p = proxoErrorPalette(tone);

    return ProxoErrorAppear(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ProxoErrorStyle.s16),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(ProxoErrorStyle.rCard),
          border: Border.all(color: p.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.well, shape: BoxShape.circle),
              child: Center(
                child: Icon(icon ?? p.icon, size: 20, color: p.accent),
              ),
            ),
            const SizedBox(width: ProxoErrorStyle.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // This is a card title (14 / SemiBold), not a dialog
                  // headline, so it goes through `cardTitle` directly
                  // rather than downsizing `title`'s Bold dialog weight.
                  Text(title,
                      style: AppTypography.cardTitle(color: AppColors.dark)
                          .copyWith(fontFamily: fontFamily)),
                  const SizedBox(height: ProxoErrorStyle.s4),
                  Text(message,
                      style: ProxoErrorType.bodyQuiet(AppColors.muted2, fontFamily)
                          .copyWith(fontSize: 12.5)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: ProxoErrorStyle.s12),
                    ProxoErrorButton(
                      label: actionLabel!,
                      palette: p,
                      icon: Icons.refresh_rounded,
                      compact: true,
                      fontFamily: fontFamily,
                      onTap: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
