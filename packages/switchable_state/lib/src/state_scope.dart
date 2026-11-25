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
/// diagnostics independently of which [StateAdapter] is active. Groups below
/// the root report to the root's observers.
///
/// This is a `base` class, like Riverpod's `ProviderObserver`, so new hooks
/// can be added without breaking existing observers. Declare a subclass as
/// `final` (or `base`):
///
/// ```dart
/// final class LoggingObserver extends StateObserver {
///   @override
///   void onChange(AppState<Object?> state, Object? previous, Object? next) =>
///       debugPrint('$state: $previous -> $next');
/// }
/// ```
///
/// An observer added when the root rebuilds sees later changes and closes of
/// stores that already exist, but not their creation.
abstract base class StateObserver {
  /// Creates a [StateObserver].
  const StateObserver();

  /// Called when a [StateScope] lazily creates [store] for [state].
  void onCreate(AppState<Object?> state, StateStore<Object?> store) {}

  /// Called whenever the store for [state] transitions from [previous] to
  /// [next], including when [StateRegistry.reset] returns it to its initial
  /// snapshot.
  ///
  /// Depending on the adapter, this runs inside the write or shortly after
  /// it; see [StateStore.listen].
  void onChange(AppState<Object?> state, Object? previous, Object? next) {}

  /// Called when a [StateScope] closes the store for [state].
  void onClose(AppState<Object?> state) {}
}

/// A declaration that a [StateScope.group] can own: an [AppState] or a whole
/// [StateFamily].
sealed class StateDeclaration {
  /// Whether only a [StateScope.group] can own this declaration.
  bool get grouped;
}

/// Declares a piece of state that screens read from the nearest
/// [StateScope], the way a Riverpod provider is declared once and read
/// through `ref`.
///
/// Declare it once as a top-level `final`. Each declaration is its own key,
/// so two declarations of the same type get separate stores.
final class AppState<S> implements StateDeclaration {
  /// Creates an app-wide state declaration.
  ///
  /// The root [StateScope] creates its store on first read and keeps it alive
  /// until the scope is disposed, like a keep-alive provider.
  AppState(this._initial, {this.debugName})
    : grouped = false,
      _family = null,
      _arg = null;

  /// Creates a grouped state declaration shared by a group of routes.
  ///
  /// Only a [StateScope.group] that lists it in [StateScope.owns] creates its
  /// store, which closes with that scope. Reading it anywhere else throws a
  /// [StateError].
  AppState.grouped(this._initial, {this.debugName})
    : grouped = true,
      _family = null,
      _arg = null;

  AppState._member(
    this._initial,
    StateFamily<Object?, Object?> this._family,
    this._arg, {
    required this.grouped,
    required this.debugName,
  });

  final S Function() _initial;

  /// A name for error messages and diagnostics.
  final String? debugName;

  /// Whether a [StateScope.group] must own this state.
  @override
  final bool grouped;

  /// The family this state is a member of, or `null` for a plain
  /// declaration.
  final StateFamily<Object?, Object?>? _family;
  final Object? _arg;

  /// Seeds this state's store with [initial] in the scope that owns it,
  /// usually in tests.
  ///
  /// [StateRegistry.reset] also returns the store to [initial]. See
  /// [StateScope.overrides].
  StateOverride<S> overrideWith(S Function() initial) =>
      StateOverride._initial(this, initial);

  /// Replaces this state's store instance with the store returned by [create]
  /// in the scope that owns it, usually for fakes or spies in tests.
  ///
  /// The scope takes ownership of the returned store and closes it when the
  /// scope is disposed. [StateRegistry.reset] writes the declaration's
  /// initial value to it. See [StateScope.overrides].
  StateOverride<S> overrideWithStore(StateStore<S> Function() create) =>
      StateOverride._store(this, create);

  // These run on the declaration so they use its reified type [S], even when
  // the caller reads it through a wider one such as `AppState<num>`.

  S _initialValue(StateOverride<Object?>? override) {
    final initial = override?._initialFactory;
    return initial == null ? _initial() : initial() as S;
  }

  StateStore<S> _createStore(
    StateAdapter adapter,
    StateOverride<Object?>? override,
  ) {
    final storeFactory = override?._storeFactory;
    if (storeFactory != null) return storeFactory() as StateStore<S>;
    return adapter.create<S>(_initialValue(override));
  }

