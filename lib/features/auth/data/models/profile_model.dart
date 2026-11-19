import 'package:zedu/features/features.dart';

/// Current user as returned by `GET /profile`.
///
/// The profile payload differs from the login `user` object: it has no
/// organisation block and uses ISO-8601 dates, so it is parsed separately
/// and mapped onto the same [User] entity.
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.username,
    required this.avatarUrl,
    required this.defaultAvatarUrl,
    required this.createdAt,
    required this.isActive,
    this.isVerified = true,
    this.isOnboarded = true,
    this.currentOrg = '',
    this.currentOrganisationSlug = '',
    this.creditBalance = 0,
    this.subscriptionPlanId = 'free',
    this.aiCreditsPurchasable = true,
    this.status = UserStatus.empty,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String username;
  final String avatarUrl;
  final String defaultAvatarUrl;
  final DateTime createdAt;
  final bool isActive;
  final bool isVerified;
  final bool isOnboarded;
  final String currentOrg;
  final String currentOrganisationSlug;
  final int creditBalance;
  final String subscriptionPlanId;
  final bool aiCreditsPurchasable;

  /// The user's custom status and presence, so they survive a restart.
  final UserStatus status;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      // `id` is the profile row; `userId` is the user the session belongs to.
      id:
          json['userId'] as String? ??
          json['user_id'] as String? ??
          json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      defaultAvatarUrl: json['default_avatar_url'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? true,
      isOnboarded: json['is_onboarded'] as bool? ?? true,
      currentOrg:
          json['organisation_id'] as String? ??
          json['current_org'] as String? ??
          '',
      currentOrganisationSlug:
          json['current_organisation_slug'] as String? ?? '',
      creditBalance: (json['credit_balance'] as num?)?.toInt() ?? 0,
      subscriptionPlanId: json['subscription_plan_id'] as String? ?? 'free',
      aiCreditsPurchasable: json['ai_credits_purchasable'] as bool? ?? true,
      status: _parseStatus(json),
    );
  }

  User toEntity() => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    username: username,
    isVerified: isVerified,
    isOnboarded: isOnboarded,
    createdAt: createdAt,
    currentOrg: currentOrg,
    currentOrganisationSlug: currentOrganisationSlug,
    avatarUrl: avatarUrl,
    defaultAvatarUrl: defaultAvatarUrl,
    creditBalance: creditBalance,
    subscriptionPlanId: subscriptionPlanId,
    aiCreditsPurchasable: aiCreditsPurchasable,
    status: status,
  );

  static UserStatus _parseStatus(Map<String, dynamic> json) {
    final statusMap = json['status'] is Map<String, dynamic>
        ? json['status'] as Map<String, dynamic>
        : json;

    final rawEmoji =
        statusMap['emoji'] ??
        statusMap['icon'] ??
        json['emoji'] ??
        json['icon'];
    final emoji = rawEmoji is String && rawEmoji.isNotEmpty ? rawEmoji : null;

    final rawText =
        statusMap['text'] ??
        statusMap['status_text'] ??
        json['text'] ??
        json['status_text'];
    final text = rawText is String && rawText.isNotEmpty ? rawText : null;

    final pauseNotifications =
        statusMap['pause_notification'] as bool? ??
        statusMap['pause_notifications'] as bool? ??
        json['pause_notification'] as bool? ??
        json['pause_notifications'] as bool? ??
        false;

    final online =
        statusMap['online'] as bool? ??
        statusMap['is_online'] as bool? ??
        json['online'] as bool? ??
        json['is_online'] as bool? ??
        true;

    final rawTimeout =
        statusMap['status_timeout'] ??
        statusMap['expires_at'] ??
        statusMap['status_expires_at'] ??
        json['status_timeout'] ??
        json['expires_at'] ??
        json['status_expires_at'];

    final expiresAt = _parseExpiresAt(rawTimeout);

    return UserStatus(
      emoji: emoji,
      text: text,
      expiresAt: expiresAt,
      pauseNotifications: pauseNotifications,
      online: online,
    );
  }

  static DateTime? _parseExpiresAt(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      if (raw <= 0) return null;
      final millis = raw > 10000000000 ? raw.toInt() : (raw * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty ||
          trimmed.toLowerCase() == 'dont-clear' ||
          trimmed.toLowerCase() == "don't-clear" ||
          trimmed.toLowerCase() == 'dont clear' ||
          trimmed.toLowerCase() == "don't clear") {
        return null;
      }
      final seconds = int.tryParse(trimmed);
      if (seconds != null) {
        if (seconds <= 0) return null;
        final millis = seconds > 10000000000 ? seconds : seconds * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return iso;
      for (final val in StatusTimeout.values) {
        if (val.apiValue.toLowerCase() == trimmed.toLowerCase() ||
            val.label.toLowerCase() == trimmed.toLowerCase()) {
          return val.expiryFrom(DateTime.now());
        }
      }
    }
    return null;
  }

  /// Accepts ISO-8601 strings and epoch-seconds strings.
  static DateTime _parseDate(Object? raw) {
    if (raw is String) {
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso;
      final seconds = int.tryParse(raw);
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
