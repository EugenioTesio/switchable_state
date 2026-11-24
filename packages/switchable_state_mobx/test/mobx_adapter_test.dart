import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';

import 'package:switchable_state_test/switchable_state_test.dart';

void main() {
  const adapter = MobXStateAdapter();

  stateStoreContract(adapter);

  group('MobX binding', () {
    testWidgets('watch renders through an Observer', (tester) async {
      final store = adapter.create(0);
      addTearDown(store.close);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
      expect(find.byType(Observer), findsOneWidget);
    });

    test(
      'replace runs in an action, so the strictest write policy accepts it',
      () {
        final previous = mainContext.config;
        mainContext.config = previous.clone(
          writePolicy: ReactiveWritePolicy.always,
        );
        addTearDown(() => mainContext.config = previous);

        // Proves the policy is active: a bare write outside an action fails.
        final bare = Observable(0);
        expect(() => bare.value = 1, throwsA(isA<AssertionError>()));

        final store = adapter.create(0);
        addTearDown(store.close);
        expect(() => store.replace(1), returnsNormally);
        expect(store.value, 1);
      },
    );

    test(
      'a write after close is rejected even though the observable survives',
      () async {
        final store = adapter.create(0);
        await store.close();
        expect(() => store.replace(1), throwsStateError);
        expect(store.value, 0);
      },
    );

    // An app adopting the adapter may still read its own MobX observables
    // inside a render callback; those reads must keep rebuilding it.
    testWidgets('watch and select track other observables read in render', (
      tester,
    ) async {
      final external = Observable(0);
      final store = adapter.create((a: 1, b: 10));
      addTearDown(store.close);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              store.watch((s) => Text('watch ${s.a} ${external.value}')),
              store.select(
                (s) => s.a,
                (a) => Text('select $a ${external.value}'),
              ),
            ],
          ),
        ),
      );

      runInAction(() => external.value = 1);
      await tester.pumpAndSettle();
      expect(find.text('watch 1 1'), findsOneWidget);
      expect(find.text('select 1 1'), findsOneWidget);
    });

    test('value reads work under ReactiveReadPolicy.always', () {
      final previous = mainContext.config;
      mainContext.config = previous.clone(
        readPolicy: ReactiveReadPolicy.always,
      );
      addTearDown(() => mainContext.config = previous);

      final store = adapter.create(42);
      addTearDown(store.close);
      expect(() => store.value, returnsNormally);
      expect(store.value, 42);
    });
  });
}
