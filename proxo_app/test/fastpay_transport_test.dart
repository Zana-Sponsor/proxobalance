import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/config/backend_config.dart';
import 'package:proxo_app/services/fastpay_transport.dart';

BackendConfig isolatedFastPayBackend({String ref = 'abcdefghijklmnopqrst'}) =>
    BackendConfig.fromValues(mode: 'staging',
      supabaseUrl: 'https://$ref.supabase.co',
      supabaseAnonKey: 'sb_publishable_fictionalAcceptanceKey',
      publicBase: 'https://proxolink-staging-proxo.vercel.app');

FastPayTransport isolatedFastPayTransport() => FastPayTransport.fromValues(
    backendConfig: isolatedFastPayBackend(),
    stagingWebhookBase: FastPayTransport.stagingBase);

void main() {
  test('legacy production route and replay policy remain unchanged', () {
    final transport = FastPayTransport.fromValues(backendConfig: BackendConfig.fromValues());
    expect(transport.createUri.toString(), 'https://email.proxopages.com/webhook/fastpay/order-create');
    expect(transport.statusUri.toString(), 'https://email.proxopages.com/webhook/fastpay/order-status');
    expect(transport.durableStaging, isFalse);
  });

  test('isolated wallet transport is disabled unless explicitly enabled', () {
    expect(() => FastPayTransport.fromValues(backendConfig: isolatedFastPayBackend()), throwsStateError);
    expect(() => FastPayTransport.fromValues(backendConfig: BackendConfig.fromValues(),
        stagingWebhookBase: FastPayTransport.stagingBase), throwsFormatException);
  });

  test('only the reviewed isolated route permits the durable protocol', () {
    final transport = isolatedFastPayTransport();
    expect(transport.createUri.toString(), '${FastPayTransport.stagingBase}/order-create');
    expect(transport.statusUri.toString(), '${FastPayTransport.stagingBase}/order-status');
    expect(transport.durableStaging, isTrue);
    expect(transport.backendOrigin, isolatedFastPayBackend().supabaseUrl);
    for (final base in [FastPayTransport.legacyBase,
      '${FastPayTransport.stagingBase}/', '${FastPayTransport.stagingBase}?next=production',
      'http://email.proxopages.com/webhook/proxo-fastpay-staging',
      'https://user@email.proxopages.com/webhook/proxo-fastpay-staging',
      'https://email.proxopages.com:443/webhook/proxo-fastpay-staging',
      'https://email.proxopages.com.evil.test/webhook/proxo-fastpay-staging']) {
      expect(() => FastPayTransport.fromValues(backendConfig: isolatedFastPayBackend(),
          stagingWebhookBase: base), throwsFormatException);
    }
  });

  test('transport binding cannot mix a protocol, project or production route', () {
    expect(FastPayTransport.validBinding(FastPayTransport.durableStagingProtocol,
        FastPayTransport.stagingBase, BackendConfig.productionSupabaseUrl), isFalse);
    expect(FastPayTransport.validBinding(FastPayTransport.durableStagingProtocol,
        FastPayTransport.legacyBase, isolatedFastPayBackend().supabaseUrl), isFalse);
    expect(FastPayTransport.validBinding('future-protocol',
        FastPayTransport.stagingBase, isolatedFastPayBackend().supabaseUrl), isFalse);
  });
}
