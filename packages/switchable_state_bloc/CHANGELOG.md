## 0.2.0

- Requires `switchable_state` 0.2: nullable snapshots, `isClosed` and `listen`.
- A first `replace` equal to the initial snapshot no longer notifies watchers.
- `select` applies its pick again on every parent rebuild, even an `==` method tear-off that now reads other data, which `BlocSelector` alone would skip.

## 0.1.0

- Initial release.
- `CubitStateAdapter`, backed by flutter_bloc 9.1: a `Cubit` per store, `BlocBuilder` and `BlocSelector` for rebuilds.
