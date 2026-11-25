## 0.2.0

- Requires `switchable_state` 0.2: nullable snapshots, `isClosed` and `listen`.
- `value` reads without reporting an observation, so it works under `ReactiveReadPolicy.always` and never subscribes the reader.
- `Observable` and `Computed` compare with `==`, like the other adapters.
- MobX observables read inside a `watch` or `select` render callback still rebuild it.

## 0.1.0

- Initial release.
- `MobXStateAdapter`, backed by MobX 2.7: an `Observable` per store, written inside actions, with `Observer` and `Computed` for rebuilds.
