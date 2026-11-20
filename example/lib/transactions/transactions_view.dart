import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../starred/starred_widgets.dart';
import 'transactions.dart';

final class TransactionsView extends StatelessWidget {
  const TransactionsView({
    super.key,
    required this.state,
    required this.actions,
  });

  final TransactionsState state;
  final TransactionsActions actions;

  @override
  Widget build(BuildContext context) {
    final visible = state.visibleEntries.toList(growable: false);
    final notice = switch (state.status) {
      LoadStatus.loading => 'Updating transactions…',
      LoadStatus.failed => 'Couldn’t load transactions. Tap Refresh to retry.',
      LoadStatus.ready when visible.isEmpty => 'No matching transactions.',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Pending only'),
          value: state.pendingOnly,
          onChanged: actions.setPendingOnly,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => unawaited(actions.refresh()),
            child: const Text('Refresh'),
          ),
        ),
        if (notice != null) Semantics(liveRegion: true, child: Text(notice)),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final entry = visible[index];
              return ListTile(
                key: ValueKey(entry.description),
                leading: StarButton(description: entry.description),
                title: Text(entry.description),
                trailing: Text(entry.pending ? 'Pending' : 'Settled'),
              );
            },
          ),
        ),
      ],
    );
  }
}
