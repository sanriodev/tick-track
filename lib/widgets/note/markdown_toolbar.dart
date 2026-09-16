import 'package:ticktrack/l10n/l10n.dart';
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
    final l10n = context.l10n;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _button(context, PhosphorIconsRegular.image, l10n.mdImage,
              onInsertImage),
          _button(context, PhosphorIconsRegular.link, l10n.mdLink, onInsertLink),
          _divider(context),
          _button(context, PhosphorIconsRegular.textB, l10n.mdBold,
              () => wrapSelection(controller, MarkdownWrap.bold)),
          _button(context, PhosphorIconsRegular.textItalic, l10n.mdItalic,
              () => wrapSelection(controller, MarkdownWrap.italic)),
          _button(
              context,
              PhosphorIconsRegular.textStrikethrough,
              l10n.mdStrikethrough,
              () => wrapSelection(controller, MarkdownWrap.strikethrough)),
          _divider(context),
          _button(context, PhosphorIconsRegular.textH, l10n.mdHeading,
              () => prefixCurrentLine(controller, MarkdownLinePrefix.heading)),
          _button(context, PhosphorIconsRegular.listBullets, l10n.mdList,
              () => prefixCurrentLine(controller, MarkdownLinePrefix.bullet)),
          _button(context, PhosphorIconsRegular.listNumbers, l10n.mdNumbered,
              () => prefixCurrentLine(controller, MarkdownLinePrefix.numbered)),
          _button(context, PhosphorIconsRegular.checkSquare, l10n.mdCheckbox,
              () => prefixCurrentLine(controller, MarkdownLinePrefix.checkbox)),
          _divider(context),
          _button(context, PhosphorIconsRegular.quotes, l10n.mdQuote,
              () => prefixCurrentLine(controller, MarkdownLinePrefix.quote)),
          _button(context, PhosphorIconsRegular.code, l10n.mdCode,
              () => wrapSelection(controller, MarkdownWrap.inlineCode)),
          _button(context, PhosphorIconsRegular.codeBlock, l10n.mdCodeBlock,
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
