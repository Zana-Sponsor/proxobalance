import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/auth/auth_models.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';

void main() {
  group('IraqPhone', () {
    test('normalizes local, 00964 and duplicated country codes', () {
      expect(IraqPhone.normalize('0750 123 4567'), '+9647501234567');
      expect(IraqPhone.normalize('+9647501234567'), '+9647501234567');
      expect(IraqPhone.normalize('00964 7501234567'), '+9647501234567');
      expect(IraqPhone.normalize('9649647501234567'), '+9647501234567');
    });

    test('validates exactly ten Iraqi mobile digits', () {
      expect(IraqPhone.isValid('7501234567'), isTrue);
      expect(IraqPhone.isValid('6501234567'), isFalse);
      expect(IraqPhone.isValid('750123456'), isFalse);
    });

    test('masks the active OTP destination', () {
      expect(
        otpDestination(AuthChannel.phone, '+9647501234567'),
        '+964 750 *** ** 67',
      );
      expect(
        otpDestination(AuthChannel.email, 'person@gmail.com'),
        'pe***@gmail.com',
      );
    });
  });

  test('login CTA readiness is visual-only', () {
    expect(
      AuthValidators.signInReady(email: 'a', password: 'x'),
      isTrue,
    );
    expect(AuthValidators.email('a'), isNotNull);
  });

  test('signup readiness includes phone, strong password and confirmation', () {
    const String password = 'Strong#1';
    expect(
      AuthValidators.signUpReady(
        name: 'Test User',
        phone: '+9647501234567',
        password: password,
        confirmation: password,
      ),
      isTrue,
    );
    expect(
      AuthValidators.signUpReady(
        name: 'Test User',
        phone: '+9647501234567',
        password: password,
        confirmation: 'Different#1',
      ),
      isFalse,
    );
  });
}
