import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/services/featured_image_cache.dart';

/// Supplies the exact production provider/cache key with a controlled image
/// stream. No HTTP client, storage URL or production image-loading code changes.
/// Useful for exercising Image.frameBuilder/errorBuilder in real card widgets.
class FeaturedThumbnailFixture {
  FeaturedThumbnailFixture._(this._key, this._stream);

  final Object _key;
  final _FixtureImageStream _stream;
  static const _pathProvider =
      MethodChannel('plugins.flutter.io/path_provider');
  static Directory? _directory;
  static final _unexpectedRequests = <Uri>[];

  /// Call once in setUpAll: CacheManager starts filesystem initialization when
  /// the first production provider is constructed, even on an image-cache hit.
  /// Its HTTP client is fail-closed and verified unused; no remote image is read.
  static Future<void> initialize() async {
    if (_directory != null) return;
    final directory =
        await Directory.systemTemp.createTemp('proxo-thumbnails-');
    _directory = directory;
    _unexpectedRequests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async {
      switch (call.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return directory.path;
        default:
          throw UnsupportedError(
              'Unexpected path provider call ${call.method}');
      }
    });
    await http.runWithClient(() async {
      final manager = FeaturedImageCache.manager;
      // Finish native-cache setup outside the fake-async widget test zone.
      await manager.config.fileSystem.createFile('fixture-initialization');
      await manager.store.getCacheSize();
    },
        () => MockClient((request) async {
              _unexpectedRequests.add(request.url);
              throw StateError(
                  'Unexpected thumbnail HTTP request ${request.url}');
            }));
  }

  static Future<void> shutdown() async {
    final directory = _directory;
    if (directory == null) return;
    await FeaturedImageCache.manager.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, null);
    await directory.delete(recursive: true);
    _directory = null;
    expect(_unexpectedRequests, isEmpty,
        reason: 'Thumbnail fixtures must use the primed production cache key');
  }

  static Future<FeaturedThumbnailFixture> pending(String url) async {
    if (_directory == null) {
      throw StateError('Initialize thumbnail fixtures in setUpAll first');
    }
    final key = await FeaturedImageCache.provider(url)
        .obtainKey(ImageConfiguration.empty);
    final cache = PaintingBinding.instance.imageCache;
    cache.evict(key);
    final stream = _FixtureImageStream();
    cache.putIfAbsent(key, () => stream, onError: (_, __) {});
    return FeaturedThumbnailFixture._(key, stream);
  }

  /// An existing bundled JPEG serves as a fictional Proxo advert creative.
  /// It is decoded through Flutter, not painted or substituted into a screenshot.
  Future<void> succeed({String asset = 'assets/images/proxo_logo.jpg'}) async {
    final bytes = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: FeaturedImageCache.decodedWidth,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      _stream.complete(frame.image);
    } finally {
      codec.dispose();
    }
  }

  void fail() => _stream.fail();

  void dispose() => PaintingBinding.instance.imageCache.evict(_key);
}

class _FixtureImageStream extends ImageStreamCompleter {
  void complete(ui.Image image) => setImage(ImageInfo(image: image));

  void fail() => reportError(
        context: ErrorDescription('fictional thumbnail decode failure'),
        exception: StateError('fixture_image_unavailable'),
        stack: StackTrace.current,
        silent: true,
      );
}
