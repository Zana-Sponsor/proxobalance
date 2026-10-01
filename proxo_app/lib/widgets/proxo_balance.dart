import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../main.dart' show supabase, firebaseAvailable, kIqdRate;

// ─────────────────────────────────────────────────────────────────────────────
// ProxoBalanceNotifier
//
// Provides real-time IQD balance via:
//   1. Firebase RTDB  wallets/{uid}/balance  (primary)
//   2. Supabase Realtime pa_wallets.balance  (fallback × kIqdRate)
//
// Use ProxoBalanceProvider.of(context) to read the current value.
// ─────────────────────────────────────────────────────────────────────────────

class ProxoBalanceProvider extends StatefulWidget {
  final Widget child;
  const ProxoBalanceProvider({super.key, required this.child});

  static _BalanceState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_BalanceState>();

  /// Returns the formatted IQD balance string (e.g. "125,000 IQD")
  static String balanceText(BuildContext context) =>
      _of(context)?._balanceText ?? '—';

  /// Returns raw IQD amount
  static double balanceIqd(BuildContext context) =>
      _of(context)?._balanceIqd ?? 0;

  @override
  State<ProxoBalanceProvider> createState() => _BalanceState();
}

class _BalanceState extends State<ProxoBalanceProvider> {
  double _balanceIqd = 0;
  String _balanceText = '0 IQD';

  StreamSubscription? _fbSub;
  RealtimeChannel? _supaSub;

  @override
  void initState() {
    super.initState();
    _startListeners();
  }

  @override
  void dispose() {
    _fbSub?.cancel();
    _supaSub?.unsubscribe();
    super.dispose();
  }

  void _setBalance(double iqd) {
    if (!mounted) return;
    setState(() {
      _balanceIqd = iqd;
      final rounded = iqd.round();
      _balanceText = '${_fmt(rounded)} IQD';
    });
  }

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  void _startListeners() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // ── 1. Firebase Realtime DB ─────────────────────────────
    if (firebaseAvailable) {
      try {
        final ref = FirebaseDatabase.instance.ref('wallets/${user.id}/balance');
        _fbSub = ref.onValue.listen((event) {
          final val = event.snapshot.value;
          if (val != null) {
            _setBalance(double.tryParse(val.toString()) ?? 0);
          }
        });
      } catch (_) {
        _startSupabase(user.id); // fallback
      }
    } else {
      _startSupabase(user.id);
    }

    // ── 2. Supabase Realtime (always as backup) ─────────────
    _startSupabase(user.id);
  }

  void _startSupabase(String uid) {
    _supaSub?.unsubscribe();

    // Initial fetch
    _fetchSupaBalance(uid);

    // Realtime updates
    _supaSub = supabase
        .channel('wallet_rt_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pa_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final newBal =
                (payload.newRecord['balance'] as num?)?.toDouble() ?? 0;
            // Only update from Supabase if Firebase is not providing balance
            if (!firebaseAvailable) {
              _setBalance(newBal * kIqdRate);
            }
          },
        )
        .subscribe();
  }

  Future<void> _fetchSupaBalance(String uid) async {
    if (firebaseAvailable) return; // Firebase handles it
    try {
      final res = await supabase
          .from('pa_wallets')
          .select('balance')
          .eq('user_id', uid)
          .maybeSingle();
      final usd = (res?['balance'] as num?)?.toDouble() ?? 0;
      _setBalance(usd * kIqdRate);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// BalanceText — simple widget that rebuilds when balance changes
// ─────────────────────────────────────────────────────────────────────────────

class BalanceText extends StatefulWidget {
  final TextStyle? style;
  const BalanceText({super.key, this.style});

  @override
  State<BalanceText> createState() => _BalanceTextState();
}

class _BalanceTextState extends State<BalanceText> {
  double _iqd = 0;
  StreamSubscription? _fbSub;
  RealtimeChannel? _supaSub;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void dispose() {
    _fbSub?.cancel();
    _supaSub?.unsubscribe();
    super.dispose();
  }

  void _attach() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (firebaseAvailable) {
      try {
        final ref = FirebaseDatabase.instance.ref('wallets/${user.id}/balance');
        _fbSub = ref.onValue.listen((e) {
          final v = e.snapshot.value;
          if (v != null && mounted) setState(() => _iqd = double.tryParse(v.toString()) ?? 0);
        });
        return;
      } catch (_) {}
    }

    // Supabase fallback
    supabase
        .from('pa_wallets')
        .select('balance')
        .eq('user_id', user.id)
        .maybeSingle()
        .then((r) {
      final usd = (r?['balance'] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() => _iqd = usd * kIqdRate);
    });
  }

  String get _text {
    final r = _iqd.round();
    return '${r.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} IQD';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _text,
      style: widget.style ??
          AppTypography.body(
            color: AppColors.white,
            weight: FontWeight.w600,
            height: AppTypography.lineTight,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
