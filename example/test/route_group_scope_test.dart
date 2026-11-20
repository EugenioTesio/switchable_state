import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';
import 'package:switchable_state_getx/switchable_state_getx.dart';
import 'package:switchable_state_mobx/switchable_state_mobx.dart';
import 'package:switchable_state_provider/switchable_state_provider.dart';
import 'package:switchable_state_riverpod/switchable_state_riverpod.dart';
import 'package:switchable_state/switchable_state.dart';

const adapters = <String, StateAdapter>{
  'Cubit': CubitStateAdapter(),
  'GetX': GetXStateAdapter(),
  'MobX': MobXStateAdapter(),
  'Provider': ProviderStateAdapter(),
  'Riverpod': RiverpodStateAdapter(),
};

/// Shared by the routes under one ShellRoute and dropped when leaving them.
final draftState = AppState<int>.grouped(() => 0, debugName: 'draft');

/// App-wide, so it survives leaving the group.
final likesState = AppState<int>(() => 0, debugName: 'likes');

void main() {
  for (final MapEntry(key: name, value: adapter) in adapters.entries) {
    testWidgets('$name: a ShellRoute group keeps state across its routes and '
        'closes it on leaving', (tester) async {
      final router = GoRouter(
        initialLocation: '/group/a',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _Home()),
          ShellRoute(
            builder: (context, state, child) =>
                StateScope.group(owns: [draftState], child: child),
            routes: [
              GoRoute(
                path: '/group/a',
                builder: (context, state) => const _GroupPage(label: 'a'),
              ),
              GoRoute(
                path: '/group/b',
                builder: (context, state) => const _GroupPage(label: 'b'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        StateScope(
          adapter: adapter,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      expect(find.text('a: draft 0, likes 0'), findsOneWidget);

      await tester.tap(find.text('Edit draft'));
      await tester.tap(find.text('Like'));
      await tester.pumpAndSettle();
      expect(find.text('a: draft 1, likes 1'), findsOneWidget);

      router.go('/group/b');
      await tester.pumpAndSettle();
      expect(find.text('b: draft 1, likes 1'), findsOneWidget);
      final draft = StateScope.of(tester.element(find.byType(_GroupPage)))
          .store(draftState);

      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(
        () => draft.replace(5),
        throwsStateError,
        reason: 'leaving the group closes its stores',
      );

      router.go('/group/a');
      await tester.pumpAndSettle();
      expect(
        find.text('a: draft 0, likes 1'),
        findsOneWidget,
        reason: 'the group starts over; app-wide state is kept',
      );
    });
  }
}

final class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

final class _GroupPage extends StatelessWidget {
  const _GroupPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final states = StateScope.of(context);
    final draft = states.store(draftState);
    final likes = states.store(likesState);
    return Scaffold(
      body: Column(
        children: [
          draft.watch(
            (d) => likes.select(
              (s) => s,
              (count) => Text('$label: draft $d, likes $count'),
            ),
          ),
          TextButton(
            onPressed: () => draft.update((d) => d + 1),
            child: const Text('Edit draft'),
          ),
          TextButton(
            onPressed: () => likes.update((s) => s + 1),
            child: const Text('Like'),
          ),
        ],
      ),
    );
  }
}
