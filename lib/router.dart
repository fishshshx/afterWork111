import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/categories_screen.dart';
import 'screens/check_in_item_edit_screen.dart';
import 'screens/check_in_manage_screen.dart';
import 'screens/check_ins_screen.dart';
import 'screens/plan_edit_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/record_edit_screen.dart';
import 'screens/record_from_plan_screen.dart';
import 'screens/records_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/today_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/today',
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) {
        return ShellScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
        GoRoute(
          path: '/plans',
          builder: (context, state) => const PlansScreen(),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const RecordsScreen(),
        ),
        GoRoute(
          path: '/check-ins',
          builder: (context, state) => const CheckInsScreen(),
        ),
        GoRoute(
          path: '/stats',
          builder: (context, state) => const StatsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/categories',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/plans/add',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PlanEditScreen(),
    ),
    GoRoute(
      path: '/plans/edit',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
        return PlanEditScreen(planId: id);
      },
    ),
    GoRoute(
      path: '/plans/complete',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(
            body: Center(child: Text('缺少计划 ID')),
          );
        }
        return RecordFromPlanScreen(planId: id);
      },
    ),
    GoRoute(
      path: '/records/add',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const RecordEditScreen(),
    ),
    GoRoute(
      path: '/records/edit',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
        return RecordEditScreen(recordId: id);
      },
    ),
    GoRoute(
      path: '/check-ins/manage',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const CheckInManageScreen(),
    ),
    GoRoute(
      path: '/check-ins/edit',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
        return CheckInItemEditScreen(itemId: id);
      },
    ),
  ],
);
