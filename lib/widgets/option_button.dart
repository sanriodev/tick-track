import 'package:ticktrack/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class OptionButton extends StatelessWidget {
  const OptionButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        color: Theme.of(context).iconTheme.color,
        icon: PhosphorIcon(
          PhosphorIconsRegular.gear,
          semanticLabel: context.l10n.settings,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
