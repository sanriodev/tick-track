import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int _maxFileNameLength = 60;

final RegExp _unsafeFileNameCharacters = RegExp(r'[\\/:*?"<>|\x00-\x1f]');
final RegExp _repeatedWhitespace = RegExp(r'\s+');
final RegExp _leadingDots = RegExp(r'^\.+');

Future<Directory> prepareExportDirectory(String name) async {
  final temporaryDirectory = await getTemporaryDirectory();
  final exportDirectory = Directory('${temporaryDirectory.path}/$name');

  if (exportDirectory.existsSync()) {
    await exportDirectory.delete(recursive: true);
  }
  return exportDirectory.create(recursive: true);
}

String safeFileName(String label, {required String fallback}) {
  final cleaned = label
      .replaceAll(_unsafeFileNameCharacters, ' ')
      .replaceAll(_repeatedWhitespace, ' ')
      .trim()
      .replaceAll(_leadingDots, '')
      .trim();

  if (cleaned.isEmpty) {
    return fallback;
  }
  if (cleaned.length <= _maxFileNameLength) {
    return cleaned;
  }
  return cleaned.substring(0, _maxFileNameLength).trim();
}
