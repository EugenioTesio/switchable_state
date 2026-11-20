import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import 'state_adapter.dart';

/// Declares a piece of state that screens read from the nearest
/// [StateScope], the way a Riverpod provider is declared once and read
/// through `ref`.
///
/// Declare it once as a top-level `final`. Each declaration is its own key,
/// so two declarations of the same type get separate stores.
final class AppState<S extends Object> {
  /// App-wide state. The root [StateScope] creates its store on first read
  /// and keeps it alive until the scope is disposed, like a keep-alive
  /// provider.
  AppState(this._initial, {this.debugName}) : grouped = false;

  /// State shared by a group of routes. Only a [StateScope.group] that lists
  /// it in `owns` creates its store, which closes with that scope. Reading it
  /// anywhere else throws a [StateError].
  AppState.grouped(this._initial, {this.debugName}) : grouped = true;

  final S Function() _initial;

  /// A name for error messages.
  final String? debugName;

  /// Whether a [StateScope.group] must own this state.
  final bool grouped;

  /// Seeds this state's store with [initial] in the scope that owns it,
  /// usually in tests. See [StateScope.overrides].
  StateOverride<S> overrideWith(S Function() initial) =>
      StateOverride._(this, initial);

  @override
  String toString() =>
      'AppState<$S>(${debugName ?? identityHashCode(this).toRadixString(16)})';
}

/// Replaces an [AppState]'s initial value in one [StateScope].
final class StateOverride<S extends Object> {
  const StateOverride._(this.state, this._initial);

  /// The overridden declaration.
  final AppState<S> state;

  final S Function() _initial;
}

/// The stores that one [StateScope] provides. Get it with [StateScope.of].
final class StateRegistry {
  StateRegistry._(
    this.adapter,
    this._parent,
    this._owns,
    List<StateOverride<Object>> overrides,
  ) : _overrides = {
        for (final override in overrides) override.state: override._initial,
      };

  /// The adapter that creates this registry's stores.
  final StateAdapter adapter;

  final StateRegistry? _parent;

  /// The grouped states a [StateScope.group] owns. Null for the root, which
  /// owns every app-wide state.
  final Set<AppState<Object>>? _owns;

  final Map<AppState<Object>, Object Function()> _overrides;
  final Map<AppState<Object>, StateStore<Object>> _stores = {};
  bool _closed = false;

  bool _isOwner(AppState<Object> state) => switch (_owns) {
    null => !state.grouped,
    final owns => owns.contains(state),
  };

  /// The store for [state], shared by every widget under the scope that owns
  /// it. It is created on first read and lives until that scope is disposed,
  /// so screens never pass it to each other.
  StateStore<S> store<S extends Object>(AppState<S> state) {
    if (_isOwner(state)) {
      if (_closed) {
        throw StateError('$state was read after its StateScope was disposed.');
      }
      final store = _stores.putIfAbsent(state, () {
        final initial = _overrides[state]?.call() ?? state._initial();
        return adapter.create<S>(initial as S);
      });
      return store as StateStore<S>;
    }
    final parent = _parent;
    if (parent != null) return parent.store(state);
    throw StateError(
      '$state is grouped, but no StateScope.group above this widget owns it.',
    );
  }

  /// A new store that the caller owns and must close, like a Riverpod
  /// `autoDispose` provider. A [State] can use [StateStoreOwner.createStore]
  /// to have it closed automatically.
  StateStore<S> create<S extends Object>(S initial) => adapter.create(initial);

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    final stores = _stores.values.toList();
    _stores.clear();
    await Future.wait(stores.map((store) => store.close()));
  }
}

/// Provides the app's state to every widget below it, like Riverpod's
/// `ProviderScope` or a `MultiBlocProvider` above the app.
///
/// Put the root scope above `MaterialApp.router`. Put a [StateScope.group]
/// in a go_router `ShellRoute` builder for state that a group of routes
/// shares and that should close when the user leaves the group.
final class StateScope extends StatefulWidget {
  /// The app's root scope. It owns every app-wide [AppState].
  const StateScope({
    super.key,
    required StateAdapter this.adapter,
    this.overrides = const [],
    required this.child,
  }) : owns = null;

