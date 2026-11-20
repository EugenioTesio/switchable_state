# switchable_state_bloc

[![pub package](https://img.shields.io/pub/v/switchable_state_bloc.svg)](https://pub.dev/packages/switchable_state_bloc)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The [flutter_bloc (Cubit)](https://pub.dev/packages/flutter_bloc) adapter for [switchable_state](https://pub.dev/packages/switchable_state): one state-management contract for Flutter with five interchangeable libraries.

**[Documentation](https://switchable-state.vercel.app/adapters/bloc/)** · [switchable_state](https://switchable-state.vercel.app/) · [API reference](https://pub.dev/documentation/switchable_state_bloc/latest/)

## Install

```sh
flutter pub add switchable_state switchable_state_bloc
```

## Use it

Pass `CubitStateAdapter` to the root `StateScope`. Every screen below it reads its state from the scope, whichever library is behind it:

```dart
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';

void main() {
  runApp(
    const StateScope(
      adapter: CubitStateAdapter(),
      child: MaterialApp(home: CounterPage()),
    ),
  );
}
```

See the [switchable_state README](https://pub.dev/packages/switchable_state) for declaring state, reading it from widgets and choosing who owns each store.

## How it maps to flutter_bloc (Cubit)

| Contract | flutter_bloc (Cubit) |
| --- | --- |
| Store | A `Cubit<S>` that publishes with `emit` |
| `watch` | `BlocBuilder` bound to the store |
| `select` | `BlocSelector` |
| `close` | `Cubit.close` |

## Notes

- A `Cubit` delivers changes through a stream, so a rebuild can land one frame after the write. In widget tests, call `pumpAndSettle` after a write rather than a single `pump`.
- The store needs no `BlocProvider`: the `StateScope` that owns it decides when it closes.

This adapter passes the shared conformance suite from [switchable_state_test](https://pub.dev/packages/switchable_state_test), like the other four.
