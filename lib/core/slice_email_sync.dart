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
  const BankEmailSyncService({
    this.imapHost = 'imap.gmail.com',
    this.imapPort = 993,
    this.isSecure = true,
  });

  final String imapHost;
  final int imapPort;
  final bool isSecure;

  /// Builds an IMAP search criteria string with nested OR expressions for multiple senders.
  /// Example: OR FROM "a" FROM "b" SINCE 01-Nov-2026
  static String buildImapSearchCriteria(List<String> senders, String formattedSince) {
    final cleanSenders = senders
        .map((s) => s.startsWith('@') ? s.substring(1).trim() : s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (cleanSenders.isEmpty) {
      return 'SINCE $formattedSince';
    }
    if (cleanSenders.length == 1) {
      return 'FROM "${cleanSenders.first}" SINCE $formattedSince';
    }
    var query = 'FROM "${cleanSenders.last}"';
    for (var i = cleanSenders.length - 2; i >= 0; i--) {
      query = 'OR FROM "${cleanSenders[i]}" $query';
    }
    return '$query SINCE $formattedSince';
  }

  Future<BankSyncResult> sync({
    required String email,
    required String appPassword,
    List<String>? activeSenders,
    String? sender,
    DateTime? lastSyncedAt,
    bool fullResync = false,
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

    final List<String> senders;
    if (activeSenders != null && activeSenders.isNotEmpty) {
      senders = activeSenders.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else if (sender != null && sender.trim().isNotEmpty) {
      final raw = sender
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      senders = raw.isNotEmpty ? raw : BankPresets.slice.senders;
    } else {
      senders = BankPresets.slice.senders;
    }

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(imapHost, imapPort, isSecure: isSecure);
      try {
        await client.login(cleanEmail, cleanPassword);
      } catch (loginError) {
        return BankSyncResult(
          success: false,
          errorMessage: 'Login failed: Invalid email or App Password ($loginError)',
        );
      }

      await client.selectInbox();

      // Incremental Sync Optimization:
      // If we have synced previously and this is not a forced full-resync,
      // search only from 2 days prior to last sync (48h safety buffer for timezones/delays).
      // Otherwise, look back 45 days.
      final DateTime sinceDate;
      if (!fullResync && lastSyncedAt != null) {
        sinceDate = lastSyncedAt.subtract(const Duration(days: 2));
      } else {
        sinceDate = DateTime.now().subtract(const Duration(days: 45));
      }
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formattedSince = '${sinceDate.day.toString().padLeft(2, '0')}-${months[sinceDate.month - 1]}-${sinceDate.year}';

      final parsedList = <ParsedEmailTransaction>[];
      final seenMessageIds = <String>{};

      final combinedSeq = MessageSequence();
      var usedCombinedSearch = false;

      // Try fast combined query if there are multiple senders (up to 8 in single round trip)
      if (senders.length > 1 && senders.length <= 8) {
        try {
          final criteria = buildImapSearchCriteria(senders, formattedSince);
          final searchRes = await client.searchMessages(searchCriteria: criteria);
          final seq = searchRes.matchingSequence;
          if (seq != null && seq.isNotEmpty) {
            combinedSeq.addList(seq.toList());
          }
          usedCombinedSearch = true;
        } catch (_) {
          // If combined search fails on this IMAP server, fall back cleanly to individual searches
          usedCombinedSearch = false;
        }
      }

      if (!usedCombinedSearch) {
        for (final rawS in senders) {
          final s = rawS.startsWith('@') ? rawS.substring(1).trim() : rawS;
          if (s.isEmpty) continue;
          try {
            final searchRes = await client.searchMessages(
              searchCriteria: 'FROM "$s" SINCE $formattedSince',
            );

            var seq = searchRes.matchingSequence;
            if (seq == null || seq.isEmpty) {
              // Fallback for banks where subdomain might vary (e.g. 'slice', 'hdfcbank', etc.)
              final domainKeyword = s.contains('@') ? s.split('@').last.split('.').first : s.split('.').first;
              if (domainKeyword.length >= 3 && domainKeyword != s) {
                try {
                  final fallbackRes = await client.searchMessages(
                    searchCriteria: 'FROM "$domainKeyword" SINCE $formattedSince',
                  );
                  seq = fallbackRes.matchingSequence;
                } catch (_) {}
              }
            }

            if (seq != null && seq.isNotEmpty) {
              combinedSeq.addList(seq.toList());
            }
          } catch (_) {
            // If searching for one bank sender fails, proceed to next
          }
        }
      }

      if (combinedSeq.isEmpty) {
        return BankSyncResult(
          success: true,
          newCount: 0,
          transactions: parsedList,
        );
      }

      // Performance Optimization: Fetch lightweight headers first to filter already-processed
      // emails before downloading full message bodies over the network.
      final headerRes = await client.fetchMessages(
        combinedSeq,
        '(UID ENVELOPE)',
      );

      final unprocessedSeq = MessageSequence();
      final messageIdBySeqId = <int, String>{};

      for (final msg in headerRes.messages) {
        final rawId = msg.envelope?.messageId ??
            msg.getHeaderValue('Message-ID') ??
            msg.getHeaderValue('message-id') ??
            msg.uid?.toString();
        final messageId = rawId?.trim();
        final seqId = msg.sequenceId;

        if (messageId != null && messageId.isNotEmpty) {
          if (seenMessageIds.contains(messageId) || await isAlreadyProcessed(messageId)) {
            continue;
          }
          seenMessageIds.add(messageId);
          if (seqId != null) {
            unprocessedSeq.add(seqId);
            messageIdBySeqId[seqId] = messageId;
          }
        } else if (seqId != null) {
          unprocessedSeq.add(seqId);
        }
      }

      if (unprocessedSeq.isEmpty) {
        return BankSyncResult(
          success: true,
          newCount: 0,
          transactions: parsedList,
        );
      }

      final fetchRes = await client.fetchMessages(
        unprocessedSeq,
        'BODY.PEEK[]',
      );

      for (final msg in fetchRes.messages) {
        final seqId = msg.sequenceId;
        final messageId = (seqId != null ? messageIdBySeqId[seqId] : null) ??
            msg.envelope?.messageId ??
            msg.getHeaderValue('Message-ID')?.trim() ??
            msg.getHeaderValue('message-id')?.trim() ??
            msg.uid?.toString();

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
      if (client.isConnected) {
        try {
          await client.disconnect();
        } catch (_) {}
      }
    }
  }

  /// Moves a processed email from Gmail INBOX to a Gmail label (defaulting to "Slice").
  /// In Gmail IMAP, moving/copying a message to a label mailbox applies the label and removes it from INBOX.
  Future<bool> moveEmailToLabel({
    required String email,
    required String appPassword,
    required String messageId,
    String label = 'Slice',
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = appPassword.replaceAll(' ', '').trim();
    final cleanId = messageId.replaceAll(RegExp(r'[<>]'), '').trim();
    final targetLabel = label.trim().isEmpty ? 'Slice' : label.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty || cleanId.isEmpty) {
      return false;
    }

    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(imapHost, imapPort, isSecure: isSecure);
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

      // Check existing mailboxes to locate the target label
      final mailboxes = await client.listMailboxes();
      Mailbox? targetMailbox;
      final cleanLabelLower = targetLabel.toLowerCase();
      for (final m in mailboxes) {
        if (m.name.toLowerCase() == cleanLabelLower ||
            m.path.toLowerCase() == cleanLabelLower ||
            m.path.toLowerCase().endsWith('/$cleanLabelLower')) {
          targetMailbox = m;
          break;
        }
      }

      // If the label mailbox does not exist yet, try creating it in Gmail
      if (targetMailbox == null) {
        try {
          targetMailbox = await client.createMailbox(targetLabel);
        } catch (_) {}
      }

      var moved = false;
      try {
        if (targetMailbox != null) {
          await client.move(seq, targetMailbox: targetMailbox);
        } else {
          await client.move(seq, targetMailboxPath: targetLabel);
        }
        moved = true;
      } catch (_) {
        // Fallback: copy to label mailbox, then remove from INBOX (markDeleted & expunge)
        try {
          if (targetMailbox != null) {
            await client.copy(seq, targetMailbox: targetMailbox);
          } else {
            await client.copy(seq, targetMailboxPath: targetLabel);
          }
          await client.markDeleted(seq);
          await client.expunge();
          moved = true;
        } catch (_) {}
      }

      if (!moved) {
        // Fallback to All Mail / archive if moving to label failed
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
        if (allMail != null) {
          try {
            await client.move(seq, targetMailbox: allMail);
            moved = true;
          } catch (_) {}
        }
        if (!moved) {
          await client.markDeleted(seq);
          await client.expunge();
        }
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
      if (client.isConnected) {
        try {
          await client.disconnect();
        } catch (_) {}
      }
    }
  }

  /// Archives/labels an email from Gmail INBOX by Message-ID.
  Future<bool> archiveEmail({
    required String email,
    required String appPassword,
    required String messageId,
    String label = 'Slice',
  }) => moveEmailToLabel(
    email: email,
    appPassword: appPassword,
    messageId: messageId,
    label: label,
  );
}

typedef SliceEmailSyncService = BankEmailSyncService;
