import 'package:flutter/material.dart';

enum MarkdownWrap {
  bold('**', '**'),
  italic('_', '_'),
  strikethrough('~~', '~~'),
  inlineCode('`', '`');

  const MarkdownWrap(this.prefix, this.suffix);

  final String prefix;
  final String suffix;
}

enum MarkdownLinePrefix {
  heading('## '),
  quote('> '),
  bullet('- '),
  numbered('1. '),
  checkbox('- [ ] ');

  const MarkdownLinePrefix(this.marker);

  final String marker;
}

void wrapSelection(TextEditingController controller, MarkdownWrap wrap) {
  final selection = controller.selection;
  final text = controller.text;
  if (!selection.isValid) {
    _appendAtEnd(controller, '${wrap.prefix}${wrap.suffix}');
    return;
  }

  final selected = selection.textInside(text);
  final replacement = '${wrap.prefix}$selected${wrap.suffix}';
  final cursor = selected.isEmpty
      ? selection.start + wrap.prefix.length
      : selection.start + replacement.length;

  _replace(controller, selection, replacement, cursor);
}

void prefixCurrentLine(
  TextEditingController controller,
  MarkdownLinePrefix prefix,
) {
  final selection = controller.selection;
  final text = controller.text;
  if (!selection.isValid) {
    _appendAtEnd(controller, prefix.marker);
    return;
  }

  final lineStart = _lineStartBefore(text, selection.start);
  final updated = text.replaceRange(lineStart, lineStart, prefix.marker);
  controller.value = TextEditingValue(
    text: updated,
    selection: TextSelection.collapsed(
      offset: selection.start + prefix.marker.length,
    ),
  );
}

void insertCodeBlock(TextEditingController controller) {
  final selection = controller.selection;
  final text = controller.text;
  final selected = selection.isValid ? selection.textInside(text) : '';
  final replacement = '\n```\n$selected\n```\n';
  final cursor = (selection.isValid ? selection.start : text.length) +
      replacement.indexOf('\n', 5) +
      1;

  if (!selection.isValid) {
    _appendAtEnd(controller, replacement);
    return;
  }
  _replace(controller, selection, replacement, cursor);
}

void insertLink(
  TextEditingController controller, {
  required String label,
  required String url,
}) {
  insertAtCursor(controller, '[$label]($url)');
}

void insertAtCursor(TextEditingController controller, String snippet) {
  final selection = controller.selection;
  if (!selection.isValid) {
    _appendAtEnd(controller, snippet);
    return;
  }
  _replace(controller, selection, snippet, selection.start + snippet.length);
}

void insertBlockAtCursor(TextEditingController controller, String block) {
  final text = controller.text;
  final needsLeadingBreak = text.isNotEmpty && !text.endsWith('\n');
  insertAtCursor(controller, '${needsLeadingBreak ? '\n\n' : ''}$block\n');
}

int _lineStartBefore(String text, int offset) {
  final previousBreak = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0);
  return previousBreak < 0 ? 0 : previousBreak + 1;
}

void _replace(
  TextEditingController controller,
  TextSelection selection,
  String replacement,
  int cursor,
) {
  controller.value = TextEditingValue(
    text: controller.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    ),
    selection: TextSelection.collapsed(offset: cursor),
  );
}

void _appendAtEnd(TextEditingController controller, String snippet) {
  final updated = '${controller.text}$snippet';
  controller.value = TextEditingValue(
    text: updated,
    selection: TextSelection.collapsed(offset: updated.length),
  );
}
