import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';
import 'package:switchable_state_getx/switchable_state_getx.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_example/transactions/transactions.dart';
import 'package:switchable_state_example/transactions/transactions_page.dart';

const adapters = <String, StateAdapter>{
  'Cubit': CubitStateAdapter(),
  'GetX': GetXStateAdapter(),
  'MobX': MobXStateAdapter(),
  'Provider': ProviderStateAdapter(),
  'Riverpod': RiverpodStateAdapter(),
};

const rows = [
  TransactionEntry('Pending purchase', pending: true),
  TransactionEntry('Settled deposit', pending: false),
];

const loading = 'Updating transactions…';
const failed = 'Couldn’t load transactions. Tap Refresh to retry.';
const empty = 'No matching transactions.';
const snackBar = 'Couldn’t load transactions.';

void main() {
  for (final MapEntry(key: name, value: adapter) in adapters.entries) {
    group('TransactionsPage with $name', () {
      late List<Completer<List<TransactionEntry>>> requests;

      setUp(() => requests = []);

      Future<void> mount(WidgetTester tester) {
        return tester.pumpWidget(
          StateScope(
            adapter: adapter,
            child: MaterialApp(
              home: TransactionsPage(
                load: () {
                  final request = Completer<List<TransactionEntry>>();
                  requests.add(request);
                  return request.future;
                },
              ),
            ),
          ),
        );
      }

      testWidgets('starring a row updates its star and the count', (
        tester,
      ) async {
        await mount(tester);
        requests.single.complete(rows);
        await tester.pumpAndSettle();
        expect(find.text('Starred (0)'), findsOneWidget);

        await tester.tap(find.byTooltip('Star Settled deposit'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Unstar Settled deposit'), findsOneWidget);
        expect(find.byTooltip('Star Pending purchase'), findsOneWidget);
        expect(find.text('Starred (1)'), findsOneWidget);
      });

      testWidgets('a row shows its own star after the filter shifts the list', (
        tester,
      ) async {
        await mount(tester);
        requests.single.complete(const [
          TransactionEntry('Settled first', pending: false),
          TransactionEntry('Pending second', pending: true),
        ]);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Star Settled first'));
        await tester.pumpAndSettle();

        // "Pending second" moves into the first row.
        await tester.tap(find.text('Pending only'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Star Pending second'), findsOneWidget);

        await tester.tap(find.text('Pending only'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Unstar Settled first'), findsOneWidget);
        expect(find.byTooltip('Star Pending second'), findsOneWidget);
      });

      testWidgets('loads, filters, survives a failed refresh and retries', (
        tester,
      ) async {
        await mount(tester);
        expect(find.text(loading), findsOneWidget);

        requests.single.complete(rows);
        await tester.pumpAndSettle();
        expect(find.text(loading), findsNothing);
        expect(find.text('Pending purchase'), findsOneWidget);
        expect(find.text('Settled deposit'), findsOneWidget);

        await tester.tap(find.text('Pending only'));
        await tester.pumpAndSettle();
        expect(find.text('Pending purchase'), findsOneWidget);
        expect(find.text('Settled deposit'), findsNothing);

        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        expect(find.text(loading), findsOneWidget);

        requests.last.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.text(failed), findsOneWidget);
        expect(find.text('Pending purchase'), findsOneWidget);

        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        requests.last.complete(const []);
        await tester.pumpAndSettle();
        expect(find.text(empty), findsOneWidget);
        expect(requests, hasLength(3));
      });

      testWidgets('a failed load shows a snack bar whose Retry reloads', (
        tester,
      ) async {
        await mount(tester);
        requests.single.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.text(failed), findsOneWidget);
        expect(find.text(snackBar), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(find.text(loading), findsOneWidget);

        requests.last.complete(rows);
        await tester.pumpAndSettle();
        expect(find.text('Pending purchase'), findsOneWidget);
      });

      testWidgets('shows the snack bar once per failure', (tester) async {
        await mount(tester);
        requests.single.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(find.text(snackBar), findsOneWidget);
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();

        // Still failed: a filter change is not a new failure.
        await tester.tap(find.text('Pending only'));
        await tester.pumpAndSettle();
        expect(find.text(snackBar), findsNothing);

        // A retry that fails again is.
        await tester.tap(find.text('Refresh'));
        await tester.pumpAndSettle();
        requests.last.completeError(StateError('still offline'));
        await tester.pumpAndSettle();
        expect(find.text(snackBar), findsOneWidget);
      });

      testWidgets('keeps a filter changed while a refresh is pending', (
        tester,
      ) async {
        await mount(tester);
        await tester.tap(find.text('Pending only'));
        await tester.pumpAndSettle();

        requests.single.complete(rows);
        await tester.pumpAndSettle();
        expect(find.text('Pending purchase'), findsOneWidget);
        expect(find.text('Settled deposit'), findsNothing);
      });

      testWidgets('ignores a response that arrives after disposal', (
        tester,
      ) async {
        await mount(tester);
        await tester.pumpWidget(const SizedBox.shrink());

        // The store is closed now, so a write would throw a StateError.
        requests.single.complete(rows);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('a rebuilt page refreshes with its newest load function', (
    tester,
  ) async {
    Widget app(String label) => StateScope(
      adapter: const CubitStateAdapter(),
      child: MaterialApp(
        home: TransactionsPage(
          load: () async => [TransactionEntry(label, pending: false)],
        ),
      ),
    );

    await tester.pumpWidget(app('From first loader'));
    await tester.pumpAndSettle();
    expect(find.text('From first loader'), findsOneWidget);

    await tester.pumpWidget(app('From second loader'));
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('From second loader'), findsOneWidget);
  });
}
