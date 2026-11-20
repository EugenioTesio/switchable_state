/// One state-management contract for Flutter, and the scope that shares
/// its stores.
///
/// - [StateAdapter] and [StateStore] are the contract each library implements.
/// - [StateScope], [AppState] and [StateStoreOwner] decide who owns a store
///   and how long it lives: app-wide, for a group of routes, or for one route.
///
/// Add one adapter package, for example `switchable_state_bloc`, and pass
/// its adapter to the root [StateScope]. An app only depends on the
/// libraries it uses.
library;

export 'src/state_adapter.dart';
export 'src/state_scope.dart';
