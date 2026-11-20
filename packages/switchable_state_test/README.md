# switchable_state_test

[![pub package](https://img.shields.io/pub/v/switchable_state_test.svg)](https://pub.dev/packages/switchable_state_test)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The conformance suite for [switchable_state](https://pub.dev/packages/switchable_state) adapters. The Cubit, GetX, MobX, Provider and Riverpod adapters all pass it; run it against your own `StateAdapter` to prove that screens behave the same whichever library is registered.

**[Write your own adapter](https://eugeniotesio.github.io/switchable_state/guides/custom-adapter/)** · [API reference](https://pub.dev/documentation/switchable_state_test/latest/)

## Install

```sh
flutter pub add --dev switchable_state_test
```

## Use it

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_test/switchable_state_test.dart';

import 'package:my_adapter/my_adapter.dart';

void main() {
  stateStoreContract(const MyStateAdapter());

  // Then add tests for your own binding.
}
```

## What it checks

- **`value`:** the initial snapshot, writes visible immediately, `update` applied to the latest snapshot, and independent stores.
- **`watch`:** renders on mount, updates every watcher, ignores unrelated stores, uses a new render function after a parent rebuild, and survives remounting.
- **`select`:** rebuilds only when the picked value changes, applies a new pick to the current snapshot, and follows two stores when nested.
- **Hidden routes:** watchers under `TickerMode(enabled: false)` catch up once shown.
- **`close`:** `value` keeps the last snapshot, `replace` throws a `StateError`, and later `close` calls do nothing.

One difference between libraries is allowed. Riverpod stops listening while a route is hidden and catches up when shown; pass `pausesHiddenWatchers: true` if your adapter does the same.

`host(child)` wraps a widget in the text direction that `Text` needs, for widget tests without an app.
