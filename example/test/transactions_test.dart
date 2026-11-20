import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:switchable_state_example/transactions/transactions.dart';

void main() {
  late TransactionsState state;
  late List<Completer<List<TransactionEntry>>> requests;
  late TransactionsController controller;

  setUp(() {
    state = const TransactionsState.initial();
    requests = [];
    controller = TransactionsController(
      load: () {
        final request = Completer<List<TransactionEntry>>();
        requests.add(request);
        return request.future;
      },
      update: (change) => state = change(state),
    );
  });

  test(
    'the newest refresh wins even when an older request fails later',
    () async {
      final older = controller.refresh();
      final newer = controller.refresh();
      controller.setPendingOnly(true);
      expect(state.status, LoadStatus.loading);

      requests[1].complete(const [TransactionEntry('New', pending: true)]);
      await newer;
      final accepted = state;
      requests[0].completeError(StateError('late failure'));
      await older;

      expect(state, same(accepted));
      expect(state.visibleEntries.single.description, 'New');
      expect(state.pendingOnly, isTrue);
    },
  );

  test('a late success cannot overwrite a newer result', () async {
    final older = controller.refresh();
    final newer = controller.refresh();
    requests[1].complete(const [TransactionEntry('Newest', pending: false)]);
    await newer;
    requests[0].complete(const [TransactionEntry('Stale', pending: true)]);
    await older;
    expect(state.entries.single.description, 'Newest');
  });

  test(
    'a refresh failure keeps existing rows and the user can retry',
    () async {
      final first = controller.refresh();
      final mutableRows = [const TransactionEntry('Existing', pending: true)];
      requests[0].complete(mutableRows);
      await first;
      mutableRows.clear();
      expect(state.entries.single.description, 'Existing');

      final failed = controller.refresh();
      requests[1].completeError(StateError('offline'));
      await failed;
      expect(state.status, LoadStatus.failed);
      expect(state.entries.single.description, 'Existing');

      final retried = controller.refresh();
      requests[2].complete(const []);
      await retried;
      expect(state.status, LoadStatus.ready);
      expect(state.entries, isEmpty);
    },
  );

  test('disposal ignores late completions and subsequent commands', () async {
    final pending = controller.refresh();
    controller.dispose();
    final last = state;
    requests.single.complete(const [TransactionEntry('Late', pending: true)]);
    await pending;
    controller.setPendingOnly(true);
    await controller.refresh();
    expect(requests, hasLength(1));
    expect(state, same(last));
  });
}
