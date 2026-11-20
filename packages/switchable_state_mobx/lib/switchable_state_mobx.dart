/// A `switchable_state` adapter backed by `package:mobx`.
///
/// Register [MobXStateAdapter] in the root `StateScope`:
///
/// ```dart
/// StateScope(
///   adapter: const MobXStateAdapter(),
///   child: const MyApp(),
/// )
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

import 'package:switchable_state/switchable_state.dart';

/// A [StateAdapter] backed by MobX.
///
/// Each store is an `Observable` that changes inside `runInAction`, so it
/// works with MobX's strictest write policy. [StateStore.watch] uses an
/// `Observer`, and [StateStore.select] reads a `Computed` inside one.
final class MobXStateAdapter implements StateAdapter {
  /// Creates the adapter. It is stateless, so one const instance serves the
  /// whole app.
  const MobXStateAdapter();

  @override
  StateStore<S> create<S extends Object>(S initial) => _MobXStore<S>(initial);
}

final class _MobXStore<S extends Object> implements StateStore<S> {
  _MobXStore(S initial) : _state = Observable<S>(initial);

  final Observable<S> _state;
  bool _closed = false;

  @override
  S get value => _state.value;

  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    runInAction(() => _state.value = next);
  }

  @override
  Widget watch(Widget Function(S) render) =>
      Observer(builder: (context) => render(_state.value));

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) =>
      _MobXSelect<S, R>(state: _state, pick: pick, render: render);

  // Observer owns its reaction and releases it when it unmounts. The
  // observable itself holds no resources, so closing only blocks writes.
  @override
  Future<void> close() async {
    _closed = true;
  }
}

/// Observes a [Computed] instead of the whole snapshot, so the [Observer]
/// only rebuilds when the picked value changes.
final class _MobXSelect<S extends Object, R> extends StatefulWidget {
  const _MobXSelect({
    required this.state,
    required this.pick,
    required this.render,
  });

  final Observable<S> state;
  final R Function(S) pick;
  final Widget Function(R) render;

  @override
  State<_MobXSelect<S, R>> createState() => _MobXSelectState<S, R>();
}

final class _MobXSelectState<S extends Object, R>
    extends State<_MobXSelect<S, R>> {
  late Computed<R> _picked = _compute();

  Computed<R> _compute() => Computed(() => widget.pick(widget.state.value));

  @override
  void didUpdateWidget(_MobXSelect<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A rebuilt parent may pass a different pick, so derive afresh.
    _picked = _compute();
  }

  @override
  Widget build(BuildContext context) =>
      Observer(builder: (context) => widget.render(_picked.value));
}
