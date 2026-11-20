# switchable_state example

A transactions app for the [switchable_state](../packages/switchable_state) packages.

1. The start screen (`/`) asks which library to use: Cubit, GetX, MobX, Provider or Riverpod.
2. Picking one registers its `StateAdapter` in `get_it` and opens `/transactions`.
3. Transactions and Starred sit in a go_router `ShellRoute` whose `StateScope` is built from that adapter. A bar at the bottom shows the active library; **Change** goes back to the start screen and disposes every store.

| Path | Screen | Reads |
| --- | --- | --- |
| `/` | `StateManagementPage` | Nothing. It registers the chosen adapter. |
| `/transactions` | `TransactionsPage` | Its own route store (`createStore`), plus the app-wide starred store |
| `/starred` | `StarredPage` | The app-wide starred store |

Starred rows are keyed by description because `TransactionEntry` has no id. A real app should key them by a stable id.

## Run it

From the repository root, resolve the workspace, then run the app:

```sh
flutter pub get
cd example
flutter run
```

The example includes an iOS runner. For another platform, generate its runner first, for example `flutter create --platforms=android --no-pub .` inside `example/`.

## Tests

- `widget_test.dart`: the app starts on the choice; choosing injects the adapter and opens Transactions; changing library starts every store over; unchosen deep links redirect to the choice; Riverpod keeps its containers across a rebuild; late responses are ignored.
- `app_router_test.dart`, for each library: `go()` rebuilds route state but keeps starred state, a route covered by `push()` shows the latest state on pop, and changing library closes the scope's stores. It also checks that an override seeds state.
- `route_group_scope_test.dart`, for each library: a `StateScope.group` in a `ShellRoute` keeps state across its routes, closes it on leaving and starts over on return, while app-wide state is kept.
- `transactions_page_test.dart` runs the Transactions screen against all five adapters: loading, filtering, failed refreshes, late responses, and starring rows.
- `readme_counter_test.dart` keeps the README's counter compiling and working on all five adapters.
- `transactions_test.dart` and `starred_test.dart` cover the controller and the starred snapshot.
