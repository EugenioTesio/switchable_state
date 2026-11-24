## 0.2.0

- Initial release.
- `ValueNotifierStateAdapter`, backed only by Flutter's `ValueNotifier`: a `ValueNotifier` per store, `ValueListenableBuilder` for `watch` and a selector that rebuilds only when its pick changes. It adds no third-party dependency.