  /// A nested scope that owns the grouped states in [owns]. It uses the
  /// adapter of the scope above it and passes other states up to it.
  const StateScope.group({
    super.key,
    required List<AppState<Object>> this.owns,
    this.overrides = const [],
    required this.child,
  }) : adapter = null;

  /// The library binding. Null for a group, which uses its parent's.
  final StateAdapter? adapter;

  /// The grouped states a group owns. Null for the root.
  final List<AppState<Object>>? owns;

  /// Initial values that replace the declared ones in this scope. A root may
  /// override app-wide states; a group may override the states it owns.
  final List<StateOverride<Object>> overrides;

  /// The widget below this scope.
  final Widget child;

  /// The registry of the nearest scope.
  ///
  /// It registers no rebuild dependency, so it is safe in `initState`; use
  /// [StateStore.watch] or [StateStore.select] to rebuild on changes.
  static StateRegistry of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_StateScopeData>();
    if (scope == null) {
      throw FlutterError(
        'StateScope.of() was called with a context that has no StateScope '
        'above it.\nWrap the app in StateScope(adapter: ...) above '
        'MaterialApp.',
      );
    }
    return scope.registry;
  }

  @override
  State<StateScope> createState() => _StateScopeState();
}

final class _StateScopeState extends State<StateScope> {
  late final StateRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = _createRegistry();
  }

  StateRegistry _createRegistry() {
    final owns = widget.owns;
    if (owns == null) {
      assert(
        widget.overrides.every((override) => !override.state.grouped),
        'A root StateScope can only override app-wide states.',
      );
      return StateRegistry._(widget.adapter!, null, null, widget.overrides);
    }
    assert(
      owns.every((state) => state.grouped),
      'StateScope.group can only own AppState.grouped declarations.',
    );
    assert(
      widget.overrides.every((override) => owns.contains(override.state)),
      'StateScope.group can only override the states it owns.',
    );
    final parent = StateScope.of(context);
    return StateRegistry._(
      parent.adapter,
      parent,
      Set.of(owns),
      widget.overrides,
    );
  }

  @override
  void didUpdateWidget(StateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(widget.adapter, oldWidget.adapter) &&
          listEquals(widget.owns, oldWidget.owns),
      'A mounted StateScope cannot change its adapter or owned states. '
      'Give it a new key to replace it.',
    );
  }

  @override
  void dispose() {
    unawaited(_registry._close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StateScopeData(registry: _registry, child: widget.child);
}

final class _StateScopeData extends InheritedWidget {
  const _StateScopeData({required this.registry, required super.child});

  final StateRegistry registry;

  @override
  bool updateShouldNotify(_StateScopeData oldWidget) =>
      !identical(registry, oldWidget.registry);
}

/// Gives a [State] stores that it owns and that close when it is disposed,
/// like `BlocProvider(create:)` or a Riverpod `autoDispose` provider.
///
/// The stores close after the [State]'s own `dispose` body, so a subclass can
/// stop the commands that write to them first.
mixin StateStoreOwner<T extends StatefulWidget> on State<T> {
  final List<StateStore<Object>> _ownedStores = [];

  /// Creates a store from the nearest [StateScope] that closes with this
  /// [State]. Call it from `initState`, never from `build`, which would
  /// create a new store on every rebuild.
  StateStore<S> createStore<S extends Object>(S initial) {
    assert(
      !context.debugDoingBuild,
      'createStore() was called during build, which would create a new store '
      'on every rebuild. Call it from initState instead.',
    );
    final store = StateScope.of(context).create(initial);
    _ownedStores.add(store);
    return store;
  }

  @override
  void dispose() {
    for (final store in _ownedStores) {
      unawaited(store.close());
    }
    _ownedStores.clear();
    super.dispose();
  }
}
