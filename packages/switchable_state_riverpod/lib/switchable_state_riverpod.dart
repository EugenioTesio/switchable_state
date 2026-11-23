/// A `switchable_state` adapter backed by `package:flutter_riverpod`.
///
/// Register [RiverpodStateAdapter] in the root [StateScope]:
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
/// Each store owns a [ProviderContainer] holding one [Notifier], shared by
/// every widget that watches the store. [StateStore.watch] uses a [Consumer],
/// and [StateStore.select] watches `provider.select`.
///
/// A [Consumer] under a route covered by another one (with [TickerMode] off)
/// stops listening and catches up when it is shown again.
final class RiverpodStateAdapter implements StateAdapter {
  /// Creates the adapter.
  ///
  /// It is stateless, so one `const` instance serves the whole app.
  const RiverpodStateAdapter();

  @override
  StateStore<S> create<S>(S initial) => _RiverpodStore<S>(initial);
}

final class _RiverpodStore<S> implements StateStore<S> {
  _RiverpodStore(S initial) : _latest = initial {
    _provider = NotifierProvider<_SnapshotNotifier<S>, S>(
      () => _SnapshotNotifier<S>(this),
    );
  }

  final ProviderContainer _container = ProviderContainer();
  late final NotifierProvider<_SnapshotNotifier<S>, S> _provider;

  S _latest;
  bool _providerMounted = false;
  bool _closed = false;

  S _mountNotifier() {
    _providerMounted = true;
    return _latest;
  }

  @override
  S get value => _latest;

  @override
  bool get isClosed => _closed;

  @override
  void replace(S next) {
    if (_closed) throw closedStoreError();
    if (_latest == next) return;
    _latest = next;
    // Defer touching the container until a watcher or listener mounts the
    // provider, so writing to a brand-new route store in initState does not
    // trip Riverpod's global debugCanModifyProviders check on an unrelated
    // mounted scope.
    if (_providerMounted) {
      _container.read(_provider.notifier).replace(next);
    }
  }

  @override
  Widget watch(Widget Function(S) render) => _RiverpodBridge(
    container: _container,
    builder: (context, ref) => render(ref.watch(_provider)),
  );

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) =>
      _RiverpodBridge(
        container: _container,
        builder: (context, ref) => render(ref.watch(_provider.select(pick))),
      );

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (_closed) return () {};
    var previous = _latest;
    var canceled = false;
    final subscription = _container.listen<S>(_provider, (_, next) {
      if (canceled || _closed) return;
      final prev = previous;
      previous = next;
      onChange(prev, next);
    });
    return () {
      if (canceled) return;
      canceled = true;
      subscription.close();
    };
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _container.dispose();
  }
}

final class _RiverpodBridge extends StatelessWidget {
  const _RiverpodBridge({required this.container, required this.builder});

  final ProviderContainer container;
  final Widget Function(BuildContext context, WidgetRef ref) builder;

  @override
  Widget build(BuildContext context) {
    final outerContainer = _maybeContainerOf(context);
    return UncontrolledProviderScope(
      // Key by container so swapping stores in the same slot disposes the old
      // _UncontrolledProviderScopeState and unregisters its scheduler Vsync.
      key: ObjectKey(container),
      container: container,
      child: Consumer(
        builder: (context, ref, child) {
          final built = builder(context, ref);
          if (outerContainer == null) return built;
          return UncontrolledProviderScope(
            container: outerContainer,
            child: built,
          );
        },
      ),
    );
  }

  static ProviderContainer? _maybeContainerOf(BuildContext context) {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null;
    }
  }
}

final class _SnapshotNotifier<S> extends Notifier<S> {
  _SnapshotNotifier(this._store);

  final _RiverpodStore<S> _store;

  @override
  S build() => _store._mountNotifier();

  void replace(S next) => state = next;
}
