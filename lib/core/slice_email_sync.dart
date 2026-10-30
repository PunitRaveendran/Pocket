import 'package:enough_mail/enough_mail.dart';
import 'slice_email_parser.dart';

class SliceSyncResult {
  const SliceSyncResult({
    required this.success,
    this.newCount = 0,
    this.errorMessage,
    this.transactions = const [],
  });

  final bool success;
  final int newCount;
  final String? errorMessage;
  final List<ParsedEmailTransaction> transactions;
}

/// On-device IMAP sync service to fetch and parse Slice Bank transaction emails.
class SliceEmailSyncService {
  const SliceEmailSyncService();

  Future<SliceSyncResult> sync({
    required String email,
    required String appPassword,
    String sender = 'noreply@slice.bank.in',
    required Future<bool> Function(String messageId) isAlreadyProcessed,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = appPassword.replaceAll(' ', '').trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return const SliceSyncResult(
        success: false,
        errorMessage: 'Email or Google App Password is empty.',
      );
    }

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      try {
        await client.login(cleanEmail, cleanPassword);
      } catch (loginError) {
        return SliceSyncResult(
          success: false,
          errorMessage: 'Login failed: Invalid email or App Password ($loginError)',
        );
      }

      await client.selectInbox();

      // Optimize: Only search messages from past 45 days to avoid downloading months of old emails
      final sinceDate = DateTime.now().subtract(const Duration(days: 45));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedSince = '${sinceDate.day}-${months[sinceDate.month - 1]}-${sinceDate.year}';

      final searchRes = await client.searchMessages(
        searchCriteria: 'FROM "$sender" SINCE $formattedSince',
      );

      var seq = searchRes.matchingSequence;
      if (seq == null || seq.isEmpty) {
        // Fallback: search for any email with 'slice' in FROM in case subdomain differed
        try {
          final fallbackRes = await client.searchMessages(
            searchCriteria: 'FROM "slice" SINCE $formattedSince',
          );
          seq = fallbackRes.matchingSequence;
        } catch (_) {}
      }

      if (seq == null || seq.isEmpty) {
        return const SliceSyncResult(success: true, newCount: 0);
      }

      // Fetch the messages content
      final fetchRes = await client.fetchMessages(
        seq,
        'BODY.PEEK[]',
      );

      final parsedList = <ParsedEmailTransaction>[];

      for (final msg in fetchRes.messages) {
        final rawId = msg.getHeaderValue('Message-ID') ?? msg.uid?.toString();
        final messageId = rawId?.trim();

        if (messageId != null && messageId.isNotEmpty) {
          if (await isAlreadyProcessed(messageId)) {
            continue;
          }
        }

        final subject = msg.decodeSubject() ?? '';
        final bodyText = msg.decodeContentText() ?? '';
        final date = msg.decodeDate();

        final parsed = SliceEmailParser.parse(
          subject: subject,
          bodyText: bodyText,
          emailDate: date,
          messageId: messageId,
        );

        if (parsed != null) {
          parsedList.add(parsed);
        }
      }

      return SliceSyncResult(
        success: true,
        newCount: parsedList.length,
        transactions: parsedList,
      );
    } catch (e) {
      return SliceSyncResult(
        success: false,
        errorMessage: 'Sync error: $e',
      );
    } finally {
      if (client.isLoggedIn) {
        try {
          await client.logout();
        } catch (_) {}
      }
    }
  }
}
