/// A `switchable_state` adapter backed by `package:get`.
///
/// Register [GetXStateAdapter] in the root [StateScope]:
///
/// ```dart
/// StateScope(
///   adapter: const GetXStateAdapter(),
///   child: const MyApp(),
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, ObjectFlagProperty;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' show Obx, Rx;
import 'package:switchable_state/switchable_state.dart';

/// A [StateAdapter] backed by GetX.
///
/// Each store is an [Rx] value. [StateStore.watch] uses [Obx], and
/// [StateStore.select] rebuilds only when the picked value changes, which
/// GetX has no widget for. It needs no `GetMaterialApp` and works with any
/// router; the owning scope, not GetX bindings, decides when a store closes.
final class GetXStateAdapter implements StateAdapter {
  /// Creates the adapter.
  ///
  /// It is stateless, so one `const` instance serves the whole app.
  const GetXStateAdapter();

  @override
  StateStore<S> create<S>(S initial) => _GetXStore<S>(initial);
}

final class _GetXStore<S> implements StateStore<S> {
  _GetXStore(S initial) : _value = initial, _state = Rx<S>(initial);

  S _value;
  final Rx<S> _state;
  bool _closed = false;

  // Return a plain field rather than _state.value so reading value inside
  // another store's Obx does not register a reactive dependency on this store.
  @override
  S get value => _value;

  @override
  bool get isClosed => _closed;

  // A closed Rx silently ignores writes, so reject them explicitly.
  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    if (_value == next) return;
    _value = next;
    _state.value = next;
  }

  @override
  Widget watch(Widget Function(S) render) =>
      _GetXWatch<S>(state: _state, render: render);

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) =>
      _GetXSelect<S, R>(store: this, pick: pick, render: render);

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (_closed || _state.subject.isClosed) return () {};
    var previous = _value;
    var canceled = false;
    final subscription = _state.listen((next) {
      if (canceled || _closed) return;
      final prev = previous;
      previous = next;
      onChange(prev, next);
    });
    return () {
      if (canceled) return;
      canceled = true;
      if (!_state.subject.isClosed) {
        unawaited(subscription.cancel());
      }
    };
  }

  // Rx.close asserts when called twice.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _state.close();
  }
}

/// Wraps [Obx] keyed by [state] inside its own widget so multiple watchers of
/// the same store can be siblings without duplicate keys, while swapping to a
/// different store in the same slot still disposes the old [Obx] state.
final class _GetXWatch<S> extends StatelessWidget {
  const _GetXWatch({required this.state, required this.render});

  final Rx<S> state;
  final Widget Function(S) render;

  @override
  Widget build(BuildContext context) =>
      Obx(() => render(state.value), key: ObjectKey(state));
}

/// GetX has no selector widget: Obx rebuilds on every change of the Rx it
/// reads. This listens to the Rx and rebuilds only when the pick changes.
final class _GetXSelect<S, R> extends StatefulWidget {
  const _GetXSelect({
    required this.store,
    required this.pick,
    required this.render,
  });

  final _GetXStore<S> store;
  final R Function(S) pick;
  final Widget Function(R) render;

  @override
  State<_GetXSelect<S, R>> createState() => _GetXSelectState<S, R>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ObjectFlagProperty<Function>.has('pick', pick))
      ..add(ObjectFlagProperty<Function>.has('render', render));
  }
}

final class _GetXSelectState<S, R> extends State<_GetXSelect<S, R>> {
  StreamSubscription<S>? _subscription;
  late R _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.pick(widget.store.value);
    _subscribe(widget.store);
  }

  void _subscribe(_GetXStore<S> store) {
    if (!store._state.subject.isClosed) {
      _subscription = store._state.listen(_onChange);
    }
  }

  void _unsubscribe(_GetXStore<S> store) {
    final sub = _subscription;
    _subscription = null;
    if (sub != null && !store._state.subject.isClosed) {
      unawaited(sub.cancel());
    }
  }

  @override
  void didUpdateWidget(_GetXSelect<S, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store)) {
      _unsubscribe(oldWidget.store);
      _subscribe(widget.store);
    }
  }

  void _onChange(S next) {
    if (!mounted) return;
    if (widget.pick(next) != _picked) setState(() {});
  }

  @override
  void dispose() {
    _unsubscribe(widget.store);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pick from the live value so a new pick from a parent rebuild applies.
    _picked = widget.pick(widget.store.value);
    return widget.render(_picked);
  }
}
