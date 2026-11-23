import 'dart:async';

import 'package:flutter/foundation.dart'
    show
        DiagnosticPropertiesBuilder,
        DiagnosticsProperty,
        IterableProperty,
        setEquals;
import 'package:flutter/widgets.dart';

import 'state_adapter.dart';

/// Observes lifecycle events and snapshot transitions across stores owned by a
/// [StateScope] hierarchy.
///
/// Register observers on the root [StateScope] to add logging, analytics, or
/// diagnostics independently of which [StateAdapter] is active.
abstract base class StateObserver {
  /// Creates a [StateObserver].
  const StateObserver();

  /// Called when a [StateScope] lazily creates [store] for [state].
  void onCreate(AppState<Object?> state, StateStore<Object?> store) {}

  /// Called whenever the store for [state] transitions from [previous] to
  /// [next].
  void onChange(AppState<Object?> state, Object? previous, Object? next) {}

  /// Called when a [StateScope] closes the store for [state].
  void onClose(AppState<Object?> state) {}
}

/// Declares a piece of state that screens read from the nearest
/// [StateScope], the way a Riverpod provider is declared once and read
/// through `ref`.
///
/// Declare it once as a top-level `final`. Each declaration is its own key,
/// so two declarations of the same type get separate stores.
final class AppState<S> {
  /// Creates an app-wide state declaration.
  ///
  /// The root [StateScope] creates its store on first read and keeps it alive
  /// until the scope is disposed, like a keep-alive provider.
  AppState(this._initial, {this.debugName}) : grouped = false;

  /// Creates a grouped state declaration shared by a group of routes.
  ///
  /// Only a [StateScope.group] that lists it in [StateScope.owns] creates its
  /// store, which closes with that scope. Reading it anywhere else throws a
  /// [StateError].
  AppState.grouped(this._initial, {this.debugName}) : grouped = true;

  final S Function() _initial;

  /// A name for error messages and diagnostics.
  final String? debugName;

  /// Whether a [StateScope.group] must own this state.
  final bool grouped;

  /// Seeds this state's store with [initial] in the scope that owns it,
  /// usually in tests.
  ///
  /// See [StateScope.overrides].
  StateOverride<S> overrideWith(S Function() initial) =>
      StateOverride._initial(this, initial);

  /// Replaces this state's store instance with the store returned by [create]
  /// in the scope that owns it, usually for fakes or spies in tests.
  ///
  /// The scope takes ownership of the returned store and closes it when the
  /// scope is disposed or reset. See [StateScope.overrides].
  StateOverride<S> overrideWithStore(StateStore<S> Function() create) =>
      StateOverride._store(this, create);

  /// Creates the backing store using this declaration's reified type [S],
  /// avoiding covariance mismatches when read through a wider type argument.
  StateStore<S> _createStore(
    StateAdapter adapter,
    StateOverride<Object?>? override,
  ) {
    if (override != null) {
      final storeFactory = override._storeFactory;
      if (storeFactory != null) return storeFactory() as StateStore<S>;
      final initialFactory = override._initialFactory!;
      return adapter.create<S>(initialFactory() as S);
    }
    return adapter.create<S>(_initial());
  }

  @override
  String toString() =>
      'AppState<$S>(${debugName ?? identityHashCode(this).toRadixString(16)})';
}

/// Declares a family of parameterized [AppState] keys indexed by [Arg].
///
/// Calling `family(arg)` returns the same [AppState] instance for equal [Arg]
/// values, so screens reading the same parameter share the same store within
/// the owning [StateScope].
final class StateFamily<S, Arg> {
  /// Creates an app-wide family of states initialized with [_initial].
  StateFamily(this._initial, {this.debugName}) : grouped = false;

  /// Creates a grouped family of states initialized with [_initial].
  StateFamily.grouped(this._initial, {this.debugName}) : grouped = true;

  final S Function(Arg arg) _initial;

  /// An optional prefix for each member's [AppState.debugName].
  final String? debugName;

