import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';
import 'package:switchable_state_getx/switchable_state_getx.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';

// The quick-start counter from the READMEs and the website, kept here so the
// published snippet always compiles and behaves the same on every adapter.

/// Declared once, read anywhere below the scope.
final counterState = AppState<int>(() => 0, debugName: 'counter');

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final counter = StateScope.of(context).store(counterState);
    return Scaffold(
      body: Center(child: counter.watch((count) => Text('$count'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.update((count) => count + 1),
        child: const Icon(Icons.add),
      ),
    );
  }
}

const adapters = <String, StateAdapter>{
  'Cubit': CubitStateAdapter(),
  'GetX': GetXStateAdapter(),
  'MobX': MobXStateAdapter(),
  'Provider': ProviderStateAdapter(),
  'Riverpod': RiverpodStateAdapter(),
};

void main() {
  for (final MapEntry(key: name, value: adapter) in adapters.entries) {
    testWidgets('$name: the README counter counts', (tester) async {
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: const MaterialApp(home: CounterPage()),
        ),
      );
      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });
  }
}
