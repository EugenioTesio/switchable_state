import 'package:material_ui/material_ui.dart';

import 'package:switchable_state/switchable_state.dart';

import 'starred.dart';
import 'starred_widgets.dart';

/// Lists the starred transactions from the app-wide starred store.
final class StarredPage extends StatelessWidget {
  const StarredPage({super.key, this.onOpenTransactions});

  final VoidCallback? onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final starred = StateScope.of(context).store(starredState);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred'),
        actions: [
          TextButton(
            onPressed: onOpenTransactions,
            child: const Text('Transactions'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: starred.watch((state) {
                if (state.descriptions.isEmpty) {
                  return const Center(child: Text('No starred transactions.'));
                }
                final descriptions = state.descriptions.toList(growable: false);
                return ListView.builder(
                  itemCount: descriptions.length,
                  itemBuilder: (context, index) {
                    final description = descriptions[index];
                    return ListTile(
                      key: ValueKey(description),
                      title: Text(description),
                      trailing: StarButton(description: description),
                    );
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
