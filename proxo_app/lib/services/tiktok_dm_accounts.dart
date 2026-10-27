import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';

String tiktokDmRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String normalizeTikTokUsername(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

bool validTikTokUsername(String value) =>
    RegExp(r'^[a-zA-Z0-9._]{2,24}$').hasMatch(normalizeTikTokUsername(value));

String? _httpsImage(dynamic value) {
  final uri = Uri.tryParse(value?.toString() ?? '');
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasPort
      ? uri.toString()
      : null;
}

/// The server is the authority for identity, permissions and public visibility.
/// These display models cannot be used to authorize or price an advertisement.
@immutable
class TikTokDmAccount {
  final String id, username, displayName, status;
  final String? profileImageUrl, errorCode;
  final bool dmReady;
  const TikTokDmAccount(
      {required this.id,
      required this.username,
      this.displayName = '',
      this.status = 'CONNECTED',
      this.profileImageUrl,
      this.errorCode,
      this.dmReady = false});
  bool get selectable => status == 'CONNECTED' && dmReady;
  factory TikTokDmAccount.fromJson(Map<String, dynamic> json) =>
      TikTokDmAccount(
          id: '${json['id'] ?? ''}',
          username: '${json['verified_username'] ?? json['username'] ?? ''}',
          displayName: '${json['display_name'] ?? ''}',
          status:
              '${json['connection_status'] ?? json['status'] ?? 'UNAVAILABLE'}',
          profileImageUrl: _httpsImage(json['profile_image_url']),
          errorCode: json['error_code']?.toString(),
          dmReady: json['dm_ready'] is bool
              ? json['dm_ready'] == true
              : (json['message_ads_eligible'] == true &&
                  json['can_pull_video'] == true &&
                  json['can_manage_message'] == true));
}

@immutable
class TikTokDmVideo {
  final String accountId, itemId, caption, permalink;
  final String? thumbnailUrl;
  final DateTime? publishedAt;
  final int? duration;
  final bool isPublic, eligible;
  const TikTokDmVideo(
      {required this.accountId,
      required this.itemId,
      this.caption = '',
      this.permalink = '',
      this.thumbnailUrl,
      this.publishedAt,
      this.duration,
      this.isPublic = false,
      this.eligible = false});
  bool get selectable => isPublic && eligible && itemId.isNotEmpty;
  factory TikTokDmVideo.fromJson(Map<String, dynamic> json, String accountId) =>
      TikTokDmVideo(
          accountId: '${json['account_id'] ?? accountId}',
          itemId: '${json['item_id'] ?? ''}',
          caption: '${json['caption'] ?? ''}',
          permalink: '${json['permalink'] ?? ''}',
          thumbnailUrl: _httpsImage(json['thumbnail_url']),
          publishedAt: DateTime.tryParse('${json['published_at'] ?? ''}'),
          duration: (json['duration'] as num?)?.round(),
          isPublic: json['public'] == true,
          eligible: json['ad_eligible'] == true);
}

@immutable
class TikTokDmVideoPage {
  final List<TikTokDmVideo> videos;
  final String? nextCursor;
  const TikTokDmVideoPage(this.videos, {this.nextCursor});
}

@immutable
class TikTokDmSelection {
  final String accountId, itemId, username, permalink, caption;
  const TikTokDmSelection(
      {required this.accountId,
      required this.itemId,
      required this.username,
      required this.permalink,
      this.caption = ''});
}

@immutable
class TikTokDmConnection {
  final String id, requestedUsername, status;
  final String? authorizationUrl, authorizedUsername, errorCode;
  final DateTime? expiresAt;
  const TikTokDmConnection(
      {required this.id,
      required this.requestedUsername,
      required this.status,
      this.authorizationUrl,
      this.authorizedUsername,
      this.errorCode,
      this.expiresAt});
  bool get terminal => const {
        'CONNECTED',
        'USERNAME_MISMATCH',
        'EXPIRED',
        'DISCONNECTED',
        'MISSING_PERMISSION',
        'NOT_BUSINESS_ACCOUNT',
        'REJECTED',
        'REVOKED',
        'VERIFIED_UNLINKED',
        'UNAVAILABLE'
      }.contains(status);
  bool get awaitingAuthorization => const {
        'PENDING',
        'WAITING_FOR_SCAN',
        'AUTHORIZATION_CREATED'
      }.contains(status);
  factory TikTokDmConnection.fromJson(Map<String, dynamic> json) =>
      TikTokDmConnection(
          id: '${json['connection_request_id'] ?? json['request_id'] ?? json['id'] ?? ''}',
          requestedUsername: '${json['requested_username'] ?? ''}',
          status: '${json['status'] ?? 'ERROR'}',
          authorizationUrl: json['authorization_url']?.toString(),
          authorizedUsername: json['authorized_username']?.toString(),
          errorCode: json['error_code']?.toString(),
          expiresAt: DateTime.tryParse('${json['expires_at'] ?? ''}'));
}

@immutable
class TikTokDmAccounts {
  final List<TikTokDmAccount> accounts;
  final TikTokDmConnection? pendingRequest;
  const TikTokDmAccounts(this.accounts, {this.pendingRequest});
}

class TikTokDmFailure implements Exception {
  final String code;
  const TikTokDmFailure(this.code);
  String get message => tiktokDmMessage(code);
}

String tiktokDmMessage(String code) =>
    switch (code.replaceFirst(RegExp(r'^TIKTOK_'), '')) {
      'OFFLINE' => 'هێڵەکەت بپشکنە و دووبارە هەوڵ بدەوە.',
      'TIMEOUT' => 'وەڵامەکە دوا کەوت؛ دووبارە پشکنین بکە.',
      'NETWORK' => 'پەیوەندی بە خزمەتگوزارییەکە نەکرا؛ دووبارە هەوڵ بدەوە.',
      'SERVER_ERROR' => 'خزمەتگوزارییەکە کێشەی هەیە؛ دواتر هەوڵ بدەوە.',
      'USERNAME_MISMATCH' =>
        'هەژماری سکەنکراو لەگەڵ ناوی نووسراو یەک ناگرێتەوە؛ بە هەمان هەژمار سکەن بکە.',
      'INVALID_USERNAME' ||
      'USERNAME_INVALID' =>
        'ناوی بەکارهێنەری تیک تۆک بە دروستی بنووسە.',
      'EXPIRED' || 'QR_EXPIRED' || 'AUTHORIZATION_EXPIRED' =>
        'کاتی QR تەواو بوو؛ کۆدێکی نوێ دروست بکە.',
      'REJECTED' || 'AUTHORIZATION_REJECTED' =>
        'ڕەزامەندی نەدرا؛ بۆ پەیوەستکردن دووبارە هەوڵ بدەوە.',
      'REVOKING' => 'پەیوەندییەکە دەپچڕێندرێت؛ تکایە چاوەڕوان بە.',
      'NOT_BUSINESS_ACCOUNT' => 'ئەم هەژمارە هەژماری بازرگانی تیک تۆک نییە.',
      'IS_PRIVATE_ACCOUNT' =>
        'هەژمارەکە تایبەتە؛ تەنها هەژمار و ڤیدیۆی گشتی بەردەستن.',
      'MESSAGE_PERMISSION_REQUIRED' ||
      'MESSAGE_PERMISSION_MISSING' ||
      'OAUTH_SCOPE_MISSING' ||
      'SCOPE_UNAVAILABLE' ||
      'MISSING_PERMISSION' =>
        'مۆڵەتی ڕیکلامی نامە نەدراوە؛ مۆڵەتەکان نوێ بکەرەوە.',
      'VIDEO_PERMISSION_REQUIRED' ||
      'VIDEO_PERMISSION_MISSING' =>
        'مۆڵەتی بینینی ڤیدیۆکانی ئەم هەژمارە نەدراوە.',
      'ACCOUNT_NOT_LINKED' ||
      'ADVERTISER_NOT_LINKED' ||
      'NO_VALID_BIND_ACCOUNT' =>
        'ئەم هەژمارە بە هەژماری ڕیکلام پەیوەست نییە؛ دووبارە پەیوەستی بکە.',
      'CONVERSATION_UNAVAILABLE' ||
      'IRAQ_CONVERSATION_UNAVAILABLE' ||
      'CONVERSATION_ALLOWLIST_REQUIRED' ||
      'ACCOUNT_ADS_INELIGIBLE' ||
      'DM_NOT_ELIGIBLE' =>
        'ڕیکلامی نامەی ڕاستەوخۆ بۆ ئەم هەژمارە بەردەست نییە.',
      'IDENTITY_ALREADY_BOUND' =>
        'ئەم هەژماری تیک تۆکە پێشتر بە هەژمارێکی تری پڕۆکسۆ پەیوەست کراوە.',
      'VIDEO_UNAVAILABLE' ||
      'VIDEO_NOT_PUBLIC_OR_AVAILABLE' =>
        'ڤیدیۆی هەڵبژێردراو چیتر بەردەست نییە؛ ڤیدیۆیەکی تر هەڵبژێرە.',
      'VIDEO_MUSIC_INELIGIBLE' =>
        'مۆسیقای ئەم ڤیدیۆیە بۆ ڕیکلام ڕێگەپێدراو نییە؛ ڤیدیۆیەکی تر هەڵبژێرە.',
      'UNAVAILABLE' ||
      'ACCOUNT_NOT_CONNECTED' ||
      'REVOKED' ||
      'DISCONNECTED' =>
        'هەژمارەکە بەردەست نییە؛ پەیوەندییەکە نوێ بکەرەوە.',
      'NOT_AUTHENTICATED' || 'UNAUTHORIZED' => 'دووبارە بچۆ ژوورەوە.',
      'FEATURE_DISABLED' ||
      'DM_DISABLED' =>
        'نامەی ڕاستەوخۆ ئێستا بەردەست نییە.',
      'AUTH_CORRELATION_UNAVAILABLE' ||
      'OAUTH_NOT_CONFIGURED' ||
      'OAUTH_CONFIGURATION_CHANGED' ||
      'PRIVATE_CREDENTIAL_INVALID' =>
        'پەیوەستکردنی هەژمار ئێستا ئامادە نییە؛ تکایە دواتر هەوڵ بدەوە.',
      'IDENTITY_JOIN_UNVERIFIED' || 'VERIFIED_UNLINKED' =>
        'هەژمارەکە پشتڕاست کرایەوە، بەڵام پەیوەندییەکەی بە هەژماری ڕیکلام هێشتا پشتڕاست نەکراوەتەوە.',
      'OWNER_BINDING_UNVERIFIED' ||
      'IDENTITY_MISMATCH' ||
      'IDENTITY_UNAVAILABLE' =>
        'ناسنامەی ئەم هەژمارە پشتڕاست نەکرایەوە؛ پەیوەندییەکە نوێ بکەرەوە.',
      'WELCOME_MESSAGE_UNAVAILABLE' ||
      'WELCOME_MESSAGE_NOT_VERIFIED' =>
        'نامەی بەخێرهاتن بۆ ئەم هەژمارە ئامادە نییە.',
      'PROVIDER_ERROR' ||
      'PROVIDER_REJECTED' ||
      'RESPONSE_INVALID' ||
      'VIDEO_RESPONSE_INVALID' =>
        'تیک تۆک وەڵامی تەواوی نەدایەوە؛ دووبارە هەوڵ بدەوە.',
      'BACKEND_UNAVAILABLE' ||
      'BACKEND_RESPONSE_INVALID' ||
      'WORKER_UNAVAILABLE' =>
        'خزمەتگوزارییەکە کێشەی هەیە؛ دواتر هەوڵ بدەوە.',
      'DISCONNECT_UNCONFIRMED' ||
      'OUTCOME_UNKNOWN' ||
      'OPERATION_STATUS_UNKNOWN' =>
        'ئەنجامەکە هێشتا پشتڕاست نەکراوەتەوە؛ دووبارە پشکنین بکە.',
      'NOT_READY' ||
      'CONVERSATION_TUPLE_NOT_VERIFIED' ||
      'DM_SETTINGS_NOT_VERIFIED' ||
      'IDENTITY_CONFIGURATION_REQUIRED' ||
      'ACCESS_TOKEN_NOT_CONFIGURED' ||
      'TOKEN_REFERENCE_INVALID' =>
        'ئەم هەژمارە هێشتا بۆ ڕیکلامی نامە ئامادە نییە.',
      _ => 'کێشەیەک ڕوویدا. تکایە دووبارە هەوڵ بدەوە.',
    };

abstract class TikTokDmRepository {
  String get ownerId;
  Stream<bool> get offlineChanges => const Stream<bool>.empty();
  Future<TikTokDmAccounts> accounts();
  Future<TikTokDmConnection> startConnection(String username, String requestId);
  Future<TikTokDmConnection> connectionStatus(String requestId);
  Future<TikTokDmVideoPage> videos(String accountId, {String? cursor});
  Future<void> disconnect(String accountId, String requestId);
}

class SupabaseTikTokDmRepository extends TikTokDmRepository {
  final SupabaseClient client;
  final BackendConfig backend;
  SupabaseTikTokDmRepository(this.client, {BackendConfig? backendConfig})
      : backend = backendConfig ?? BackendConfig.current;
  @override
  String get ownerId => client.auth.currentUser?.id ?? '';
  @override
  Stream<bool> get offlineChanges => Connectivity()
      .onConnectivityChanged
      .map((results) => results.contains(ConnectivityResult.none))
      .distinct();

  Future<Map<String, dynamic>> _call(String op,
      [Map<String, dynamic> body = const {}]) async {
    final owner = ownerId, token = client.auth.currentSession?.accessToken;
    if (owner.isEmpty || token == null) {
      throw const TikTokDmFailure('NOT_AUTHENTICATED');
    }
    try {
      final response = await http
          .post(Uri.parse('${backend.publicBase}/api/tiktok-dm?op=$op'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json'
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));
      if (ownerId != owner) throw const TikTokDmFailure('NOT_AUTHENTICATED');
      final result = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map);
      if (response.statusCode != 200 || result['ok'] != true) {
        throw TikTokDmFailure(
            '${result['code'] ?? result['error'] ?? 'SERVER_ERROR'}');
      }
      return result;
    } on TimeoutException {
      throw const TikTokDmFailure('TIMEOUT');
    } on http.ClientException {
      var offline = false;
      try {
        offline = (await Connectivity().checkConnectivity())
            .contains(ConnectivityResult.none);
      } catch (_) {}
      throw TikTokDmFailure(offline ? 'OFFLINE' : 'NETWORK');
    } on TikTokDmFailure {
      rethrow;
    } catch (_) {
      throw const TikTokDmFailure('SERVER_ERROR');
    }
  }

  @override
  Future<TikTokDmAccounts> accounts() async {
    final json = await _call('accounts');
    return TikTokDmAccounts(
        List.unmodifiable((json['accounts'] as List? ?? const [])
            .whereType<Map>()
            .map(
                (j) => TikTokDmAccount.fromJson(Map<String, dynamic>.from(j)))),
        pendingRequest: json['pending_request'] is Map
            ? TikTokDmConnection.fromJson(
                Map<String, dynamic>.from(json['pending_request']))
            : null);
  }

  @override
  Future<TikTokDmConnection> startConnection(
          String username, String requestId) async =>
      TikTokDmConnection.fromJson(await _call('connect-start',
          {'username': username.trim(), 'idempotency_key': requestId}));
  @override
  Future<TikTokDmConnection> connectionStatus(String requestId) async =>
      TikTokDmConnection.fromJson(
          await _call('connect-status', {'request_id': requestId}));
  @override
  Future<TikTokDmVideoPage> videos(String accountId, {String? cursor}) async {
    final json = await _call('videos',
        {'account_id': accountId, if (cursor != null) 'cursor': cursor});
    final videos = (json['videos'] as List? ?? const [])
        .whereType<Map>()
        .map((j) =>
            TikTokDmVideo.fromJson(Map<String, dynamic>.from(j), accountId))
        .where((video) => video.accountId == accountId && video.selectable)
        .toList(growable: false);
    return TikTokDmVideoPage(List.unmodifiable(videos),
        nextCursor: json['next_cursor']?.toString());
  }

  @override
  Future<void> disconnect(String accountId, String requestId) async {
    await _call(
        'disconnect', {'account_id': accountId, 'idempotency_key': requestId});
  }
}
