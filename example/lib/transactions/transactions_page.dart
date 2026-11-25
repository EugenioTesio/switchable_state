import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../starred/starred_widgets.dart';

import 'package:switchable_state/switchable_state.dart';

import 'transactions.dart';
import 'transactions_view.dart';

final class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.load, this.onOpenStarred});

  final LoadTransactions load;
  final VoidCallback? onOpenStarred;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

final class _TransactionsPageState extends State<TransactionsPage>
    with StateStoreOwner<TransactionsPage> {
  late final StateStore<TransactionsState> _store;
  late final TransactionsController _controller;

  @override
  void initState() {
    super.initState();
    // Route-owned, like an autoDispose provider: StateStoreOwner closes it
    // when this route is disposed.
    _store = createStore(const TransactionsState.initial());
    // Read widget.load on each request so a rebuilt page uses its newest
    // loader.
    _controller = TransactionsController(
      load: () => widget.load(),
      update: _store.update,
    );
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    // Stop the controller first; StateStoreOwner then closes the store.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A one-shot side effect, like BlocListener or ref.listen: it reacts to
    // the store without rebuilding the page, and runs after the write that
    // caused it, whichever library is registered.
    return StateListener<TransactionsState>(
      store: _store,
      // Only on entering the failed state, not on every later write while
      // it stays failed (toggling the filter, for example).
      listenWhen: (previous, current) =>
          previous.status != LoadStatus.failed &&
          current.status == LoadStatus.failed,
      listener: (context, state) => _showLoadFailed(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transactions'),
          actions: [StarredCountButton(onPressed: widget.onOpenStarred)],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _store.watch(
                  (state) =>
                      TransactionsView(state: state, actions: _controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLoadFailed(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Couldn’t load transactions.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_controller.refresh()),
          ),
        ),
      );
  }
}
