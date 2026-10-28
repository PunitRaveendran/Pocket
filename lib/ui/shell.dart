import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/copy.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'insights/insights_screen.dart';
import 'outings/outings_screen.dart';
import 'settings/settings_screen.dart';
import 'today/today_screen.dart';
import 'widgets/hairline.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _titles = [Copy.today, Copy.outings, Copy.insights];

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: Copy.settings,
            onPressed: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, _, _) => const SettingsScreen(),
                  transitionsBuilder: (context, anim, _, child) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                  transitionDuration: Motion.normal,
                ),
              );
            },
            icon: Icon(Icons.tune, color: t.inkSoft, size: 22),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayScreen(),
          OutingsScreen(),
          InsightsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
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
            },
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.today_outlined, color: t.inkSoft),
                selectedIcon: Icon(Icons.today_outlined, color: t.accent),
                label: Copy.today,
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_walk_outlined, color: t.inkSoft),
                selectedIcon: Icon(Icons.directions_walk_outlined, color: t.accent),
                label: Copy.outings,
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: t.inkSoft),
                selectedIcon: Icon(Icons.bar_chart_outlined, color: t.accent),
                label: Copy.insights,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
