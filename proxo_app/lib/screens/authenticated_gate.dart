import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';

/// Returning users need a session, not signup provisioning. Database access
/// remains governed by the signed-in user's RLS policies.
class AuthenticatedGate extends StatelessWidget {
  const AuthenticatedGate({super.key, required this.child, this.client});
  final Widget child;
  final SupabaseClient? client;
  @override
  Widget build(BuildContext context) {
    final auth = (client ?? Supabase.instance.client).auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = auth.currentSession;
        if (session == null) return const AuthScreen();
        return KeyedSubtree(key: ValueKey(session.user.id), child: child);
      },
    );
  }
}
