import 'package:material_ui/material_ui.dart';

import 'state_management.dart';

/// The start screen: the user picks which library backs every store.
final class StateManagementPage extends StatelessWidget {
  const StateManagementPage({super.key, required this.onSelected});

  final ValueChanged<StateManagementOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose state management')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Every screen uses the same state contract. Pick the '
                    'library that implements it for this session.',
                  ),
                ),
                for (final option in stateManagementOptions)
                  ListTile(
                    title: Text(option.name),
                    subtitle: Text(option.summary),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
