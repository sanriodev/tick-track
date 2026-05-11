import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
        icon: const PhosphorIcon(
          PhosphorIconsRegular.gear,
          semanticLabel: 'Einstellungen',
        ),
        onPressed: onPressed,
      ),
    );
  }
}
