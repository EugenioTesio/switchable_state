/// @docImport 'state_listener.dart';
/// @docImport 'state_scope.dart';
/// @docImport 'value_notifier_adapter.dart';
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Creates [StateStore]s backed by one state-management library.
///
/// An app registers one stateless adapter at startup, usually through a root
/// [StateScope]. Built-in and official adapters include
/// [ValueNotifierStateAdapter], `CubitStateAdapter`, `GetXStateAdapter`,
/// `MobXStateAdapter`, `ProviderStateAdapter` and `RiverpodStateAdapter`. To
/// write another one, check it with `stateStoreContract` from
/// `switchable_state_test`.
abstract interface class StateAdapter {
  /// Creates an independent store that starts at [initial] and is owned by
  /// the caller, which must [StateStore.close] it.
  StateStore<S> create<S>(S initial);
}

/// Holds one immutable snapshot of type [S] and renders it with the
/// adapter's library.
///
/// Replace the whole snapshot with [replace] or [StateStoreUpdates.update],
/// rebuild widgets with [watch] or [select], and react to changes outside
/// `build` with [listen] or [StateListener].
abstract interface class StateStore<S> {
  /// The current snapshot, immediately reflecting the most recent call to
  /// [replace].
  ///
  /// After [close] it keeps returning the last snapshot. Reading [value] never
  /// registers a reactive widget dependency.
  S get value;

  /// Whether [close] has been called on this store.
  bool get isClosed;

  /// Publishes [next] to every watching widget and listener.
  ///
  /// Does nothing when [next] is `==` to [value]. Throws a [StateError] after
  /// [close] and leaves [value] unchanged.
  void replace(S next);

  /// Renders the current snapshot on mount and follows subsequent changes.
  ///
  /// Flutter may combine multiple writes into one rendered frame. Some
  /// libraries deliver a change after a microtask (Cubit uses a stream), so a
  /// widget test should pump until the tree settles after a write.
  Widget watch(Widget Function(S state) render);

  /// Renders the value returned by [pick] and rebuilds only when it changes,
  /// compared with `==`.
  ///
  /// Use it to rebuild for one part of a snapshot, like `BlocSelector` or
  /// Provider's `Selector`. [pick] must be pure. When a parent rebuilds with
  /// a different [pick], the new one applies to the current snapshot.
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render);

  /// Registers [onChange] to be called with the previous and next snapshots
  /// whenever the snapshot changes.
  ///
  /// Returns a [VoidCallback] that cancels the subscription. Calling the
  /// returned callback more than once has no effect. If the store is already
  /// closed, returns a no-op callback and never invokes [onChange].
  ///
  /// Most adapters call [onChange] inside the write; a Cubit delivers it
  /// shortly after, through its stream. A write can happen while Flutter
  /// builds, so run side effects that touch other widgets (navigation, snack
  /// bars, dialogs) through [StateListener], which always defers them until
  /// the write has returned.
  VoidCallback listen(void Function(S previous, S current) onChange);

  /// Releases the native store and prevents further writes.
  ///
  /// Called by the owner after the widgets that watch this store unmount.
  /// Later calls have no effect.
  Future<void> close();
}

/// Creates the [StateError] every adapter throws from [StateStore.replace] and
/// [StateStoreUpdates.update] after [StateStore.close].
///
/// Using this helper ensures misuse fails the same way whichever library is
/// registered.
StateError closedStoreError() =>
    StateError('Cannot replace the snapshot of a closed StateStore.');

/// Updates and adapts a [StateStore] from its current snapshot.
extension StateStoreUpdates<S> on StateStore<S> {
  /// Replaces the snapshot with `change(value)`, reading the latest snapshot
  /// even after an async gap.
  ///
  /// Throws a [StateError] before invoking [change] if [isClosed] is `true`.
  /// Does nothing when the result is `==` to the current snapshot.
  void update(S Function(S current) change) {
    if (isClosed) throw closedStoreError();
    final current = value;
    final next = change(current);
    if (next != current) replace(next);
  }

  /// Exposes this store as a [ValueListenable] for Flutter APIs such as
  /// `GoRouter.refreshListenable` or [ValueListenableBuilder].
  ///
  /// The result holds a [StateStore.listen] subscription only while it has
  /// listeners, so it needs no disposal, and calling this inline in `build`
  /// leaks nothing.
  StateStoreValueListenable<S> asListenable() =>
      StateStoreValueListenable<S>(this);
}

/// Adapts a [StateStore] to Flutter's [ValueListenable] interface.
///
/// It subscribes to the store when its first listener is added and cancels
/// that subscription when its last listener is removed.
final class StateStoreValueListenable<S> implements ValueListenable<S> {
  /// Creates a [ValueListenable] backed by [store].
  StateStoreValueListenable(StateStore<S> store) : _store = store;

  final StateStore<S> _store;
  final List<VoidCallback> _listeners = [];
  VoidCallback? _cancel;

  @override
  S get value => _store.value;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    _cancel ??= _store.listen((_, _) => _notifyListeners());
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    if (_listeners.isNotEmpty) return;
    final cancel = _cancel;
    _cancel = null;
    cancel?.call();
  }

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      // Like ChangeNotifier, skip listeners removed by an earlier one.
      if (!_listeners.contains(listener)) continue;
      try {
        listener();
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'switchable_state',
            context: ErrorDescription('while notifying $runtimeType listeners'),
          ),
        );
      }
    }
  }
}
