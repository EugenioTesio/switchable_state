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
  final created = <_FakeStore<Object>>[];

  @override
  StateStore<S> create<S extends Object>(S initial) {
    final store = _FakeStore<S>(initial);
    created.add(store);
    return store;
  }
}

/// A non-reactive store: these tests only check ownership and lifetime.
final class _FakeStore<S extends Object> implements StateStore<S> {
  _FakeStore(this.value);

  @override
  S value;

  bool closed = false;

  @override
  void replace(S next) {
    if (closed) throw closedStoreError();
    value = next;
  }

  @override
  Widget watch(Widget Function(S state) render) => render(value);

  @override
  Widget select<R>(R Function(S state) pick, Widget Function(R value) render) =>
      render(pick(value));

  @override
  Future<void> close() async {
    closed = true;
  }
}
