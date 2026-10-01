// auth_otp_field.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_design.dart';

class AuthOtpBoxes extends StatefulWidget {
  const AuthOtpBoxes({
    super.key,
    required this.length,
    required this.codeController,
    required this.firstBoxFocus,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.shaker,
  });

  final int length;
  final TextEditingController codeController;
  final FocusNode firstBoxFocus;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final bool enabled;
  final OtpShakeController? shaker;

  @override
  State<AuthOtpBoxes> createState() => _AuthOtpBoxesState();
}

final class OtpShakeController {
  _AuthOtpBoxesState? _state;

  Future<void> shakeAndReset() async => _state?._shakeAndReset();

  void _attach(_AuthOtpBoxesState s) => _state = s;
  void _detach(_AuthOtpBoxesState s) {
    if (identical(_state, s)) _state = null;
  }

  void dispose() => _state = null;
}

class _AuthOtpBoxesState extends State<AuthOtpBoxes>
    with SingleTickerProviderStateMixin {
  late List<TextEditingController> _boxes;
  late List<FocusNode> _nodes;

  late final AnimationController _shake =
      AnimationController(vsync: this, duration: AuthTokens.shake);

  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _build(widget.length);
    widget.shaker?._attach(this);
    widget.codeController.addListener(_onExternalCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) widget.firstBoxFocus.requestFocus();
    });
  }

  void _build(int n) {
    _boxes = List<TextEditingController>.generate(
        n, (_) => TextEditingController(),
        growable: false);
    _nodes = List<FocusNode>.generate(
        n, (i) => i == 0 ? widget.firstBoxFocus : FocusNode(),
        growable: false);
    for (final FocusNode f in _nodes) {
      f.addListener(_repaint);
    }
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _disposeBoxes() {
    for (final TextEditingController c in _boxes) {
      c.dispose();
    }
    for (int i = 0; i < _nodes.length; i++) {
      _nodes[i].removeListener(_repaint);
      if (i != 0) _nodes[i].dispose();
    }
  }

  void _onExternalCode() {
    if (_syncing) return;
    final String code = widget.codeController.text;
    final String current = _boxes.map((c) => c.text).join();
    if (code == current) return;
    for (int i = 0; i < _boxes.length; i++) {
      _boxes[i].text = i < code.length ? code[i] : '';
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AuthOtpBoxes old) {
    super.didUpdateWidget(old);
    if (!identical(old.shaker, widget.shaker)) {
      old.shaker?._detach(this);
      widget.shaker?._attach(this);
    }
    if (!identical(old.codeController, widget.codeController)) {
      old.codeController.removeListener(_onExternalCode);
      widget.codeController.addListener(_onExternalCode);
    }
    if (old.length != widget.length) {
      _disposeBoxes();
      _build(widget.length);
    }
  }

  @override
  void dispose() {
    widget.shaker?._detach(this);
    widget.codeController.removeListener(_onExternalCode);
    _shake.dispose();
    _disposeBoxes();
    super.dispose();
  }

  void _emit() {
    final String code = _boxes.map((c) => c.text).join();
    _syncing = true;
    widget.codeController.text = code;
    _syncing = false;
    widget.onChanged?.call(code);
    if (code.length == widget.length) widget.onCompleted(code);
  }

  Future<void> _shakeAndReset() async {
    if (!mounted) return;
    await _shake.forward(from: 0).orCancel.catchError((Object _) {});
    if (!mounted) return;
    for (final TextEditingController c in _boxes) {
      c.clear();
    }
    _syncing = true;
    widget.codeController.clear();
    _syncing = false;
    if (mounted) setState(() {});
    widget.firstBoxFocus.requestFocus();
  }

  void _onChanged(int index, String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      int cursor = index;
      for (int i = 0; i < digits.length && cursor < widget.length; i++, cursor++) {
        _boxes[cursor].text = digits[i];
        _boxes[cursor].selection = const TextSelection.collapsed(offset: 1);
      }
      if (cursor >= widget.length) {
        _nodes[widget.length - 1].unfocus();
      } else {
        _nodes[cursor].requestFocus();
      }
      if (mounted) setState(() {});
      _emit();
      return;
    }

    _boxes[index].text = digits;
    _boxes[index].selection = TextSelection.collapsed(offset: digits.length);

    if (digits.isEmpty) {
      if (index > 0) _nodes[index - 1].requestFocus();
    } else if (index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    } else {
      _nodes[index].unfocus();
    }
    if (mounted) setState(() {});
    _emit();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_boxes[index].text.isNotEmpty) return KeyEventResult.ignored;
    if (index == 0) return KeyEventResult.handled;
    _boxes[index - 1].clear();
    _nodes[index - 1].requestFocus();
    if (mounted) setState(() {});
    _emit();
    return KeyEventResult.handled;
  }

  static double _offset(double t) =>
      (t == 0 || t == 1) ? 0 : math.sin(t * math.pi * 6) * 8 * (1 - t);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset(_shake.value), 0),
        child: child,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double gap = constraints.maxWidth < 330 ? 5 : AuthTokens.otpBoxGap;
            final double available =
                constraints.maxWidth - (gap * (widget.length - 1));
            final double boxWidth =
                (available / widget.length).clamp(38.0, AuthTokens.otpBoxWidth);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < widget.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  _box(context, i, boxWidth),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _box(BuildContext context, int i, double width) {
    final bool filled  = _boxes[i].text.isNotEmpty;
    final bool focused = _nodes[i].hasFocus;
    
    final Color border = widget.hasError
        ? AuthTokens.dangerField
        : focused
            ? AuthTokens.accent
            : filled
                ? AuthTokens.accent.withOpacity(0.5)
                : AuthTokens.line;

    return SizedBox(
      width: width,
      height: AuthTokens.otpBoxHeight,
      child: Focus(
        onKeyEvent: (node, event) => _onKey(i, event),
        child: AnimatedContainer(
          duration: AuthTokens.microTransition,
          curve: AuthTokens.microCurve,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AuthTokens.otpBoxRadius),
            border: Border.all(
              color: border,
              width: focused || widget.hasError ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _boxes[i],
            focusNode: _nodes[i],
            enabled: widget.enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            autofillHints: i == 0 ? const <String>[AutofillHints.oneTimeCode] : null,
            inputFormatters: const <TextInputFormatter>[],
            style: AuthTokens.otpDigit,
            cursorColor: AuthTokens.accent,
            showCursor: false,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) => _onChanged(i, v),
            onTap: () => _boxes[i].selection =
                TextSelection.collapsed(offset: _boxes[i].text.length),
          ),
        ),
      ),
    );
  }
}
