# switchable_state_riverpod example

A counter whose state lives in the scope, backed by flutter_riverpod:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';

/// Declared once, read anywhere below the scope.
final counterState = AppState<int>(() => 0, debugName: 'counter');

void main() {
  runApp(
    const StateScope(
      adapter: RiverpodStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}

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
```

Replacing `RiverpodStateAdapter()` with another adapter is the only change needed to run the same app on another library.

For a full app with routes, app-wide state and a library picker, see the [example app](https://github.com/EugenioTesio/switchable_state/tree/main/example).
