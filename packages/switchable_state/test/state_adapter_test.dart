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

  group('ValueNotifierStateAdapter', () {
    testWidgets('supports watch, select, listen, and nullable state', (
      tester,
    ) async {
      const adapter = ValueNotifierStateAdapter();
      final store = adapter.create<String?>(null);
      addTearDown(store.close);

      final events = <(String?, String?)>[];
      final cancel = store.listen((p, n) => events.add((p, n)));
      addTearDown(cancel);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: store.watch((s) => Text(s ?? 'empty')),
        ),
      );
      expect(find.text('empty'), findsOneWidget);

      store.replace('ready');
      await tester.pump();
      expect(find.text('ready'), findsOneWidget);
      expect(events, [(null, 'ready')]);
    });
  });
}

final class _RecordingStore<S> implements StateStore<S> {
  _RecordingStore(this.value);

  @override
  S value;

  @override
  bool isClosed = false;

  final replaced = <S>[];

  @override
  void replace(S next) {
    if (isClosed) throw closedStoreError();
    replaced.add(next);
    value = next;
  }

  @override
  Widget watch(Widget Function(S state) render) => render(value);

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      render(pick(value));

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) => () {};

  @override
  Future<void> close() async {
    isClosed = true;
  }
}
