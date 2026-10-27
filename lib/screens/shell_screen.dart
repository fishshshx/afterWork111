import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  static const _tabs = [
    _TabItem(label: '今天', icon: Icons.today, path: '/today'),
    _TabItem(label: '计划', icon: Icons.calendar_today, path: '/plans'),
    _TabItem(label: '记录', icon: Icons.timeline, path: '/records'),
    _TabItem(label: '打卡', icon: Icons.check_circle_outline, path: '/check-ins'),
    _TabItem(label: '统计', icon: Icons.pie_chart_outline, path: '/stats'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((tab) => tab.path == location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_tabs[index].path);
        },
        destinations:
            _tabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final String path;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}
