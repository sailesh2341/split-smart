import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/expenses/add_expense_screen.dart';
import '../features/expenses/expense_detail_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/groups/group_expenses_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/requests/requests_screen.dart';
import '../features/auth/state/auth_controller.dart';
import '../models/app_group.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = authState.value ?? false;
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/requests', builder: (_, __) => const RequestsScreen()),
      GoRoute(
        path: '/group',
        builder: (_, state) {
          return GroupExpensesScreen(group: state.extra as AppGroup);
        },
      ),
      GoRoute(
        path: '/add-expense',
        builder: (_, state) {
          return AddExpenseScreen(group: state.extra as AppGroup);
        },
      ),
      GoRoute(
        path: '/expense',
        builder: (_, state) {
          return ExpenseDetailScreen(args: state.extra as ExpenseDetailArgs);
        },
      ),
    ],
  );
});
