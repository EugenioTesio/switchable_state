import 'package:flutter/widgets.dart';
import 'package:switchable_state/switchable_state.dart';
import 'package:switchable_state_test/switchable_state_test.dart';

/// A reference adapter built only on Flutter's [ValueNotifier]. It shows the
/// least an adapter needs to pass the contract, and proves the contract does
/// not depend on any state-management library.
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
    if (widget.pick(widget.notifier.value) != _picked) setState(() {});
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

void main() => stateStoreContract(const ValueNotifierStateAdapter());
