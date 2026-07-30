import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Corner radius the cards in the overviews are drawn with. The slidable
/// actions next to them line up with it.
const double _cardRadius = 12;

/// Rounding for the action at the outer end of a start (left hand) pane.
/// Square towards the card so it reads as continuing underneath it.
const BorderRadius slidableStartOuterRadius =
    BorderRadius.horizontal(left: Radius.circular(_cardRadius));

/// Rounding for the action at the outer end of an end (right hand) pane.
const BorderRadius slidableEndOuterRadius =
    BorderRadius.horizontal(right: Radius.circular(_cardRadius));

// Actions sitting between the outer end of a pane and the card stay square on
// both sides so a pane with several actions reads as one strip. That is
// already `SlidableAction`'s default, so they need no constant here.

/// Closes the gap the cards' rounded corners would otherwise leave next to a
/// revealed slidable action.
///
/// The cards are rounded, so where a card meets a revealed action the scaffold
/// background shows through its corner and the action appears to stop short
/// instead of running underneath the card. Painting the color of the action
/// that sits directly next to the card into that notch produces the "the card
/// slides aside and the action appears from behind it" effect.
///
/// Belongs directly into the [Stack] behind the `Slidable`, sharing its
/// [controller]: which pane is open decides the color, and the notch travels
/// with the card as it slides, so a fixed left/right split would not do.
class SlidableUnderlay extends StatelessWidget {
  /// The controller of the `Slidable` this sits behind. Only needed when the
  /// card has a pane on both sides - with a single pane there is nothing to
  /// tell apart and the one color given is simply painted permanently.
  final SlidableController? controller;

  /// Color of the start pane's action that sits directly next to the card.
  /// Omit when there is no start pane.
  final Color? startColor;

  /// Color of the end pane's action that sits directly next to the card.
  /// Omit when there is no end pane.
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
      // inset by more than the corner radius: the notch to fill is always at
      // the card's sliding edge, well inside the card, while the outer corner
      // of the pane itself has to stay rounded against the background
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
                    // nothing revealed, so nothing to fill
                    ActionPaneType.none => null,
                  };
                  return ColoredBox(color: color ?? Colors.transparent);
                },
              ),
      ),
    );
  }
}
