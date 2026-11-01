import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/copy.dart';
import '../state/ledger.dart';
import '../theme/app_theme.dart';
import 'outings/outings_screen.dart';
import 'settings/settings_screen.dart';
import 'sheets/pending_inbox_sheet.dart';
import 'splits/splits_screen.dart';
import 'today/today_screen.dart';
import 'widgets/hairline.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _lastSyncAttempt;
  late final PageController _pageController;

  static const _titles = [Copy.today, Copy.splits, Copy.outings, Copy.settings];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoSync(force: true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAutoSync();
    }
  }

  void _checkAutoSync({bool force = false}) {
    final ledger = ref.read(ledgerProvider).valueOrNull;
    if (ledger == null) return;
    final s = ledger.settings;
    final hasEmail = s.emailSyncEnabled &&
        s.emailSyncAddress.trim().isNotEmpty &&
        s.emailSyncAppPassword.trim().isNotEmpty;
    final hasSms = s.smsSyncEnabled;

    if (!hasEmail && !hasSms) {
      return;
    }

    final now = DateTime.now();
    // Throttle auto-sync to once every 30 seconds when returning from background
    if (!force && _lastSyncAttempt != null && now.difference(_lastSyncAttempt!).inSeconds < 30) {
      return;
    }
    _lastSyncAttempt = now;
    ref.read(ledgerProvider.notifier).syncAllBankTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final pendingCount = ref.watch(
      ledgerProvider.select((a) => a.valueOrNull?.pendingInbox.length ?? 0),
    );

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(_titles[_index]),
        actions: [
          if (pendingCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: '$pendingCount pending Slice transaction${pendingCount > 1 ? "s" : ""}',
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      showPendingInboxSheet(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: t.accentTint,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: t.accent.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 14,
                            color: t.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$pendingCount new',
                            style: TypeScale.caption(t.accent).copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_index != 3)
            IconButton(
              tooltip: Copy.settings,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _index = 3);
                _pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              },
              icon: Icon(Icons.tune, color: t.inkSoft, size: 22),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        children: const [
          TodayScreen(),
          SplitsScreen(),
          OutingsScreen(),
          SettingsScreen(isTab: true),
        ],
      ),
      bottomNavigationBar: Container(
        color: t.paper,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Hairline(),
              NavigationBar(
                selectedIndex: _index,
                height: 64,
                backgroundColor: t.paper,
                indicatorColor: t.accentTint,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                },
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.today_outlined, color: t.inkSoft),
                    selectedIcon: Icon(Icons.today_outlined, color: t.accent),
                    label: Copy.today,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.group_outlined, color: t.inkSoft),
                    selectedIcon: Icon(Icons.group_outlined, color: t.accent),
                    label: Copy.splits,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_walk_outlined, color: t.inkSoft),
                    selectedIcon: Icon(Icons.directions_walk_outlined, color: t.accent),
                    label: Copy.outings,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_outlined, color: t.inkSoft),
                    selectedIcon: Icon(Icons.tune_outlined, color: t.accent),
                    label: Copy.settings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
