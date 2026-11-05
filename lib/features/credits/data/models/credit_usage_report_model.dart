import 'package:zedu/features/features.dart';

class CreditUsageReportModel extends CreditUsageReport {
  const CreditUsageReportModel({
    required super.balance,
    required super.purchased,
    required super.consumed,
    required super.periodLabel,
  });

  factory CreditUsageReportModel.fromJson(Map<String, dynamic> json) {
    return CreditUsageReportModel(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      purchased:
          (json['purchased'] as num?)?.toInt() ??
          (json['total_purchased'] as num?)?.toInt() ??
          (json['total_credited'] as num?)?.toInt() ??
          0,
      consumed:
          (json['consumed'] as num?)?.toInt() ??
          (json['total_consumed'] as num?)?.toInt() ??
          (json['total_used'] as num?)?.toInt() ??
          0,
      periodLabel: json['period_label'] as String? ?? 'This month',
    );
  }
}
