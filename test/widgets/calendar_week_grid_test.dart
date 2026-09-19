import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/ui/theme.dart';
import 'package:ticktrack/widgets/calendar/calendar_week_grid.dart';

final DateTime monday = DateTime(2026, 9, 14);

CalendarOccurrence buildOccurrence({
  required int id,
  required String title,
  required DateTime startAt,
  required DateTime endAt,
  bool allDay = false,
}) {
  return CalendarOccurrence(
    event: CalendarEvent(
      id: id,
      title: title,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      recurrence: EventRecurrence.none,
      privacyMode: PrivacyMode.private,
      color: EventColor.blue,
    ),
    startAt: startAt,
    endAt: endAt,
    isRecurrence: false,
  );
}

Map<DateTime, List<CalendarOccurrence>> bucketOf(
  List<CalendarOccurrence> occurrences,
) {
  final map = <DateTime, List<CalendarOccurrence>>{};
  for (final occurrence in occurrences) {
    map.putIfAbsent(occurrence.day, () => []).add(occurrence);
  }
  return map;
}

Widget hostedIn(
  Map<DateTime, List<CalendarOccurrence>> occurrencesByDay,
  ThemeData theme,
  Locale locale, {
  void Function(CalendarOccurrence occurrence)? onOccurrenceTap,
}) {
  return MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: CalendarWeekGrid(
          weekStart: monday,
          selectedDay: monday,
          occurrencesByDay: occurrencesByDay,
          onDaySelected: (_) {},
          onOccurrenceTap: onOccurrenceTap ?? (_) {},
          onPreviousWeek: () {},
          onNextWeek: () {},
        ),
      ),
    ),
  );
}

void main() {
  final themes = {'hell': appThemeLight, 'dunkel': appThemeDark};
  const german = Locale('de');

  for (final theme in themes.entries) {
    testWidgets('Wochenansicht zeigt sieben Tage (${theme.key})',
        (WidgetTester tester) async {
      await tester.pumpWidget(hostedIn(const {}, theme.value, german));

      for (var dayOfWeek = 14; dayOfWeek <= 20; dayOfWeek++) {
        expect(find.text('$dayOfWeek'), findsOneWidget);
      }
    });

    testWidgets('Wochenansicht zeigt Termine und ganztägige Events '
        '(${theme.key})', (WidgetTester tester) async {
      final occurrences = bucketOf([
        buildOccurrence(
          id: 1,
          title: 'Putztag',
          startAt: DateTime(2026, 9, 14, 9),
          endAt: DateTime(2026, 9, 14, 10, 30),
        ),
        buildOccurrence(
          id: 2,
          title: 'Standup',
          startAt: DateTime(2026, 9, 14, 9, 30),
          endAt: DateTime(2026, 9, 14, 10),
        ),
        buildOccurrence(
          id: 3,
          title: 'Urlaub',
          startAt: DateTime(2026, 9, 16),
          endAt: DateTime(2026, 9, 16, 23, 59),
          allDay: true,
        ),
      ]);

      await tester.pumpWidget(hostedIn(occurrences, theme.value, german));

      expect(find.text('Putztag'), findsOneWidget);
      expect(find.text('Standup'), findsOneWidget);
      expect(find.text('Urlaub'), findsOneWidget);
    });
  }

  testWidgets('Überlappende Termine teilen sich die Tagesspalte',
      (WidgetTester tester) async {
    final occurrences = bucketOf([
      buildOccurrence(
        id: 1,
        title: 'Putztag',
        startAt: DateTime(2026, 9, 14, 9),
        endAt: DateTime(2026, 9, 14, 10, 30),
      ),
      buildOccurrence(
        id: 2,
        title: 'Standup',
        startAt: DateTime(2026, 9, 14, 9, 30),
        endAt: DateTime(2026, 9, 14, 10),
      ),
    ]);

    await tester.pumpWidget(
      hostedIn(occurrences, appThemeLight, const Locale('en')),
    );

    final firstBlock = tester.getRect(find.text('Putztag'));
    final secondBlock = tester.getRect(find.text('Standup'));
    expect(firstBlock.overlaps(secondBlock), isFalse);
    expect(secondBlock.left, greaterThan(firstBlock.left));
  });

  testWidgets('Tippen auf einen Termin meldet das Vorkommen',
      (WidgetTester tester) async {
    CalendarOccurrence? tapped;
    final occurrences = bucketOf([
      buildOccurrence(
        id: 1,
        title: 'Putztag',
        startAt: DateTime(2026, 9, 14, 9),
        endAt: DateTime(2026, 9, 14, 10, 30),
      ),
    ]);

    await tester.pumpWidget(
      hostedIn(
        occurrences,
        appThemeLight,
        const Locale('en'),
        onOccurrenceTap: (occurrence) => tapped = occurrence,
      ),
    );
    await tester.tap(find.text('Putztag'));

    expect(tapped?.event.id, 1);
  });
}
