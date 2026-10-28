import 'package:home_widget/home_widget.dart';

import '../data/models.dart';
import '../state/ledger.dart';
import 'dates.dart';
import 'money.dart';

class GlanceWidgetService {
  const GlanceWidgetService._();

  static const String androidWidgetName = 'GlanceWidgetProvider';

  static Future<void> update(Ledger ledger) async {
    try {
      if (ledger.settings.isVacationMode) {
        await HomeWidget.saveWidgetData<String>('amount_text', '🌴 Vacation Break');
        await HomeWidget.saveWidgetData<String>('caption_text', 'Pacing paused while at home');
        await HomeWidget.saveWidgetData<int>('progress_percent', 0);
        await HomeWidget.updateWidget(
          name: androidWidgetName,
          androidName: androidWidgetName,
        );
        return;
      }

      final today = LocalDate.today();
      final todayView = buildToday(ledger, date: today);
      final remaining = todayView.budget.remaining;
      final allowance = todayView.budget.allowancePaise;

      final amountText = remaining < 0
          ? '${Money.formatPaise(remaining.abs())} over today'
          : '${Money.formatPaise(remaining)} left today';

      final captionText = 'Daily Target: ${Money.formatPaise(allowance)}';
      final progressPercent = allowance > 0
          ? ((todayView.budget.netSpent / allowance) * 100).round().clamp(0, 100)
          : 0;

      await HomeWidget.saveWidgetData<String>('amount_text', amountText);
      await HomeWidget.saveWidgetData<String>('caption_text', captionText);
      await HomeWidget.saveWidgetData<int>('progress_percent', progressPercent);

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (_) {
      // Safe no-op on platforms without home_widget support or widget not pinned
    }
  }
}
