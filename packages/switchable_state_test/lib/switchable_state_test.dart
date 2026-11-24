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
    StateStore<S> create<S>(S initial) {
      final store = adapter.create<S>(initial);
      addTearDown(store.close);
      return store;
    }

    group('value', () {
      test('starts at the initial snapshot', () {
        expect(create(7).value, 7);
        expect(create(7).isClosed, isFalse);
      });

      test('supports nullable snapshots', () {
        final store = create<String?>(null);
        expect(store.value, isNull);
        store.replace('hello');
        expect(store.value, 'hello');
        store.replace(null);
        expect(store.value, isNull);
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

      testWidgets('ignores an initial replace equal to the initial snapshot', (
        tester,
      ) async {
        final store = create('ab');
        var builds = 0;
        await tester.pumpWidget(
          host(
            store.watch((s) {
              builds++;
              return Text(s);
            }),
          ),
        );
        expect(builds, 1);

        store.replace(['a', 'b'].join());
        await tester.pumpAndSettle();
        expect(builds, 1);
      });

      testWidgets(
        'reading another store.value inside watch does not subscribe',
        (tester) async {
          final watched = create(1);
          final other = create(10);
          var builds = 0;
          await tester.pumpWidget(
            host(
              watched.watch((w) {
                builds++;
                return Text('$w-${other.value}');
              }),
            ),
          );
          expect(find.text('1-10'), findsOneWidget);
          expect(builds, 1);

          other.replace(20);
          await tester.pumpAndSettle();
          expect(
            builds,
            1,
            reason: 'reading other.value must not subscribe to other',
          );
        },
      );

      testWidgets(
        'switching stores in the same slot unsubscribes the old one',
        (tester) async {
          final first = create(1);
          final second = create(100);
          var builds = 0;

          await tester.pumpWidget(
            host(
              first.watch((n) {
                builds++;
                return Text('v $n');
              }),
            ),
          );
          expect(find.text('v 1'), findsOneWidget);

          await tester.pumpWidget(
            host(
              second.watch((n) {
                builds++;
                return Text('v $n');
              }),
            ),
          );
          expect(find.text('v 100'), findsOneWidget);
          final buildsAfterSwap = builds;

          first.replace(2);
          await tester.pumpAndSettle();
          expect(builds, buildsAfterSwap);

          await first.close();
          second.replace(101);
          await tester.pumpAndSettle();
          expect(find.text('v 101'), findsOneWidget);
        },
      );
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

      // Tear-offs of one method on one object compare equal, so a rebuilt
      // selector can receive an "equal" pick that now reads different data
      // from its owner. It must re-pick instead of reusing a cached result.
      testWidgets('a rebuilt selector re-picks when its pick is an equal '
          'tear-off', (tester) async {
        final store = create((a: 1, b: 10));
        final picker = _FieldPicker();
        Widget tree() =>
            host(store.select(picker.pick, (v) => Text('value $v')));

        await tester.pumpWidget(tree());
        expect(find.text('value 1'), findsOneWidget);

        picker.useB = true;
        await tester.pumpWidget(tree());
        await tester.pumpAndSettle();
        expect(find.text('value 10'), findsOneWidget);

        store.replace((a: 1, b: 11));
        await tester.pumpAndSettle();
        expect(find.text('value 11'), findsOneWidget);
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

      testWidgets(
        'reading store.value or another store.value inside select does not '
        'defeat selection',
        (tester) async {
          final store = create((a: 1, b: 10));
          final other = create(100);
          var renders = 0;
          await tester.pumpWidget(
            host(
              store.select((s) => s.a, (a) {
                renders++;
                return Text('$a-${store.value.b}-${other.value}');
              }),
            ),
          );
          expect(renders, 1);

          store.replace((a: 1, b: 11));
          other.replace(200);
          await tester.pumpAndSettle();
          expect(
            renders,
            1,
            reason: 'value reads inside render must not add subscriptions',
          );
        },
      );

      testWidgets('supports nullable picked values', (tester) async {
        final store = create<({String? label, int count})>((
          label: null,
          count: 0,
        ));
        var renders = 0;
        await tester.pumpWidget(
          host(
            store.select((s) => s.label, (label) {
              renders++;
              return Text(label ?? 'none');
            }),
          ),
        );
        expect(find.text('none'), findsOneWidget);
        expect(renders, 1);

        store.replace((label: null, count: 1));
        await tester.pumpAndSettle();
        expect(renders, 1);

        store.replace((label: 'hi', count: 1));
        await tester.pumpAndSettle();
        expect(find.text('hi'), findsOneWidget);
        expect(renders, 2);

        store.replace((label: null, count: 2));
        await tester.pumpAndSettle();
        expect(find.text('none'), findsOneWidget);
        expect(renders, 3);
      });

      testWidgets('switching stores in select unsubscribes the old one', (
        tester,
      ) async {
        final first = create((a: 1, b: 10));
        final second = create((a: 2, b: 20));
        var renders = 0;

        await tester.pumpWidget(
          host(
            first.select((s) => s.a, (a) {
              renders++;
              return Text('a $a');
            }),
          ),
        );
        await tester.pumpWidget(
          host(
            second.select((s) => s.a, (a) {
              renders++;
              return Text('a $a');
            }),
          ),
        );
        expect(find.text('a 2'), findsOneWidget);
        final rendersAfterSwap = renders;

        first.replace((a: 99, b: 10));
        await tester.pumpAndSettle();
        expect(renders, rendersAfterSwap);

        await first.close();
        second.replace((a: 3, b: 20));
        await tester.pumpAndSettle();
        expect(find.text('a 3'), findsOneWidget);
      });
    });

    testWidgets(
      'writing to a new unwatched store in initState works while another '
      'watcher is mounted',
      (tester) async {
        final existing = create(0);
        late StateStore<int> createdInInit;
        await tester.pumpWidget(
          host(Column(children: [existing.watch((n) => Text('existing $n'))])),
        );

        await tester.pumpWidget(
          host(
            Column(
              children: [
                existing.watch((n) => Text('existing $n')),
                _WritesNewStoreInInitState(
                  onCreate: () {
                    createdInInit = create(1);
                    return createdInInit;
                  },
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('init 2'), findsOneWidget);
        expect(createdInInit.value, 2);
      },
    );

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

    group('listen', () {
      test('notifies listeners with previous and current snapshots', () async {
        final store = create(1);
        final events = <(int, int)>[];
        final cancel = store.listen((prev, next) => events.add((prev, next)));
        addTearDown(cancel);

        store.replace(1);
        store.replace(2);
        store.replace(3);
        await Future<void>.delayed(Duration.zero);

        expect(events, [(1, 2), (2, 3)]);
      });

      test('stops notifying after the disposer is called', () async {
        final store = create(0);
        final events = <int>[];
        final cancel = store.listen((_, next) => events.add(next));

        store.replace(1);
        await Future<void>.delayed(Duration.zero);
        cancel();
        cancel(); // idempotent

        store.replace(2);
        await Future<void>.delayed(Duration.zero);
        expect(events, [1]);
      });

      test('listen on a closed store is a safe no-op', () async {
        final store = create(0);
        await store.close();
        var called = false;
        final cancel = store.listen((_, _) => called = true);
        expect(cancel, returnsNormally);
        expect(called, isFalse);
      });

      testWidgets('StateListener runs side effects without rebuilding child', (
        tester,
      ) async {
        final store = create(0);
        final seen = <int>[];
        var childBuilds = 0;

        await tester.pumpWidget(
          host(
            StateListener<int>(
              store: store,
              listenWhen: (prev, next) => next.isEven,
              listener: (context, value) => seen.add(value),
              child: Builder(
                builder: (context) {
                  childBuilds++;
                  return const Text('static');
                },
              ),
            ),
          ),
        );
        expect(childBuilds, 1);

        store.replace(1);
        store.replace(2);
        await tester.pumpAndSettle();

        expect(seen, [2]);
        expect(childBuilds, 1);
      });

      // A route that writes in initState while a StateListener above it
      // shows a snack bar or navigates: the side effect calls setState on an
      // ancestor, which Flutter forbids while it is building. A watcher of
      // another store is mounted too, as in any real screen.
      testWidgets('StateListener side effects never run during a build', (
        tester,
      ) async {
        final listened = create(0);
        final watched = create(0);
        var notified = 0;
        var showWriter = false;
        late StateSetter showWriterSetState;

        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setOuterState) => Column(
                children: [
                  Text('notified $notified'),
                  watched.watch((n) => Text('watched $n')),
                  StateListener<int>(
                    store: listened,
                    listener: (context, value) =>
                        setOuterState(() => notified++),
                    child: const SizedBox(),
                  ),
                  StatefulBuilder(
                    builder: (context, setState) {
                      showWriterSetState = setState;
                      return showWriter
                          ? _RunsInInitState(() => listened.replace(1))
                          : const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        showWriterSetState(() => showWriter = true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('notified 1'), findsOneWidget);
        expect(listened.value, 1);
      });

      test('asListenable adapts the store to ValueListenable', () async {
        final store = create(10);
        final listenable = store.asListenable();

        final values = <int>[];
        void onChange() => values.add(listenable.value);
        listenable.addListener(onChange);
        addTearDown(() => listenable.removeListener(onChange));

        expect(listenable.value, 10);
        store.replace(11);
        await Future<void>.delayed(Duration.zero);
        expect(values, [11]);

        listenable.removeListener(onChange);
        store.replace(12);
        await Future<void>.delayed(Duration.zero);
        expect(values, [11], reason: 'a removed listener is not called');
        expect(listenable.value, 12);
      });
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
        expect(store.isClosed, isTrue);
        expect(store.value, 2);
      });

      test('works for a store that was never watched', () async {
        final store = create(1);
        store.replace(2);
        await store.close();
        expect(store.isClosed, isTrue);
        expect(store.value, 2);
      });

      test(
        'makes replace and update (even no-op) throw a StateError',
        () async {
          final store = create(1);
          await store.close();

          var changeCalled = false;
          expect(() => store.replace(2), throwsStateError);
          expect(() => store.update((n) => n + 1), throwsStateError);
          expect(
            () => store.update((n) {
              changeCalled = true;
              return n;
            }),
            throwsStateError,
          );
          expect(changeCalled, isFalse);
          expect(store.value, 1, reason: 'a rejected write must not land');
        },
      );

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

/// Owns a pick whose tear-off stays `==` while the data it reads changes.
final class _FieldPicker {
  bool useB = false;

  int pick(({int a, int b}) s) => useB ? s.b : s.a;
}

/// Runs [onInit] from `initState`, which happens while Flutter builds.
final class _RunsInInitState extends StatefulWidget {
  const _RunsInInitState(this.onInit);

  final VoidCallback onInit;

  @override
  State<_RunsInInitState> createState() => _RunsInInitStateState();
}

final class _RunsInInitStateState extends State<_RunsInInitState> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

final class _WritesNewStoreInInitState extends StatefulWidget {
  const _WritesNewStoreInInitState({required this.onCreate});

  final StateStore<int> Function() onCreate;

  @override
  State<_WritesNewStoreInInitState> createState() =>
      _WritesNewStoreInInitStateState();
}

final class _WritesNewStoreInInitStateState
    extends State<_WritesNewStoreInInitState> {
  late final StateStore<int> _store;

  @override
  void initState() {
    super.initState();
    _store = widget.onCreate();
    _store.replace(2);
  }

  @override
  Widget build(BuildContext context) => _store.watch((n) => Text('init $n'));
}
