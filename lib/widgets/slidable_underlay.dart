import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

const double _cardRadius = 12;

const BorderRadius slidableStartOuterRadius =
    BorderRadius.horizontal(left: Radius.circular(_cardRadius));

const BorderRadius slidableEndOuterRadius =
    BorderRadius.horizontal(right: Radius.circular(_cardRadius));

class SlidableUnderlay extends StatelessWidget {
  final SlidableController? controller;

  final Color? startColor;

  final Color? endColor;

  const SlidableUnderlay({
    super.key,
    this.controller,
    this.startColor,
    this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    final localController = controller;

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _cardRadius + 2),
        child: localController == null
            ? ColoredBox(color: endColor ?? startColor ?? Colors.transparent)
            : ValueListenableBuilder<ActionPaneType>(
                valueListenable: localController.actionPaneType,
                builder: (context, type, _) {
                  final Color? color = switch (type) {
                    ActionPaneType.start => startColor,
                    ActionPaneType.end => endColor,
                    ActionPaneType.none => null,
                  };
                  return ColoredBox(color: color ?? Colors.transparent);
                },
              ),
      ),
    );
  }
}
