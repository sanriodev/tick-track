import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/ui/theme.dart';
import 'package:ticktrack/widgets/group/groups_preview_widget.dart';
import 'package:ticktrack/widgets/profile_preview_widget.dart';

Widget _hostedIn(Widget child, ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    ),
  );
}

void main() {
  final themes = {'hell': appThemeLight, 'dunkel': appThemeDark};

  for (final theme in themes.entries) {
    testWidgets('Profilvorschau zeigt Ladezustand (${theme.key})',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _hostedIn(
          ProfilePreviewWidget(
            user: null,
            isLoading: true,
            onPressed: () {},
          ),
          theme.value,
        ),
      );

      expect(find.text('Willkommen zurück,'), findsOneWidget);
      expect(find.text('Profil wird geladen …'), findsOneWidget);
    });

    testWidgets('Profilvorschau öffnet das Profil (${theme.key})',
        (WidgetTester tester) async {
      var opened = false;
      await tester.pumpWidget(
        _hostedIn(
          ProfilePreviewWidget(
            user: null,
            isLoading: false,
            onPressed: () => opened = true,
          ),
          theme.value,
        ),
      );

      await tester.tap(find.byType(ProfilePreviewWidget));

      expect(opened, isTrue);
    });

    testWidgets('Gruppenvorschau zeigt Platzhalter ohne Gruppen (${theme.key})',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _hostedIn(GroupsPreviewWidget(onPressed: () {}), theme.value),
      );

      expect(find.text('Gruppen'), findsOneWidget);
      expect(find.text('Du bist noch in keiner Gruppe.'), findsOneWidget);
      expect(find.text('Neue Gruppe hinzufügen'), findsOneWidget);
    });
  }
}
