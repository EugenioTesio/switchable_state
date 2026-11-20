# switchable_state_provider

[![pub package](https://img.shields.io/pub/v/switchable_state_provider.svg)](https://pub.dev/packages/switchable_state_provider)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The [provider](https://pub.dev/packages/provider) adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter with five interchangeable libraries.

**[Documentation](https://switchable-state.vercel.app/adapters/provider/)** · [switchable_state](https://switchable-state.vercel.app/) · [API reference](https://pub.dev/documentation/switchable_state_provider/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_provider
```

## Use it

Pass `ProviderStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';

void main() {
  runApp(
    const StateScope(
      adapter: ProviderStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to provider

| Contract | provider |
| --- | --- |
| Store | A `ChangeNotifier` that notifies only when the snapshot changes |
| `watch` | `ChangeNotifierProvider.value` with a `Consumer` |
| `select` | `Selector` that compares with `==` instead of its default deep equality |
| `close` | `ChangeNotifier.dispose` |

## Notes

- Each store is provided with `.value`, so unmounting a watcher never disposes it; the owning `StateScope` does.
- Stores are looked up by declaration, not by type, so two states of the same type never collide.

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other four.
