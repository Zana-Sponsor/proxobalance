import 'package:flutter/material.dart';
import 'auth/auth_models.dart';
import 'auth/auth_shell.dart';

/// Backwards-compatible entry point used by the existing app router.
/// The actual three-screen flow is coordinated by [AuthShell].
class AuthScreen extends AuthShell {
  const AuthScreen({super.key});

  static bool get inOtpFlow => AuthFlowGuard.inOtpFlow;
  static set inOtpFlow(bool value) => AuthFlowGuard.inOtpFlow = value;
}
