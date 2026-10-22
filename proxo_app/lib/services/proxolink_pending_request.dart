import 'package:shared_preferences/shared_preferences.dart';
import 'owner_storage_queue.dart';

/// Stores only an owner-scoped random request ID, never page/customer content.
/// Keeping the same ID after interruption lets the API resolve a late save.
class ProxoLinkPendingRequestStore {
  const ProxoLinkPendingRequestStore();
  static final _storage = OwnerStorageQueue();

  String _key(String? owner) =>
      'proxolink-create-request-${owner ?? 'fixture'}';

  Future<String?> read(String? owner) => _storage.run(
      _key(owner),
      () async =>
          (await SharedPreferences.getInstance()).getString(_key(owner)));

  Future<void> write(String? owner, String request) =>
      _storage.run(_key(owner), () async {
        final saved = await (await SharedPreferences.getInstance())
            .setString(_key(owner), request);
        if (!saved) throw StateError('pending_request_not_saved');
      });

  Future<void> clear(String? owner) => _storage.run(_key(owner), () async {
        await (await SharedPreferences.getInstance()).remove(_key(owner));
      });
}
