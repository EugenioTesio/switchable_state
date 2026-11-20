/// A `switchable_state` adapter backed by `package:provider`.
///
/// Register [ProviderStateAdapter] in the root `StateScope`:
///
/// ```dart
/// StateScope(
///   adapter: const ProviderStateAdapter(),
///   child: const MyApp(),
/// )
/// ```
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/widgets.dart' show Widget;
import 'package:provider/provider.dart';

import 'package:switchable_state/switchable_state.dart';

/// A [StateAdapter] backed by Provider.
///
/// Each store is a `ChangeNotifier` that notifies only when the snapshot
/// changes. [StateStore.watch] uses `ChangeNotifierProvider.value` with a
/// `Consumer`, and [StateStore.select] a `Selector` that compares with `==`.
final class ProviderStateAdapter implements StateAdapter {
  /// Creates the adapter. It is stateless, so one const instance serves the
  /// whole app.
  const ProviderStateAdapter();

  @override
  StateStore<S> create<S extends Object>(S initial) =>
      _ProviderStore<S>(initial);
}

final class _ProviderStore<S extends Object> extends ChangeNotifier
    implements StateStore<S> {
  _ProviderStore(this._value);

  S _value;
  bool _closed = false;

  @override
  S get value => _value;

  // Check before assigning: a disposed ChangeNotifier only fails in
  // notifyListeners, after the snapshot would already have changed.
  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  @override
  Widget watch(Widget Function(S) render) {
    return ChangeNotifierProvider<_ProviderStore<S>>.value(
      value: this,
      child: Consumer<_ProviderStore<S>>(
        builder: (context, store, child) => render(store.value),
      ),
    );
  }

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) {
    return ChangeNotifierProvider<_ProviderStore<S>>.value(
      value: this,
      child: Selector<_ProviderStore<S>, R>(
        selector: (context, store) => pick(store.value),
        // Selector compares collections deeply by default; the contract
        // uses ==, like the other adapters.
        shouldRebuild: (previous, next) => previous != next,
        builder: (context, value, child) => render(value),
      ),
    );
  }

  // ChangeNotifier.dispose fails when called twice.
  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    dispose();
  }
}
