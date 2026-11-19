import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Incoming webhook contract verified against zedu-fe useChannelWebhook.ts.
class WebhookRepository {
  WebhookRepository(this.api);
  final ApiBaseService api;
  Future<bool> canManage(String orgId) async {
    final response = await api.get<Map<String, dynamic>>(
      path: '/organisations/$orgId',
    );
    final org = response.data['data'];
    if (org is! Map) return false;
    final role = org['user_role'];
    final name = (role is Map ? role['role_name'] : org['role'])
        ?.toString()
        .toLowerCase();
    final permissions = [
      if (role is Map && role['permissions'] is List)
        ...role['permissions'] as List,
      if (org['permissions'] is List) ...org['permissions'] as List,
    ];
    return ['owner', 'administrator'].contains(name) ||
        permissions.contains('create:webhooks') ||
        permissions.contains('can_create_webhooks');
  }

  Future<WebhookModel?> fetch(String channelId) async {
    final response = await api.get<Map<String, dynamic>>(
      path: '/webhooks/$channelId',
    );
    final data = response.data['data'];
    if (data == null) return null;
    if (data is! Map) {
      throw const ApiFailure(message: 'Could not read webhook details.');
    }
    return WebhookModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> create(String channelId, String name) async {
    await api.post<Map<String, dynamic>>(
      path: '/webhooks/$channelId',
      data: {'webhook_name': name.trim()},
    );
  }

  Future<void> delete(String channelId, String webhookId) async {
    await api.delete<Map<String, dynamic>>(
      path: '/webhooks/$channelId/$webhookId',
    );
  }
}

final webhookRepositoryProvider = Provider(
  (ref) => WebhookRepository(locator<ApiBaseService>()),
);
final webhookManagementPermissionProvider = FutureProvider<bool>((ref) {
  final org = ref.watch(
    workspaceProvider.select((s) => s.selectedWorkspace?.id),
  );
  ref.watch(authNotifierProvider.select((s) => s.user?.id));
  return org == null
      ? Future.value(false)
      : ref.watch(webhookRepositoryProvider).canManage(org);
}, retry: (_, _) => null);
final channelWebhookProvider = FutureProvider.autoDispose
    .family<WebhookModel?, String>((ref, channelId) {
      ref.watch(workspaceProvider.select((s) => s.selectedWorkspace?.id));
      return ref.watch(webhookRepositoryProvider).fetch(channelId);
    }, retry: (_, _) => null);
