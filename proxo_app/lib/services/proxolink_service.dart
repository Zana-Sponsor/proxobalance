import 'dart:convert';
import 'account_cache.dart';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../models/proxo_card.dart';
import '../models/proxolink_page_type.dart';

String newProxoRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ProxoLinkFailure implements Exception {
  final String code;
  final String? savedCardId;
  final ProxoCard? savedCard;
  const ProxoLinkFailure(this.code, {this.savedCardId, this.savedCard});
  String get message => switch (code) {
        'forbidden' ||
        'not_found' ||
        'card_not_found' =>
          'پەڕەکە نەدۆزرایەوە یان دەسەڵاتی دەستکاری نییە.',
        'invalid_tiktok' => 'تکایە ناوی تیک تۆک بێ بەستەر بنووسە.',
        'browser_launch_failed' =>
          'نەتوانرا پەڕەکە لە وێبگەڕ بکەرێتەوە. تکایە وێبگەڕێک دابمەزرێنە.',
        'page_archived' => 'ئەم پەڕەیە ئەرشیف کراوە.',
        'invalid_page_type' => 'جۆری پەڕەکە گونجاو نییە.',
        'provider_required' => 'تکایە کەمترین یەک دووگمە زیاد بکە.',
        'idempotency_conflict' =>
          'ئەم داواکارییە پێشتر پاشەکەوت کراوە. پەڕەکانت نوێ بکەرەوە.',
        'saved_refresh_failed' =>
          'پەڕەکە پاشەکەوت کرا. بۆ بینینی نوێی بکەرەوە.',
        'ad_dependency' =>
          'ئەم پەڕەیە لە ڕیکلامێکدا بەکارهاتووە و ناتوانرێت ئێستا ناچالاک بکرێت یان بسڕدرێتەوە.',
        'isolated_staging_required' ||
        'page_creation_unavailable' ||
        'template_not_found' ||
        'templates_unavailable' =>
          'دروستکردنی پەڕە ئێستا بەردەست نییە. تکایە دواتر هەوڵ بدەرەوە.',
        'invalid_provider_destination' ||
        'invalid_page_settings' =>
          'تکایە بەستەری دووگمەکان بپشکنە.',
        'edit_conflict' =>
          'پەڕەکە لە شوێنێکی تر دەستکاری کراوە. تکایە نوێی بکەرەوە.',
        'unauthorized' => 'تکایە دووبارە بچۆ ژوورەوە.',
        'avatar_required' => 'تکایە وێنەی پرۆفایل هەڵبژێرە.',
        'invalid_avatar' =>
          'وێنەکە گونجاو نییە. وێنەی JPEG، PNG یان WebP هەڵبژێرە.',
        'invalid_platform_value' => 'تکایە ژمارە و ناوی پلاتفۆرمەکان بپشکنە.',
        'publish_failed' =>
          'پەڕەکە پاشەکەوت کرا، بەڵام دروستکردنی سەرکەوتوو نەبوو. دەتوانیت دووبارە هەوڵ بدەیتەوە.',
        _ => 'نەتوانرا داواکارییەکە تەواو بکرێت. تکایە دووبارە هەوڵ بدەرەوە.',
      };
}

/// Optional capability reported by the same server that accepts page writes.
/// Older repositories can omit this; a production service fails closed when
/// its provider metadata explicitly reports that authoring is unavailable.
abstract interface class ProxoLinkAuthoringAvailability {
  bool? get pageCreationEnabled;
}

abstract class ProxoLinkRepository {
  String? get ownerScope => null;
  Future<List<ProxoCard>> cards();
  Future<ProxoCard?> card(String id) async {
    for (final card in await cards()) {
      if (card.id == id) return card;
    }
    return null;
  }

  Future<Uri?> avatar(ProxoCard card) async => null;
  Future<void> manage(ProxoCard card, String action) =>
      this.action(card.id, action);
  Future<List<ProxoTemplate>> templates();
  Future<List<ProxoProvider>> providers();
  Future<Uri> formPreview(Map<String, dynamic> data, {ProxoCard? existing});
  Future<ProxoCard> save(Map<String, dynamic> data, {ProxoCard? existing});
  Future<void> action(String id, String action);
  Future<Uri> preview(String id);
  Future<Uri> templatePreview(
    String key,
    int version, {
    String theme = 'purple',
    String language = 'ku',
    String pageType = 'contact',
  });
  Future<String> uploadAvatar(String id, Uint8List bytes);
  Uri publicUrl(String id, {String pageType = 'contact'});
}

