<p align="center">
  <img src="https://switchable-state.vercel.app/images/hero.svg" alt="One state contract connected to five interchangeable adapters: Cubit, GetX, MobX, Provider and Riverpod" width="640">
</p>

# switchable_state

[![pub package](https://img.shields.io/pub/v/switchable_state.svg)](https://pub.dev/packages/switchable_state)
[![CI](https://github.com/EugenioTesio/switchable_state/actions/workflows/ci.yaml/badge.svg)](https://github.com/EugenioTesio/switchable_state/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

One state-management contract for Flutter, with five interchangeable implementations: **Cubit, GetX, MobX, Provider and Riverpod**. Screens read state from a `StateScope` and never pass it to each other through constructors. Change one line at startup and the whole app runs on another library.

**[Documentation](https://switchable-state.vercel.app/)** · [Example app](https://github.com/EugenioTesio/switchable_state/tree/main/example) · [API reference](https://pub.dev/documentation/switchable_state/latest/)

## Packages

This package holds the contract and the scope. Add it together with the adapter for the library you use, so your app only depends on that library.

| Package | Library | Version |
| --- | --- | --- |
| `switchable_state` | Contract and `StateScope` | [![pub](https://img.shields.io/pub/v/switchable_state.svg)](https://pub.dev/packages/switchable_state) |
| `switchable_state_bloc` | flutter_bloc (Cubit) | [![pub](https://img.shields.io/pub/v/switchable_state_bloc.svg)](https://pub.dev/packages/switchable_state_bloc) |
| `switchable_state_getx` | GetX | [![pub](https://img.shields.io/pub/v/switchable_state_getx.svg)](https://pub.dev/packages/switchable_state_getx) |
| `switchable_state_mobx` | MobX | [![pub](https://img.shields.io/pub/v/switchable_state_mobx.svg)](https://pub.dev/packages/switchable_state_mobx) |
| `switchable_state_provider` | provider | [![pub](https://img.shields.io/pub/v/switchable_state_provider.svg)](https://pub.dev/packages/switchable_state_provider) |
| `switchable_state_riverpod` | flutter_riverpod | [![pub](https://img.shields.io/pub/v/switchable_state_riverpod.svg)](https://pub.dev/packages/switchable_state_riverpod) |
| `switchable_state_value_notifier` | Flutter only (`ValueNotifier`) | [![pub](https://img.shields.io/pub/v/switchable_state_value_notifier.svg)](https://pub.dev/packages/switchable_state_value_notifier) |
| `switchable_state_test` | Conformance tests for adapters | [![pub](https://img.shields.io/pub/v/switchable_state_test.svg)](https://pub.dev/packages/switchable_state_test) |

## Install

```sh
flutter pub add switchable_state switchable_state_riverpod
```

## Quick start

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

The same code passes the same tests on all five adapters. `context.store(counterState)` is a shorter way to write `StateScope.of(context).store(counterState)`.

## The contract

A `StateStore<S>` holds one immutable snapshot:

| Member | What it does |
| --- | --- |
| `value` | The current snapshot. After `close` it keeps the last one. |
| `isClosed` | Whether `close` has been called. |
| `replace(next)` | Publishes a new snapshot. Throws a `StateError` after `close`. |
| `update(change)` | Replaces the snapshot with `change(value)`, and skips equal results. |
| `watch(render)` | A widget that rebuilds on every change. |
| `select(pick, render)` | A widget that rebuilds only when `pick`'s result changes (`==`). |
| `listen(onChange)` | Calls `onChange(previous, current)` on every change. Returns a callback that cancels it. |
| `asListenable()` | A `ValueListenable`, for `ValueListenableBuilder` or go_router's `refreshListenable`. |
| `close()` | Releases the library's store. Later calls do nothing. |

Snapshots can be nullable, for example `AppState<User?>(() => null)`.

A `StateAdapter` creates stores with one library. Each adapter uses that library's own tools: `BlocSelector`, `Selector`, `provider.select`, a MobX `Computed`, or a GetX `Rx` listener.

## Side effects

`StateListener` runs a one-shot side effect, such as a snack bar or navigation, when a store changes, without rebuilding its child. It is the counterpart of `BlocListener` or Riverpod's `ref.listen`, and it runs after the write has returned on every adapter, so a write made during a build never runs a side effect mid-build.

```dart
StateListener<TransactionsState>(
  store: store,
  listenWhen: (previous, current) =>
      previous.status != LoadStatus.failed && current.status == LoadStatus.failed,
  listener: (context, state) => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Couldn’t load transactions.'))),
  child: const TransactionsView(),
)
```

## Who owns a store

App-wide state is decided by who owns a store, not by a setting in each library.

| Declaration | Owner and lifetime | Similar to |
| --- | --- | --- |
| `AppState(...)` | The root `StateScope`. Created on first read, kept until the scope is disposed. | A keep-alive Riverpod provider, a `BlocProvider` above the app |
| `AppState.grouped(...)` | The `StateScope.group` that lists it, for example in a go_router `ShellRoute`. Closes when the user leaves the group. | A provider inside a `ShellRoute` |
| `StateFamily(...)`, `StateFamily.grouped(...)` | One key per argument: `todoState(id)`. Equal arguments share a store. A group that owns a grouped family owns all its members. | A Riverpod `family` |
| `createStore(...)` in a `State` with `StateStoreOwner` | One route. Closes after the route's own `dispose`. | `autoDispose`, `BlocProvider(create:)` |

`StateScope.of(context)` registers no rebuild dependency, so it is safe in `initState`. Widgets rebuild through `watch` or `select`. `StateScope.maybeOf(context)` returns `null` instead of throwing, and `StateScope.inherit` passes a scope's stores into a dialog or bottom sheet without owning them.

```dart
final class _TransactionsPageState extends State<TransactionsPage>
    with StateStoreOwner<TransactionsPage> {
  late final StateStore<TransactionsState> _store;

  @override
  void initState() {
    super.initState();
    _store = createStore(const TransactionsState.initial()); // closed with the route
  }
}
```

To start a store over, for example on logout, call `StateScope.of(context).reset(sessionState)`. The store keeps its identity, so widgets and listeners holding it see the reset like any other write.

## Observers

A `StateObserver` sees every store the scope hierarchy creates, changes and closes, whichever adapter runs. Use it for logging, analytics or debugging:

```dart
final class LoggingObserver extends StateObserver {
  @override
  void onChange(AppState<Object?> state, Object? previous, Object? next) =>
      debugPrint('$state: $previous -> $next');
}

StateScope(
  adapter: const RiverpodStateAdapter(),
  observers: [LoggingObserver()],
  child: const MyApp(),
)
```

## Testing

Start any state from a prepared value with `overrides`:

```dart
await tester.pumpWidget(
  StateScope(
    adapter: const CubitStateAdapter(),
    overrides: [counterState.overrideWith(() => 41)],
    child: const MaterialApp(home: CounterPage()),
  ),
);
```

`overrideWithStore(() => fakeStore)` replaces a state's store with your own, for fakes or spies.

Writing your own adapter? Run the same conformance suite as the official ones with [`switchable_state_test`](https://pub.dev/packages/switchable_state_test).

## Library differences

The contract hides most differences. These remain:

- **Cubit** delivers changes through a stream, so a rebuild can land one frame after the write. In widget tests, call `pumpAndSettle` after a write.
- **Riverpod** stops listening under a route covered by `push()` and catches up when the route is shown again. The other four keep rebuilding while hidden.
- **GetX** only disposes dependencies for routes it builds itself. With this package the owning scope closes the store, whatever router you use.

## Learn more

- [Getting started](https://switchable-state.vercel.app/getting-started/)
- [Side effects and observers](https://switchable-state.vercel.app/concepts/observing/)
- [Store lifetimes with go_router](https://switchable-state.vercel.app/guides/go-router/)
- [Comparison with the five libraries](https://switchable-state.vercel.app/reference/comparison/)
- [The example app](https://github.com/EugenioTesio/switchable_state/tree/main/example): pick a library at startup, then browse and star transactions.

## Contributors

- [Eugenio Tesio](https://github.com/EugenioTesio)
- [Alan Monteiro](https://github.com/alanmonteiro32)

See all [contributors on GitHub](https://github.com/EugenioTesio/switchable_state/graphs/contributors).
