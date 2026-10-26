import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'owner_storage_queue.dart';

/// Only checkout identity and the original intent are stored. Provider QR data,
/// bearer tokens and merchant credentials never enter this recovery record.
class FastPayPendingCheckout {
  const FastPayPendingCheckout({required this.orderId, required this.amountIqd, this.note, this.dispatched = false});
  final String orderId;
  final int amountIqd;
  final String? note;
  final bool dispatched;

  Map<String, dynamic> toJson() => {
    'order_id': orderId, 'amount_iqd': amountIqd, 'note': note, 'dispatched': dispatched,
  };
  factory FastPayPendingCheckout.fromJson(Map<String, dynamic> value) {
    final order = value['order_id'], amount = value['amount_iqd'], note = value['note'];
    if (order is! String || !RegExp(r'^PX[A-Za-z0-9_-]{6,30}$').hasMatch(order) ||
        amount is! int || amount < 5000 ||
        (note != null && (note is! String || note.length > 500))) {
      throw StateError('fastpay_pending_record_invalid');
    }
    return FastPayPendingCheckout(orderId: order, amountIqd: amount, note: note as String?, dispatched: value['dispatched'] != false);
  }
}

class FastPayPendingCheckoutStore {
  const FastPayPendingCheckoutStore();
  static final _queue = OwnerStorageQueue();
  static String key(String owner) => 'proxo.fastpay.wallet.pending.v1.$owner';
  FastPayPendingCheckout? _decode(SharedPreferences prefs, String owner) {
    final raw = prefs.getString(key(owner));
    return raw == null ? null : FastPayPendingCheckout.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }
  Future<FastPayPendingCheckout?> read(String owner) => _queue.run(key(owner), () async =>
      _decode(await SharedPreferences.getInstance(), owner))
      .timeout(const Duration(seconds: 10));

  /// A late storage write stays ahead of subsequent claims even when its caller
  /// times out. Concurrent or restarted sheets recover the same original intent.
  Future<FastPayPendingCheckout> claim(String owner, FastPayPendingCheckout proposed) =>
      _queue.run(key(owner), () async {
        final prefs = await SharedPreferences.getInstance();
        final existing = _decode(prefs, owner);
        if (existing != null) return existing;
        FastPayPendingCheckout.fromJson(proposed.toJson());
        if (!await prefs.setString(key(owner), jsonEncode(proposed.toJson()))) {
          throw StateError('fastpay_pending_record_not_saved');
        }
        return proposed;
      }).timeout(const Duration(seconds: 10));

  /// Persist the outbound boundary before HTTP. A lost response (or a process
  /// exit at this boundary) permits reconciliation only, never blind QR replay.
  Future<bool> markDispatched(String owner, String orderId) => _queue.run(key(owner), () async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _decode(prefs, owner);
    if (existing == null || existing.orderId != orderId) throw StateError('fastpay_pending_identity_changed');
    if (existing.dispatched) return false;
    final dispatched = FastPayPendingCheckout(orderId: existing.orderId,
        amountIqd: existing.amountIqd, note: existing.note, dispatched: true);
    if (!await prefs.setString(key(owner), jsonEncode(dispatched.toJson()))) {
      throw StateError('fastpay_dispatch_not_saved');
    }
    return true;
  }).timeout(const Duration(seconds: 10));

  /// Clear only the exact resolved checkout; a late completion cannot remove a
  /// newer checkout or another owner's pending payment.
  Future<void> clear(String owner, String orderId) => _queue.run(key(owner), () async {
    final prefs = await SharedPreferences.getInstance();
    if (_decode(prefs, owner)?.orderId != orderId) return;
    if (!await prefs.remove(key(owner))) throw StateError('fastpay_pending_record_not_cleared');
  }).timeout(const Duration(seconds: 10));
}
