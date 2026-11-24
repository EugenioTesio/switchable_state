/// One state-management contract for Flutter, and the scope that shares
/// its stores.
///
/// - [StateAdapter] and [StateStore] are the contract each library implements.
/// - [StateScope], [AppState], [StateFamily], [StateObserver], [StateListener],
///   and [StateStoreOwner] decide who owns a store, how long it lives, and how
///   side effects are observed.
///
/// Add one adapter package, for example `switchable_state_bloc`, and pass
/// its adapter to the root [StateScope]. An app only depends on the libraries
/// it uses; `switchable_state_value_notifier` needs none at all.
///
/// @docImport 'src/state_adapter.dart';
/// @docImport 'src/state_listener.dart';
/// @docImport 'src/state_scope.dart';
library;

export 'src/state_adapter.dart';
export 'src/state_listener.dart';
export 'src/state_scope.dart';
