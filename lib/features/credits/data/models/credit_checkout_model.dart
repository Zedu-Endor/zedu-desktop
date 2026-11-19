import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditCheckoutModel extends CreditCheckoutSession {
  const CreditCheckoutModel({
    required super.checkoutSessionId,
    required super.checkoutSessionUrl,
  });

  factory CreditCheckoutModel.fromJson(Map<String, dynamic> json) {
    return CreditCheckoutModel(
      checkoutSessionId:
          json['checkout_session_id'] as String? ??
          json['session_id'] as String? ??
          '',
      checkoutSessionUrl: _checkoutUrl(json),
    );
  }

  /// The checkout page link. A response without one can't send the buyer
  /// anywhere, so it fails here and the purchase shows an error instead of
  /// silently doing nothing.
  static String _checkoutUrl(Map<String, dynamic> json) {
    for (final key in const ['checkout_session_url', 'url']) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    throw const ApiFailure(
      message: 'The checkout link is missing. Please try again.',
      kind: ApiFailureKind.parsing,
    );
  }
}
