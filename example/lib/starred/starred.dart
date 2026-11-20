import 'package:switchable_state/switchable_state.dart';

/// The transactions the user starred, shared by every screen.
///
/// Rows are keyed by description because `TransactionEntry` has no id in
/// this sample. A real app should key them by a stable id.
final class StarredState {
  const StarredState._(this.descriptions);
  const StarredState.initial() : this._(const {});

  /// Starred descriptions, in the order they were starred.
  final Set<String> descriptions;

  int get count => descriptions.length;

  bool contains(String description) => descriptions.contains(description);

  StarredState toggled(String description) {
    final next = {...descriptions};
    if (!next.remove(description)) next.add(description);
    return StarredState._(Set.unmodifiable(next));
  }
}

/// App-wide and kept alive: the root `StateScope` creates the store when a
/// screen first reads it and keeps it until the app's scope is disposed.
final starredState = AppState<StarredState>(
  () => const StarredState.initial(),
  debugName: 'starred',
);
