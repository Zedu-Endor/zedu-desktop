import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

void main() {
  test('reads checkout_session_url', () {
    final model = CreditCheckoutModel.fromJson({
      'checkout_session_id': 'cs_1',
      'checkout_session_url': 'https://checkout.example.com/cs_1',
    });

    expect(model.checkoutSessionId, 'cs_1');
    expect(model.checkoutSessionUrl, 'https://checkout.example.com/cs_1');
  });

  test('falls back to url when checkout_session_url is blank', () {
    final model = CreditCheckoutModel.fromJson({
      'session_id': 'cs_2',
      'checkout_session_url': '  ',
      'url': 'https://checkout.example.com/cs_2',
    });

    expect(model.checkoutSessionUrl, 'https://checkout.example.com/cs_2');
  });

  test('fails with a parsing error when no checkout link is returned', () {
    expect(
      () => CreditCheckoutModel.fromJson({'checkout_session_id': 'cs_3'}),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.parsing,
        ),
      ),
    );
  });
}