  /// Whether each member is created as [AppState.grouped].
  final bool grouped;

  final Map<Arg, AppState<S>> _cache = {};

  /// Returns the [AppState] key for [arg], creating and caching it on first
  /// access.
  AppState<S> call(Arg arg) => _cache.putIfAbsent(arg, () {
    final name = debugName != null ? '$debugName($arg)' : null;
    return grouped
        ? AppState<S>.grouped(() => _initial(arg), debugName: name)
        : AppState<S>(() => _initial(arg), debugName: name);
  });
}

/// Replaces an [AppState]'s initial value or store factory in one [StateScope].
final class StateOverride<S> {
  const StateOverride._initial(this.state, S Function() initial)
    : _initialFactory = initial,
      _storeFactory = null;

  const StateOverride._store(this.state, StateStore<S> Function() create)
    : _initialFactory = null,
      _storeFactory = create;

  /// The overridden declaration.
  final AppState<S> state;

  final S Function()? _initialFactory;
  final StateStore<S> Function()? _storeFactory;
}

/// Holds the stores that one [StateScope] provides.
///
/// Retrieve the nearest registry with [StateScope.of] or [StateScope.maybeOf].
final class StateRegistry {
  StateRegistry._(
    this.adapter,
    this._parent,
    this._owns,
    List<StateOverride<Object?>> overrides,
    List<StateObserver> observers,
  ) : _overrides = {
        for (final override in overrides) override.state: override,
      },
      _observers = List.unmodifiable(observers);

  /// The adapter that creates this registry's stores.
  final StateAdapter adapter;

  StateRegistry? _parent;

  /// The grouped states a [StateScope.group] owns. Null for the root, which
  /// owns every app-wide state.
  final Set<AppState<Object?>>? _owns;

  final Map<AppState<Object?>, StateOverride<Object?>> _overrides;
  final List<StateObserver> _observers;
  final Map<AppState<Object?>, StateStore<Object?>> _stores = {};
  final Map<AppState<Object?>, VoidCallback> _observerDisposers = {};
  final Set<AppState<Object?>> _creating = {};
  bool _closed = false;

  /// Whether this registry has been closed by its owning [StateScope].
  bool get isClosed => _closed;

  bool _isOwner(AppState<Object?> state) => switch (_owns) {
    null => !state.grouped,
    final owns => owns.contains(state),
  };

  /// Returns the shared store for [state] under the scope that owns it.
  ///
  /// The store is created lazily on first read and lives until its owning
  /// scope is disposed or [reset] is called.
  StateStore<S> store<S>(AppState<S> state) {
    if (_isOwner(state)) {
      if (_closed) {
        throw StateError('$state was read after its StateScope was disposed.');
      }
      final existing = _stores[state];
      if (existing != null) return existing as StateStore<S>;
      if (!_creating.add(state)) {
        throw StateError(
          'Circular initialization detected while reading $state.',
        );
      }
      try {
        final created = state._createStore(adapter, _overrides[state]);
        _stores[state] = created;
        _attachObservers(state, created);
        return created;
      } finally {
        _creating.remove(state);
      }
    }
    final parent = _parent;
    if (parent != null) return parent.store(state);
    throw StateError(
      '$state is grouped, but no StateScope.group above this widget owns it.',
    );
  }

  /// Creates a new store owned by the caller, who must close it.
  ///
  /// A [State] can mix in [StateStoreOwner] and call
  /// [StateStoreOwner.createStore] to have it closed automatically.
  StateStore<S> create<S>(S initial) {
    if (_closed) {
      throw StateError(
        'Cannot create a StateStore after its StateScope was disposed.',
      );
    }
    return adapter.create<S>(initial);
  }

