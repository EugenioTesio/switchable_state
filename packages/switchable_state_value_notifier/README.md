# switchable_state_value_notifier

[![pub package](https://img.shields.io/pub/v/switchable_state_value_notifier.svg)](https://pub.dev/packages/switchable_state_value_notifier)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The `ValueNotifier` adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter, here backed only by Flutter itself, with no third-party dependency.

**[Documentation](https://switchable-state.vercel.app/)** · [API reference](https://pub.dev/documentation/switchable_state_value_notifier/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_value_notifier
```

## Use it

Pass `ValueNotifierStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_value_notifier/switchable_state_value_notifier.dart';

void main() {
  runApp(
    const StateScope(
      adapter: ValueNotifierStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to Flutter

| Contract | Flutter |
| --- | --- |
| Store | A `ValueNotifier` |
| `watch` | `ValueListenableBuilder` |
| `select` | A small widget that listens to the notifier and rebuilds only when the pick changes, compared with `==` |
| `listen` | `ValueNotifier.addListener` |
| `close` | `ValueNotifier.dispose` |

## Notes

- Use it for tests, prototypes, or apps that don't want a state-management dependency. Switching to another adapter later only changes the adapter passed to `StateScope`.
- It is also the smallest complete adapter, so its source is a good reference when [writing your own](https://switchable-state.vercel.app/guides/custom-adapter/).

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other adapters.
