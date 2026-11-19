import 'package:zedu/features/features.dart';

class CreditUsageModel extends CreditUsage {
  const CreditUsageModel({
    required super.balance,
    required super.totalPurchased,
    required super.totalConsumed,
  });

  factory CreditUsageModel.fromJson(Map<String, dynamic> json) {
    return CreditUsageModel(
      balance:
          (json['balance'] as num?)?.toInt() ??
          (json['credit_balance'] as num?)?.toInt() ??
          0,
      totalPurchased:
          (json['total_purchased'] as num?)?.toInt() ??
          (json['purchased'] as num?)?.toInt() ??
          // The usage-report endpoint answers with these aliases.
          (json['total_credited'] as num?)?.toInt() ??
          0,
      totalConsumed:
          (json['total_consumed'] as num?)?.toInt() ??
          (json['consumed'] as num?)?.toInt() ??
          // The usage-report endpoint answers with these aliases.
          (json['total_used'] as num?)?.toInt() ??
          0,
    );
  }
}