  /// Closes and removes the store for [state] if it has been created, so the
  /// next read starts from its initial value again.
  Future<void> reset<S>(AppState<S> state) async {
    if (_isOwner(state)) {
      if (_closed) {
        throw StateError('$state was reset after its StateScope was disposed.');
      }
      final store = _stores.remove(state);
      if (store == null) return;
      _observerDisposers.remove(state)?.call();
      await store.close();
      for (final observer in _observers) {
        observer.onClose(state);
      }
      return;
    }
    final parent = _parent;
    if (parent != null) return parent.reset(state);
    throw StateError(
      '$state is grouped, but no StateScope.group above this widget owns it.',
    );
  }

  void _attachObservers<S>(AppState<S> state, StateStore<S> store) {
    if (_observers.isEmpty) return;
    for (final observer in _observers) {
      observer.onCreate(state, store);
    }
    _observerDisposers[state] = store.listen((previous, next) {
      for (final observer in _observers) {
        observer.onChange(state, previous, next);
      }
    });
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    for (final dispose in _observerDisposers.values) {
      dispose();
    }
    _observerDisposers.clear();
    final entries = _stores.entries.toList();
    _stores.clear();
    await Future.wait(entries.map((entry) => entry.value.close()));
    for (final entry in entries) {
      for (final observer in _observers) {
        observer.onClose(entry.key);
      }
    }
  }
}

/// Provides the app's state to every widget below it, like Riverpod's
/// `ProviderScope` or a `MultiBlocProvider` above the app.
///
/// Put the root scope above `MaterialApp.router`. Put a [StateScope.group]
/// in a go_router `ShellRoute` builder for state that a group of routes
/// shares and that should close when the user leaves the group. Use
/// [StateScope.inherit] to share an existing [StateRegistry] with dialogs,
/// bottom sheets, or pushed routes without transferring ownership.
final class StateScope extends StatefulWidget {
  /// Creates the app's root scope, which owns every app-wide [AppState].
  const StateScope({
    super.key,
    required StateAdapter this.adapter,
    this.overrides = const [],
    this.observers = const [],
    required this.child,
  }) : owns = null,
       _inheritedRegistry = null;

  /// Creates a nested scope that owns the grouped states in [owns].
  ///
  /// It uses the adapter and observers of the scope above it and forwards
  /// other states up to its parent.
  const StateScope.group({
    super.key,
    required List<AppState<Object?>> this.owns,
    this.overrides = const [],
    required this.child,
  }) : adapter = null,
       observers = const [],
       _inheritedRegistry = null;

  /// Re-exposes an existing [registry] to [child] without owning or closing
  /// its stores when this widget is disposed.
  ///
  /// Useful for passing a [StateScope.group] registry into `showDialog`,
  /// `showModalBottomSheet`, or a pushed route mounted on the root navigator.
  const StateScope.inherit({
    super.key,
    required StateRegistry registry,
    required this.child,
  }) : adapter = null,
       owns = null,
       overrides = const [],
       observers = const [],
       _inheritedRegistry = registry;

  /// The library binding, or `null` for a group or inherited scope.
  final StateAdapter? adapter;

  /// The grouped states a group owns, or `null` for a root or inherited scope.
  final List<AppState<Object?>>? owns;

  /// Initial values or store factories that replace the declared ones in this
  /// scope.
  ///
  /// A root scope may override app-wide states; a group may override the
  /// states it owns.
  final List<StateOverride<Object?>> overrides;

  /// Observers notified when stores in this scope hierarchy are created,
  /// updated, or closed.
  final List<StateObserver> observers;

  final StateRegistry? _inheritedRegistry;

  /// The widget below this scope.
  final Widget child;

  /// Returns the [StateRegistry] of the nearest enclosing [StateScope], or
  /// `null` if none exists.
  ///
  /// Registers no rebuild dependency, so it is safe to call from
  /// [State.initState].
  static StateRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_StateScopeData>()?.registry;

  /// Returns the [StateRegistry] of the nearest enclosing [StateScope].
  ///
  /// Registers no rebuild dependency, so it is safe to call from
  /// [State.initState]; use [StateStore.watch] or [StateStore.select] to
  /// rebuild on changes. Throws a [FlutterError] if no [StateScope] is above
  /// [context].
  static StateRegistry of(BuildContext context) {
    final registry = maybeOf(context);
    if (registry == null) {
      throw FlutterError(
        'StateScope.of() was called with a context that has no StateScope '
        'above it.\nWrap the app in StateScope(adapter: ...) above '
        'MaterialApp.',
      );
    }
    return registry;
  }

