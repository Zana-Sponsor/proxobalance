import 'package:proxo_app/theme/app_locale.dart';
// auth_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart' show ProxoInk;
import 'auth_design.dart';
import '../proxo_symbol.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthTextField
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.error,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.ltr = false,
    this.forceLtr = false,
    this.prefix,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FocusNode? focusNode;
  final String? error;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool ltr;
  final bool forceLtr;

  /// ویدجێتێکی نەگۆڕ لە پێش خانەکەوە — بۆ نموونە پێشگری کۆدی وڵات
  /// `+964`. لەناو خودی خانەکەدایە (`prefix`ی `InputDecoration`)، نەک
  /// بۆکسێکی جیا لەتەنیشتی، بۆیە یەک سنوور و یەک ڕەنگی فۆکەسیان هەیە.
  final Widget? prefix;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final bool hasError = error != null;

    final Widget field = Container(
      decoration: BoxDecoration(
        color: AuthTokens.fieldFill,
        borderRadius: BorderRadius.circular(AuthTokens.fieldRadius),
      ),
      child: ProxoDirectionalInput(
        controller: controller,
        keyboardType: keyboardType,
        forceLtr: forceLtr,
        builder: (context, inputDirection) => TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          textDirection: inputDirection,
          textAlign: TextAlign.start,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: AuthTokens.fieldText,
          cursorColor: AuthTokens.accent,
          decoration: InputDecoration(
            hint: FittedBox(fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: ProxoText(hint, translate: true, maxLines: 1, softWrap: false,
                style: AuthTokens.fieldText.copyWith(color: AuthTokens.placeholder))),
            hintStyle: AuthTokens.fieldText.copyWith(color: AuthTokens.placeholder),
            filled: true,
            fillColor: enabled ? AuthTokens.fieldFill : AuthTokens.fieldFillOff,
            isDense: true,
            contentPadding: AuthTokens.fieldContentPadding,
            // A persistent country-code inset, not a disappearing inline prefix.
            // Ordinary fields use their label instead of decorative icons.
            prefixIcon: prefix == null ? null : Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
              child: Center(widthFactor: 1, child: prefix),
            ),
            prefixIconConstraints: const BoxConstraints(minHeight: 52),
            suffixIcon: trailing,
            border: _border(AuthTokens.line),
            enabledBorder: _border(
              hasError ? AuthTokens.dangerField : AuthTokens.line,
            ),
            focusedBorder: _border(
              hasError ? AuthTokens.dangerField : AuthTokens.accent,
              width: 1.3,
            ),
            disabledBorder: _border(AuthTokens.lineOff),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
              start: 2, bottom: AuthTokens.gapLabelToField),
          child: ProxoText(label, translate: true, style: AuthTokens.fieldLabel),
        ),
        if (ltr)
          Directionality(textDirection: TextDirection.ltr, child: field)
        else
          field,
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
            child: Semantics(liveRegion: true, child: ProxoText(
              error!, translate: true,
              style: AuthTokens.inlineError.copyWith(color: AuthTokens.danger),
            )),
          ),
      ],
    );
  }

  OutlineInputBorder _border(Color c, {double width = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuthTokens.fieldRadius),
        borderSide: BorderSide(color: c, width: width),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthPrimaryButton
// ─────────────────────────────────────────────────────────────────────────────

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final String label;
  final Future<void> Function()? onPressed;
  final bool loading;
  final bool enabled;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  static const Duration _cooldown = Duration(milliseconds: 350);
  bool _locked = false;

  Future<void> _tap() async {
    if (_locked || widget.loading || widget.onPressed == null) return;
    _locked = true;
    try {
      await widget.onPressed!.call();
    } finally {
      await Future<void>.delayed(_cooldown);
      if (mounted) _locked = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final bool live =
        widget.enabled && !widget.loading && widget.onPressed != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AuthTokens.buttonHeight),
      child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: live ? _tap : null,
        style: FilledButton.styleFrom(
          // ⚠ بوو شینی #0365FF. دوگمەی سەرەکی ئێستا مەرەکەبی تۆخە —
          // هەمان پیلی «ئامرازی نوێ +»ی tools_screen و CTAی دۆخە
          // بەتاڵەکان. شینەکە هێشتا فۆکەسی خانەکان و لینکەکان دەگرێت.
          backgroundColor: AuthTokens.primary,
          foregroundColor: AuthTokens.onPrimary,
          disabledBackgroundColor: AuthTokens.primary.withOpacity(0.35),
          disabledForegroundColor: Colors.white.withOpacity(0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          animationDuration: AuthTokens.microTransition,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthTokens.buttonRadius),
          ),
        ),
        child: AnimatedSwitcher(
          duration: AuthTokens.microTransition,
          child: widget.loading
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : ProxoText(widget.label, translate: true,
                  key: const ValueKey('label'), style: AuthTokens.buttonText),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthTextLink
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
  });

  final String label;
  final VoidCallback? onTap;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: ProxoText(
          label, translate: true,
          style: (style ?? AuthTokens.link).copyWith(color: AuthTokens.accent),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthBackButton
// ─────────────────────────────────────────────────────────────────────────────

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        tooltip: AuthStrings.back,
        icon: ProxoSymbol(
          Directionality.of(context) == TextDirection.rtl
              ? ProxoSymbolName.back
              : ProxoSymbolName.forward,
          color: AuthTokens.ink,
          size: 24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthAlert
// ─────────────────────────────────────────────────────────────────────────────

class AuthAlert extends StatelessWidget {
  const AuthAlert({super.key, this.message, this.success = false});

  final String? message;

  /// ⚠ ئەم بانەرە بە بنەڕەت **سوورە** (هەڵە / سنووردارکردنی نرخ). دۆخی
  /// سەرکەوتن — بۆ نموونە «کۆدەکە نێردرا» — پێویستی بە هەمان پێکهاتەیە
  /// بەڵام بە پیتەیەکی سەوز. بەبێ ئەمە، پەیامێکی سەرکەوتوو لەناو
  /// بانەرێکی سووردا دەردەکەوت.
  final bool success;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    if (message == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      // ⚠ بوو ڕووی سپی + سنووری #FCA5A5 + سێبەرێکی سووری کاڵ. ئێستا
      // بانەرێکی سووری نەرمە: ڕووی #FEF2F2، سنوور و دەقی #DC2626، بێ
      // سێبەر. سێبەرێکی ڕەنگاوڕەنگ لەسەر ڕووێکی ڕەنگین دووجار هەمان
      // شت دەڵێت، و لەسەر پەڕەی #FAFAFA بە زەحمەت دەبینرا.
      decoration: BoxDecoration(
        color: success ? AuthTokens.successBg : AuthTokens.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: success ? AuthTokens.success : AuthTokens.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProxoSymbol(
            success ? ProxoSymbolName.check : ProxoSymbolName.info,
            size: 22,
            color: success ? AuthTokens.success : AuthTokens.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ProxoText(
              message!, translate: true,
              style: AuthTokens.subtitle.copyWith(
                fontSize: AuthTokens.textSize,
                color: success ? AuthTokens.success : AuthTokens.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PasswordStrengthMeter
// ─────────────────────────────────────────────────────────────────────────────

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final PasswordStrength strength = PasswordPolicy.evaluate(password);
    final List<bool> satisfied = PasswordPolicy.satisfaction(password);
    final Color tone = strength == PasswordStrength.none
        ? AuthTokens.line
        : strength.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 4,
          children: [
            ProxoText(
              AuthStrings.strengthHeader,
              style: AuthTokens.ruleText.copyWith(color: AuthTokens.inkMuted),
            ),
            AnimatedSwitcher(
              duration: AuthTokens.microTransition,
              child: ProxoText(
                strength.label,
                key: ValueKey<PasswordStrength>(strength),
                style: AuthTokens.ruleText.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AuthTokens.meterSegmentGap),
              Expanded(
                child: AnimatedContainer(
                  duration: AuthTokens.microTransition,
                  curve: AuthTokens.microCurve,
                  height: AuthTokens.meterSegmentHeight,
                  decoration: BoxDecoration(
                    color: i < strength.filledSegments
                        ? tone
                        : AuthTokens.line,
                    borderRadius: BorderRadius.circular(AuthTokens.meterSegmentRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < PasswordPolicy.rules.length; i++)
          _RuleRow(label: PasswordPolicy.rules[i].label, satisfied: satisfied[i]),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final Color tone =
        satisfied ? AuthTokens.success : AuthTokens.placeholder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: Center(
              child: satisfied ? ProxoSymbol(ProxoSymbolName.check, size: 16, color: tone)
                : Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tone))),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ProxoText(
              label, translate: true,
              style: AuthTokens.ruleText.copyWith(
                color: tone,
                fontWeight: satisfied ? FontWeight.w500 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthClearButton
// ─────────────────────────────────────────────────────────────────────────────

class AuthClearButton extends StatefulWidget {
  const AuthClearButton({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onCleared,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onCleared;

  @override
  State<AuthClearButton> createState() => _AuthClearButtonState();
}

class _AuthClearButtonState extends State<AuthClearButton> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    widget.focusNode.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant AuthClearButton old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
    if (!identical(old.focusNode, widget.focusNode)) {
      old.focusNode.removeListener(_sync);
      widget.focusNode.addListener(_sync);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    widget.focusNode.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onCleared?.call();
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final bool visible =
        widget.controller.text.isNotEmpty && widget.focusNode.hasFocus;

    return SizedBox(
      width: AuthTokens.trailingSlot,
      height: AuthTokens.trailingSlot,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AuthTokens.microTransition,
        curve: AuthTokens.microCurve,
        child: IgnorePointer(
          ignoring: !visible,
          child: IconButton(
            onPressed: _clear,
            splashRadius: 16,
            padding: EdgeInsets.zero,
            icon: ProxoSymbol(
              ProxoSymbolName.close,
              size: AuthTokens.clearIconSize,
              color: AuthTokens.placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmailDomainChips
// ─────────────────────────────────────────────────────────────────────────────

class EmailDomainChips extends StatefulWidget {
  const EmailDomainChips({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  State<EmailDomainChips> createState() => _EmailDomainChipsState();
}

class _EmailDomainChipsState extends State<EmailDomainChips> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    widget.focusNode.addListener(_sync);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    widget.focusNode.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  List<String> get _matches {
    if (!widget.focusNode.hasFocus) return const <String>[];
    final String text = widget.controller.text;
    final int at = text.lastIndexOf('@');
    if (at < 1) return const <String>[];
    final String tail = text.substring(at);
    if (kEmailDomainSuggestions.contains(tail)) return const <String>[];
    return kEmailDomainSuggestions
        .where((d) => d.startsWith(tail))
        .toList(growable: false);
  }

  void _apply(String domain) {
    final String text = widget.controller.text;
    final int at = text.lastIndexOf('@');
    final String user = at < 0 ? text : text.substring(0, at);
    final String next = '$user$domain';
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final List<String> matches = _matches;

    return AnimatedSize(
      duration: AuthTokens.microTransition,
      curve: AuthTokens.microCurve,
      alignment: Alignment.topCenter,
      child: matches.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.only(top: AuthTokens.gapFieldToChips, bottom: 2),
              child: SizedBox(
                height: AuthTokens.chipHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: matches.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AuthTokens.chipGap),
                  itemBuilder: (context, i) => _Chip(
                    label: matches[i],
                    onTap: () => _apply(matches[i]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AuthTokens.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuthTokens.chipRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AuthTokens.chipRadius),
            border: Border.all(color: AuthTokens.line),
          ),
          child: ProxoText(
            label, translate: true,
            textDirection: TextDirection.ltr,
            style: AuthTokens.chipText.copyWith(color: AuthTokens.accent),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthLockoutNotice
// ─────────────────────────────────────────────────────────────────────────────

class AuthLockoutNotice extends StatelessWidget {
  const AuthLockoutNotice({super.key, required this.onContactSupport});

  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // ⚠ بوو ڕووی سپی + سنووری #FCA5A5 + سێبەرێکی سووری کاڵ. ئێستا
      // بانەرێکی سووری نەرمە: ڕووی #FEF2F2، سنوور و دەقی #DC2626، بێ
      // سێبەر. سێبەرێکی ڕەنگاوڕەنگ لەسەر ڕووێکی ڕەنگین دووجار هەمان
      // شت دەڵێت، و لەسەر پەڕەی #FAFAFA بە زەحمەت دەبینرا.
      decoration: BoxDecoration(
        color: AuthTokens.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthTokens.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProxoSymbol(ProxoSymbolName.lock, size: 22, color: AuthTokens.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProxoText(
                  AuthStrings.lockoutBody,
                  style: AuthTokens.subtitle.copyWith(
                    fontSize: AuthTokens.textSize,
                    color: AuthTokens.danger,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onContactSupport,
                  child: ProxoText(
                    AuthStrings.lockoutAction,
                    style: AuthTokens.link.copyWith(
                      color: AuthTokens.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthFastAccountCard
// ─────────────────────────────────────────────────────────────────────────────

class AuthFastAccountCard extends StatelessWidget {
  const AuthFastAccountCard({
    super.key,
    required this.email,
    required this.onContinue,
    required this.onForget,
    this.selected = false,
  });

  final String email;
  final VoidCallback onContinue;
  final VoidCallback onForget;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AuthTokens.fieldRadius),
        border: Border.all(
          color: selected ? AuthTokens.accent : AuthTokens.line,
          width: selected ? 1.3 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AuthTokens.fieldRadius),
        child: InkWell(
          onTap: selected ? null : onContinue,
          borderRadius: BorderRadius.circular(AuthTokens.fieldRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AuthTokens.accent.withOpacity(0.08),
                  child: ProxoSymbol(ProxoSymbolName.user,
                      size: 18, color: AuthTokens.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProxoText(
                        AuthStrings.continueAsPrefix.trim(),
                        style: AuthTokens.ruleText
                            .copyWith(color: AuthTokens.inkMuted),
                      ),
                      ProxoText(
                        email,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuthTokens.fieldLabel.copyWith(fontSize: AuthTokens.textSize),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (selected)
                  AuthTextLink(
                    label: AuthStrings.notYou,
                    onTap: onForget,
                    style: AuthTokens.chipText,
                  )
                else
                  ProxoSymbol(ProxoSymbolName.forward,
                      size: 20, color: AuthTokens.placeholder),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AuthSegmentedControl — سویچی سلایدی «ژمارەی مۆبایل / ئیمەیڵ»
// ═════════════════════════════════════════════════════════════════════════════
// ⚠ تەنها لە شاشەی **چوونەژوورەوە**دا بەکاردێت.
//
// نەخشەکە `Stack`ـە نەک `Row`ی دوو دوگمە: پیلی هەڵبژێردراو دەبێت لە نێوان
// دوو شوێندا **بسلایتێت**، و ئەوە تەنها کاتێک دەکرێت کە پیلەکە چینێکی
// سەربەخۆ بێت لە سەرەوەی لەیبڵەکانەوە. بە `Row`ێکی دوو کۆنتەینەری
// ڕەنگاوڕەنگ، گۆڕینەکە دەبووە فەیدێکی ڕەنگ لە جیاتی جوڵە.
//
// `AnimatedAlign` (نەک `AnimatedPositioned`) بەکارهێنراوە چونکە
// `AlignmentDirectional` بە ئۆتۆماتیکی ئاراستەی RTL ڕەچاو دەکات: لە
// کوردیدا «یەکەم» واتە لای ڕاست، و هیچ حیسابێکی دەستی بۆ پێچەوانەکردنەوە
// پێویست نییە.
class AuthSegmentedControl extends StatelessWidget {
  const AuthSegmentedControl({super.key, required this.labels, required this.index,
    required this.onChanged, this.enabled = true});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      final labelWidth = (width - 20).clamp(1.0, double.infinity);
      final scaler = MediaQuery.textScalerOf(context);
      // Material's inherited letter spacing must not differ from the painter.
      var labelStyle = AuthTokens.fieldLabel.copyWith(letterSpacing: 0);
      // Keep whole words on each line, including Arabic email at 280dp/2x.
      // Both segments use the same size and retain system text scaling.
      for (var pass = 0; pass < 4; pass++) {
        var widest = 0.0;
        for (final word in labels.join(' ').split(RegExp(r'\s+'))) {
          final p = TextPainter(text: TextSpan(text: word, style: labelStyle),
            textDirection: TextDirection.rtl, textScaler: scaler)..layout();
          if (p.width > widest) widest = p.width;
          p.dispose();
        }
        if (widest <= labelWidth - 0.5 || widest == 0) break;
        labelStyle = labelStyle.copyWith(fontSize: labelStyle.fontSize! * (labelWidth - 0.5) / widest);
      }
      double height = 48;
      for (final label in labels) {
        final p = TextPainter(text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.rtl, textScaler: scaler)
          ..layout(maxWidth: labelWidth);
        if (p.height + 24 > height) height = p.height + 24;
        p.dispose();
      }
      return Container(padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(16)),
        child: Row(children: List.generate(labels.length, (i) => Expanded(
          child: Semantics(selected: i == index, button: true,
            child: Material(color: i == index ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(borderRadius: BorderRadius.circular(12),
                onTap: enabled ? () => onChanged(i) : null,
                child: SizedBox(height: height, child: Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ProxoText(labels[i], textAlign: TextAlign.center,
                    style: labelStyle.copyWith(
                      color: i == index ? AuthTokens.accent : AuthTokens.inkMuted)),
                ))),
              ),
            ),
          ),
        ))),
      );
    });
  }
}
