import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_test/switchable_state_test.dart';
import 'package:switchable_state_value_notifier/switchable_state_value_notifier.dart';

void main() {
  const adapter = ValueNotifierStateAdapter();

  stateStoreContract(adapter);

  group('ValueNotifier binding', () {
    testWidgets('watch renders through a ValueListenableBuilder', (
      tester,
    ) async {
      final store = adapter.create(0);
      addTearDown(store.close);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
      expect(find.byType(ValueListenableBuilder<int>), findsOneWidget);
    });

    testWidgets('supports watch, select, listen, and nullable state', (
      tester,
    ) async {
      final store = adapter.create<String?>(null);
      addTearDown(store.close);

      final events = <(String?, String?)>[];
      final cancel = store.listen((p, n) => events.add((p, n)));
      addTearDown(cancel);

      await tester.pumpWidget(
        host(
          Column(
            children: [
              store.watch((s) => Text(s ?? 'empty')),
              store.select((s) => s?.length, (n) => Text('length $n')),
            ],
          ),
        ),
      );
      expect(find.text('empty'), findsOneWidget);
      expect(find.text('length null'), findsOneWidget);

      store.replace('ready');
      await tester.pump();
      expect(find.text('ready'), findsOneWidget);
      expect(find.text('length 5'), findsOneWidget);
      expect(events, [(null, 'ready')]);
    });

    test('a write after close is rejected and the value is kept', () async {
      final store = adapter.create(1);
      await store.close();
      expect(() => store.replace(2), throwsStateError);
      expect(store.value, 1);
    });
  });
}