  @override
  State<StateScope> createState() => _StateScopeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<StateAdapter?>(
          'adapter',
          adapter,
          defaultValue: null,
        ),
      )
      ..add(
        IterableProperty<AppState<Object?>>('owns', owns, defaultValue: null),
      )
      ..add(
        IterableProperty<StateOverride<Object?>>(
          'overrides',
          overrides,
          defaultValue: const [],
        ),
      )
      ..add(
        IterableProperty<StateObserver>(
          'observers',
          observers,
          defaultValue: const [],
        ),
      );
  }
}

final class _StateScopeState extends State<StateScope> {
  StateRegistry? _ownedRegistry;

  StateRegistry get _activeRegistry =>
      widget._inheritedRegistry ?? _ownedRegistry!;

  @override
  void initState() {
    super.initState();
    if (widget._inheritedRegistry == null) {
      _ownedRegistry = _createRegistry();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.owns != null) {
      final parent = context
          .dependOnInheritedWidgetOfExactType<_StateScopeData>()
          ?.registry;
      if (parent != null) {
        _ownedRegistry?._parent = parent;
      }
    }
  }

  StateRegistry _createRegistry() {
    assert(
      widget.overrides.map((override) => override.state).toSet().length ==
          widget.overrides.length,
      'StateScope.overrides must not contain duplicate entries for the same '
      'AppState.',
    );
    final owns = widget.owns;
    if (owns == null) {
      assert(
        widget.overrides.every((override) => !override.state.grouped),
        'A root StateScope can only override app-wide states.',
      );
      return StateRegistry._(
        widget.adapter!,
        null,
        null,
        widget.overrides,
        widget.observers,
      );
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
      parent._observers,
    );
  }

  @override
  void didUpdateWidget(StateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      (widget._inheritedRegistry != null) ==
          (oldWidget._inheritedRegistry != null),
      'A mounted StateScope cannot switch between owning and inheriting a '
      'registry. Give it a new key to replace it.',
    );
    if (widget._inheritedRegistry != null) return;
    assert(
      (widget.adapter == oldWidget.adapter ||
              widget.adapter?.runtimeType == oldWidget.adapter?.runtimeType) &&
          setEquals(widget.owns?.toSet(), oldWidget.owns?.toSet()),
      'A mounted StateScope cannot change its adapter or owned states. '
      'Give it a new key to replace it.',
    );
  }

  @override
  void dispose() {
    final owned = _ownedRegistry;
    if (owned != null) {
      unawaited(owned._close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StateScopeData(registry: _activeRegistry, child: widget.child);
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
/// The stores close after the [State]'s own [State.dispose] body, so a
/// subclass can stop the commands that write to them first.
mixin StateStoreOwner<T extends StatefulWidget> on State<T> {
  final List<StateStore<Object?>> _ownedStores = [];

  /// Creates a store from the nearest [StateScope] that closes with this
  /// [State].
  ///
  /// Call it from [State.initState], never from [State.build], which would
  /// create a new store on every rebuild.
  StateStore<S> createStore<S>(S initial) {
    assert(
      !context.debugDoingBuild,
      'createStore() was called during build, which would create a new store '
      'on every rebuild. Call it from initState instead.',
    );
    final store = StateScope.of(context).create<S>(initial);
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

/// Convenience extensions for reading stores from a [BuildContext].
extension StateScopeContext on BuildContext {
  /// Returns the shared [StateStore] for [state] from the nearest [StateScope].
  ///
  /// Shorthand for `StateScope.of(this).store(state)`. Registers no rebuild
  /// dependency, so it is safe to call from [State.initState].
  StateStore<S> store<S>(AppState<S> state) => StateScope.of(this).store(state);
}
