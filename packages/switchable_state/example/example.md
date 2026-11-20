# switchable_state example

## A counter

```dart
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';

/// Declared once, read anywhere below the scope.
final counterState = AppState<int>(() => 0, debugName: 'counter');

void main() {
  runApp(
    const StateScope(
      adapter: RiverpodStateAdapter(), // or CubitStateAdapter(), GetXStateAdapter(), ...
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

## A full app

The [example app](https://github.com/EugenioTesio/switchable_state/tree/main/example) starts by asking which library to use, injects that adapter, and routes to a Transactions screen with go_router:

- `/transactions` owns its own store (`StateStoreOwner.createStore`), closed when the route goes away.
- Starred transactions are app-wide (`AppState`), shared with `/starred` without passing anything between screens.
- **Change** goes back to the library picker and closes every store, so the next library starts fresh.

```sh
git clone https://github.com/EugenioTesio/switchable_state.git
cd switchable_state/example
flutter run
```
