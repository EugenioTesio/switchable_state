# switchable_state_test example

A complete adapter built only on Flutter's `ValueNotifier`, checked with the conformance suite. `switchable_state` ships the same adapter as `ValueNotifierStateAdapter`, and this package's own tests run the suite against it: [value_notifier_adapter.dart](https://github.com/EugenioTesio/switchable_state/blob/main/packages/switchable_state/lib/src/value_notifier_adapter.dart).

```dart
import 'package:flutter/widgets.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_test/switchable_state_test.dart';

final class NotifierStateAdapter implements StateAdapter {
  const NotifierStateAdapter();

  @override
  StateStore<S> create<S>(S initial) => _NotifierStore<S>(initial);
}

final class _NotifierStore<S> implements StateStore<S> {
  _NotifierStore(S initial) : _notifier = ValueNotifier<S>(initial);

  final ValueNotifier<S> _notifier;
  bool _closed = false;

  @override
  S get value => _notifier.value;

  @override
  bool get isClosed => _closed;

  @override
  void replace(S next) {
    if (_closed) throw closedStoreError(); // the same error on every adapter
    if (_notifier.value == next) return; // equal writes notify no one
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
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (_closed) return () {};
    var previous = _notifier.value;
    void listener() {
      final current = _notifier.value;
      final before = previous;
      previous = current;
      onChange(before, current);
    }

    _notifier.addListener(listener);
    return () => _notifier.removeListener(listener);
  }

  @override
  Future<void> close() async {
    if (_closed) return; // later calls do nothing
    _closed = true;
    _notifier.dispose();
  }
}

/// Rebuilds only when the picked value changes.
final class _Select<S, R> extends StatefulWidget {
  const _Select({
    required this.notifier,
    required this.pick,
    required this.render,
  });

  final ValueNotifier<S> notifier;
  final R Function(S state) pick;
  final Widget Function(R value) render;

  @override
  State<_Select<S, R>> createState() => _SelectState<S, R>();
}

final class _SelectState<S, R> extends State<_Select<S, R>> {
  late R _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.pick(widget.notifier.value);
    widget.notifier.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_Select<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onChange);
      widget.notifier.addListener(_onChange);
    }
  }

  void _onChange() {
    if (mounted && widget.pick(widget.notifier.value) != _picked) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pick from the live value so a new pick from a parent rebuild applies.
    _picked = widget.pick(widget.notifier.value);
    return widget.render(_picked);
  }
}

void main() => stateStoreContract(const NotifierStateAdapter());
```
