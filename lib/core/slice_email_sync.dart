import 'package:enough_mail/enough_mail.dart';
import 'slice_email_parser.dart';
export 'slice_email_parser.dart';

class BankSyncResult {
  const BankSyncResult({
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

typedef SliceSyncResult = BankSyncResult;

/// On-device IMAP sync service to fetch and parse bank and UPI transaction emails
/// (Slice, HDFC, SBI, ICICI, Axis, Kotak, Jupiter/Fi, Federal Bank, etc.).
class BankEmailSyncService {
  const BankEmailSyncService();

  Future<BankSyncResult> sync({
    required String email,
    required String appPassword,
    String sender = 'noreply@slice.bank.in',
    required Future<bool> Function(String messageId) isAlreadyProcessed,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = appPassword.replaceAll(' ', '').trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return const BankSyncResult(
        success: false,
        errorMessage: 'Email or Google App Password is empty.',
      );
    }

    final rawSenders = sender
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final senders = rawSenders.isEmpty ? BankPresets.allSenders : rawSenders;

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      try {
        await client.login(cleanEmail, cleanPassword);
      } catch (loginError) {
        return BankSyncResult(
          success: false,
          errorMessage: 'Login failed: Invalid email or App Password ($loginError)',
        );
      }

      await client.selectInbox();

      // Optimize: Only search messages from past 45 days to avoid downloading months of old emails
      final sinceDate = DateTime.now().subtract(const Duration(days: 45));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedSince = '${sinceDate.day}-${months[sinceDate.month - 1]}-${sinceDate.year}';

      final parsedList = <ParsedEmailTransaction>[];
      final seenMessageIds = <String>{};

      for (final s in senders) {
        try {
          final searchRes = await client.searchMessages(
            searchCriteria: 'FROM "$s" SINCE $formattedSince',
          );

          var seq = searchRes.matchingSequence;
          if (seq == null || seq.isEmpty) {
            // Fallback for banks where subdomain might vary (e.g. 'slice', 'hdfcbank', etc.)
            final domainKeyword = s.contains('@') ? s.split('@').last.split('.').first : s;
            if (domainKeyword.length >= 4) {
              try {
                final fallbackRes = await client.searchMessages(
                  searchCriteria: 'FROM "$domainKeyword" SINCE $formattedSince',
                );
                seq = fallbackRes.matchingSequence;
              } catch (_) {}
            }
          }

          if (seq == null || seq.isEmpty) {
            continue;
          }

          final fetchRes = await client.fetchMessages(
            seq,
            'BODY.PEEK[]',
          );

          for (final msg in fetchRes.messages) {
            final rawId = msg.getHeaderValue('Message-ID') ?? msg.uid?.toString();
            final messageId = rawId?.trim();

            if (messageId != null && messageId.isNotEmpty) {
              if (seenMessageIds.contains(messageId) || await isAlreadyProcessed(messageId)) {
                continue;
              }
              seenMessageIds.add(messageId);
            }

            final subject = msg.decodeSubject() ?? '';
            final plainText = msg.decodeTextPlainPart();
            final htmlText = msg.decodeTextHtmlPart();
            final rawText = msg.decodeContentText();
            final bodyText = (plainText != null && plainText.trim().isNotEmpty)
                ? plainText
                : (htmlText != null && htmlText.trim().isNotEmpty)
                    ? htmlText
                    : (rawText ?? '');
            final date = msg.decodeDate();

            final parsed = BankEmailParser.parse(
              subject: subject,
              bodyText: bodyText,
              emailDate: date,
              messageId: messageId,
            );

            if (parsed != null) {
              parsedList.add(parsed);
            }
          }
        } catch (_) {
          // If searching or fetching for one bank sender fails, proceed to next
        }
      }

      return BankSyncResult(
        success: true,
        newCount: parsedList.length,
        transactions: parsedList,
      );
    } catch (e) {
      return BankSyncResult(
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

  /// Archives an email from Gmail INBOX by Message-ID.
  /// Moves the message from INBOX to All Mail (or removes the \Inbox label).
  Future<bool> archiveEmail({
    required String email,
    required String appPassword,
    required String messageId,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = appPassword.replaceAll(' ', '').trim();
    final cleanId = messageId.replaceAll(RegExp(r'[<>]'), '').trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty || cleanId.isEmpty) {
      return false;
    }

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      await client.login(cleanEmail, cleanPassword);
      await client.selectInbox();

      // Search for the specific email by Message-ID
      var searchRes = await client.searchMessages(
        searchCriteria: 'HEADER Message-ID "$cleanId"',
      );
      var seq = searchRes.matchingSequence;

      if (seq == null || seq.isEmpty) {
        searchRes = await client.searchMessages(
          searchCriteria: 'HEADER Message-ID "<$cleanId>"',
        );
        seq = searchRes.matchingSequence;
      }

      if (seq == null || seq.isEmpty) {
        return false;
      }

      // Try finding All Mail box first
      final mailboxes = await client.listMailboxes();
      Mailbox? allMail;
      for (final m in mailboxes) {
        if (m.hasFlag(MailboxFlag.all) ||
            m.hasFlag(MailboxFlag.archive) ||
            m.path == '[Gmail]/All Mail' ||
            m.path == '[Google Mail]/All Mail') {
          allMail = m;
          break;
        }
      }

      var moved = false;
      if (allMail != null) {
        try {
          await client.move(seq, targetMailbox: allMail);
          moved = true;
        } catch (_) {}
      }

      if (!moved) {
        // In Gmail IMAP, marking deleted in INBOX and expunging removes the \Inbox label (archives it)
        await client.markDeleted(seq);
        await client.expunge();
      }

      return true;
    } catch (_) {
      return false;
    } finally {
      if (client.isLoggedIn) {
        try {
          await client.logout();
        } catch (_) {}
      }
    }
  }
}

typedef SliceEmailSyncService = BankEmailSyncService;
