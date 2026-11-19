// Subscription token model for Centrifugo channel subscriptions.
class SubscriptionTokenModel {
  final String channel;
  final String token;

  const SubscriptionTokenModel({required this.channel, required this.token});

  factory SubscriptionTokenModel.fromJson(Map<String, dynamic>? json) {
    json = json ?? {};
    return SubscriptionTokenModel(
      channel: (json['channel'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'channel': channel, 'token': token};
}
