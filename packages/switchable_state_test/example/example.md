# switchable_state_test example

A complete adapter built only on Flutter's `ValueNotifier`, checked with the conformance suite. The same file lives in this package's tests: [value_notifier_adapter_test.dart](https://github.com/EugenioTesio/switchable_state/blob/main/packages/switchable_state_test/test/value_notifier_adapter_test.dart).

```dart
import 'package:flutter/widgets.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_test/switchable_state_test.dart';

final class ValueNotifierStateAdapter implements StateAdapter {
  const ValueNotifierStateAdapter();

  @override
  StateStore<S> create<S extends Object>(S initial) =>
      _ValueNotifierStore<S>(initial);
}

final class _ValueNotifierStore<S extends Object> implements StateStore<S> {
  _ValueNotifierStore(S initial) : _notifier = ValueNotifier<S>(initial);

  final ValueNotifier<S> _notifier;
  bool _closed = false;

  @override
  S get value => _notifier.value;

  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    _notifier.value = next;
  }

  @override
  Widget watch(Widget Function(S state) render) => ValueListenableBuilder<S>(
    valueListenable: _notifier,
    builder: (context, state, _) => render(state),
  );

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      _Select<S, R>(notifier: _notifier, pick: pick, render: render);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _notifier.dispose();
  }
}

// _Select listens to the notifier and calls setState only when
// pick(notifier.value) changes; see the linked file for the full widget.

void main() => stateStoreContract(const ValueNotifierStateAdapter());
```
