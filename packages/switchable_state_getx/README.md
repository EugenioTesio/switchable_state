# switchable_state_getx

[![pub package](https://img.shields.io/pub/v/switchable_state_getx.svg)](https://pub.dev/packages/switchable_state_getx)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The [GetX](https://pub.dev/packages/get) adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter with five interchangeable libraries.

**[Documentation](https://switchable-state.vercel.app/adapters/getx/)** · [switchable_state](https://switchable-state.vercel.app/) · [API reference](https://pub.dev/documentation/switchable_state_getx/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_getx
```

## Use it

Pass `GetXStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_getx/switchable_state_getx.dart';

void main() {
  runApp(
    const StateScope(
      adapter: GetXStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to GetX

| Contract | GetX |
| --- | --- |
| Store | An `Rx<S>` |
| `watch` | `Obx` |
| `select` | A small widget that listens to the `Rx` and rebuilds only when the pick changes (GetX has no selector widget) |
| `close` | `Rx.close`, guarded so a second call does nothing |

## Notes

- It needs no `GetMaterialApp` and works with any router, including go_router.
- GetX bindings only dispose dependencies for routes GetX builds. Here the owning `StateScope` closes the store instead, so lifetimes are the same as with the other adapters.
- A closed `Rx` silently ignores writes; this adapter throws a `StateError` instead, like every adapter.

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other four.
