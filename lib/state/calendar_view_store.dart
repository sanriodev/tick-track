import 'package:ticktrack/enum/calendar_view_mode_enum.dart';
import 'package:hive/hive.dart';

class CalendarViewStore {
  static const String _boxName = 'settings';
  static const String _viewModeKey = 'calendarViewMode';

  CalendarViewMode read() {
    if (!Hive.isBoxOpen(_boxName)) return CalendarViewMode.month;
    return CalendarViewMode.fromJson(Hive.box(_boxName).get(_viewModeKey));
  }

  Future<void> save(CalendarViewMode mode) async {
    if (!Hive.isBoxOpen(_boxName)) return;
    await Hive.box(_boxName).put(_viewModeKey, mode.toJson());
  }
}
