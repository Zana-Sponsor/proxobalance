import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AuthChannel { phone, email }

enum AuthOtpPurpose { login, signup, passwordReset }

/// Shared guard used by the app-level auth listener while verification is in
/// progress. It prevents a transient session event from skipping the intended
/// OTP step.
abstract final class AuthFlowGuard {
  static bool inOtpFlow = false;
}

abstract final class IraqPhone {
  /// Accept digits from Iraqi Arabic and Kurdish keyboards, including paste.
  static String latinDigits(String raw) => String.fromCharCodes(raw.runes.map((c) {
    if (c >= 0x660 && c <= 0x669) return c - 0x660 + 48;
    if (c >= 0x6f0 && c <= 0x6f9) return c - 0x6f0 + 48;
    return c;
  }));

  static String normalize(String? raw) {
    String digits = latinDigits(raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    while (digits.startsWith('964')) {
      digits = digits.substring(3);
    }
    return '+964$digits';
  }

  static bool isValid(String? raw) {
    final String local = normalize(raw).replaceFirst('+964', '');
    return local.length == 10 && local.startsWith('7');
  }

  static String editableDigits(String? raw) =>
      normalize(raw).replaceFirst('+964', '');

  static String mask(String? raw) {
    final String local = editableDigits(raw);
    if (local.length != 10) return '+964';
    return '+964 ${local.substring(0, 3)} *** ** ${local.substring(8)}';
  }
}

/// Normalize before filtering so localized digits are not silently discarded.
/// Keep the caret beside the edited digit rather than jumping to the end.
class IraqPhoneInputFormatter extends TextInputFormatter {
  const IraqPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = IraqPhone.editableDigits(newValue.text);
    if (text.length > 10) return oldValue;
    int offset(int value) {
      if (value < 0) return text.length;
      final prefix = newValue.text.substring(0, value.clamp(0, newValue.text.length));
      return IraqPhone.editableDigits(prefix).length.clamp(0, text.length);
    }
    return TextEditingValue(text: text, selection: TextSelection(
      baseOffset: offset(newValue.selection.baseOffset),
      extentOffset: offset(newValue.selection.extentOffset),
    ));
  }
}

String maskEmail(String raw) {
  final String email = raw.trim();
  final int at = email.indexOf('@');
  if (at <= 0) return email;
  final String name = email.substring(0, at);
  final String domain = email.substring(at + 1);
  final String visible = name.length <= 2 ? name.substring(0, 1) : name.substring(0, 2);
  return '$visible***@$domain';
}

@visibleForTesting
String otpDestination(AuthChannel channel, String value) =>
    channel == AuthChannel.phone ? IraqPhone.mask(value) : maskEmail(value);
