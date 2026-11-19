import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// A credits repository whose usage call completes only when the test says so,
/// so the notifier's stale-response behaviour can be exercised.
class GatedCreditsRepository implements CreditsRepository {
  final Map<String, Completer<CreditUsage>> usageGates = {};

  @override
  Future<Result<List<CreditPackage>>> getPackages() async =>
      const Success<List<CreditPackage>>(<CreditPackage>[]);

  @override
  Future<Result<CreditUsage>> getUsage(String orgId) async {
    final gate = usageGates[orgId];
    if (gate == null) return const Success<CreditUsage>(CreditUsage.empty);
    return Success<CreditUsage>(await gate.future);
  }

  @override
  Future<Result<CreditUsageReport>> getUsageReport(String orgId) async =>
      const Success<CreditUsageReport>(CreditUsageReport.empty);

  @override
  Future<Result<List<CreditTransaction>>> getTransactions(String orgId) async =>
      const Success<List<CreditTransaction>>(<CreditTransaction>[]);

  @override
  Future<Result<CreditCheckoutSession>> purchaseCredits({
    String? planId,
    required String email,
    String? packageId,
  }) async => const Success<CreditCheckoutSession>(
    CreditCheckoutSession(
      checkoutSessionId: 'cs',
      checkoutSessionUrl: 'https://pay.example.com/cs',
    ),
  );

  @override
  Future<Result<void>> verifyPayment({required String sessionId}) async =>
      const Success<void>(null);
}

void main() {
  late GatedCreditsRepository repository;
  late ProviderContainer container;
  late CreditsNotifier notifier;

  setUp(() {
    repository = GatedCreditsRepository();
    container = ProviderContainer(
      overrides: [creditsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    notifier = container.read(creditsNotifierProvider.notifier);
  });

  group('load generation guard', () {
    test(
      'a slower earlier workspace load cannot overwrite the latest one',
      () async {
        repository.usageGates['A'] = Completer<CreditUsage>();
        repository.usageGates['B'] = Completer<CreditUsage>();

        final loadA = notifier.load(orgId: 'A');
        final loadB = notifier.load(orgId: 'B');

        // The newer workspace answers first.
        repository.usageGates['B']!.complete(
          const CreditUsage(
            balance: 200,
            totalPurchased: 200,
            totalConsumed: 0,
          ),
        );
        await loadB;
        expect(container.read(creditsNotifierProvider).usage.balance, 200);

        // The older one answers late: its result must be dropped.
        repository.usageGates['A']!.complete(
          const CreditUsage(
            balance: 100,
            totalPurchased: 100,
            totalConsumed: 0,
          ),
        );
        await loadA;

        expect(
          container.read(creditsNotifierProvider).usage.balance,
          200,
          reason: 'the stale A=100 response must not replace B=200',
        );
      },
    );

    test('the latest load still applies when it finishes last', () async {
      repository.usageGates['A'] = Completer<CreditUsage>();
      repository.usageGates['B'] = Completer<CreditUsage>();

      final loadA = notifier.load(orgId: 'A');
      final loadB = notifier.load(orgId: 'B');

      repository.usageGates['A']!.complete(
        const CreditUsage(balance: 100, totalPurchased: 100, totalConsumed: 0),
      );
      await loadA;
      repository.usageGates['B']!.complete(
        const CreditUsage(balance: 200, totalPurchased: 200, totalConsumed: 0),
      );
      await loadB;

      expect(container.read(creditsNotifierProvider).usage.balance, 200);
    });

    test('an empty orgId is ignored', () async {
      await notifier.load(orgId: '');
      await notifier.load();

      expect(
        container.read(creditsNotifierProvider).status,
        CreditsStatus.initial,
      );
    });
  });
}
