## 0.1.0

- Initial release.
- `StateAdapter` and `StateStore`: one contract with `value`, `replace`, `update`, `watch`, `select` and `close`.
- `StateScope` and `AppState`: app-wide stores created on first read and kept until the scope is disposed.
- `AppState.grouped` and `StateScope.group`: stores shared by a group of routes, for example inside a go_router `ShellRoute`.
- `StateStoreOwner`: stores owned by one route and closed with it.
- `overrides`: seed any state's initial value, usually in tests.
