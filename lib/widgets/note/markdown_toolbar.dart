import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/markdown_editing.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertLink;
  final bool enabled;

  const MarkdownToolbar({
    super.key,
    required this.controller,
    required this.onInsertImage,
    required this.onInsertLink,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _button(context, PhosphorIconsRegular.image, 'Bild', onInsertImage),
          _button(context, PhosphorIconsRegular.link, 'Link', onInsertLink),
          _divider(context),
          _button(context, PhosphorIconsRegular.textB, 'Fett',
              () => wrapSelection(controller, MarkdownWrap.bold)),
          _button(context, PhosphorIconsRegular.textItalic, 'Kursiv',
              () => wrapSelection(controller, MarkdownWrap.italic)),
          _button(
              context,
              PhosphorIconsRegular.textStrikethrough,
              'Durchgestrichen',
              () => wrapSelection(controller, MarkdownWrap.strikethrough)),
          _divider(context),
          _button(context, PhosphorIconsRegular.textH, 'Überschrift',
              () => prefixCurrentLine(controller, MarkdownLinePrefix.heading)),
          _button(context, PhosphorIconsRegular.listBullets, 'Liste',
              () => prefixCurrentLine(controller, MarkdownLinePrefix.bullet)),
          _button(context, PhosphorIconsRegular.listNumbers, 'Nummeriert',
              () => prefixCurrentLine(controller, MarkdownLinePrefix.numbered)),
          _button(context, PhosphorIconsRegular.checkSquare, 'Checkbox',
              () => prefixCurrentLine(controller, MarkdownLinePrefix.checkbox)),
          _divider(context),
          _button(context, PhosphorIconsRegular.quotes, 'Zitat',
              () => prefixCurrentLine(controller, MarkdownLinePrefix.quote)),
          _button(context, PhosphorIconsRegular.code, 'Code',
              () => wrapSelection(controller, MarkdownWrap.inlineCode)),
          _button(context, PhosphorIconsRegular.codeBlock, 'Codeblock',
              () => insertCodeBlock(controller)),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    PhosphorIconData icon,
    String tooltip,
    VoidCallback action,
  ) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: PhosphorIcon(icon, size: 20),
      color: Theme.of(context).primaryIconTheme.color,
      onPressed: enabled ? () => _run(action) : null,
    );
  }

  void _run(VoidCallback action) {
    Haptics.tick();
    action();
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }
}
