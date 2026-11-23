import 'package:flutter/widgets.dart';

import 'state_adapter.dart';

/// A zero-dependency [StateAdapter] backed only by Flutter's [ValueNotifier].
///
/// Use it for tests, prototypes, or apps that want [StateScope] and
/// [StateStore] without adding a third-party state-management library.
final class ValueNotifierStateAdapter implements StateAdapter {
  /// Creates the adapter.
  ///
  /// It is stateless, so one `const` instance serves the whole app.
  const ValueNotifierStateAdapter();

  @override
  StateStore<S> create<S>(S initial) => _ValueNotifierStore<S>(initial);
}

final class _ValueNotifierStore<S> implements StateStore<S> {
  _ValueNotifierStore(S initial) : _notifier = ValueNotifier<S>(initial);

  final ValueNotifier<S> _notifier;
  bool _closed = false;

  @override
  S get value => _notifier.value;

  @override
  bool get isClosed => _closed;

  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    if (_notifier.value == next) return;
    _notifier.value = next;
  }

  @override
  Widget watch(Widget Function(S state) render) => ValueListenableBuilder<S>(
    valueListenable: _notifier,
    builder: (context, state, _) => render(state),
  );

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      _ValueNotifierSelect<S, R>(
        notifier: _notifier,
        pick: pick,
        render: render,
      );

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (_closed) return () {};
    var previous = _notifier.value;
    var canceled = false;
    void listener() {
      if (canceled || _closed) return;
      final current = _notifier.value;
      if (current == previous) return;
      final prev = previous;
      previous = current;
      onChange(prev, current);
    }

    _notifier.addListener(listener);
    return () {
      if (canceled) return;
      canceled = true;
      if (!_closed) {
        _notifier.removeListener(listener);
      }
    };
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _notifier.dispose();
  }
}

final class _ValueNotifierSelect<S, R> extends StatefulWidget {
  const _ValueNotifierSelect({
    required this.notifier,
    required this.pick,
    required this.render,
  });

  final ValueNotifier<S> notifier;
  final R Function(S state) pick;
  final Widget Function(R value) render;

  @override
  State<_ValueNotifierSelect<S, R>> createState() =>
      _ValueNotifierSelectState<S, R>();
}

final class _ValueNotifierSelectState<S, R>
    extends State<_ValueNotifierSelect<S, R>> {
  late R _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.pick(widget.notifier.value);
    widget.notifier.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_ValueNotifierSelect<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notifier, widget.notifier)) {
      oldWidget.notifier.removeListener(_onChange);
      widget.notifier.addListener(_onChange);
    }
  }

  void _onChange() {
    if (!mounted) return;
    if (widget.pick(widget.notifier.value) != _picked) setState(() {});
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _picked = widget.pick(widget.notifier.value);
    return widget.render(_picked);
  }
}
