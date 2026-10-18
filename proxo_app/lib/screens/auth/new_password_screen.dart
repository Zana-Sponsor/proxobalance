import 'package:flutter/material.dart';

import '../../l10n/proxo_strings.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_icon.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'recovery_screen.dart';

/// Shared production form, also rendered by the offline visual fixture.
class NewPasswordScreen extends StatelessWidget {
  const NewPasswordScreen({
    super.key,
    required this.onBack,
    required this.password,
    required this.confirmation,
    required this.passwordVisible,
    required this.confirmationVisible,
    required this.onSave,
    this.onPasswordChanged,
    this.onConfirmationChanged,
    this.passwordError,
    this.confirmationError,
    this.loading = false,
  });
  final VoidCallback onBack;
  final Future<void> Function() onSave;
  final TextEditingController password, confirmation;
  final ValueNotifier<bool> passwordVisible, confirmationVisible;
  final ValueChanged<String>? onPasswordChanged, onConfirmationChanged;
  final String? passwordError, confirmationError;
  final bool loading;
  @override
  Widget build(BuildContext context) => RecoveryScreen(
    onBack: onBack,
    newPassword: true,
    content: ListenableBuilder(
      listenable: Listenable.merge([
        password,
        confirmation,
        passwordVisible,
        confirmationVisible,
      ]),
      builder: (context, _) {
        final mismatch =
            confirmation.text.isNotEmpty &&
            !password.text.startsWith(confirmation.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: password,
              forceLtr: true,
              label: AuthStrings.passwordLabel,
              hint: AuthStrings.passwordHint,
              icon: Icons.lock_outline_rounded,
              error: passwordError,
              obscure: !passwordVisible.value,
              ltr: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !loading,
              onChanged: onPasswordChanged,
              trailing: _visibility(passwordVisible),
            ),
            const SizedBox(height: 12),
            PasswordStrengthMeter(password: password.text),
            const SizedBox(height: 22),
            AuthTextField(
              controller: confirmation,
              forceLtr: true,
              label: AuthStrings.confirmPasswordLabel,
              hint: AuthStrings.passwordHint,
              icon: Icons.lock_reset_rounded,
              error:
                  confirmationError ??
                  (mismatch ? AuthStrings.errPasswordMismatch : null),
              obscure: !confirmationVisible.value,
              ltr: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !loading,
              onChanged: onConfirmationChanged,
              onSubmitted: (_) => onSave(),
              trailing: _visibility(confirmationVisible),
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              label: AuthStrings.savePasswordButton,
              loading: loading,
              onPressed: onSave,
            ),
          ],
        );
      },
    ),
  );
  Widget _visibility(ValueNotifier<bool> visible) => IconButton(
    onPressed: loading ? null : () => visible.value = !visible.value,
    tooltip: ProxoStrings.text(
      visible.value ? 'شاردنەوەی وشەی نهێنی' : 'پیشاندانی وشەی نهێنی',
    ),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: AuthIcon(
      visible.value ? 'visibility_off' : 'visibility',
      size: 22,
      color: AuthTokens.placeholder,
    ),
  );
}
