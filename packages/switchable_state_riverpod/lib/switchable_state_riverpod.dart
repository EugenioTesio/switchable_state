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

import 'dart:async';

import 'package:flutter/scheduler.dart';
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
///
/// Riverpod forbids modifying a provider while Flutter builds a frame. A write
/// made then, for example from `initState`, updates [StateStore.value] at
/// once and reaches watchers and listeners right after the frame.
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
  bool _publishScheduled = false;
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
    // An unmounted provider builds from _latest when a watcher or listener
    // first reads it, so there is nothing to publish yet. A pending publish
    // already sends the newest snapshot.
    if (!_providerMounted || _publishScheduled) return;
    // Riverpod forbids modifying a provider while Flutter builds a frame, for
    // example from initState or dispose, so publish such a write right after
    // the frame. Later writes fold into it, so the newest snapshot wins.
    if (_isFlutterBuilding()) {
      _publishScheduled = true;
      scheduleMicrotask(_publishLatest);
      return;
    }
    _publish(next);
  }

  void _publishLatest() {
    _publishScheduled = false;
    if (!_closed) _publish(_latest);
  }

  void _publish(S next) => _container.read(_provider.notifier).replace(next);

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
          // Restores the app's container for Riverpod widgets in render. Each
          // restore registers one more vsync on that container; measured with
          // 1000 watchers, app provider writes cost no more than without it.
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

/// Whether Flutter is building a frame (build, layout, paint or tree
/// finalization), when Riverpod forbids modifying providers.
bool _isFlutterBuilding() {
  final binding = _schedulerBinding();
  if (binding == null) return false;
  if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    return true;
  }
  // runApp builds the first frame outside the frame callbacks.
  return binding is WidgetsBinding &&
      (binding.buildOwner?.debugBuilding ?? false);
}

SchedulerBinding? _binding;

SchedulerBinding? _schedulerBinding() {
  if (_binding case final binding?) return binding;
  try {
    return _binding = SchedulerBinding.instance;
  } on Object {
    // No binding yet, as in a plain Dart test: nothing can be building.
    return null;
  }
}

final class _SnapshotNotifier<S> extends Notifier<S> {
  _SnapshotNotifier(this._store);

  final _RiverpodStore<S> _store;

  @override
  S build() => _store._mountNotifier();

  void replace(S next) => state = next;
}
