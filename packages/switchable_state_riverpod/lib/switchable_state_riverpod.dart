/// A `switchable_state` adapter backed by `package:flutter_riverpod`.
///
/// Register [RiverpodStateAdapter] in the root `StateScope`:
///
/// ```dart
/// StateScope(
///   adapter: const RiverpodStateAdapter(),
///   child: const MyApp(),
/// )
/// ```
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:switchable_state/switchable_state.dart';

/// A [StateAdapter] backed by Riverpod.
///
/// Each store owns a `ProviderContainer` holding one `Notifier`, shared by
/// every widget that watches the store. [StateStore.watch] uses a
/// `Consumer`, and [StateStore.select] watches `provider.select`.
///
/// A `Consumer` under a route covered by another one (with `TickerMode` off)
/// stops listening and catches up when it is shown again.
final class RiverpodStateAdapter implements StateAdapter {
  /// Creates the adapter. It is stateless, so one const instance serves the
  /// whole app.
  const RiverpodStateAdapter();

  @override
  StateStore<S> create<S extends Object>(S initial) =>
      _RiverpodStore<S>(initial);
}

final class _RiverpodStore<S extends Object> implements StateStore<S> {
  _RiverpodStore(S initial)
    : _provider = NotifierProvider<_SnapshotNotifier<S>, S>(
        () => _SnapshotNotifier(initial),
      );

  final ProviderContainer _container = ProviderContainer();
  final NotifierProvider<_SnapshotNotifier<S>, S> _provider;

  /// The last snapshot, kept because a disposed container cannot be read.
  /// Non-null exactly when the store is closed.
  S? _closedValue;

  @override
  S get value => _closedValue ?? _container.read(_provider);

  @override
  void replace(S next) {
    if (_closedValue != null) throw closedStoreError();
    _container.read(_provider.notifier).replace(next);
  }

  @override
  Widget watch(Widget Function(S) render) => UncontrolledProviderScope(
    container: _container,
    child: Consumer(
      builder: (context, ref, child) => render(ref.watch(_provider)),
    ),
  );

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) =>
      UncontrolledProviderScope(
        container: _container,
        child: Consumer(
          builder: (context, ref, child) =>
              render(ref.watch(_provider.select(pick))),
        ),
      );

  @override
  Future<void> close() async {
    if (_closedValue != null) return;
    _closedValue = value;
    _container.dispose();
  }
}

final class _SnapshotNotifier<S extends Object> extends Notifier<S> {
  _SnapshotNotifier(this.initial);

  final S initial;

  @override
  S build() => initial;

  void replace(S next) => state = next;
}
