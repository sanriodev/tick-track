// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/models/calendar/dto/create_calendar_event_dto.dart';
import 'package:ticktrack/models/calendar/dto/update_calendar_event_dto.dart';
import 'package:ticktrack/screens/calendar/calendar_screen.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Wide enough for the longest date label ("Endet am") so none of them wraps.
const double _labelWidth = 84;

/// Creates or edits an event.
///
/// Saving is explicit rather than autosaved like the note editor: dates and
/// repetition only make sense together, and writing half a changed series on
/// every keystroke would produce events nobody asked for.
class CalendarEventEditScreen extends StatefulWidget {
  const CalendarEventEditScreen({super.key});

  @override
  State<CalendarEventEditScreen> createState() =>
      _CalendarEventEditScreenState();
}

class _CalendarEventEditScreenState extends State<CalendarEventEditScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  CalendarEvent? _event;
  bool _initialized = false;
  bool _busy = false;

  late DateTime _startAt;
  late DateTime _endAt;
  bool _allDay = false;
  EventRecurrence _recurrence = EventRecurrence.none;
  DateTime? _recurrenceEndDate;
  PrivacyMode _privacyMode = PrivacyMode.private;

  /// Tells "never had an end date" from "the user just cleared it".
  bool _hadRecurrenceEnd = false;

  bool get _isNew => _event == null;

  bool get _isOwnEvent =>
      _event?.user?.username == AuthBackend().loggedInUser?.user?.username;

  /// Same rule the backend enforces: the owner always, group members only on
  /// public events.
  bool get _isEditable =>
      _isNew ||
      _isOwnEvent ||
      (_event!.groupId != null && _event!.privacyMode == PrivacyMode.public);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;

    final extra = GoRouterState.of(context).extra;
    if (extra is! CalendarEditorArgs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehlender Parameter für den Termin.')),
        );
        Navigator.of(context).pop();
      });
      // initialized for the frame before the pop lands
      _startAt = DateTime.now();
      _endAt = _startAt;
      return;
    }

    final event = extra.event;
    if (event == null) {
      _prefillNew(extra.day);
    } else {
      _prefillFrom(event);
    }
  }

  /// Next full hour, one hour long - two taps less in the common case.
  void _prefillNew(DateTime day) {
    final now = DateTime.now();
    final hour = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day
        ? now.hour + 1
        : 9;
    _startAt = DateTime(day.year, day.month, day.day, hour);
    _endAt = _startAt.add(const Duration(hours: 1));
    // in a group the point of an event is that the others see it
    _privacyMode = GroupContext().activeGroup != null
        ? PrivacyMode.protected
        : PrivacyMode.private;
  }

  void _prefillFrom(CalendarEvent event) {
    _event = event;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _locationController.text = event.location ?? '';
    _startAt = event.startAt;
    _endAt = event.endAt;
    _allDay = event.allDay;
    _recurrence = event.recurrence;
    _recurrenceEndDate = event.recurrenceEndDate;
    _hadRecurrenceEnd = event.recurrenceEndDate != null;
    _privacyMode = event.privacyMode;
  }

  // ------------------------------------------------------------------ pickers

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 10),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
      if (isStart) {
        // moving the start drags the end along, keeping the duration
        final duration = _endAt.difference(_startAt);
        _startAt = updated;
        _endAt = _startAt.add(duration);
      } else {
        _endAt = updated;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final updated = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        final duration = _endAt.difference(_startAt);
        _startAt = updated;
        _endAt = _startAt.add(duration);
      } else {
        _endAt = updated;
      }
    });
  }

  Future<void> _pickRecurrenceEnd() async {
    final initial = _recurrenceEndDate ?? _startAt.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_startAt) ? _startAt : initial,
      firstDate: _startAt,
      lastDate: DateTime(_startAt.year + 20),
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  // -------------------------------------------------------------------- save

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Titel eingeben.')),
      );
      return;
    }
    if (_endAt.isBefore(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Das Ende darf nicht vor dem Beginn liegen.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    // the backend rejects a series end without a repetition
    final seriesEnd = _recurrence.repeats ? _recurrenceEndDate : null;

    try {
      if (_isNew) {
        await Backend().createCalendarEvent(CreateCalendarEventDto(
          title: title,
          description: description,
          location: location,
          startAt: _startAt,
          endAt: _endAt,
          allDay: _allDay,
          recurrence: _recurrence,
          recurrenceEndDate: seriesEnd,
          privacyMode: _privacyMode,
          groupId: GroupContext().activeGroup?.id,
        ));
      } else {
        await Backend().updateCalendarEvent(UpdateCalendarEventDto(
          id: _event!.id,
          title: title,
          description: description,
          location: location,
          startAt: _startAt,
          endAt: _endAt,
          allDay: _allDay,
          recurrence: _recurrence,
          recurrenceEndDate: seriesEnd,
          clearRecurrenceEndDate: seriesEnd == null && _hadRecurrenceEnd,
          // only the owner may move the privacy mode
          privacyMode: _isOwnEvent ? _privacyMode : null,
        ));
      }
      Haptics.tap();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Haptics.warning();
      if (mounted) setState(() => _busy = false);
      await showBackendError(
        context,
        e,
        'Termin konnte nicht gespeichert werden',
      );
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readOnly = !_isEditable || _busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? 'Neuer Termin' : 'Termin bearbeiten',
          style: theme.primaryTextTheme.titleMedium,
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: theme.primaryIconTheme.color,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditable)
            TextButton(
              onPressed: _busy ? null : _save,
              child: Text(
                'Speichern',
                style: theme.primaryTextTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!_isEditable)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Diesen Termin hat ${_event?.user?.username ?? 'jemand anderes'} '
                  'erstellt, du kannst ihn nur ansehen.',
                  style: theme.primaryTextTheme.titleSmall,
                ),
              ),
            TextField(
              controller: _titleController,
              enabled: !readOnly,
              textCapitalization: TextCapitalization.sentences,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: 'Titel',
                labelStyle: theme.primaryTextTheme.bodySmall,
                hintText: 'z.B. Müll rausbringen',
                hintStyle: theme.primaryTextTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 20),
            _buildAllDaySwitch(theme, readOnly),
            _buildDateTimeRow(theme, readOnly, isStart: true),
            _buildDateTimeRow(theme, readOnly, isStart: false),
            const SizedBox(height: 8),
            _buildRecurrenceRow(theme, readOnly),
            if (_recurrence.repeats) _buildRecurrenceEndRow(theme, readOnly),
            if (GroupContext().activeGroup != null)
              _buildPrivacyRow(theme, readOnly),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              enabled: !readOnly,
              textCapitalization: TextCapitalization.sentences,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: 'Ort (optional)',
                labelStyle: theme.primaryTextTheme.bodySmall,
                prefixIcon: PhosphorIcon(
                  PhosphorIconsRegular.mapPin,
                  size: 18,
                  color: theme.primaryIconTheme.color,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              enabled: !readOnly,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: 'Notiz (optional)',
                labelStyle: theme.primaryTextTheme.bodySmall,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllDaySwitch(ThemeData theme, bool readOnly) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Ganztägig', style: theme.primaryTextTheme.titleSmall),
      value: _allDay,
      onChanged: readOnly
          ? null
          : (value) {
              Haptics.tick();
              setState(() {
                _allDay = value;
                if (value) {
                  // stretch over the whole day, so it still covers the day it
                  // was placed on once the time is hidden
                  _startAt =
                      DateTime(_startAt.year, _startAt.month, _startAt.day);
                  _endAt =
                      DateTime(_endAt.year, _endAt.month, _endAt.day, 23, 59);
                }
              });
            },
    );
  }

  Widget _buildDateTimeRow(
    ThemeData theme,
    bool readOnly, {
    required bool isStart,
  }) {
    final value = isStart ? _startAt : _endAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              isStart ? 'Beginn' : 'Ende',
              style: theme.primaryTextTheme.titleSmall,
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: readOnly ? null : () => _pickDate(isStart: isStart),
              child: Text(
                // numeric on purpose: "Fr., 31.07.2026" always fits next to
                // the time button, a spelled out month does not
                DateFormat('EE, dd.MM.y').format(value),
                style: theme.primaryTextTheme.titleSmall,
              ),
            ),
          ),
          if (!_allDay) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: OutlinedButton(
                onPressed: readOnly ? null : () => _pickTime(isStart: isStart),
                child: Text(
                  DateFormat('HH:mm').format(value),
                  style: theme.primaryTextTheme.titleSmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Label inside the field: "Wiederholung" does not fit the narrow label column
  /// the date rows use, and the text fields on this screen are labelled that way
  /// anyway.
  Widget _buildRecurrenceRow(ThemeData theme, bool readOnly) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<EventRecurrence>(
        initialValue: _recurrence,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: theme.primaryTextTheme.titleSmall,
        decoration: InputDecoration(
          labelText: 'Wiederholung',
          labelStyle: theme.primaryTextTheme.bodySmall,
        ),
        items: [
          for (final value in EventRecurrence.values)
            DropdownMenuItem(
              value: value,
              child:
                  Text(value.label, style: theme.primaryTextTheme.titleSmall),
            ),
        ],
        onChanged: readOnly
            ? null
            : (value) {
                if (value == null) return;
                Haptics.tick();
                setState(() {
                  _recurrence = value;
                  if (!value.repeats) {
                    _recurrenceEndDate = null;
                  }
                });
              },
      ),
    );
  }

  Widget _buildRecurrenceEndRow(ThemeData theme, bool readOnly) {
    final end = _recurrenceEndDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text('Endet am', style: theme.primaryTextTheme.titleSmall),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: readOnly ? null : _pickRecurrenceEnd,
              child: Text(
                end != null ? DateFormat('dd.MM.y').format(end) : 'Ohne Ende',
                style: theme.primaryTextTheme.titleSmall,
              ),
            ),
          ),
          if (end != null && !readOnly)
            IconButton(
              tooltip: 'Enddatum entfernen',
              icon: PhosphorIcon(
                PhosphorIconsRegular.x,
                size: 16,
                color: theme.primaryIconTheme.color,
              ),
              onPressed: () => setState(() => _recurrenceEndDate = null),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRow(ThemeData theme, bool readOnly) {
    // matching the backend: only the owner may change who sees an event
    final canChange = !readOnly && (_isNew || _isOwnEvent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<PrivacyMode>(
        initialValue: _privacyMode,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: theme.primaryTextTheme.titleSmall,
        decoration: InputDecoration(
          labelText: 'Sichtbarkeit',
          labelStyle: theme.primaryTextTheme.bodySmall,
          // "Geschützt" alone is open to interpretation
          helperText: _privacyMode.description,
          helperStyle: theme.primaryTextTheme.displayMedium,
          helperMaxLines: 2,
        ),
        items: [
          for (final value in PrivacyMode.values)
            DropdownMenuItem(
              value: value,
              child: Row(
                children: [
                  Icon(
                    privacyIconFor(value),
                    size: 16,
                    color: theme.primaryIconTheme.color,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.primaryTextTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: canChange
            ? (value) {
                if (value == null) return;
                Haptics.tick();
                setState(() => _privacyMode = value);
              }
            : null,
      ),
    );
  }
}
