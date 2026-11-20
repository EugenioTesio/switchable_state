import 'package:flutter/widgets.dart';

/// Creates [StateStore]s backed by one state-management library.
///
/// An app registers one stateless adapter at startup, usually through a root
/// [StateScope]. The official adapters are `CubitStateAdapter`,
/// `GetXStateAdapter`, `MobXStateAdapter`, `ProviderStateAdapter` and
/// `RiverpodStateAdapter`, each in its own package. To write another one,
/// check it with `stateStoreContract` from `switchable_state_test`.
abstract interface class StateAdapter {
  /// Creates an independent store that starts at [initial] and is owned by
  /// the caller, which must [StateStore.close] it.
  StateStore<S> create<S extends Object>(S initial);
}

/// Holds one immutable snapshot of type [S] and renders it with the
/// adapter's library.
///
/// Replace the whole snapshot with [replace] or [StateStoreUpdates.update];
/// rebuild widgets with [watch] or [select].
abstract interface class StateStore<S extends Object> {
  /// Immediately reflects the most recent call to [replace].
  ///
  /// After [close] it keeps returning the last snapshot.
  S get value;

  /// Publishes [next] to every watching widget.
  ///
  /// Throws a [StateError] after [close] and leaves [value] unchanged.
  void replace(S next);

  /// Renders the current snapshot on mount and follows subsequent changes.
  ///
  /// Flutter may combine multiple writes into one rendered frame. Some
  /// libraries deliver a change after a microtask (Cubit uses a stream), so a
  /// widget test should pump until the tree settles after a write.
  Widget watch(Widget Function(S state) render);

  /// Like [watch], but calls [render] only when [pick]'s result changes,
  /// compared with `==`.
  ///
  /// Use it to rebuild for one part of a snapshot, like `BlocSelector` or
  /// Provider's `Selector`. [pick] must be pure. When a parent rebuilds with
  /// a different [pick], the new one applies to the current snapshot.
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render);

  /// Called by the owner after the widgets that watch this store unmount.
  ///
  /// Releases the native store. Later calls have no effect.
  Future<void> close();
}

/// The error every adapter throws from [StateStore.replace] after
/// [StateStore.close], so misuse fails the same way whichever library is
/// registered.
StateError closedStoreError() =>
    StateError('Cannot replace the snapshot of a closed StateStore.');

/// Updates a [StateStore] from its current snapshot.
extension StateStoreUpdates<S extends Object> on StateStore<S> {
  /// Replaces the snapshot with `change(value)`, reading the latest snapshot
  /// even after an async gap. Does nothing when the result is `==` to it.
  void update(S Function(S current) change) {
    final current = value;
    final next = change(current);
    if (next != current) replace(next);
  }
}
