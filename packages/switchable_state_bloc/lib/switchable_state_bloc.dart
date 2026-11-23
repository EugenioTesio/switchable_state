/// A `switchable_state` adapter backed by `package:flutter_bloc`.
///
/// Register [CubitStateAdapter] in the root [StateScope]:
///
/// ```dart
/// StateScope(
///   adapter: const CubitStateAdapter(),
///   child: const MyApp(),
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:switchable_state/switchable_state.dart';

/// A [StateAdapter] backed by [Cubit].
///
/// Each store is a [Cubit] that publishes with [Cubit.emit].
/// [StateStore.watch] uses a [BlocBuilder] and [StateStore.select] a
/// [BlocSelector].
///
/// A [Cubit] delivers changes through a stream, so a rebuild or listener can
/// land one frame after the write. In widget tests, call `pumpAndSettle` after
/// a write.
final class CubitStateAdapter implements StateAdapter {
  /// Creates the adapter.
  ///
  /// It is stateless, so one `const` instance serves the whole app.
  const CubitStateAdapter();

  @override
  StateStore<S> create<S>(S initial) => _CubitStore<S>(initial);
}

final class _CubitStore<S> extends Cubit<S> implements StateStore<S> {
  _CubitStore(super.initial);

  @override
  S get value => state;

  @override
  void replace(S next) {
    if (isClosed) throw closedStoreError();
    if (state == next) return;
    emit(next);
  }

  @override
  Widget watch(Widget Function(S) render) => BlocBuilder<_CubitStore<S>, S>(
    bloc: this,
    builder: (context, snapshot) => render(snapshot),
  );

  @override
  Widget select<R>(R Function(S) pick, Widget Function(R) render) =>
      BlocSelector<_CubitStore<S>, S, R>(
        bloc: this,
        selector: pick,
        builder: (context, value) => render(value),
      );

  @override
  VoidCallback listen(void Function(S previous, S current) onChange) {
    if (isClosed) return () {};
    var previous = state;
    var canceled = false;
    final subscription = stream.listen((next) {
      if (canceled) return;
      final prev = previous;
      previous = next;
      onChange(prev, next);
    });
    return () {
      if (canceled) return;
      canceled = true;
      unawaited(subscription.cancel());
    };
  }

  @override
  Future<void> close() async {
    if (isClosed) return;
    await super.close();
  }
}
