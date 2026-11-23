import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state/switchable_state.dart';

final counter = AppState<int>(() => 0, debugName: 'counter');
final otherCounter = AppState<int>(() => 0, debugName: 'otherCounter');
final draft = AppState<int>.grouped(() => 0, debugName: 'draft');

void main() {
  late _RecordingAdapter adapter;

  setUp(() => adapter = _RecordingAdapter());

  /// Pumps [tree] and returns the registry seen by the widget [capture]
  /// builds.
  Future<StateRegistry> pumpAndCapture(
    WidgetTester tester,
    Widget Function(Widget capture) tree,
  ) async {
    late StateRegistry registry;
    await tester.pumpWidget(
      tree(
        Builder(
          builder: (context) {
            registry = StateScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return registry;
  }

  group('root StateScope', () {
    testWidgets('creates an app-wide store on first read and keeps it', (
      tester,
    ) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      expect(adapter.created, isEmpty, reason: 'stores are created lazily');

      final store = registry.store(counter);
      expect(store.value, 0);
      expect(registry.store(counter), same(store));
      expect(adapter.created, hasLength(1));
    });

    testWidgets('gives each declaration its own store', (tester) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      expect(
        registry.store(counter),
        isNot(same(registry.store(otherCounter))),
      );
    });

    testWidgets('seeds a store from an override', (tester) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(
          adapter: adapter,
          overrides: [counter.overrideWith(() => 5)],
          child: capture,
        ),
      );
      expect(registry.store(counter).value, 5);
      expect(registry.store(otherCounter).value, 0);
    });

    testWidgets('create returns a new store owned by the caller', (
      tester,
    ) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      final first = registry.create(1);
      final second = registry.create(1);
      expect(first, isNot(same(second)));
      expect(registry.store(counter), isNot(same(first)));
    });

    testWidgets('closes its app-wide stores, not created ones, when disposed', (
      tester,
    ) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      final appWide = registry.store(counter) as _FakeStore<int>;
      final created = registry.create(0) as _FakeStore<int>;

      await tester.pumpWidget(const SizedBox());
      expect(appWide.closed, isTrue);
      expect(created.closed, isFalse, reason: 'its owner closes it');
      expect(() => registry.store(counter), throwsStateError);
    });

    testWidgets('keeps its registry when rebuilt', (tester) async {
      Widget tree(Widget capture) =>
          StateScope(adapter: adapter, child: capture);
      final first = await pumpAndCapture(tester, tree);
      final second = await pumpAndCapture(tester, tree);
      expect(second, same(first));
    });

    testWidgets('of throws without a scope above', (tester) async {
      Object? error;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              StateScope.of(context);
            } catch (e) {
              error = e;
            }
            return const SizedBox();
          },
        ),
      );
      expect(error, isA<FlutterError>());
    });

    testWidgets('of works from initState', (tester) async {
      await tester.pumpWidget(
        StateScope(adapter: adapter, child: const _ReadsInInitState()),
      );
      expect(tester.takeException(), isNull);
      expect(adapter.created, hasLength(1));
    });

    testWidgets('rejects an override of a grouped state', (tester) async {
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          overrides: [draft.overrideWith(() => 1)],
          child: const SizedBox(),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('allows rebuilding with a non-const adapter of the same type', (
      tester,
    ) async {
      await tester.pumpWidget(
        StateScope(adapter: _RecordingAdapter(), child: const SizedBox()),
      );
      await tester.pumpWidget(
        StateScope(adapter: _RecordingAdapter(), child: const SizedBox()),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects duplicate overrides for the same AppState', (
      tester,
    ) async {
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          overrides: [
            counter.overrideWith(() => 1),
            counter.overrideWith(() => 2),
          ],
          child: const SizedBox(),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('rejects create() after disposal', (tester) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      await tester.pumpWidget(const SizedBox());
      expect(() => registry.create(0), throwsStateError);
    });

    testWidgets('supports re-entrant store reads during initialization', (
      tester,
    ) async {
      late StateRegistry registry;
      final derived = AppState<int>(
        () => registry.store(counter).value + 10,
        debugName: 'derived',
      );
      registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(
          adapter: adapter,
          overrides: [counter.overrideWith(() => 5)],
          child: capture,
        ),
      );
      expect(registry.store(derived).value, 15);
    });

    testWidgets('detects circular initialization', (tester) async {
      late StateRegistry registry;
      late final AppState<int> cyclicA;
      late final AppState<int> cyclicB;
      cyclicA = AppState<int>(
        () => registry.store(cyclicB).value,
        debugName: 'cyclicA',
      );
      cyclicB = AppState<int>(
        () => registry.store(cyclicA).value,
        debugName: 'cyclicB',
      );
      registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      expect(() => registry.store(cyclicA), throwsStateError);
    });

    testWidgets('preserves declared type S when first read through a supertype', (
      tester,
    ) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      final AppState<num> widened = counter;
      final asNum = registry.store(widened);
      final asInt = registry.store(counter);
      expect(asInt, same(asNum));
      expect(asInt.value, 0);
    });

    testWidgets('maybeOf returns null without a scope and registry inside one', (
      tester,
    ) async {
      StateRegistry? outside;
      StateRegistry? inside;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            outside = StateScope.maybeOf(context);
            return StateScope(
              adapter: adapter,
              child: Builder(
                builder: (innerContext) {
                  inside = StateScope.maybeOf(innerContext);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      expect(outside, isNull);
      expect(inside, isNotNull);
    });

    testWidgets('context.store() is shorthand for StateScope.of(context).store()', (
      tester,
    ) async {
      late StateStore<int> viaExtension;
      late StateStore<int> viaScope;
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: Builder(
            builder: (context) {
              viaExtension = context.store(counter);
              viaScope = StateScope.of(context).store(counter);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(viaExtension, same(viaScope));
    });

    testWidgets('overrideWithStore injects a custom store owned by the scope', (
      tester,
    ) async {
      final injected = _FakeStore<int>(99);
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(
          adapter: adapter,
          overrides: [counter.overrideWithStore(() => injected)],
          child: capture,
        ),
      );
      expect(registry.store(counter), same(injected));
      expect(adapter.created, isEmpty);

      await tester.pumpWidget(const SizedBox());
      expect(injected.closed, isTrue);
    });

    testWidgets('reset closes the store and starts fresh on next read', (
      tester,
    ) async {
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      final first = registry.store(counter) as _FakeStore<int>;
      first.replace(42);

      await registry.reset(counter);
      expect(first.closed, isTrue);

      final second = registry.store(counter);
      expect(second, isNot(same(first)));
      expect(second.value, 0);
    });

    testWidgets('StateObserver receives create, change, and close events', (
      tester,
    ) async {
      final events = <String>[];
      final observer = _RecordingObserver(events);
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(
          adapter: adapter,
          observers: [observer],
          child: capture,
        ),
      );

      final store = registry.store(counter);
      store.replace(1);
      store.replace(2);
      await tester.pumpWidget(const SizedBox());

      expect(events, [
        'create:counter',
        'change:counter:0->1',
        'change:counter:1->2',
        'close:counter',
      ]);
    });

    testWidgets('StateFamily caches keys per argument and isolates stores', (
      tester,
    ) async {
      final itemState = StateFamily<String, int>(
        (id) => 'item-$id',
        debugName: 'item',
      );
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );

      expect(itemState(1), same(itemState(1)));
      expect(itemState(1), isNot(same(itemState(2))));
      expect(registry.store(itemState(1)).value, 'item-1');
      expect(registry.store(itemState(2)).value, 'item-2');
      expect(
        registry.store(itemState(1)),
        isNot(same(registry.store(itemState(2)))),
      );
    });

    testWidgets('StateScope.inherit shares a registry without closing it', (
      tester,
    ) async {
      late StateRegistry group;
      late StateStore<int> seenInInherited;
      var showOverlay = false;
      late StateSetter setHostState;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return Stack(
              textDirection: TextDirection.ltr,
              children: [
                StateScope(
                  adapter: adapter,
                  child: StateScope.group(
                    owns: [draft],
                    child: Builder(
                      builder: (context) {
                        group = StateScope.of(context);
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                if (showOverlay)
                  StateScope.inherit(
                    registry: group,
                    child: Builder(
                      builder: (context) {
                        seenInInherited = context.store(draft);
                        return const SizedBox();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      );

      final draftStore = group.store(draft) as _FakeStore<int>;
      draftStore.replace(7);

      setHostState(() => showOverlay = true);
      await tester.pump();
      expect(seenInInherited, same(draftStore));
      expect(seenInInherited.value, 7);

      // Disposing the inherited scope must NOT close the original registry.
      setHostState(() => showOverlay = false);
      await tester.pump();
      expect(draftStore.closed, isFalse);
      expect(group.store(draft).value, 7);
    });

    testWidgets('supports nullable AppState declarations', (tester) async {
      final nullableUser = AppState<String?>(() => null, debugName: 'user');
      final registry = await pumpAndCapture(
        tester,
        (capture) => StateScope(adapter: adapter, child: capture),
      );
      final store = registry.store(nullableUser);
      expect(store.value, isNull);
      store.replace('Ada');
      expect(store.value, 'Ada');
      store.replace(null);
      expect(store.value, isNull);
    });
  });

  group('StateScope.group', () {
    Widget groupTree(Widget capture, {bool withGroup = true}) => StateScope(
      adapter: adapter,
      child: withGroup
          ? StateScope.group(owns: [draft], child: capture)
          : capture,
    );

    testWidgets('owns its grouped states and passes app-wide ones up', (
      tester,
    ) async {
      late StateRegistry root;
      late StateRegistry group;
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: Builder(
            builder: (context) {
              root = StateScope.of(context);
              return StateScope.group(
                owns: [draft],
                child: Builder(
                  builder: (context) {
                    group = StateScope.of(context);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(group, isNot(same(root)));
      expect(group.store(draft).value, 0);
      expect(group.store(counter), same(root.store(counter)));
    });

    testWidgets('a grouped state cannot be read outside an owning group', (
      tester,
    ) async {
      final root = await pumpAndCapture(
        tester,
        (capture) => groupTree(capture, withGroup: false),
      );
      expect(() => root.store(draft), throwsStateError);
    });

    testWidgets('closes only its own stores when the group is removed', (
      tester,
    ) async {
      final group = await pumpAndCapture(tester, groupTree);
      final grouped = group.store(draft) as _FakeStore<int>;
      final appWide = group.store(counter) as _FakeStore<int>;
      grouped.replace(3);

      final root = await pumpAndCapture(
        tester,
        (capture) => groupTree(capture, withGroup: false),
      );
      expect(grouped.closed, isTrue);
      expect(appWide.closed, isFalse);
      expect(root.store(counter), same(appWide));

      final regrouped = await pumpAndCapture(tester, groupTree);
      expect(regrouped.store(draft), isNot(same(grouped)));
      expect(
        regrouped.store(draft).value,
        0,
        reason: 'a new group starts over',
      );
    });

    testWidgets('can override the states it owns', (tester) async {
      final group = await pumpAndCapture(
        tester,
        (capture) => StateScope(
          adapter: adapter,
          child: StateScope.group(
            owns: [draft],
            overrides: [draft.overrideWith(() => 7)],
            child: capture,
          ),
        ),
      );
      expect(group.store(draft).value, 7);
    });

    testWidgets('rejects owning an app-wide state', (tester) async {
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: StateScope.group(owns: [counter], child: const SizedBox()),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('rejects overriding a state it does not own', (tester) async {
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: StateScope.group(
            owns: [draft],
            overrides: [counter.overrideWith(() => 1)],
            child: const SizedBox(),
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('needs a root scope above it', (tester) async {
      await tester.pumpWidget(
        StateScope.group(owns: [draft], child: const SizedBox()),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('allows rebuilding with reordered owns', (tester) async {
      final otherDraft = AppState<int>.grouped(
        () => 1,
        debugName: 'otherDraft',
      );
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: StateScope.group(
            owns: [draft, otherDraft],
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: StateScope.group(
            owns: [otherDraft, draft],
            child: const SizedBox(),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates parent registry when ancestor StateScope is replaced', (
      tester,
    ) async {
      final groupKey = GlobalKey();
      late StateRegistry groupRegistry;
      Widget buildTree(Key rootKey) => StateScope(
        key: rootKey,
        adapter: adapter,
        child: StateScope.group(
          key: groupKey,
          owns: [draft],
          child: Builder(
            builder: (context) {
              groupRegistry = StateScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(buildTree(const ValueKey('root-1')));
      final firstCounter = groupRegistry.store(counter);

      await tester.pumpWidget(buildTree(const ValueKey('root-2')));
      final secondCounter = groupRegistry.store(counter);
      expect(secondCounter, isNot(same(firstCounter)));
      expect(secondCounter.value, 0);
    });
  });

  group('StateStoreOwner', () {
    testWidgets('closes its stores after the subclass dispose body', (
      tester,
    ) async {
      final events = <String>[];
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: _Owner(events: events),
        ),
      );
      final store = adapter.created.single;
      expect(store.closed, isFalse);

      await tester.pumpWidget(
        StateScope(adapter: adapter, child: const SizedBox()),
      );
      expect(events, ['dispose body ran while store open']);
      expect(store.closed, isTrue);
    });

    testWidgets('rejects createStore during build', (tester) async {
      await tester.pumpWidget(
        StateScope(adapter: adapter, child: const _CreatesInBuild()),
      );
      expect(tester.takeException(), isAssertionError);
    });
  });
}

final class _ReadsInInitState extends StatefulWidget {
  const _ReadsInInitState();

  @override
  State<_ReadsInInitState> createState() => _ReadsInInitStateState();
}

final class _ReadsInInitStateState extends State<_ReadsInInitState> {
  @override
  void initState() {
    super.initState();
    StateScope.of(context).store(counter);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

final class _Owner extends StatefulWidget {
  const _Owner({required this.events});

  final List<String> events;

  @override
  State<_Owner> createState() => _OwnerState();
}

final class _OwnerState extends State<_Owner> with StateStoreOwner<_Owner> {
  late final _FakeStore<int> _store;

  @override
  void initState() {
    super.initState();
    _store = createStore(0) as _FakeStore<int>;
  }

  @override
  void dispose() {
    if (!_store.closed) widget.events.add('dispose body ran while store open');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

final class _CreatesInBuild extends StatefulWidget {
  const _CreatesInBuild();

  @override
  State<_CreatesInBuild> createState() => _CreatesInBuildState();
}

final class _CreatesInBuildState extends State<_CreatesInBuild>
    with StateStoreOwner<_CreatesInBuild> {
  @override
  Widget build(BuildContext context) {
    createStore(0);
    return const SizedBox();
  }
}

/// Records every store it creates so tests can check laziness and closing.
final class _RecordingAdapter implements StateAdapter {
  final created = <_FakeStore<Object?>>[];

  @override
  StateStore<S> create<S>(S initial) {
    final store = _FakeStore<S>(initial);
    created.add(store);
    return store;
  }
}

/// A simple store with synchronous listeners for testing ownership and hooks.
final class _FakeStore<S> implements StateStore<S> {
  _FakeStore(this.value);

  @override
  S value;

  bool closed = false;

  @override
  bool get isClosed => closed;

  final List<void Function(S previous, S current)> _listeners = [];

  @override
  void replace(S next) {
    if (closed) throw closedStoreError();
    if (value == next) return;
    final previous = value;
    value = next;
    for (final listener in _listeners.toList()) {
      listener(previous, next);
    }
  }

  @override
  Widget watch(Widget Function(S state) render) => render(value);

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      render(pick(value));

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (closed) return () {};
    _listeners.add(onChange);
    return () => _listeners.remove(onChange);
  }

  @override
  Future<void> close() async {
    closed = true;
    _listeners.clear();
  }
}

final class _RecordingObserver extends StateObserver {
  _RecordingObserver(this.events);

  final List<String> events;

  @override
  void onCreate(AppState<Object?> state, StateStore<Object?> store) {
    events.add('create:${state.debugName}');
  }

  @override
  void onChange(AppState<Object?> state, Object? previous, Object? next) {
    events.add('change:${state.debugName}:$previous->$next');
  }

  @override
  void onClose(AppState<Object?> state) {
    events.add('close:${state.debugName}');
  }
}