  void _reset(StateStore<Object?> store, StateOverride<Object?>? override) =>
      (store as StateStore<S>).replace(_initialValue(override));

  /// Family members for equal arguments are equal, so they share a store.
  /// Any other declaration is only equal to itself.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (_family != null &&
          other is AppState<Object?> &&
          identical(other._family, _family) &&
          other._arg == _arg);

  @override
  int get hashCode =>
      _family == null ? super.hashCode : Object.hash(_family, _arg);

  @override
  String toString() =>
      'AppState<$S>(${debugName ?? identityHashCode(this).toRadixString(16)})';
}

/// Declares a family of parameterized [AppState] keys indexed by [Arg].
///
/// `family(arg)` returns a key that is `==` to every other key for an equal
/// [Arg], so screens reading the same argument share one store in the scope
/// that owns it. The family itself keeps nothing per argument.
///
/// Like a keep-alive Riverpod family, the root keeps an app-wide member's
/// store until the root scope is disposed. For unbounded arguments, such as
/// one entry per item id, declare the family with [StateFamily.grouped] and
/// own it in a [StateScope.group] so its stores close with the group, or
/// create a route-owned store with [StateStoreOwner.createStore].
final class StateFamily<S, Arg> implements StateDeclaration {
  /// Creates an app-wide family of states initialized with [_initial].
  StateFamily(this._initial, {this.debugName}) : grouped = false;

  /// Creates a grouped family of states initialized with [_initial].
  ///
  /// List the family in [StateScope.owns] to own every member: a member for
  /// any argument can then be read below that group.
  StateFamily.grouped(this._initial, {this.debugName}) : grouped = true;

  final S Function(Arg arg) _initial;

  /// An optional prefix for each member's [AppState.debugName].
  final String? debugName;

  /// Whether each member is created as [AppState.grouped].
  @override
  final bool grouped;

  /// Returns the [AppState] key for [arg].
  AppState<S> call(Arg arg) => AppState<S>._member(
    () => _initial(arg),
    this,
    arg,
    grouped: grouped,
    debugName: debugName == null ? null : '$debugName($arg)',
  );

  @override
  String toString() => 'StateFamily<$S, $Arg>(${debugName ?? hashCode})';
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
  StateRegistry._root(
    StateAdapter this._adapter,
    List<StateOverride<Object?>> overrides,
    List<StateObserver> observers,
  ) : _owns = null,
      _overrides = _overrideMap(overrides),
      _rootObservers = List.unmodifiable(observers);

  StateRegistry._group(
    StateRegistry this._parent,
    Set<StateDeclaration> this._owns,
    List<StateOverride<Object?>> overrides,
  ) : _adapter = null,
      _overrides = _overrideMap(overrides),
      _rootObservers = const [];

  static Map<AppState<Object?>, StateOverride<Object?>> _overrideMap(
    List<StateOverride<Object?>> overrides,
  ) => {for (final override in overrides) override.state: override};

  /// Set for the root only; a group reads its parent's.
  final StateAdapter? _adapter;

  StateRegistry? _parent;

  /// The grouped states and families a [StateScope.group] owns. Null for the
  /// root, which owns every app-wide state.
  final Set<StateDeclaration>? _owns;

  Map<AppState<Object?>, StateOverride<Object?>> _overrides;
  List<StateObserver> _rootObservers;
  final Map<AppState<Object?>, StateStore<Object?>> _stores = {};
  final Map<AppState<Object?>, VoidCallback> _subscriptions = {};
  final Set<AppState<Object?>> _creating = {};
  bool _closed = false;

  /// The adapter that creates this registry's stores.
  ///
  /// A group uses the adapter of the scope currently above it, so a group
  /// moved under another root creates its next stores with that root's
  /// adapter. Stores it already created keep theirs.
  StateAdapter get adapter => _adapter ?? _parent!.adapter;

  /// The root's observers, read at each event, so a group moved under another
  /// root, or a root rebuilt with new observers, reports to the current ones.
  List<StateObserver> get _observers => _parent?._observers ?? _rootObservers;

  /// Whether this registry has been closed by its owning [StateScope].
  bool get isClosed => _closed;

  bool _isOwner(AppState<Object?> state) => switch (_owns) {
    null => !state.grouped,
    final owns => _ownsState(owns, state),
  };

  static bool _ownsState(
    Iterable<StateDeclaration> owns,
    AppState<Object?> state,
  ) {
    final family = state._family;
    return owns.contains(state) || (family != null && owns.contains(family));
  }

