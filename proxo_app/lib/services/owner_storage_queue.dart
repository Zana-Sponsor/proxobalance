import 'dart:async';

/// Serializes durable state changes for one account. Apply caller timeouts to
/// the returned Future, never inside an operation: an unfinished platform
/// write must stay ahead of later writes even after its caller stops waiting.
class OwnerStorageQueue {
  final _tails = <String, Future<void>>{};

  Future<T> run<T>(String owner, Future<T> Function() operation) {
    final prior = _tails[owner] ?? Future<void>.value();
    final result = prior.then((_) => operation());
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _tails[owner] = tail;
    unawaited(tail.then((_) {
      if (identical(_tails[owner], tail)) _tails.remove(owner);
    }));
    return result;
  }
}
