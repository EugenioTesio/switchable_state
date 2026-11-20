import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_bloc/switchable_state_bloc.dart';

import 'package:switchable_state_test/switchable_state_test.dart';

void main() {
  const adapter = CubitStateAdapter();

  stateStoreContract(adapter);

  group('Cubit binding', () {
    test(
      'each store is a Cubit that publishes replacements on its stream',
      () async {
        final store = adapter.create(0);
        final published = expectLater(
          (store as Cubit<int>).stream,
          emitsInOrder(<Object>[1, 2, emitsDone]),
        );

        store.replace(1);
        store.replace(2);
        await store.close();
        await published;
      },
    );

    testWidgets('watch renders through a BlocBuilder bound to the store', (
      tester,
    ) async {
      final store = adapter.create(0);
      addTearDown(store.close);
      await tester.pumpWidget(host(store.watch((n) => Text('count $n'))));

      final builder = tester.widget<BlocBuilderBase<Cubit<int>, int>>(
        find.byWidgetPredicate((w) => w is BlocBuilderBase<Cubit<int>, int>),
      );
      expect(builder.bloc, same(store));
    });

    test('close closes the Cubit', () async {
      final store = adapter.create(0);
      await store.close();
      expect((store as Cubit<int>).isClosed, isTrue);
    });

    test('a write after close is rejected before reaching emit', () async {
      final errors = <Object>[];
      final previousObserver = Bloc.observer;
      Bloc.observer = _ErrorRecorder(errors);
      addTearDown(() => Bloc.observer = previousObserver);

      final store = adapter.create(0);
      await store.close();
      expect(() => store.replace(1), throwsStateError);
      expect(
        errors,
        isEmpty,
        reason: 'emit reports its own failures to the observer',
      );
    });
  });
}

final class _ErrorRecorder extends BlocObserver {
  _ErrorRecorder(this.errors);

  final List<Object> errors;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}
