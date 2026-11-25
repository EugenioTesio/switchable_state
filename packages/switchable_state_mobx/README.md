# switchable_state_mobx

[![pub package](https://img.shields.io/pub/v/switchable_state_mobx.svg)](https://pub.dev/packages/switchable_state_mobx)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The [MobX](https://pub.dev/packages/flutter_mobx) adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter with five interchangeable libraries.

**[Documentation](https://switchable-state.vercel.app/adapters/mobx/)** · [switchable_state](https://switchable-state.vercel.app/) · [API reference](https://pub.dev/documentation/switchable_state_mobx/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_mobx
```

## Use it

Pass `MobXStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';

void main() {
  runApp(
    const StateScope(
      adapter: MobXStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to MobX

| Contract | MobX |
| --- | --- |
| Store | An `Observable<S>` changed inside `runInAction` |
| `watch` | `Observer` |
| `select` | A `Computed` read inside an `Observer` |
| `close` | Stops accepting writes |

## Notes

- Writes run inside an action, so the strictest MobX write policy accepts them.
- No code generation: the snapshot is one observable value, and `Computed` recalculates only the picked part.

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other four.

## Contributors

- [Eugenio Tesio](https://github.com/EugenioTesio)
- [Alan Monteiro](https://github.com/alanmonteiro32)

See all [contributors on GitHub](https://github.com/EugenioTesio/switchable_state/graphs/contributors).
