import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state/switchable_state.dart';

void main() {
  group('StateStore.update', () {
    test('passes the latest snapshot and replaces it with the result', () {
      final store = _RecordingStore<int>(1);
      final seen = <int>[];

      store.update((n) {
        seen.add(n);
        return n + 1;
      });
      store.update((n) {
        seen.add(n);
        return n * 10;
      });

      expect(seen, [1, 2]);
      expect(store.replaced, [2, 20]);
    });

    test('skips replace when the change returns the same snapshot', () {
      final store = _RecordingStore<int>(1);
      store.update((n) => n);
      expect(store.replaced, isEmpty);
    });

    test('skips replace when the change returns an equal snapshot', () {
      const current = 'ab';
      final store = _RecordingStore<String>(current);
      store.update((_) => ['a', 'b'].join());
      expect(store.replaced, isEmpty);
      expect(store.value, same(current));
    });

    test('throws StateError before running change on a closed store', () async {
      final store = _RecordingStore<int>(1);
      await store.close();
      var ran = false;
      expect(
        () => store.update((n) {
          ran = true;
          return n;
        }),
        throwsStateError,
      );
      expect(ran, isFalse);
    });
  });

  test('closedStoreError is a StateError', () {
    expect(closedStoreError(), isA<StateError>());
  });

  group('asListenable', () {
    test('subscribes to the store only while it has listeners', () {
      final store = _RecordingStore<int>(0);
      final listenable = store.asListenable();
      expect(store.listeners, isEmpty, reason: 'creating it is free');

      var calls = 0;
      void first() => calls++;
      void second() => calls++;
      listenable
        ..addListener(first)
        ..addListener(second);
      expect(store.listeners, hasLength(1), reason: 'one shared subscription');

      store.replace(1);
      expect(calls, 2);

      listenable.removeListener(first);
      expect(store.listeners, hasLength(1));
      listenable.removeListener(second);
      expect(store.listeners, isEmpty);

      store.replace(2);
      expect(calls, 2);
      expect(listenable.value, 2);
    });

    test('a listener removed during a notification is not called again', () {
      final store = _RecordingStore<int>(0);
      final listenable = store.asListenable();
      final calls = <String>[];
      late VoidCallback second;
      void first() {
        calls.add('first');
        listenable.removeListener(second);
      }

      second = () => calls.add('second');
      listenable
        ..addListener(first)
        ..addListener(second);

      store.replace(1);
      store.replace(2);
      expect(calls, ['first', 'first']);
    });

    // Calling asListenable() inline in build, as with ValueListenableBuilder,
    // creates a new adapter on every rebuild. None of them may leak.
    testWidgets('inline use in build does not accumulate subscriptions', (
      tester,
    ) async {
      final store = _RecordingStore<int>(0);
      late StateSetter rebuild;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ValueListenableBuilder<int>(
                valueListenable: store.asListenable(),
                builder: (context, value, _) => Text('value $value'),
              );
            },
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        rebuild(() {});
        await tester.pump();
      }
      expect(store.listeners, hasLength(1));

      store.replace(3);
      await tester.pump();
      expect(find.text('value 3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      expect(store.listeners, isEmpty);
    });
  });

  group('StateListener', () {
    testWidgets('runs its listener after the write returns', (tester) async {
      final store = _RecordingStore<int>(0);
      final seen = <int>[];
      await tester.pumpWidget(
        StateListener<int>(
          store: store,
          listener: (context, value) => seen.add(value),
          child: const SizedBox(),
        ),
      );

      store.replace(1);
      store.replace(2);
      expect(seen, isEmpty, reason: 'never inside the writer call stack');
      await tester.pump();
      expect(seen, [1, 2]);
    });

    // The write to the old store lands in the same build that switches the
    // listener to a new store, so its delivery is still pending afterwards.
    testWidgets('drops pending events of a store it no longer listens to', (
      tester,
    ) async {
      final first = _RecordingStore<int>(0);
      final second = _RecordingStore<int>(0);
      final seen = <int>[];
      Widget tree(StateStore<int> store, {VoidCallback? writeFirst}) => Column(
        children: [
          if (writeFirst != null) _RunsInInitState(writeFirst),
          StateListener<int>(
            store: store,
            listener: (context, value) => seen.add(value),
            child: const SizedBox(),
          ),
        ],
      );
      await tester.pumpWidget(tree(first));

      await tester.pumpWidget(tree(second, writeFirst: () => first.replace(1)));
      second.replace(2);
      await tester.pump();
      expect(seen, [2]);
      expect(first.listeners, isEmpty);
    });

    testWidgets('drops pending events after it unmounts', (tester) async {
      final store = _RecordingStore<int>(0);
      final seen = <int>[];
      await tester.pumpWidget(
        StateListener<int>(
          store: store,
          listener: (context, value) => seen.add(value),
          child: const SizedBox(),
        ),
      );
      // The listener unmounts in the build where the write happens.
      await tester.pumpWidget(_RunsInInitState(() => store.replace(1)));
      await tester.pump();
      expect(seen, isEmpty);
      expect(store.listeners, isEmpty);
    });
  });
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

final class _RecordingStore<S> implements StateStore<S> {
  _RecordingStore(this.value);

  @override
  S value;

  @override
  bool isClosed = false;

  final replaced = <S>[];

  /// The active [listen] subscriptions, notified synchronously.
  final listeners = <void Function(S previous, S current)>[];

  @override
  void replace(S next) {
    if (isClosed) throw closedStoreError();
    replaced.add(next);
    final previous = value;
    value = next;
    for (final listener in listeners.toList()) {
      listener(previous, next);
    }
  }

  @override
  Widget watch(Widget Function(S state) render) => render(value);

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      render(pick(value));

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    // A fresh closure per call, so two subscriptions stay distinct.
    void subscription(S previous, S current) => onChange(previous, current);
    listeners.add(subscription);
    return () => listeners.remove(subscription);
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}
