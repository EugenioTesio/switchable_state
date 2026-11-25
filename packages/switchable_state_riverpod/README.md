# switchable_state_riverpod

[![pub package](https://img.shields.io/pub/v/switchable_state_riverpod.svg)](https://pub.dev/packages/switchable_state_riverpod)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter with five interchangeable libraries.

**[Documentation](https://switchable-state.vercel.app/adapters/riverpod/)** · [switchable_state](https://switchable-state.vercel.app/) · [API reference](https://pub.dev/documentation/switchable_state_riverpod/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_riverpod
```

## Use it

Pass `RiverpodStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';

void main() {
  runApp(
    const StateScope(
      adapter: RiverpodStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to flutter_riverpod

| Contract | flutter_riverpod |
| --- | --- |
| Store | A `Notifier<S>` in a `ProviderContainer` that the store owns |
| `watch` | `Consumer` inside an `UncontrolledProviderScope` |
| `select` | `ref.watch(provider.select(pick))` |
| `close` | `ProviderContainer.dispose` |

## Notes

- Your app needs no `ProviderScope`: each store owns its container, and every widget that watches it shares that container.
- A `Consumer` under a route covered by `push()` stops listening while hidden (`TickerMode` off) and catches up when the route is shown again. The other adapters keep rebuilding while hidden; both show the latest state.
- flutter_riverpod 3.5 depends on `flutter_test`, so pub.dev doesn't list it, or this adapter, as web compatible.

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other four.

## Contributors

- [Eugenio Tesio](https://github.com/EugenioTesio)
- [Alan Monteiro](https://github.com/alanmonteiro32)

See all [contributors on GitHub](https://github.com/EugenioTesio/switchable_state/graphs/contributors).
