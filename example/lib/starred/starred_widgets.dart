import 'package:material_ui/material_ui.dart';

import 'package:switchable_state/switchable_state.dart';

import 'starred.dart';

/// Stars or unstars one transaction. It reads the app-wide starred store
/// itself, so any screen can place it without passing state around.
final class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final starred = StateScope.of(context).store(starredState);
    return starred.select(
      (state) => state.contains(description),
      (isStarred) => IconButton(
        tooltip: isStarred ? 'Unstar $description' : 'Star $description',
        icon: Icon(isStarred ? Icons.star : Icons.star_border),
        onPressed: () => starred.update((state) => state.toggled(description)),
      ),
    );
  }
}

/// Shows how many transactions are starred. It rebuilds only when the count
/// changes, not on every star.
final class StarredCountButton extends StatelessWidget {
  const StarredCountButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final starred = StateScope.of(context).store(starredState);
    return starred.select(
      (state) => state.count,
      (count) => TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.star),
        label: Text('Starred ($count)'),
      ),
    );
  }
}
