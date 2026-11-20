import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_example/starred/starred.dart';

void main() {
  test('starts empty', () {
    const state = StarredState.initial();
    expect(state.count, 0);
    expect(state.contains('Coffee'), isFalse);
  });

  test('toggled stars and unstars a description', () {
    final starred = const StarredState.initial().toggled('Coffee');
    expect(starred.contains('Coffee'), isTrue);
    expect(starred.count, 1);

    final unstarred = starred.toggled('Coffee');
    expect(unstarred.contains('Coffee'), isFalse);
    expect(unstarred.count, 0);
  });

  test('keeps the order descriptions were starred in', () {
    final state = const StarredState.initial()
        .toggled('Coffee')
        .toggled('Books')
        .toggled('Rent')
        .toggled('Books')
        .toggled('Books');
    expect(state.descriptions, ['Coffee', 'Rent', 'Books']);
  });

  test('returns a new snapshot and never changes the previous one', () {
    const initial = StarredState.initial();
    final next = initial.toggled('Coffee');
    expect(next, isNot(same(initial)));
    expect(initial.count, 0);
  });

  test('exposes an unmodifiable set', () {
    final state = const StarredState.initial().toggled('Coffee');
    expect(() => state.descriptions.add('Books'), throwsUnsupportedError);
  });
}
