## 0.2.0

- Requires `switchable_state` 0.2: nullable snapshots, `isClosed` and `listen`.
- Reading `value` inside an `Obx` no longer subscribes it to the store.
- Moving a watcher to another store in the same widget slot unsubscribes from the old `Rx`.
- Closing a store before its selectors unmount no longer throws, and a first `replace` equal to the initial snapshot no longer rebuilds.

## 0.1.0

- Initial release.
- `GetXStateAdapter`, backed by GetX 4.7: an `Rx` per store, `Obx` for rebuilds and a selector that rebuilds only when its pick changes.
