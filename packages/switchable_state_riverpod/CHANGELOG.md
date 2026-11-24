## 0.2.0

- Requires `switchable_state` 0.2: nullable snapshots, `isClosed` and `listen`.
- Riverpod widgets inside `watch` and `select` still see the app's `ProviderScope` and its overrides.
- A write made while Flutter builds, for example from `initState`, no longer throws "Tried to modify a provider while the widget tree was building". `value` updates at once; watchers and listeners receive the write right after the frame.
- Moving a watcher to another store in the same widget slot releases the old scope.

## 0.1.0

- Initial release.
- `RiverpodStateAdapter`, backed by Riverpod 3.5: a `Notifier` in its own `ProviderContainer` per store, `Consumer` and `provider.select` for rebuilds.
