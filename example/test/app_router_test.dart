import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_example/app.dart';
import 'package:switchable_state_example/main.dart' show buildApp;
import 'package:switchable_state_example/starred/starred.dart';
import 'package:switchable_state_example/state_management/state_management.dart';
import 'package:switchable_state_example/transactions/transactions.dart';
import 'package:switchable_state_example/transactions/transactions_page.dart';

const rows = [
  TransactionEntry('Pending purchase', pending: true),
  TransactionEntry('Settled deposit', pending: false),
];

void main() {
  for (final option in stateManagementOptions) {
    group('App routes with ${option.name}', () {
      late GetIt services;
      late int loads;

      Future<List<TransactionEntry>> load() async {
        loads++;
        return rows;
      }

      setUp(() {
        loads = 0;
        services = GetIt.asNewInstance();
      });
      tearDown(() => services.reset());

      /// Starts the app and picks [option] on the start screen.
      Future<void> start(WidgetTester tester) async {
        await tester.pumpWidget(buildApp(services, load: load));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option.name));
        await tester.pumpAndSettle();
        expect(find.text('State management: ${option.name}'), findsOneWidget);
      }

      testWidgets('go() rebuilds route state but keeps app-wide state', (
        tester,
      ) async {
        await start(tester);
        expect(loads, 1);

        await tester.tap(find.byTooltip('Star Pending purchase'));
        await tester.pumpAndSettle();
        expect(find.text('Starred (1)'), findsOneWidget);

        await tester.tap(find.text('Starred (1)'));
        await tester.pumpAndSettle();
        expect(
          find.byType(TransactionsPage, skipOffstage: false),
          findsNothing,
          reason: 'go() replaced the route, closing its store',
        );
        expect(find.text('Pending purchase'), findsOneWidget);

        await tester.tap(find.byTooltip('Unstar Pending purchase'));
        await tester.pumpAndSettle();
        expect(find.text('No starred transactions.'), findsOneWidget);

        await tester.tap(find.text('Transactions'));
        await tester.pumpAndSettle();
        expect(loads, 2, reason: 'a new route store loads again');
        expect(find.text('Starred (0)'), findsOneWidget);
        expect(find.byTooltip('Star Pending purchase'), findsOneWidget);
      });

      testWidgets('a route covered by push() shows the latest state on pop', (
        tester,
      ) async {
        await start(tester);
        await tester.tap(find.byTooltip('Star Pending purchase'));
        await tester.pumpAndSettle();

        final router = GoRouter.of(
          tester.element(find.byType(TransactionsPage)),
        );
        unawaited(router.push(AppRoutes.starred));
        await tester.pumpAndSettle();
        expect(
          find.byType(TransactionsPage, skipOffstage: false),
          findsOneWidget,
          reason: 'push() keeps the covered route mounted',
        );

        await tester.tap(find.byTooltip('Unstar Pending purchase'));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Starred (0)'), findsOneWidget);
        expect(find.byTooltip('Star Pending purchase'), findsOneWidget);
        expect(loads, 1, reason: 'the covered route kept its store');
      });

      testWidgets('changing the library closes the scope and its stores', (
        tester,
      ) async {
        await start(tester);
        final starred = StateScope.of(
          tester.element(find.byType(TransactionsPage)),
        ).store(starredState);

        await tester.tap(find.text('Change'));
        await tester.pumpAndSettle();
        expect(find.text('Choose state management'), findsOneWidget);
        expect(
          () => starred.replace(const StarredState.initial()),
          throwsStateError,
        );
      });
    });
  }

  testWidgets('an override seeds app-wide state', (tester) async {
    await tester.pumpWidget(
      StateScope(
        adapter: stateManagementOptions.first.adapter,
        overrides: [
          starredState.overrideWith(
            () => const StarredState.initial().toggled('Pending purchase'),
          ),
        ],
        child: MaterialApp(home: TransactionsPage(load: () async => rows)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Starred (1)'), findsOneWidget);
    expect(find.byTooltip('Unstar Pending purchase'), findsOneWidget);
  });
}
