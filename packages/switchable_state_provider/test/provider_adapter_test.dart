import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';

import 'package:switchable_state_test/switchable_state_test.dart';

void main() {
  const adapter = ProviderStateAdapter();

  stateStoreContract(adapter);

  group('Provider binding', () {
    testWidgets(
      'watch exposes the store through ChangeNotifierProvider and Consumer',
      (tester) async {
        final store = adapter.create(0);
        addTearDown(store.close);
        await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));

        expect(
          find.byWidgetPredicate(
            (w) => w is ChangeNotifierProvider<ChangeNotifier>,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is Consumer<ChangeNotifier>),
          findsOneWidget,
        );
      },
    );

    test('an equal snapshot does not notify listeners', () {
      const current = 'ab';
      final equal = ['a', 'b'].join();
      final store = adapter.create(current);
      addTearDown(store.close);
      var notifications = 0;
      (store as ChangeNotifier).addListener(() => notifications++);

      store.replace(equal);
      expect(notifications, 0);
      expect(store.value, same(current));

      store.replace('c');
      expect(notifications, 1);
    });

    testWidgets('unmounting a watcher does not dispose the route-owned store', (
      tester,
    ) async {
      final store = adapter.create(0);
      addTearDown(store.close);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
      await tester.pumpWidget(const SizedBox.shrink());

      void listener() {}
      expect(
        () => (store as ChangeNotifier).addListener(listener),
        returnsNormally,
      );
      (store as ChangeNotifier).removeListener(listener);
    });

    test('close disposes the ChangeNotifier', () async {
      final store = adapter.create(0);
      await store.close();
      expect(
        () => (store as ChangeNotifier).addListener(() {}),
        throwsFlutterError,
      );
    });

    // A disposed ChangeNotifier only fails inside notifyListeners, which runs
    // after the snapshot field has already been assigned.
    test('a write after close leaves the snapshot unchanged', () async {
      final store = adapter.create(0);
      await store.close();
      expect(() => store.replace(1), throwsStateError);
      expect(store.value, 0);
    });
  });
}
