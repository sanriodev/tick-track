import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown instead of an empty list. Explains what the screen would hold and
/// points at the way to create the first entry, so a fresh account never
/// looks broken.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Optional call to action, e.g. "Erste Notiz anlegen".
  final String? actionLabel;
  final void Function()? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // stays scrollable and fills the viewport so it sits centered and
    // pull to refresh keeps working on an otherwise empty screen
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _buildContent(theme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.canvasColor,
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                icon,
                size: 48,
                color: theme.primaryIconTheme.color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.primaryTextTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.primaryTextTheme.titleSmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(
                  actionLabel!,
                  style: theme.primaryTextTheme.titleSmall?.copyWith(
                    color: theme.brightness == Brightness.light
                        ? Colors.white
                        : Colors.grey[900],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
