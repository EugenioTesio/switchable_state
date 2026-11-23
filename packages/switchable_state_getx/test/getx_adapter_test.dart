import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' show Obx;
import 'package:switchable_state_getx/switchable_state_getx.dart';

import 'package:switchable_state_test/switchable_state_test.dart';

void main() {
  const adapter = GetXStateAdapter();

  stateStoreContract(adapter);

  group('GetX binding', () {
    testWidgets('watch renders through Obx without GetMaterialApp or Get.put', (
      tester,
    ) async {
      final store = adapter.create(0);
      addTearDown(store.close);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));
      expect(find.byType(Obx), findsOneWidget);

      store.replace(1);
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);
    });

    // A closed Rx drops writes without an error and asserts when closed
    // again. The adapter must not expose either behaviour.
    test('a write after close is not silently dropped', () async {
      final store = adapter.create(0);
      await store.close();
      expect(() => store.replace(1), throwsStateError);
    });

    test('a second close does not reach the closed Rx', () async {
      final store = adapter.create(0);
      await store.close();
      await expectLater(store.close(), completes);
    });

    testWidgets('closing a store before select unmounts does not throw', (
      tester,
    ) async {
      final store = adapter.create((a: 1, b: 10));
      await tester.pumpWidget(
        host(store.select((s) => s.a, (a) => Text('a $a'))),
      );
      await store.close();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });
}
