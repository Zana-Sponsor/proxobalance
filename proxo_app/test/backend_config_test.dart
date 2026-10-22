import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/config/backend_config.dart';

const _ref = 'abcdefghijklmnopqrst';
const _database = 'https://$_ref.supabase.co';
const _api = 'https://proxolink-staging-proxo.vercel.app';
const _key = 'sb_publishable_fictionalAcceptanceKey';

String _jwt(String role, {String ref = _ref}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({
              'role': role,
              'ref': ref,
            }))).replaceAll('=', '')}.signature';

BackendConfig _staging({
  String database = _database,
  String key = _key,
  String api = _api,
}) =>
    BackendConfig.fromValues(
      mode: 'staging',
      supabaseUrl: database,
      supabaseAnonKey: key,
      publicBase: api,
    );

void main() {
  test('default foreground/background config preserves production endpoints',
      () {
    final config = BackendConfig.fromValues();
    expect(config.isStaging, isFalse);
    expect(config.supabaseUrl, 'https://cojchkwssmasiejcgvbk.supabase.co');
    expect(config.publicBase, 'https://www.proxobalance.app');
    final claims = jsonDecode(utf8.decode(base64Url.decode(
      base64Url.normalize(config.supabaseAnonKey.split('.')[1]),
    )));
    expect(claims['role'], 'anon');
    expect(claims['ref'], 'cojchkwssmasiejcgvbk');
    expect(config.supabaseAnonKey.split('.').last,
        'RCALy3wpKHGAkmXWcBqEb_QFEUmh6ErdRbfrBmagvtw');
  });

  test('complete isolated settings route Auth and page API together', () {
    final config = _staging();
    expect(config.isStaging, isTrue);
    expect(config.supabaseUrl, _database);
    expect(config.supabaseAnonKey, _key);
    expect(config.publicBase, _api);
  });

  test('origins normalize trailing slash before SDK path concatenation', () {
    final config = _staging(database: '$_database/', api: '$_api/');
    expect(config.supabaseUrl, _database);
    expect('${config.supabaseUrl}/auth/v1', '$_database/auth/v1');
    expect(config.publicBase, _api);
    expect(
        BackendConfig.fromValues(
          publicBase: '${BackendConfig.productionPublicBase}/',
        ).publicBase,
        BackendConfig.productionPublicBase);
  });

  test('staging disables production transports while defaults preserve them',
      () {
    expect(BackendConfig.fromValues().productionTransportsEnabled, isTrue);
    expect(
        BackendConfig.fromValues().requireProductionTransport, returnsNormally);
    expect(_staging().productionTransportsEnabled, isFalse);
    expect(_staging().requireProductionTransport, throwsStateError);
  });

  test('matching legacy anon JWT remains supported', () {
    expect(_staging(key: _jwt('anon')).isStaging, isTrue);
  });

  test('staging refuses the production project', () {
    expect(() => _staging(database: BackendConfig.productionSupabaseUrl),
        throwsFormatException);
  });

  test('staging refuses each missing setting rather than production fallback',
      () {
    expect(() => _staging(database: ''), throwsFormatException);
    expect(() => _staging(key: ''), throwsFormatException);
    expect(() => _staging(api: ''), throwsFormatException);
  });

  test('staging refuses production and unrelated API hosts', () {
    for (final base in [
      BackendConfig.productionPublicBase,
      'https://proxobalance-799afikbi-proxoapp-1758.vercel.app',
      'https://proxolink-staging-proxo.vercel.app.example.com'
    ]) {
      expect(() => _staging(api: base), throwsFormatException);
    }
  });

  test('credential and path URL tricks fail before network initialization', () {
    for (final base in [
      'http://proxolink-staging.vercel.app',
      'https://user@proxolink-staging.vercel.app',
      'https://proxolink-staging.vercel.app:8443',
      'https://proxolink-staging.vercel.app/api',
      'https://proxolink-staging.vercel.app?target=production',
      'https://proxolink-staging.vercel.app#production'
    ]) {
      expect(() => _staging(api: base), throwsFormatException);
    }
    expect(() => _staging(database: 'https://$_ref.supabase.co.evil.test'),
        throwsFormatException);
  });

  test('server, malformed, and another project credentials are rejected', () {
    for (final key in [
      'sb_secret_fictional',
      _jwt('service_role'),
      _jwt('anon', ref: BackendConfig.productionProjectRef),
      BackendConfig.productionAnonKey,
      'not-a-publishable-key',
      'header.invalid.signature',
      ' $_key'
    ]) {
      expect(() => _staging(key: key), throwsFormatException);
    }
  });

  test('errors never include supplied credential values', () {
    const secret = 'sb_secret_doNotPrintThis';
    try {
      _staging(key: secret);
      fail('Expected configuration rejection');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains(secret)));
      expect(error.source, isNull);
    }
  });

  test('partial isolated overrides require explicit staging mode', () {
    expect(() => BackendConfig.fromValues(supabaseUrl: _database),
        throwsFormatException);
    expect(() => BackendConfig.fromValues(supabaseAnonKey: _key),
        throwsFormatException);
    expect(() => BackendConfig.fromValues(publicBase: _api),
        throwsFormatException);
  });

  test('unknown mode is rejected instead of silently becoming production', () {
    expect(
        () => BackendConfig.fromValues(mode: 'stagng'), throwsFormatException);
  });

  test('existing protected read-only preview override remains compatible', () {
    const preview =
        'https://proxobalance-git-feat-proxolink-private-re-00a2aa-proxoapp-1758.vercel.app';
    final config = BackendConfig.fromValues(publicBase: preview);
    expect(config.isStaging, isFalse);
    expect(config.publicBase, preview);
    expect(config.supabaseUrl, BackendConfig.productionSupabaseUrl);
  });
}
