import 'package:flutter/material.dart';

import '../theme/app_locale.dart';

/// Shared receipt/app policy. Layout direction is deliberately independent.
abstract final class ProxoTextDirection {
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _rtlScript = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF\u{1EE00}-\u{1EEFF}]',
    unicode: true,
  );
  static final _digit = RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9]');
  static final _iqd = RegExp(
      r'^[+\-−]?[0-9\u0660-\u0669\u06F0-\u06F9,\.\u066B\u066C\s]+\s*د\.?\s*ع\.?$');
  static final _ltrRun = RegExp(
    r'[+\-−$#@]{0,2}[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9]'
    r'[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9\p{M}_.,:/@+%?=&~\u066A\u066B\u066C\-]*'
    r'(?:[ \t]+[+\-−$#@]{0,2}[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9]'
    r'[A-Za-z\u00C0-\u024F0-9\u0660-\u0669\u06F0-\u06F9\p{M}_.,:/@+%?=&~\u066A\u066B\u066C\-]*)*',
    unicode: true,
  );

  static bool hasRtlLetters(String text) => text.runes.any((rune) {
        final char = String.fromCharCode(rune);
        return _letter.hasMatch(char) && _rtlScript.hasMatch(char);
      });

  /// The first strong letter selects a paragraph's direction. Digits are not
  /// strong RTL characters, including Arabic/Persian digits. Numeric-only
  /// values, signed amounts and the receipt's IQD format stay LTR.
  static TextDirection of(
    String text, {
    TextDirection fallback = TextDirection.rtl,
  }) {
    if (_iqd.hasMatch(text.trim())) return TextDirection.ltr;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (!_letter.hasMatch(char)) continue;
      return _rtlScript.hasMatch(char) ? TextDirection.rtl : TextDirection.ltr;
    }
    return _digit.hasMatch(text) ? TextDirection.ltr : fallback;
  }

  /// Display-only Unicode isolates protect complete Latin/numeric runs from
  /// surrounding RTL punctuation. Never apply this to controller, stored,
  /// copied or submitted values. LRI/PDI have no advance width.
  static String display(String text, {bool mixed = false}) {
    if ((!mixed && !hasRtlLetters(text)) ||
        text.contains(RegExp(r'[\u2066-\u2069]'))) {
      return text;
    }
    return text.replaceAllMapped(_ltrRun, (match) => '\u2066${match[0]}\u2069');
  }

  /// Generated contact-card previews use HTML's equivalent isolation. The
  /// caller still escapes every text segment; links/attributes are untouched.
  static String html(String text, {required String Function(String) escape}) {
    if (!hasRtlLetters(text)) return escape(text);
    final buffer = StringBuffer();
    var offset = 0;
    for (final match in _ltrRun.allMatches(text)) {
      buffer.write(escape(text.substring(offset, match.start)));
      buffer.write('<bdi dir="ltr">${escape(match[0]!)}</bdi>');
      offset = match.end;
    }
    buffer.write(escape(text.substring(offset)));
    return buffer.toString();
  }

  static InlineSpan displaySpan(InlineSpan span, {required bool mixed}) {
    final plain = span.toPlainText(includeSemanticsLabels: false);
    if ((!mixed && !hasRtlLetters(plain)) ||
        plain.contains(RegExp(r'[\u2066-\u2069]'))) {
      return span;
    }
    // Run boundaries are calculated across the full rich string so adjacent
    // styles (e.g. USD + a differently colored amount) form one LTR island.
    final boundaries = <int, String>{};
    for (final match in _ltrRun.allMatches(plain)) {
      boundaries[match.start] = '${boundaries[match.start] ?? ''}\u2066';
      boundaries[match.end] = '${boundaries[match.end] ?? ''}\u2069';
    }
    var offset = 0;
    InlineSpan visit(InlineSpan current) {
      if (current is! TextSpan) {
        offset += current.toPlainText(includeSemanticsLabels: false).length;
        return current;
      }
      final raw = current.text;
      String? rendered;
      if (raw != null) {
        final buffer = StringBuffer();
        for (var i = 0; i <= raw.length; i++) {
          buffer.write(boundaries.remove(offset + i) ?? '');
          if (i < raw.length) buffer.write(raw[i]);
        }
        offset += raw.length;
        rendered = buffer.toString();
      }
      final children = current.children?.map(visit).toList(growable: false);
      return TextSpan(
        text: rendered,
        children: children,
        style: current.style,
        recognizer: current.recognizer,
        mouseCursor: current.mouseCursor,
        onEnter: current.onEnter,
        onExit: current.onExit,
        semanticsLabel:
            current.semanticsLabel ?? (raw != rendered ? raw : null),
        semanticsIdentifier: current.semanticsIdentifier,
        locale: current.locale,
        spellOut: current.spellOut,
      );
    }

    return visit(span);
  }

  static bool isLtrInput(TextInputType? type) =>
      type != null &&
      <int>{
        TextInputType.number.index,
        TextInputType.phone.index,
        TextInputType.datetime.index,
        TextInputType.emailAddress.index,
        TextInputType.url.index,
        TextInputType.visiblePassword.index,
      }.contains(type.index);
}

