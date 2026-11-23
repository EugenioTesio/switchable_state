/// One state-management contract for Flutter, and the scope that shares
/// its stores.
///
/// - [StateAdapter], [StateStore], and [ValueNotifierStateAdapter] form the
///   contract each library implements.
/// - [StateScope], [AppState], [StateFamily], [StateObserver], [StateListener],
///   and [StateStoreOwner] decide who owns a store, how long it lives, and how
///   side effects are observed.
///
/// Add one adapter package, for example `switchable_state_bloc`, and pass
/// its adapter to the root [StateScope], or use the built-in
/// [ValueNotifierStateAdapter] with zero third-party dependencies.
library;

export 'src/state_adapter.dart';
export 'src/state_listener.dart';
export 'src/state_scope.dart';
export 'src/value_notifier_adapter.dart';