  /// Returns the shared store for [state] under the scope that owns it.
  ///
  /// The store is created lazily on first read and lives until its owning
  /// scope is disposed.
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
        _observe(state, created);
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

  /// Returns the store for [state] to its initial snapshot, for example on
  /// logout.
  ///
  /// The initial snapshot is this scope's override for [state], if any, or
  /// the declaration's initial value. The store instance is kept, so widgets
  /// and listeners that hold it see the reset like any other write and can
  /// keep writing to it. Does nothing if the store was never created. Work
  /// still in flight, such as a pending request, can write to the store
  /// afterwards; cancel it first if that matters.
  void reset<S>(AppState<S> state) {
    if (_isOwner(state)) {
      if (_closed) {
        throw StateError('$state was reset after its StateScope was disposed.');
      }
      final store = _stores[state];
      if (store != null) state._reset(store, _overrides[state]);
      return;
    }
    final parent = _parent;
    if (parent != null) return parent.reset(state);
    throw StateError(
      '$state is grouped, but no StateScope.group above this widget owns it.',
    );
  }

  // Every scope store is observed, whether or not there are observers yet,
  // because the observers can change: a rebuilt root, or a group moved under
  // another root. The callback reads the current observers at each event.
  void _observe<S>(AppState<S> state, StateStore<S> store) {
    for (final observer in _observers) {
      observer.onCreate(state, store);
    }
    _subscriptions[state] = store.listen((previous, next) {
      for (final observer in _observers) {
        observer.onChange(state, previous, next);
      }
    });
  }

  void _update(
    List<StateOverride<Object?>> overrides,
    List<StateObserver> observers,
  ) {
    _overrides = _overrideMap(overrides);
    if (_parent == null) _rootObservers = List.unmodifiable(observers);
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    for (final cancel in _subscriptions.values) {
      cancel();
    }
    _subscriptions.clear();
    final entries = _stores.entries.toList();
    _stores.clear();
    final observers = _observers;
    await Future.wait(entries.map((entry) => entry.value.close()));
    for (final entry in entries) {
      for (final observer in observers) {
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
  /// [owns] lists [AppState.grouped] declarations and [StateFamily.grouped]
  /// families; owning a family owns every one of its members. The group uses
  /// the adapter and observers of the scope above it and forwards other
  /// states up to its parent.
  const StateScope.group({
    super.key,
    required List<StateDeclaration> this.owns,
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

  /// The grouped states and families a group owns, or `null` for a root or
  /// inherited scope.
  final List<StateDeclaration>? owns;

  /// Initial values or store factories that replace the declared ones in this
  /// scope.
  ///
  /// A root scope may override app-wide states; a group may override the
  /// states it owns, including single members of a family it owns. When the
  /// scope rebuilds with new overrides, they apply to stores created or
  /// [StateRegistry.reset] afterwards.
  final List<StateOverride<Object?>> overrides;

  /// Observers notified when stores in this scope hierarchy are created,
  /// updated, or closed.
  ///
  /// When the root rebuilds with new observers, they replace the old ones for
  /// every store in the hierarchy.
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
        IterableProperty<StateDeclaration>('owns', owns, defaultValue: null),
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
    _debugCheckConfiguration();
    final owns = widget.owns;
    if (owns == null) {
      return StateRegistry._root(
        widget.adapter!,
        widget.overrides,
        widget.observers,
      );
    }
    return StateRegistry._group(
      StateScope.of(context),
      Set.of(owns),
      widget.overrides,
    );
  }

  void _debugCheckConfiguration() {
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
      return;
    }
    assert(
      owns.every((declaration) => declaration.grouped),
      'StateScope.group can only own AppState.grouped and StateFamily.grouped '
      'declarations.',
    );
    assert(
      widget.overrides.every(
        (override) => StateRegistry._ownsState(owns, override.state),
      ),
      'StateScope.group can only override the states it owns.',
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
    final owned = _ownedRegistry;
    if (owned == null) return;
    assert(
      (widget.adapter == oldWidget.adapter ||
              widget.adapter?.runtimeType == oldWidget.adapter?.runtimeType) &&
          setEquals(widget.owns?.toSet(), oldWidget.owns?.toSet()),
      'A mounted StateScope cannot change its adapter or owned states. '
      'Give it a new key to replace it.',
    );
    _debugCheckConfiguration();
    owned._update(widget.overrides, widget.observers);
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
