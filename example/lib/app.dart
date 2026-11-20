import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state/switchable_state.dart';

import 'starred/starred_page.dart';
import 'state_management/state_management.dart';
import 'state_management/state_management_page.dart';
import 'transactions/transactions.dart';
import 'transactions/transactions_page.dart';

/// The app's route paths.
abstract final class AppRoutes {
  static const stateManagement = '/';
  static const transactions = '/transactions';
  static const starred = '/starred';
}

/// Starts on the state-management choice. The chosen adapter is registered in
/// [services], and a `StateScope` built from it wraps every screen that reads
/// state. Going back to the choice disposes that scope and its stores.
final class TransactionsApp extends StatefulWidget {
  const TransactionsApp({
    super.key,
    required this.services,
    required this.load,
  });

  final GetIt services;
  final LoadTransactions load;

  @override
  State<TransactionsApp> createState() => _TransactionsAppState();
}

final class _TransactionsAppState extends State<TransactionsApp> {
  // One router for the app's lifetime, so an ordinary rebuild keeps the
  // navigation stack and every mounted route's state.
  late final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.stateManagement,
    // Screens below the shell need an adapter; without a choice, go pick one.
    redirect: (context, state) =>
        state.matchedLocation != AppRoutes.stateManagement &&
            !widget.services.isRegistered<StateAdapter>()
        ? AppRoutes.stateManagement
        : null,
    routes: [
      GoRoute(
        path: AppRoutes.stateManagement,
        builder: (context, state) => StateManagementPage(
          onSelected: (option) {
            selectStateManagement(widget.services, option);
            context.go(AppRoutes.transactions);
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final option = selectedStateManagement(widget.services)!;
          return StateScope(
            // A different choice gets a new scope, so stores start over.
            key: ObjectKey(option.adapter),
            adapter: widget.services<StateAdapter>(),
            child: _StateManagementBar(
              option: option,
              onChange: () => context.go(AppRoutes.stateManagement),
              child: child,
            ),
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.transactions,
            builder: (context, state) => TransactionsPage(
              load: widget.load,
              onOpenStarred: () => context.go(AppRoutes.starred),
            ),
          ),
          GoRoute(
            path: AppRoutes.starred,
            builder: (context, state) => StarredPage(
              onOpenTransactions: () => context.go(AppRoutes.transactions),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Transactions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xff16665c)),
      routerConfig: _router,
    );
  }
}

/// Shows which library is active below every state-backed screen.
final class _StateManagementBar extends StatelessWidget {
  const _StateManagementBar({
    required this.option,
    required this.onChange,
    required this.child,
  });

  final StateManagementOption option;
  final VoidCallback onChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(child: child),
        Material(
          color: colors.surfaceContainer,
          child: SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text('State management: ${option.name}'),
              trailing: TextButton(
                onPressed: onChange,
                child: const Text('Change'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