/// A drop-in Text that retains raw data and every existing typography/layout
/// option. Only paragraph direction and invisible display isolation change.
class ProxoText extends Text {
  const ProxoText(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    // ignore: deprecated_member_use
    super.textScaleFactor,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  const ProxoText.rich(
    super.textSpan, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    // ignore: deprecated_member_use
    super.textScaleFactor,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  }) : super.rich();

  String get _plain =>
      data ?? textSpan!.toPlainText(includeSemanticsLabels: false);

  @override
  TextDirection get textDirection => ProxoTextDirection.of(
        _plain,
        fallback: super.textDirection ??
            ProxoLocale.directionOf(ProxoLocale.current.value),
      );

  @override
  Widget build(BuildContext context) {
    final raw = _plain;
    final direction = ProxoTextDirection.of(
      raw,
      fallback: super.textDirection ?? Directionality.of(context),
    );
    // Current app labels are not selectable. If a caller adds SelectionArea,
    // retain the exact raw selection/clipboard text and native Unicode bidi.
    final selectable = SelectionContainer.maybeOf(context) != null;
    final span = data != null
        ? TextSpan(
            text: selectable ? data : ProxoTextDirection.display(data!),
            semanticsLabel: semanticsLabel ?? data,
          )
        : selectable
            ? textSpan!
            : ProxoTextDirection.displaySpan(
                textSpan!,
                mixed: ProxoTextDirection.hasRtlLetters(raw),
              );
    // Calling the framework's Text build retains its semantics, selection,
    // inherited styles, scaling, strut and overflow behavior unchanged.
    return Text.rich(
      span,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: direction,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      // ignore: deprecated_member_use
      textScaleFactor: textScaleFactor,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    ).build(context);
  }
}

/// Nullable decoration labels keep their original presence/absence and styles.
Widget? proxoFieldText(String? text) => text == null ? null : ProxoText(text);

/// Updates native editable direction when typing or changing a controller.
/// The same controller, selection, composing range and callbacks are retained.
/// Uncontrolled uses in this app are read-only initial-value form fields.
class ProxoDirectionalInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final TextInputType? keyboardType;
  final bool forceLtr;
  final Widget Function(BuildContext context, TextDirection direction) builder;

  const ProxoDirectionalInput({
    super.key,
    this.controller,
    this.initialValue,
    this.keyboardType,
    this.forceLtr = false,
    required this.builder,
  });

  Widget _build(BuildContext context, String text) => builder(
        context,
        forceLtr || ProxoTextDirection.isLtrInput(keyboardType)
            ? TextDirection.ltr
            : ProxoTextDirection.of(text, fallback: Directionality.of(context)),
      );

  @override
  Widget build(BuildContext context) => controller == null
      ? _build(context, initialValue ?? '')
      : ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller!,
          builder: (context, value, _) => _build(context, value.text),
        );
}
