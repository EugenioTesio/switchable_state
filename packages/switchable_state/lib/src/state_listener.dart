import 'dart:async';

import 'package:flutter/foundation.dart'
    show DiagnosticPropertiesBuilder, ObjectFlagProperty;
import 'package:flutter/widgets.dart';

import 'state_adapter.dart';

/// Runs one-shot side effects when a [StateStore] changes, without rebuilding
/// [child].
///
/// Use this for navigation, snack bars, dialogs, analytics, or logging—similar
/// to `BlocListener` or Riverpod's `ref.listen`.
///
/// [listener] always runs after the write that caused it has returned, in a
/// microtask, whichever adapter is registered. A write made while Flutter
/// builds, for example from a route's `initState`, therefore never runs a
/// side effect in the middle of that build.
final class StateListener<S> extends StatefulWidget {
  /// Creates a listener attached to [store].
  const StateListener({
    super.key,
    required this.store,
    required this.listener,
    this.listenWhen,
    required this.child,
  });

  /// The store whose changes trigger [listener].
  final StateStore<S> store;

  /// Invoked when [store] changes and [listenWhen] returns `true` (or is
  /// `null`).
  final void Function(BuildContext context, S state) listener;

  /// Optional predicate that filters which transitions invoke [listener].
  final bool Function(S previous, S current)? listenWhen;

  /// The widget subtree rendered without rebuilding on store changes.
  final Widget child;

  @override
  State<StateListener<S>> createState() => _StateListenerState<S>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ObjectFlagProperty<Function>.has('listener', listener))
      ..add(ObjectFlagProperty<Function?>.has('listenWhen', listenWhen));
  }
}

final class _StateListenerState<S> extends State<StateListener<S>> {
  VoidCallback? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final store = widget.store;
    _unsubscribe = store.listen((previous, current) {
      scheduleMicrotask(() => _deliver(store, previous, current));
    });
  }

  void _deliver(StateStore<S> store, S previous, S current) {
    // Drop events that arrive after unmounting or switching stores.
    if (!mounted || !identical(store, widget.store)) return;
    if (widget.listenWhen?.call(previous, current) ?? true) {
      widget.listener(context, current);
    }
  }

  @override
  void didUpdateWidget(StateListener<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store)) {
      _unsubscribe?.call();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _unsubscribe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
