import 'dart:convert';
import 'dart:io' show Platform;

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trusted-device recovery, Android only.
///
/// ── Why ANDROID_ID and not device_info_plus ────────────────────────────────
/// `AndroidDeviceInfo.id` is `Build.ID` — the OS build number. It is identical
/// on every handset running the same firmware, so keying accounts on it would
/// map thousands of phones to one "device". `Settings.Secure.ANDROID_ID`, what
/// the `android_id` package returns, is the right value: since API 26 it is
/// scoped per (device, user, app signing key) and SURVIVES uninstall/reinstall,
/// which is the property this feature needs.
///
/// ── What it is NOT ─────────────────────────────────────────────────────────
/// Not an authenticator. It is readable by anything running as the app and
/// forgeable on a rooted device, so recognition only ever PRE-FILLS an email.
/// Password verification and the email OTP both still run. A spoofed device_id
/// buys an attacker one thing: the knowledge that some account's address was
/// last used on that handset.
///
/// ── Caveats worth knowing ──────────────────────────────────────────────────
///   • ANDROID_ID is scoped to the SIGNING KEY, so a debug build and a Play
///     Store build see different values. A device trusted in debug will not be
///     recognised in release. That is correct behaviour, not a bug.
///   • It resets on factory reset, which correctly drops the trust.
///   • It can be null on some OEM images; every method here degrades to "not
///     recognised" rather than throwing.
abstract final class TrustedDeviceService {
  static const AndroidId _androidId = AndroidId();

  static String? _cachedHash;

  /// SHA-256 of ANDROID_ID, or null when unavailable (non-Android, or an OEM
  /// that returns nothing). Hashing happens HERE so the raw hardware
  /// identifier never leaves the handset — Supabase logs and backups only ever
  /// contain the digest.
  static Future<String?> deviceHash() async {
    if (_cachedHash != null) return _cachedHash;
    if (!Platform.isAndroid) return null;
    try {
      final String? raw = await _androidId.getId();
      if (raw == null || raw.trim().isEmpty) return null;
      _cachedHash = sha256.convert(utf8.encode(raw.trim())).toString();
      return _cachedHash;
    } catch (e) {
      debugPrint('[PROXO][DEVICE] android_id unavailable: ' + e.toString());
      return null;
    }
  }

  /// The email last signed in on this handset, or null.
  ///
  /// Never throws: a failed lookup must degrade to the ordinary login form,
  /// never block it.
  static Future<String?> recognisedEmail(SupabaseClient db) async {
    final String? hash = await deviceHash();
    if (hash == null) return null;
    try {
      final res =
          await db.rpc('pa_trusted_device_lookup', params: {'p_device_id': hash});
      if (res is Map && res['found'] == true) {
        final String email = (res['email'] as String?) ?? '';
        if (email.isEmpty || email.endsWith('@phone.proxopages.com')) {
          return null;
        }
        return email;
      }
      return null;
    } catch (e) {
      debugPrint('[PROXO][DEVICE] lookup failed: ' + e.toString());
      return null;
    }
  }

  /// Links this handset to the signed-in account. Call AFTER the OTP step, so
  /// a device is only ever trusted once identity is fully proven.
  ///
  /// The RPC keys on auth.uid(), not on anything passed from here, so this
  /// cannot register a device against someone else's account.
  static Future<void> remember(SupabaseClient db) async {
    final String? hash = await deviceHash();
    if (hash == null) return;
    try {
      await db.rpc('pa_trusted_device_register', params: {'p_device_id': hash});
    } catch (e) {
      debugPrint('[PROXO][DEVICE] register failed: ' + e.toString());
    }
  }

  /// "Not you?" — revokes the mapping so the card stops appearing.
  static Future<void> forget(SupabaseClient db) async {
    final String? hash = await deviceHash();
    if (hash == null) return;
    try {
      await db.rpc('pa_trusted_device_forget', params: {'p_device_id': hash});
    } catch (e) {
      debugPrint('[PROXO][DEVICE] forget failed: ' + e.toString());
    }
  }
}
