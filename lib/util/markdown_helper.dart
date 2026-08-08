import 'package:ticktrack/models/note/note_attachment_model.dart';

final RegExp _attachmentUriPattern = RegExp('^$attachmentUriScheme:(\\d+)\$');
final RegExp _imagePattern = RegExp(r'!\[[^\]]*\]\([^)]*\)');
final RegExp _linkPattern = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final RegExp _fencedCodePattern = RegExp(r'```[\s\S]*?```');
final RegExp _inlineCodePattern = RegExp('`([^`]*)`');
final RegExp _headingPattern = RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true);
final RegExp _quotePattern = RegExp(r'^\s{0,3}>\s?', multiLine: true);
final RegExp _listBulletPattern =
    RegExp(r'^\s{0,3}([-*+]|\d+\.)\s+', multiLine: true);
final RegExp _emphasisPattern = RegExp(r'(\*{1,3}|_{1,3}|~~)');
final RegExp _horizontalRulePattern =
    RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$', multiLine: true);
final RegExp _trailingSpacesPattern = RegExp(r'[ \t]+$', multiLine: true);
final RegExp _repeatedSpacesPattern = RegExp(r'[ \t]{2,}');
final RegExp _blankLinesPattern = RegExp(r'\n[ \t]*(?:\n[ \t]*)+');

final RegExp _taskLinePattern =
    RegExp(r'^(\s*(?:[-*+]|\d+\.)\s+\[)([ xX])(\])');

int countTasks(String markdown) {
  return markdown
      .split('\n')
      .where((line) => _taskLinePattern.hasMatch(line))
      .length;
}

String toggleTaskAt(String markdown, int taskIndex) {
  final lines = markdown.split('\n');
  var seenTasks = 0;

  for (var index = 0; index < lines.length; index++) {
    final match = _taskLinePattern.firstMatch(lines[index]);
    if (match == null) {
      continue;
    }
    if (seenTasks == taskIndex) {
      lines[index] = _flipTaskState(lines[index], match);
      break;
    }
    seenTasks++;
  }

  return lines.join('\n');
}

String _flipTaskState(String line, RegExpMatch match) {
  final statePosition = match.group(1)!.length;
  final isChecked = match.group(2)!.toLowerCase() == 'x';
  return line.replaceRange(statePosition, statePosition + 1, isChecked ? ' ' : 'x');
}

int? attachmentIdFromUri(String uri) {
  final match = _attachmentUriPattern.firstMatch(uri.trim());
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(1)!);
}

Set<int> referencedAttachmentIds(String markdown) {
  final ids = <int>{};
  for (final match in _imagePattern.allMatches(markdown)) {
    final uri = _uriOf(match.group(0)!);
    final id = uri == null ? null : attachmentIdFromUri(uri);
    if (id != null) {
      ids.add(id);
    }
  }
  return ids;
}

String? _uriOf(String imageMarkdown) {
  final start = imageMarkdown.lastIndexOf('(');
  final end = imageMarkdown.lastIndexOf(')');
  if (start < 0 || end <= start) {
    return null;
  }
  return imageMarkdown.substring(start + 1, end);
}

String removeAttachmentReference(String markdown, int attachmentId) {
  return markdown
      .replaceAll(
        RegExp(r'!\[[^\]]*\]\(' '$attachmentUriScheme:$attachmentId' r'\)\n?'),
        '',
      )
      .trimRight();
}

String markdownToPlainText(String markdown) {
  return markdown
      .replaceAll(_fencedCodePattern, ' ')
      .replaceAll(_imagePattern, ' ')
      .replaceAllMapped(_linkPattern, (match) => match.group(1) ?? '')
      .replaceAllMapped(_inlineCodePattern, (match) => match.group(1) ?? '')
      .replaceAll(_horizontalRulePattern, ' ')
      .replaceAll(_headingPattern, '')
      .replaceAll(_quotePattern, '')
      .replaceAll(_listBulletPattern, '')
      .replaceAll(_emphasisPattern, '')
      .replaceAll(_trailingSpacesPattern, '')
      .replaceAll(_repeatedSpacesPattern, ' ')
      .replaceAll(_blankLinesPattern, '\n')
      .trim();
}
