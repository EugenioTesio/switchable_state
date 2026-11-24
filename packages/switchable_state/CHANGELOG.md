## 0.2.0

Breaking changes for adapter authors:

- `StateStore` gains `isClosed` and `listen`, and `StateAdapter.create` drops the `extends Object` bound so snapshots can be nullable. An adapter written for 0.1 must implement both members; check it with `switchable_state_test` 0.2.
- `StateStore.replace` must ignore a snapshot `==` to the current one, the first write included.

New:

- Nullable snapshots, for example `AppState<User?>(() => null)`.
- `StateStore.listen`, and the `StateListener` widget for side effects such as navigation or snack bars. `StateListener` runs its listener after the write has returned on every adapter, so a write made while Flutter builds never runs a side effect mid-build.
- `asListenable()`: a `ValueListenable` for `ValueListenableBuilder` or go_router's `refreshListenable`. It listens to the store only while it has listeners, so it needs no disposal.
- `ValueNotifierStateAdapter`: a built-in adapter with no third-party dependency.
- `StateObserver`: create, change and close events for every store a scope hierarchy owns, registered with `StateScope(observers: ...)`.
- `StateFamily`: keys parameterized by an argument. A `StateScope.group` can own a whole `StateFamily.grouped`, so its members close with the group.
- `StateRegistry.reset` returns a store to its initial snapshot in place, for example on logout. Widgets holding the store see the reset and keep working.
- `StateScope.maybeOf`, `StateScope.inherit`, `AppState.overrideWithStore` and `context.store(state)`.
- A rebuilt `StateScope` applies new `overrides` and `observers` instead of ignoring them.

Fixes:

- Rebuilding a root with a non-const adapter of the same type, or a group with reordered `owns`, no longer trips an assertion.
- An `AppState` initializer can read another state; a cycle throws a `StateError`.
- A state first read through a wider type, such as `AppState<num>`, keeps its own type.
- A group moved under another root uses that root's adapter and observers.
- `StateRegistry.create` after disposal throws a `StateError`, and `update` on a closed store throws before calling `change`.

## 0.1.0

- Initial release.
- `StateAdapter` and `StateStore`: one contract with `value`, `replace`, `update`, `watch`, `select` and `close`.
- `StateScope` and `AppState`: app-wide stores created on first read and kept until the scope is disposed.
- `AppState.grouped` and `StateScope.group`: stores shared by a group of routes, for example inside a go_router `ShellRoute`.
- `StateStoreOwner`: stores owned by one route and closed with it.
- `overrides`: seed any state's initial value, usually in tests.
