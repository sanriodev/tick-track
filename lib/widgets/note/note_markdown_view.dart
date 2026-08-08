import 'package:ticktrack/util/helpers.dart';
import 'package:ticktrack/util/markdown_helper.dart';
import 'package:ticktrack/widgets/note/note_attachment_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class NoteMarkdownView extends StatelessWidget {
  final String markdown;
  final void Function(int taskIndex)? onToggleTask;

  const NoteMarkdownView({
    super.key,
    required this.markdown,
    this.onToggleTask,
  });

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) {
      return _buildEmptyHint(Theme.of(context));
    }

    return MarkdownBody(
      data: markdown,
      // a tap has to reach the checkbox, and selection swallows it
      selectable: onToggleTask == null,
      styleSheet: _buildStyleSheet(Theme.of(context)),
      imageBuilder: _buildImage,
      checkboxBuilder: _createCheckboxBuilder(context),
      onTapLink: _openLink,
    );
  }

  MarkdownCheckboxBuilder _createCheckboxBuilder(BuildContext context) {
    var renderedTasks = 0;
    return (checked) {
      final taskIndex = renderedTasks++;
      return _buildCheckbox(context, checked, taskIndex);
    };
  }

  Widget _buildCheckbox(BuildContext context, bool checked, int taskIndex) {
    final theme = Theme.of(context);
    final toggle = onToggleTask;

    return InkWell(
      onTap: toggle == null ? null : () => toggle(taskIndex),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
          size: 20,
          color: checked ? theme.primaryColor : theme.dividerColor,
        ),
      ),
    );
  }

  Widget _buildEmptyHint(ThemeData theme) {
    return Text(
      'Diese Notiz ist noch leer.',
      style: theme.primaryTextTheme.displayMedium,
    );
  }

  Widget _buildImage(Uri uri, String? title, String? alt) {
    final attachmentId = attachmentIdFromUri(uri.toString());
    if (attachmentId == null) {
      return const SizedBox.shrink();
    }
    return NoteAttachmentImage(attachmentId: attachmentId);
  }

  void _openLink(String text, String? href, String title) {
    if (href == null) {
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      launchUrlInBrowser(uri);
    }
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme) {
    final body = theme.primaryTextTheme.titleSmall;
    final muted = theme.primaryTextTheme.displayMedium?.color;
    final codeBackground = theme.canvasColor;

    return MarkdownStyleSheet(
      p: body?.copyWith(height: 1.45),
      h1: theme.primaryTextTheme.titleMedium,
      h2: theme.primaryTextTheme.displayLarge,
      h3: theme.primaryTextTheme.bodySmall,
      h4: theme.primaryTextTheme.bodySmall,
      h5: theme.primaryTextTheme.bodySmall,
      h6: theme.primaryTextTheme.bodySmall,
      strong: body?.copyWith(fontWeight: FontWeight.bold),
      em: body?.copyWith(fontStyle: FontStyle.italic),
      del: body?.copyWith(decoration: TextDecoration.lineThrough),
      a: body?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      listBullet: body,
      blockquote: body?.copyWith(color: muted),
      blockquoteDecoration: BoxDecoration(
        color: codeBackground.withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(color: theme.dividerColor, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      code: body?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: Colors.transparent,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      tableBorder: TableBorder.all(color: theme.dividerColor),
      tableHead: body?.copyWith(fontWeight: FontWeight.bold),
      tableBody: body,
      blockSpacing: 10,
    );
  }
}
