import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
