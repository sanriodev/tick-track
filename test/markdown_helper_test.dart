import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/util/markdown_helper.dart';

void main() {
  group('attachmentIdFromUri', () {
    test('erkennt eine Anhang-Referenz', () {
      expect(attachmentIdFromUri('tt-attachment:12'), 12);
    });

    test('toleriert umgebende Leerzeichen', () {
      expect(attachmentIdFromUri('  tt-attachment:7 '), 7);
    });

    test('ignoriert fremde Schemata', () {
      expect(attachmentIdFromUri('https://example.com/bild.png'), isNull);
      expect(attachmentIdFromUri('attachment:12'), isNull);
    });

    test('ignoriert nicht numerische Ids', () {
      expect(attachmentIdFromUri('tt-attachment:abc'), isNull);
      expect(attachmentIdFromUri('tt-attachment:'), isNull);
    });
  });

  group('referencedAttachmentIds', () {
    test('sammelt alle eingebetteten Anhänge', () {
      const markdown = 'Text\n\n'
          '![](tt-attachment:1)\n'
          'mehr Text\n'
          '![Alt](tt-attachment:42)\n';

      expect(referencedAttachmentIds(markdown), {1, 42});
    });

    test('ignoriert externe Bilder', () {
      const markdown = '![](https://example.com/a.png)\n![](tt-attachment:5)';

      expect(referencedAttachmentIds(markdown), {5});
    });

    test('ist leer ohne Bilder', () {
      expect(referencedAttachmentIds('nur Text'), isEmpty);
    });
  });

  group('removeAttachmentReference', () {
    test('entfernt genau die eine Referenz', () {
      const markdown = 'oben\n![](tt-attachment:1)\n![](tt-attachment:2)\nunten';

      final result = removeAttachmentReference(markdown, 1);

      expect(result, 'oben\n![](tt-attachment:2)\nunten');
    });

    test('lässt andere Ids unberührt', () {
      const markdown = '![](tt-attachment:10)';

      expect(removeAttachmentReference(markdown, 1), markdown);
    });
  });

  group('markdownToPlainText', () {
    test('entfernt Überschriften-Markierungen', () {
      expect(markdownToPlainText('## Einkauf'), 'Einkauf');
    });

    test('entfernt Auszeichnungen', () {
      expect(markdownToPlainText('**fett** und _kursiv_'), 'fett und kursiv');
      expect(markdownToPlainText('~~weg~~'), 'weg');
    });

    test('behält den Linktext', () {
      expect(
        markdownToPlainText('siehe [Doku](https://example.com)'),
        'siehe Doku',
      );
    });

    test('entfernt Bilder komplett', () {
      expect(
        markdownToPlainText('Vorher ![Alt](tt-attachment:1) nachher').trim(),
        contains('Vorher'),
      );
      expect(markdownToPlainText('![Alt](tt-attachment:1)'), isEmpty);
    });

    test('entfernt Codeblöcke', () {
      const markdown = 'davor\n```\nvar x = 1;\n```\ndanach';

      final result = markdownToPlainText(markdown);

      expect(result, contains('davor'));
      expect(result, contains('danach'));
      expect(result, isNot(contains('var x')));
    });

    test('behält Inline-Code ohne Backticks', () {
      expect(markdownToPlainText('nutze `flutter test`'), 'nutze flutter test');
    });

    test('entfernt Zitat- und Listenzeichen', () {
      expect(markdownToPlainText('> zitiert'), 'zitiert');
      expect(markdownToPlainText('- eins\n- zwei'), 'eins\nzwei');
      expect(markdownToPlainText('1. eins'), 'eins');
    });

    test('entfernt horizontale Linien', () {
      expect(markdownToPlainText('oben\n\n---\n\nunten'), 'oben\nunten');
    });

    test('bleibt bei leerem Inhalt leer', () {
      expect(markdownToPlainText(''), isEmpty);
    });
  });
}