class ProxoLinkService
    implements ProxoLinkRepository, ProxoLinkAuthoringAvailability {
  static String get publicBase => BackendConfig.current.publicBase;
  final SupabaseClient db;
  final http.Client? httpClient;
  bool? _pageCreationEnabled;
  ProxoLinkService(this.db, {this.httpClient});
  @override
  bool? get pageCreationEnabled => _pageCreationEnabled;
  @override
  String? get ownerScope => db.auth.currentUser?.id;
  Uri _url(String path) {
    final base = Uri.parse(publicBase);
    final result = base.resolve(path);
    if (base.scheme != 'https' || result.origin != base.origin) {
      throw const ProxoLinkFailure('invalid_request');
    }
    return result;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final session = db.auth.currentSession;
    if (session == null) throw const ProxoLinkFailure('unauthorized');
    final request = http.Request(method, _url(path))
      ..headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      });
    if (data != null) request.body = jsonEncode(data);
    try {
      final response = await (httpClient?.send(request) ?? request.send())
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
      if (db.auth.currentUser?.id != session.user.id) {
        throw const ProxoLinkFailure('unauthorized');
      }
      if (response.statusCode == 401) {
        throw const ProxoLinkFailure('unauthorized');
      }
      // A V5 server does not expose the V6 provider endpoint. Vercel returns
      // plain text for the missing rewrite, so do not mislabel it as offline.
      if (path == '/api/page-providers' && response.statusCode == 404) {
        throw const ProxoLinkFailure('page_creation_unavailable');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ProxoLinkFailure('network_error');
      }
      final body = decoded;
      if (response.statusCode >= 400 || body['ok'] != true) {
        final card = body['card'] is Map
            ? Map<String, dynamic>.from(body['card'] as Map)
            : null;
        throw ProxoLinkFailure(
          body['error'] as String? ?? 'network_error',
          savedCardId: (body['card'] as Map?)?['id'] as String?,
          savedCard: card?['user_id'] is String &&
                  card?['created_at'] is String &&
                  card?['updated_at'] is String
              ? ProxoCard.fromJson(card!)
              : null,
        );
      }
      return body;
    } on ProxoLinkFailure {
      rethrow;
    } catch (_) {
      throw const ProxoLinkFailure('network_error');
    }
  }

  @override
  Future<List<ProxoCard>> cards() async {
    final body = await _request('/api/contact-cards');
    return [
      for (final j in body['cards'] as List)
        ProxoCard.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  @override
  Future<ProxoCard?> card(String id) async {
    try {
      final body = await _request(
        '/api/contact-cards?id=${Uri.encodeQueryComponent(id)}',
      );
      return ProxoCard.fromJson(Map<String, dynamic>.from(body['card'] as Map));
    } on ProxoLinkFailure catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  @override
  Future<Uri?> avatar(ProxoCard card) async {
    if (card.avatarPath == null || !card.canPreview) return null;
    final signed = await preview(card.id);
    return signed.replace(path: '${card.publicPath}/avatar');
  }

  @override
  Future<List<ProxoTemplate>> templates() async {
    final cache = AppDataCache.forClient(db)..bindOwner();
    final body = await cache.cache
        .get('templates', () => _request('/api/contact-templates'));
    final templates = [
      for (final j in body['templates'] as List)
        ProxoTemplate.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
    const requiredKeys = {'pill', 'pill-mint', 'pill-dark', 'pill-white'};
    final available =
        templates.where((t) => t.version == 6).map((t) => t.key).toSet();
    if (!available.containsAll(requiredKeys))
      cache.cache.invalidate('templates');
    return templates;
  }

  @override
  Future<List<ProxoProvider>> providers() async {
    final cache = AppDataCache.forClient(db)..bindOwner();
    final body = await cache.cache
        .get('providers', () => _request('/api/page-providers'));
    _pageCreationEnabled = body['writes_enabled'] == true;
    if (_pageCreationEnabled == false) {
      // Retry must recheck the server after a deployment, rather than replay a
      // cached disabled capability for the next five minutes.
      cache.cache.invalidate('providers');
    }
    return [
      for (final j in body['providers'] as List)
        ProxoProvider.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  @override
  Future<Uri> formPreview(
    Map<String, dynamic> data, {
    ProxoCard? existing,
  }) async =>
      _url(
        (await _request(
          '/api/page-preview-token',
          method: 'POST',
          data: {...data, if (existing != null) 'card_id': existing.id},
        ))['preview_path'] as String,
      );

  @override
  Future<ProxoCard> save(
    Map<String, dynamic> data, {
    ProxoCard? existing,
  }) async {
    final result = await _request(
      '/api/contact-cards${existing == null ? '' : '?id=${existing.id}'}',
      method: existing == null ? 'POST' : 'PATCH',
      data: {
        ...data,
        if (existing != null)
          'expected_updated_at': existing.updatedAt.toIso8601String(),
      },
    );
    final id = (result['card'] as Map)['id'];
    final returned = Map<String, dynamic>.from(result['card'] as Map);
    if (returned['user_id'] is String &&
        returned['created_at'] is String &&
        returned['updated_at'] is String) {
      return ProxoCard.fromJson(returned);
    }
    try {
      final saved = await card(id as String);
      if (saved == null) throw const ProxoLinkFailure('not_found');
      return saved;
    } catch (_) {
      throw ProxoLinkFailure('saved_refresh_failed', savedCardId: id as String);
    }
  }

  @override
  Future<void> action(String id, String action) async {
    await _request(
      '/api/contact-card-action',
      method: 'POST',
      data: {'card_id': id, 'action': action},
    );
  }

  @override
  Future<void> manage(ProxoCard card, String action) async {
    await _request(
      '/api/contact-card-action',
      method: 'POST',
      data: {
        'card_id': card.id,
        'action': action,
        'expected_updated_at': card.updatedAt.toIso8601String(),
      },
    );
  }

  @override
  Future<Uri> preview(String id) async => _url(
        (await _request(
          '/api/contact-preview-token',
          method: 'POST',
          data: {'card_id': id},
        ))['preview_path'] as String,
      );
  @override
  Future<Uri> templatePreview(
    String key,
    int version, {
    String theme = 'purple',
    String language = 'ku',
    String pageType = 'contact',
  }) async =>
      _url(
        ((await _request(
          '/api/contact-templates?template_key=${Uri.encodeQueryComponent(key)}&version=$version&theme=${Uri.encodeQueryComponent(theme)}&language=${Uri.encodeQueryComponent(language)}&page_type=${Uri.encodeQueryComponent(pageType)}',
        ))['templates'] as List)
            .map((j) =>
                ProxoTemplate.fromJson(Map<String, dynamic>.from(j as Map)))
            .firstWhere((t) => t.key == key && t.version == version)
            .previewPath,
      );
  @override
  Uri publicUrl(String id, {String pageType = 'contact'}) {
    if (!ProxoPageType.values.any((t) => t.key == pageType))
      throw const ProxoLinkFailure('invalid_request');
    return _url('/$pageType/$id');
  }

  @override
  Future<String> uploadAvatar(String id, Uint8List bytes) async {
    final owner = ownerScope;
    if (owner == null) throw const ProxoLinkFailure('unauthorized');
    if (bytes.length < 12 || bytes.length > 10 * 1024 * 1024)
      throw const ProxoLinkFailure('invalid_avatar');
    final String extension, mime;
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      extension = 'jpg';
      mime = 'image/jpeg';
    } else if (bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      extension = 'png';
      mime = 'image/png';
    } else if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
            'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      extension = 'webp';
      mime = 'image/webp';
    } else {
      throw const ProxoLinkFailure('invalid_avatar');
    }
    if ((await _request('/api/page-providers'))['writes_enabled'] != true) {
      throw const ProxoLinkFailure('isolated_staging_required');
    }
    final user = db.auth.currentUser?.id;
    if (user != owner) throw const ProxoLinkFailure('unauthorized');
    final path = '$user/$id/avatar-${newProxoRequestId()}.$extension';
    await db.storage.from('proxolink-assets').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    if (ownerScope != owner) throw const ProxoLinkFailure('unauthorized');
    return path;
  }
}
