import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/slice_email_sync.dart';
import 'package:pocket/core/sms_sync_service.dart';
import 'package:pocket/data/database.dart';
import 'package:pocket/data/repository.dart';
import 'package:pocket/state/ledger.dart';
import 'package:pocket/theme/app_theme.dart';
import 'package:pocket/theme/tokens.dart';
import 'package:pocket/ui/onboarding/onboarding_screen.dart';

class FakeBankEmailSyncService extends BankEmailSyncService {
  const FakeBankEmailSyncService();

  @override
  Future<BankSyncResult> sync({
    required String email,
    required String appPassword,
    String sender = 'noreply@slice.bank.in',
    required Future<bool> Function(String messageId) isAlreadyProcessed,
  }) async {
    return const BankSyncResult(success: true, newCount: 0);
  }
}

class FakeSmsSyncService extends SmsSyncService {
  const FakeSmsSyncService();

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<SmsSyncResult> syncSms({
    int days = 14,
    required Future<bool> Function(String messageId) isAlreadyProcessed,
  }) async {
    return const SmsSyncResult(success: true, newCount: 0);
  }
}

void main() {
  Widget createOnboardingWidget({required PocketRepository repo}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        emailSyncServiceProvider.overrideWithValue(const FakeBankEmailSyncService()),
        smsSyncServiceProvider.overrideWithValue(const FakeSmsSyncService()),
      ],
      child: TokenScope(
        tokens: PaperTokens.dark,
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
  }

  group('OnboardingScreen Flow Tests', () {
    late PocketRepository inMemoryRepo;

    setUp(() {
      inMemoryRepo = PocketRepository(PocketDatabase.instance, inMemory: true);
    });

    testWidgets('Completes onboarding by turning off SMS sync and skipping', (tester) async {
      await tester.pumpWidget(createOnboardingWidget(repo: inMemoryRepo));
      await tester.pumpAndSettle();

      // Step 0: Stipend
      expect(find.text('How much lands each month?'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 1: Cycle Start Day
      expect(find.text('When does your month start?'), findsOneWidget);
      expect(find.text('1st'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Auto-detect bank & UPI spends?
      expect(find.text('Auto-detect bank & UPI spends?'), findsOneWidget);
      expect(find.text('Direct SMS Auto-Sync'), findsOneWidget);
      expect(find.text('Bank Email Auto-Sync'), findsOneWidget);

      // Turn off SMS sync switch (index 0)
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Since both SMS and Email are off, button shows 'Skip for now'
      expect(find.text('Skip for now'), findsOneWidget);

      // Tap Skip for now
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // Step 3: Outings explanation
      expect(find.text('Days and nights out stay apart.'), findsOneWidget);
      expect(find.text('Open the ledger'), findsOneWidget);

      // Finish onboarding
      await tester.tap(find.text('Open the ledger'));
      await tester.pumpAndSettle();

      final ledger = await inMemoryRepo.load();
      expect(ledger.settings.onboarded, isTrue);
      expect(ledger.settings.smsSyncEnabled, isFalse);
      expect(ledger.settings.emailSyncEnabled, isFalse);
    });

    testWidgets('Completes onboarding with Direct SMS Auto-Sync enabled', (tester) async {
      await tester.pumpWidget(createOnboardingWidget(repo: inMemoryRepo));
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: SMS sync is enabled by default
      expect(find.text('Direct SMS Auto-Sync'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to proceed with SMS sync enabled
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 3: Outings explanation
      expect(find.text('Days and nights out stay apart.'), findsOneWidget);
      await tester.tap(find.text('Open the ledger'));
      await tester.pumpAndSettle();

      final ledger = await inMemoryRepo.load();
      expect(ledger.settings.onboarded, isTrue);
      expect(ledger.settings.smsSyncEnabled, isTrue);
      expect(ledger.settings.emailSyncEnabled, isFalse);
    });

    testWidgets('Completes onboarding with bank email credentials configured', (tester) async {
      await tester.pumpWidget(createOnboardingWidget(repo: inMemoryRepo));
      await tester.pumpAndSettle();

      // Advance Step 0 -> Step 1 -> Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Step 2: Auto-detect bank & UPI spends?
      expect(find.text('Auto-detect bank & UPI spends?'), findsOneWidget);

      // Toggle Email switch ON (switch at index 1)
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Verify fields appear
      expect(find.text('Gmail address'), findsOneWidget);
      expect(find.text('Google App Password'), findsOneWidget);
      expect(find.text('Slice'), findsOneWidget);
      expect(find.text('HDFC'), findsOneWidget);
      expect(find.text('SBI'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Enter email and password
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3)); // email, password, and sender textfield
      await tester.enterText(textFields.at(0), 'student@gmail.com');
      await tester.enterText(textFields.at(1), 'abcd efgh ijkl mnop');
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Days and nights out stay apart.'), findsOneWidget);

      // Finish onboarding
      await tester.tap(find.text('Open the ledger'));
      await tester.pumpAndSettle();

      final ledger = await inMemoryRepo.load();
      expect(ledger.settings.onboarded, isTrue);
      expect(ledger.settings.emailSyncEnabled, isTrue);
      expect(ledger.settings.emailSyncAddress, 'student@gmail.com');
      expect(ledger.settings.emailSyncAppPassword, 'abcd efgh ijkl mnop');
      expect(ledger.settings.emailSyncSender, contains('slice.bank.in'));
      expect(ledger.settings.emailSyncSender, contains('hdfcbank.net'));
    });

    testWidgets('Tapping "How to create?" opens App Password guide sheet', (tester) async {
      await tester.pumpWidget(createOnboardingWidget(repo: inMemoryRepo));
      await tester.pumpAndSettle();

      // Advance to Step 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Toggle Email switch ON (switch at index 1)
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      // Find and tap "How to create?"
      expect(find.text('How to create?'), findsOneWidget);
      await tester.ensureVisible(find.text('How to create?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How to create?'));
      await tester.pumpAndSettle();

      // Verify guide sheet is visible
      expect(find.text('Google App Password Guide'), findsOneWidget);
      expect(find.text('Turn on 2-Step Verification'), findsOneWidget);
      expect(find.text('Open Google App Passwords'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Close guide sheet
      await tester.ensureVisible(find.text('Got it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Google App Password Guide'), findsNothing);
    });
  });
}
