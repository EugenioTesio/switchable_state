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
  });

  test('closedStoreError is a StateError', () {
    expect(closedStoreError(), isA<StateError>());
  });
}

final class _RecordingStore<S extends Object> implements StateStore<S> {
  _RecordingStore(this.value);

  @override
  S value;

  final replaced = <S>[];

  @override
  void replace(S next) {
    replaced.add(next);
    value = next;
  }

  @override
  Widget watch(Widget Function(S state) render) => render(value);

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      render(pick(value));

  @override
  Future<void> close() async {}
}
