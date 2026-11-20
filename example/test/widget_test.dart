import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, UncontrolledProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_example/main.dart' show buildApp;
import 'package:switchable_state_example/transactions/transactions.dart';

const entries = [
  TransactionEntry('Pending purchase', pending: true),
  TransactionEntry('Settled deposit', pending: false),
];

void main() {
  late GetIt services;

  setUp(() => services = GetIt.asNewInstance());
  tearDown(() => services.reset());

  testWidgets('the app starts on the state-management choice', (tester) async {
    await tester.pumpWidget(buildApp(services, load: () async => entries));
    await tester.pumpAndSettle();

    expect(find.text('Choose state management'), findsOneWidget);
    for (final name in ['Cubit', 'GetX', 'MobX', 'Provider', 'Riverpod']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(services.isRegistered<StateAdapter>(), isFalse);
  });

  testWidgets('choosing a library injects its adapter and opens transactions', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(services, load: () async => entries));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cubit'));
    await tester.pumpAndSettle();
    expect(services<StateAdapter>(), isA<CubitStateAdapter>());
    expect(find.text('State management: Cubit'), findsOneWidget);
    expect(find.text('Pending purchase'), findsOneWidget);

    await tester.tap(find.text('Pending only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Pending purchase'), findsOneWidget);
    expect(find.text('Settled deposit'), findsNothing);
  });

  testWidgets('changing the library starts every store over', (tester) async {
    await tester.pumpWidget(buildApp(services, load: () async => entries));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cubit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Star Pending purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Starred (1)'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Choose state management'), findsOneWidget);

    await tester.tap(find.text('Riverpod'));
    await tester.pumpAndSettle();
    expect(services<StateAdapter>(), isA<RiverpodStateAdapter>());
    expect(find.text('State management: Riverpod'), findsOneWidget);
    expect(find.text('Starred (0)'), findsOneWidget);
  });

  testWidgets('a deep link without a choice goes to the choice', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(services, load: () async => entries));
    await tester.pumpAndSettle();

    // The router redirects any state-backed path while nothing is chosen.
    await tester.binding.handlePushRoute('/transactions');
    await tester.pumpAndSettle();
    expect(find.text('Choose state management'), findsOneWidget);
  });

  testWidgets('Riverpod keeps its containers across an ordinary rebuild', (
    tester,
  ) async {
    final result = Completer<List<TransactionEntry>>();
    var loads = 0;
    Future<List<TransactionEntry>> load() {
      loads++;
      return result.future;
    }

    // Each Riverpod store has its own container: the route store's sits above
    // the filter switch, the app-wide starred store's above the count button.
    ProviderContainer containerAbove(String text) => tester
        .widget<UncontrolledProviderScope>(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(UncontrolledProviderScope),
          ),
        )
        .container;

    await tester.pumpWidget(buildApp(services, load: load));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riverpod'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final routeContainer = containerAbove('Pending only');
    final starredContainer = containerAbove('Starred (0)');
    expect(routeContainer, isNot(same(starredContainer)));

    await tester.tap(find.text('Pending only'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildApp(services, load: load));
    expect(containerAbove('Pending only'), same(routeContainer));
    expect(containerAbove('Starred (0)'), same(starredContainer));

    result.complete(entries);
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Pending purchase'), findsOneWidget);
    expect(find.text('Settled deposit'), findsNothing);
  });

  testWidgets('a late response is ignored after the route is disposed', (
    tester,
  ) async {
    final result = Completer<List<TransactionEntry>>();
    await tester.pumpWidget(buildApp(services, load: () => result.future));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cubit'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.pumpWidget(const SizedBox.shrink());
    result.complete(entries);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
