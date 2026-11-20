enum LoadStatus { idle, loading, ready, failed }

final class TransactionEntry {
  const TransactionEntry(this.description, {required this.pending});

  final String description;
  final bool pending;
}

final class TransactionsState {
  const TransactionsState._(this.entries, this.pendingOnly, this.status);
  const TransactionsState.initial() : this._(const [], false, LoadStatus.idle);

  final List<TransactionEntry> entries;
  final bool pendingOnly;
  final LoadStatus status;

  Iterable<TransactionEntry> get visibleEntries =>
      pendingOnly ? entries.where((entry) => entry.pending) : entries;

  TransactionsState withFilter(bool enabled) => enabled == pendingOnly
      ? this
      : TransactionsState._(entries, enabled, status);

  TransactionsState withStatus(LoadStatus next) =>
      next == status ? this : TransactionsState._(entries, pendingOnly, next);

  TransactionsState withEntries(List<TransactionEntry> next) =>
      TransactionsState._(
        List<TransactionEntry>.unmodifiable(next),
        pendingOnly,
        LoadStatus.ready,
      );
}

typedef LoadTransactions = Future<List<TransactionEntry>> Function();
typedef UpdateState<S> = void Function(S Function(S current) change);

abstract interface class TransactionsActions {
  void setPendingOnly(bool enabled);
  Future<void> refresh();
}

final class TransactionsController implements TransactionsActions {
  TransactionsController({required this.load, required this.update});

  final LoadTransactions load;
  final UpdateState<TransactionsState> update;
  int _request = 0;
  bool _disposed = false;

  @override
  void setPendingOnly(bool enabled) {
    if (_disposed) return;
    update((current) => current.withFilter(enabled));
  }

  @override
  Future<void> refresh() async {
    if (_disposed) return;
    final request = ++_request;
    update((current) => current.withStatus(LoadStatus.loading));

    final List<TransactionEntry> entries;
    try {
      entries = await load();
    } catch (_) {
      if (_isCurrent(request)) {
        update((current) => current.withStatus(LoadStatus.failed));
      }
      return;
    }

    if (_isCurrent(request)) {
      // The user may have changed the filter while this request was pending.
      update((current) => current.withEntries(entries));
    }
  }

  bool _isCurrent(int request) => !_disposed && request == _request;

  void dispose() => _disposed = true;
}
