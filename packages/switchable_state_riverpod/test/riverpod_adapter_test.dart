import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';

import 'package:switchable_state_test/switchable_state_test.dart';

void main() {
  const adapter = RiverpodStateAdapter();

  stateStoreContract(adapter, pausesHiddenWatchers: true);

  group('Riverpod binding', () {
    ProviderContainer containerAbove(WidgetTester tester, String text) {
      final scope = find.ancestor(
        of: find.text(text),
        matching: find.byType(UncontrolledProviderScope),
      );
      return tester.widget<UncontrolledProviderScope>(scope).container;
    }

    testWidgets('each store owns one container shared by all its watchers', (
      tester,
    ) async {
      final first = adapter.create(1);
      final second = adapter.create(2);
      addTearDown(first.close);
      addTearDown(second.close);
      await tester.pumpWidget(
        host(
          Column(
            children: [
              first.watch((n) => Text('first $n')),
              first.watch((n) => Text('mirror $n')),
              second.watch((n) => Text('second $n')),
            ],
          ),
        ),
      );

      final firstContainer = containerAbove(tester, 'first 1');
      expect(containerAbove(tester, 'mirror 1'), same(firstContainer));
      expect(containerAbove(tester, 'second 2'), isNot(same(firstContainer)));
    });

    testWidgets('the container outlives its watchers until close', (
      tester,
    ) async {
      final probe = Provider((ref) => 'alive');
      final store = adapter.create(1);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
      final container = containerAbove(tester, 'count 1');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(container.read(probe), 'alive');

      await store.close();
      expect(() => container.read(probe), throwsStateError);
    });

    // A disposed container cannot be read, so the store keeps a copy.
    test('value stays readable after close', () async {
      final store = adapter.create(1);
      store.replace(2);
      await store.close();
      expect(store.value, 2);
    });

    testWidgets('preserves an ancestor ProviderScope inside watch and select', (
      tester,
    ) async {
      final appProvider = Provider((ref) => 'from-app-scope');
      final store = adapter.create((a: 1, b: 10));
      addTearDown(store.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWithValue('overridden-in-app')],
          child: host(
            Column(
              children: [
                store.watch(
                  (s) => Consumer(
                    builder: (context, ref, _) =>
                        Text('w:${s.a}:${ref.watch(appProvider)}'),
                  ),
                ),
                store.select(
                  (s) => s.a,
                  (a) => Consumer(
                    builder: (context, ref, _) =>
                        Text('s:$a:${ref.watch(appProvider)}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('w:1:overridden-in-app'), findsOneWidget);
      expect(find.text('s:1:overridden-in-app'), findsOneWidget);
    });

    group('writes made while Flutter builds', () {
      /// Pumps [watched] plus a slot that later mounts a widget running
      /// [onInit] from initState, and returns a callback that mounts it.
      Future<void Function()> pumpWithWriter(
        WidgetTester tester, {
        required Widget watched,
        required VoidCallback onInit,
        Widget Function(Widget child)? wrap,
      }) async {
        var show = false;
        late StateSetter setSlotState;
        final tree = host(
          Column(
            children: [
              watched,
              StatefulBuilder(
                builder: (context, setState) {
                  setSlotState = setState;
                  return show ? _RunsInInitState(onInit) : const SizedBox();
                },
              ),
            ],
          ),
        );
        await tester.pumpWidget(wrap?.call(tree) ?? tree);
        return () => setSlotState(() => show = true);
      }

      // Observers subscribe to every scope store, which mounts its provider,
      // so a screen writing a scope store in initState used to throw.
      testWidgets('to a scope store with observers do not throw', (
        tester,
      ) async {
        final listened = AppState<int>(() => 0, debugName: 'listened');
        final other = adapter.create(0);
        addTearDown(other.close);
        final changes = <Object?>[];
        late StateRegistry registry;

        final showWriter = await pumpWithWriter(
          tester,
          watched: other.watch((n) => Text('other $n')),
          onInit: () => registry.store(listened).replace(1),
          wrap: (child) => StateScope(
            adapter: adapter,
            observers: [_ChangeLog(changes)],
            child: Builder(
              builder: (context) {
                registry = StateScope.of(context);
                registry.store(listened);
                return child;
              },
            ),
          ),
        );

        showWriter();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(registry.store(listened).value, 1);
        expect(changes, [1]);
      });

      testWidgets('to a watched store do not throw and reach the watcher', (
        tester,
      ) async {
        final store = adapter.create(0);
        addTearDown(store.close);
        int? valueInBuild;
        final showWriter = await pumpWithWriter(
          tester,
          watched: Column(
            children: [
              store.watch((n) => Text('watch $n')),
              store.select((n) => n.isEven, (even) => Text('even $even')),
            ],
          ),
          onInit: () {
            store.replace(1);
            store.replace(2);
            store.replace(3);
            valueInBuild = store.value;
          },
        );

        showWriter();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(valueInBuild, 3, reason: 'value is never deferred');
        expect(find.text('watch 3'), findsOneWidget);
        expect(find.text('even false'), findsOneWidget);
      });

      // The post-frame write lands before the deferred one is published; the
      // newest snapshot must still win.
      testWidgets('never let a deferred write overtake a later one', (
        tester,
      ) async {
        final store = adapter.create(0);
        addTearDown(store.close);
        final events = <(int, int)>[];
        final cancel = store.listen((p, n) => events.add((p, n)));
        addTearDown(cancel);

        final showWriter = await pumpWithWriter(
          tester,
          watched: store.watch((n) => Text('watch $n')),
          onInit: () {
            store.replace(1);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => store.replace(2),
            );
          },
        );
        showWriter();
        await tester.pumpAndSettle();

        expect(store.value, 2);
        expect(find.text('watch 2'), findsOneWidget);
        expect(events.last.$2, 2);
        store.replace(3);
        expect(events.last, (2, 3));
      });
    });
  });
}

final class _ChangeLog extends StateObserver {
  _ChangeLog(this.changes);

  final List<Object?> changes;

  @override
  void onChange(AppState<Object?> state, Object? previous, Object? next) =>
      changes.add(next);
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
