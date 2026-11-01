import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'slice_email_parser.dart';

class SmsSyncResult {
  const SmsSyncResult({
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

/// 100% on-device SMS sync service to read and parse Indian bank & UPI transaction alerts directly.
class SmsSyncService {
  const SmsSyncService();

  static const _channel = MethodChannel('app.pocket.pocket/sms');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<SmsSyncResult> syncSms({
    required Future<bool> Function(String messageId) isAlreadyProcessed,
    int days = 45,
  }) async {
    if (!isSupported) {
      return const SmsSyncResult(
        success: false,
        errorMessage: 'SMS auto-sync is only available on Android devices.',
      );
    }

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      return const SmsSyncResult(
        success: false,
        errorMessage: 'SMS permission not granted. Please allow SMS permission in Settings.',
      );
    }

    try {
      final sinceMs = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
      final rawList = await _channel.invokeMethod<List<dynamic>>('readSms', {
        'sinceMs': sinceMs,
        'limit': 300,
      });

      if (rawList == null || rawList.isEmpty) {
        return const SmsSyncResult(success: true, newCount: 0);
      }

      final parsedList = <ParsedEmailTransaction>[];

      for (final item in rawList) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        final address = item['address']?.toString() ?? '';
        final body = item['body']?.toString() ?? '';
        final dateMs = item['date'] is int
            ? item['date'] as int
            : int.tryParse(item['date']?.toString() ?? '') ?? 0;

        if (id.isEmpty || body.isEmpty) continue;

        final messageId = 'sms-$id';
        if (await isAlreadyProcessed(messageId)) {
          continue;
        }

        final lowerBody = body.toLowerCase();

        // Fast-filter: Ignore authentication OTPs and 2FA codes
        final isOtp = (lowerBody.contains('otp') ||
                lowerBody.contains('one time password') ||
                lowerBody.contains('verification code') ||
                lowerBody.contains('security code')) &&
            !lowerBody.contains('debited') &&
            !lowerBody.contains('credited') &&
            !lowerBody.contains('successfully');
        if (isOtp) {
          continue;
        }

        final hasTransactionKeyword = lowerBody.contains('debited') ||
            lowerBody.contains('debit') ||
            lowerBody.contains('dr') ||
            lowerBody.contains('spent') ||
            lowerBody.contains('credited') ||
            lowerBody.contains('credit') ||
            lowerBody.contains('cr') ||
            lowerBody.contains('paid') ||
            lowerBody.contains('payment') ||
            lowerBody.contains('sent') ||
            lowerBody.contains('transferred') ||
            lowerBody.contains('transfer') ||
            lowerBody.contains('trf') ||
            lowerBody.contains('withdrawn') ||
            lowerBody.contains('refund') ||
            lowerBody.contains('received') ||
            lowerBody.contains('purchase') ||
            lowerBody.contains('charged');

        final hasCurrencyKeyword = lowerBody.contains('rs') ||
            lowerBody.contains('inr') ||
            body.contains('₹') ||
            RegExp(r'\b(?:debited|credited|trf|paid|sent|withdrawn)\s+(?:by|for|of|with)?\s*[\d,]+(?:\.\d{1,2})?\b', caseSensitive: false).hasMatch(body);

        if (!hasTransactionKeyword || !hasCurrencyKeyword) {
          continue;
        }

        final emailDate = dateMs > 0 ? DateTime.fromMillisecondsSinceEpoch(dateMs) : DateTime.now();

        final parsed = BankEmailParser.parse(
          subject: address,
          bodyText: body,
          emailDate: emailDate,
          messageId: messageId,
        );

        if (parsed != null) {
          parsedList.add(parsed);
        }
      }

      return SmsSyncResult(
        success: true,
        newCount: parsedList.length,
        transactions: parsedList,
      );
    } catch (e) {
      return SmsSyncResult(
        success: false,
        errorMessage: 'SMS sync error: $e',
      );
    }
  }
}
