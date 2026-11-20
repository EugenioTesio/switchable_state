/// Conformance tests for `switchable_state` adapters.
///
/// Call [stateStoreContract] inside a test file to check that a
/// [StateAdapter] behaves like the official ones:
///
/// ```dart
/// import 'package:flutter_test/flutter_test.dart';
/// import 'package:switchable_state_test/switchable_state_test.dart';
///
/// void main() => stateStoreContract(const MyStateAdapter());
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state/switchable_state.dart';

/// Gives [child] the text direction that [Text] needs without an app shell.
Widget host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// Registers the behaviour every [StateAdapter] must share, so a feature
/// gets the same results whichever library the app registers.
///
/// Call it from a test file's `main`, then add tests for your own binding.
/// It registers its tests in a `StateStore contract` group.
///
/// [pausesHiddenWatchers] records a known difference: Riverpod stops
/// listening while `TickerMode` is off (a route covered by another one) and
/// catches up when shown; the other libraries keep rebuilding while hidden.
void stateStoreContract(
  StateAdapter adapter, {
  bool pausesHiddenWatchers = false,
}) {
  group('StateStore contract', () {
    // Test tear-downs run after testWidgets has unmounted the tree, which
    // matches the ownership rule that watchers unmount before close.
    StateStore<S> create<S extends Object>(S initial) {
      final store = adapter.create(initial);
      addTearDown(store.close);
      return store;
    }

    group('value', () {
      test('starts at the initial snapshot', () {
        expect(create(7).value, 7);
      });

      test('reflects the most recent replace immediately', () {
        final store = create(0);
        store.replace(1);
        store.replace(2);
        expect(store.value, 2);
      });

      test('keeps the identity of object snapshots', () {
        const initial = _Snapshot('initial');
        const next = _Snapshot('next');
        final store = create(initial);
        expect(store.value, same(initial));

        store.replace(next);
        expect(store.value, same(next));
      });

      test('update applies each change to the latest snapshot', () {
        final store = create(1);
        store.update((n) => n + 1);
        store.update((n) => n * 10);
        expect(store.value, 20);
      });

      test('each create call returns an independent store', () {
        final first = create(0);
        final second = create(0);
        first.replace(1);
        expect(first, isNot(same(second)));
        expect(second.value, 0);
      });
    });

    group('watch', () {
      testWidgets('renders the current snapshot on mount', (tester) async {
        final store = create(1);
        store.replace(2);

        await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
        expect(find.text('count 2'), findsOneWidget);
      });

      testWidgets('updates every watcher and leaves other stores alone', (
        tester,
      ) async {
        final first = create(3);
        final second = create(30);
        var secondBuilds = 0;
        await tester.pumpWidget(
          host(
            Column(
              children: [
                first.watch((n) => Text('first $n')),
                first.watch((n) => Text('mirror $n')),
                second.watch((n) {
                  secondBuilds++;
                  return Text('second $n');
                }),
              ],
            ),
          ),
        );
        expect(find.text('first 3'), findsOneWidget);
        expect(find.text('mirror 3'), findsOneWidget);
        expect(find.text('second 30'), findsOneWidget);
        final secondBuildsBefore = secondBuilds;

        first.update((n) => n + 1);
        first.update((n) => n + 1);
        expect(first.value, 5);
        expect(second.value, 30);
        await tester.pumpAndSettle();

        expect(find.text('first 5'), findsOneWidget);
        expect(find.text('mirror 5'), findsOneWidget);
        expect(find.text('second 30'), findsOneWidget);
        expect(
          secondBuilds,
          secondBuildsBefore,
          reason: 'a write to one store must not rebuild another',
        );
      });

      testWidgets('renders object snapshots', (tester) async {
        final store = create(const _Snapshot('first'));
        await tester.pumpWidget(host(store.watch((s) => Text(s.label))));
        expect(find.text('first'), findsOneWidget);

        store.replace(const _Snapshot('second'));
        await tester.pumpAndSettle();
        expect(find.text('second'), findsOneWidget);
      });

      testWidgets('a rebuilt watcher uses the newest render function', (
        tester,
      ) async {
        final store = create(1);
        await tester.pumpWidget(host(store.watch((n) => Text('old $n'))));
        await tester.pumpWidget(host(store.watch((n) => Text('new $n'))));
        expect(find.text('new 1'), findsOneWidget);

        store.replace(2);
        await tester.pumpAndSettle();
        expect(find.text('new 2'), findsOneWidget);
        expect(find.textContaining('old'), findsNothing);
      });

      testWidgets('a remounted watcher shows writes made while unmounted', (
        tester,
      ) async {
        final store = create(1);
        await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
        await tester.pumpWidget(const SizedBox.shrink());

        store.replace(2);
        await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
        expect(find.text('count 2'), findsOneWidget);

        store.replace(3);
        await tester.pumpAndSettle();
        expect(find.text('count 3'), findsOneWidget);
      });
    });

    group('select', () {
      testWidgets('renders the picked value on mount', (tester) async {
        final store = create((a: 1, b: 10));
        store.replace((a: 2, b: 10));

        await tester.pumpWidget(
          host(store.select((s) => s.a, (a) => Text('a $a'))),
        );
        expect(find.text('a 2'), findsOneWidget);
      });

      testWidgets('re-renders only when the picked value changes', (
        tester,
      ) async {
        final store = create((a: 1, b: 10));
        var renders = 0;
        await tester.pumpWidget(
          host(
            store.select((s) => s.a, (a) {
              renders++;
              return Text('a $a');
            }),
          ),
        );
        expect(renders, 1);

        store.replace((a: 1, b: 11));
        await tester.pumpAndSettle();
        expect(renders, 1, reason: 'only b changed, and b is not picked');

        store.replace((a: 2, b: 11));
        await tester.pumpAndSettle();
        expect(find.text('a 2'), findsOneWidget);
        expect(renders, 2);
      });

      // A list row reused for another entry is rebuilt with a new pick after
      // writes it ignored. The new pick must read the current snapshot.
      testWidgets('a rebuilt selector applies its new pick to the current '
          'snapshot', (tester) async {
        final store = create((a: 1, b: 10));
        await tester.pumpWidget(
          host(store.select((s) => s.a, (v) => Text('value $v'))),
        );
        store.replace((a: 1, b: 11));
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          host(store.select((s) => s.b, (v) => Text('value $v'))),
        );
        expect(find.text('value 11'), findsOneWidget);

        store.replace((a: 1, b: 12));
        await tester.pumpAndSettle();
        expect(find.text('value 12'), findsOneWidget);
      });

      testWidgets('a selector nested in another store\'s watcher follows '
          'both stores', (tester) async {
        final outer = create(1);
        final inner = create((a: 1, b: 10));
        var outerRenders = 0;
        await tester.pumpWidget(
          host(
            outer.watch((o) {
              outerRenders++;
              return inner.select((s) => s.a, (a) => Text('$o-$a'));
            }),
          ),
        );
        expect(find.text('1-1'), findsOneWidget);

        inner.replace((a: 2, b: 10));
        await tester.pumpAndSettle();
        expect(find.text('1-2'), findsOneWidget);
        expect(
          outerRenders,
          1,
          reason: 'an inner write must not rebuild outer',
        );

        outer.replace(2);
        await tester.pumpAndSettle();
        expect(find.text('2-2'), findsOneWidget);
      });
    });

    // A route covered by another one stays mounted with TickerMode off. The
    // same widget instance is reused when it is shown again, so only the
    // library's own subscription can bring it up to date.
    testWidgets('hidden watchers and selectors catch up once shown', (
      tester,
    ) async {
      final store = create((a: 1, b: 10));
      final content = Column(
        children: [
          store.watch((s) => Text('watch ${s.a}')),
          store.select((s) => s.a, (a) => Text('select $a')),
        ],
      );
      await tester.pumpWidget(host(TickerMode(enabled: false, child: content)));

      store.replace((a: 2, b: 10));
      await tester.pumpAndSettle();
      final whileHidden = pausesHiddenWatchers ? 1 : 2;
      expect(find.text('watch $whileHidden'), findsOneWidget);
      expect(find.text('select $whileHidden'), findsOneWidget);

      await tester.pumpWidget(host(TickerMode(enabled: true, child: content)));
      await tester.pumpAndSettle();
      expect(find.text('watch 2'), findsOneWidget);
      expect(find.text('select 2'), findsOneWidget);
    });

    group('close', () {
      testWidgets('after the watchers unmount keeps the last snapshot', (
        tester,
      ) async {
        final store = create(1);
        await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
        store.replace(2);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());

        await store.close();
        expect(store.value, 2);
      });

      test('works for a store that was never watched', () async {
        final store = create(1);
        store.replace(2);
        await store.close();
        expect(store.value, 2);
      });

      test('makes replace and update throw a StateError', () async {
        final store = create(1);
        await store.close();

        expect(() => store.replace(2), throwsStateError);
        expect(() => store.update((n) => n + 1), throwsStateError);
        expect(store.value, 1, reason: 'a rejected write must not land');
      });

      test('can be called more than once', () async {
        final store = create(1);
        await store.close();
        await expectLater(store.close(), completes);
        expect(store.value, 1);
      });
    });
  });
}

/// An immutable snapshot without value equality, like the feature states.
final class _Snapshot {
  const _Snapshot(this.label);

  final String label;
}
