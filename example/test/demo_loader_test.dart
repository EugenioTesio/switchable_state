import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_example/main.dart';

void main() {
  test('the demo backend alternates between success and failure', () async {
    expect(await loadDemoTransactions(), hasLength(3));
    await expectLater(loadDemoTransactions(), throwsStateError);
    expect(await loadDemoTransactions(), hasLength(3));
  });
}
