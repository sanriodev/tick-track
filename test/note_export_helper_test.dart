import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/models/note/note_api_model.dart';
import 'package:ticktrack/util/export_helper.dart';
import 'package:ticktrack/util/note_export_helper.dart';

Note buildNote({String title = 'Einkauf', String? content}) {
  return Note(
    id: 7,
    title: title,
    content: content,
    privacyMode: PrivacyMode.private,
  );
}

void main() {
  group('buildNoteMarkdownExport', () {
    test('stellt den Titel als Überschrift voran', () {
      final markdown = buildNoteMarkdownExport(
        buildNote(content: '- [ ] Milch'),
        const {},
      );

      expect(markdown, '# Einkauf\n\n- [ ] Milch\n');
    });

    test('bleibt bei leerem Inhalt bei der Überschrift', () {
      expect(buildNoteMarkdownExport(buildNote(), const {}), '# Einkauf\n');
      expect(
        buildNoteMarkdownExport(buildNote(content: '   \n'), const {}),
        '# Einkauf\n',
      );
    });

    test('zeigt Anhänge auf die exportierten Dateien', () {
      final markdown = buildNoteMarkdownExport(
        buildNote(content: 'Vorher\n\n![](tt-attachment:4)\n\nNachher'),
        const {4: 'anhang-4.png'},
      );

      expect(markdown, '# Einkauf\n\nVorher\n\n![](anhang-4.png)\n\nNachher\n');
    });

    test('lässt nicht exportierte Anhänge unberührt', () {
      final markdown = buildNoteMarkdownExport(
        buildNote(content: '![](tt-attachment:4)'),
        const {},
      );

      expect(markdown, '# Einkauf\n\n![](tt-attachment:4)\n');
    });
  });

  group('safeFileName', () {
    test('behält lesbare Titel samt Umlauten', () {
      expect(safeFileName('Müllabfuhr Plan', fallback: 'notiz'),
          'Müllabfuhr Plan');
    });

    test('ersetzt Zeichen, die in Dateinamen stören', () {
      expect(safeFileName('Woche 1/2: Plan?', fallback: 'notiz'),
          'Woche 1 2 Plan');
    });

    test('nutzt den Ersatzwert für leere Titel', () {
      expect(safeFileName('   ', fallback: 'notiz-7'), 'notiz-7');
      expect(safeFileName('///', fallback: 'notiz-7'), 'notiz-7');
    });

    test('entfernt führende Punkte', () {
      expect(safeFileName('..versteckt', fallback: 'notiz'), 'versteckt');
    });

    test('kürzt sehr lange Titel', () {
      final name = safeFileName('a' * 200, fallback: 'notiz');

      expect(name.length, 60);
    });
  });
}
