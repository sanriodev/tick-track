// ignore_for_file: use_build_context_synchronously

import 'package:ticktrack/enum/event_color_enum.dart';
import 'package:ticktrack/l10n/l10n.dart';
import 'package:ticktrack/enum/event_recurrence_enum.dart';
import 'package:ticktrack/enum/privacy_mode_enum.dart';
import 'package:ticktrack/backend/service/backend_service.dart';
import 'package:ticktrack/models/calendar/calendar_event_model.dart';
import 'package:ticktrack/models/calendar/dto/create_calendar_event_dto.dart';
import 'package:ticktrack/models/calendar/dto/update_calendar_event_dto.dart';
import 'package:ticktrack/screens/calendar/calendar_screen.dart';
import 'package:ticktrack/state/group_context.dart';
import 'package:ticktrack/state/reminder_scheduler.dart';
import 'package:ticktrack/util/haptics.dart';
import 'package:ticktrack/util/helpers.dart';
import 'package:blvckleg_dart_core/service/auth_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const double _labelWidth = 84;

const List<int?> _reminderOffsets = [null, 0, 5, 15, 30, 60, 120, 1440, 2880];

String _reminderLabel(AppLocalizations l10n, int? minutes) {
  return switch (minutes) {
    null => l10n.reminderNone,
    0 => l10n.reminderAtStart,
    60 => l10n.reminderOneHour,
    120 => l10n.reminderTwoHours,
    1440 => l10n.reminderOneDay,
    2880 => l10n.reminderTwoDays,
    _ => l10n.reminderMinutes(minutes),
  };
}

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
  EventColor? _color;
  int? _remindMinutesBefore;
  PrivacyMode _privacyMode = PrivacyMode.private;

  bool _hadColor = false;

  bool _hadReminder = false;

  bool _hadRecurrenceEnd = false;

  bool get _isNew => _event == null;

  bool get _isOwnEvent =>
      _event?.user?.username == AuthBackend().loggedInUser?.user?.username;

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
          SnackBar(content: Text(context.l10n.eventMissingParameter)),
        );
        Navigator.of(context).pop();
      });
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

  void _prefillNew(DateTime day) {
    final now = DateTime.now();
    final hour =
        day.year == now.year && day.month == now.month && day.day == now.day
            ? now.hour + 1
            : 9;
    _startAt = DateTime(day.year, day.month, day.day, hour);
    _endAt = _startAt.add(const Duration(hours: 1));
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
    _color = event.color;
    _hadColor = event.color != null;
    _remindMinutesBefore = event.remindMinutesBefore;
    _hadReminder = event.remindMinutesBefore != null;
    _privacyMode = event.privacyMode;
  }

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
    final initial =
        _recurrenceEndDate ?? _startAt.add(const Duration(days: 30));
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.eventTitleRequired)),
      );
      return;
    }
    if (_endAt.isBefore(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.eventEndBeforeStart)),
      );
      return;
    }

    setState(() => _busy = true);
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
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
          color: _color,
          remindMinutesBefore: _remindMinutesBefore,
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
          color: _color,
          clearColor: _color == null && _hadColor,
          remindMinutesBefore: _remindMinutesBefore,
          clearReminder: _remindMinutesBefore == null && _hadReminder,
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
        context.l10n.eventSaveFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final readOnly = !_isEditable || _busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? l10n.eventNew : l10n.eventEdit,
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
                l10n.save,
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
                  l10n.eventReadOnlyHint(
                    _event?.user?.username ?? l10n.someoneElse,
                  ),
                  style: theme.primaryTextTheme.titleSmall,
                ),
              ),
            TextField(
              controller: _titleController,
              enabled: !readOnly,
              textCapitalization: TextCapitalization.sentences,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: l10n.title,
                labelStyle: theme.primaryTextTheme.bodySmall,
                hintText: l10n.eventTitleHint,
                hintStyle: theme.primaryTextTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 20),
            _buildAllDaySwitch(theme, l10n, readOnly),
            _buildDateTimeRow(theme, l10n, readOnly, isStart: true),
            _buildDateTimeRow(theme, l10n, readOnly, isStart: false),
            const SizedBox(height: 8),
            _buildRecurrenceRow(theme, l10n, readOnly),
            if (_recurrence.repeats)
              _buildRecurrenceEndRow(theme, l10n, readOnly),
            _buildReminderRow(theme, l10n, readOnly),
            _buildColorRow(theme, l10n, readOnly),
            if (GroupContext().activeGroup != null)
              _buildPrivacyRow(theme, l10n, readOnly),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              enabled: !readOnly,
              textCapitalization: TextCapitalization.sentences,
              style: theme.primaryTextTheme.bodySmall,
              decoration: InputDecoration(
                labelText: l10n.eventLocation,
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
                labelText: l10n.eventNote,
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

  Widget _buildAllDaySwitch(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.eventAllDay, style: theme.primaryTextTheme.titleSmall),
      value: _allDay,
      onChanged: readOnly
          ? null
          : (value) {
              Haptics.tick();
              setState(() {
                _allDay = value;
                if (value) {
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
    AppLocalizations l10n,
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
              isStart ? l10n.eventStart : l10n.eventEnd,
              style: theme.primaryTextTheme.titleSmall,
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: readOnly ? null : () => _pickDate(isStart: isStart),
              child: Text(
                DateFormat.yMEd().format(value),
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
                  DateFormat.jm().format(value),
                  style: theme.primaryTextTheme.titleSmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurrenceRow(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<EventRecurrence>(
        initialValue: _recurrence,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: theme.primaryTextTheme.titleSmall,
        decoration: InputDecoration(
          labelText: l10n.eventRecurrence,
          labelStyle: theme.primaryTextTheme.bodySmall,
        ),
        items: [
          for (final value in EventRecurrence.values)
            DropdownMenuItem(
              value: value,
              child:
                  Text(value.label(l10n),
                      style: theme.primaryTextTheme.titleSmall),
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

  Widget _buildRecurrenceEndRow(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    final end = _recurrenceEndDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(l10n.eventRecurrenceEnd,
                style: theme.primaryTextTheme.titleSmall),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: readOnly ? null : _pickRecurrenceEnd,
              child: Text(
                end != null ? DateFormat.yMd().format(end) : l10n.eventNoEnd,
                style: theme.primaryTextTheme.titleSmall,
              ),
            ),
          ),
          if (end != null && !readOnly)
            IconButton(
              tooltip: l10n.eventRemoveEndDate,
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

  Widget _buildColorRow(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.eventColor, style: theme.primaryTextTheme.titleSmall),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const swatches = <EventColor?>[null, ...EventColor.values];
              final diameter = _swatchDiameter(
                constraints.maxWidth,
                swatches.length,
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final value in swatches)
                    _buildSwatch(theme, l10n, readOnly, value, diameter),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _swatchDiameter(double availableWidth, int swatchCount) {
    const maxDiameter = 34.0;
    const minDiameter = 22.0;
    const minSpacing = 6.0;

    final fittingDiameter =
        (availableWidth - minSpacing * (swatchCount - 1)) / swatchCount;
    return fittingDiameter.clamp(minDiameter, maxDiameter);
  }

  Widget _buildSwatch(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
    EventColor? value,
    double diameter,
  ) {
    final isSelected = _color == value;
    final swatchColor = value?.resolve(theme.brightness);

    return Semantics(
      button: true,
      selected: isSelected,
      label: value?.label(l10n) ?? l10n.eventNoColor,
      excludeSemantics: true,
      child: Tooltip(
        message: value?.label(l10n) ?? l10n.eventNoColor,
        child: InkWell(
          onTap: readOnly
              ? null
              : () {
                  Haptics.tick();
                  setState(() => _color = value);
                },
          customBorder: const CircleBorder(),
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: swatchColor ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (theme.primaryTextTheme.bodySmall?.color ??
                        theme.primaryColor)
                    : theme.dividerColor,
                width: isSelected ? 2.5 : 1.5,
              ),
            ),
            child: value == null
                ? Icon(
                    Icons.block,
                    size: diameter * 0.47,
                    color: theme.primaryTextTheme.displayMedium?.color
                        ?.withValues(alpha: 0.6),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderRow(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<int?>(
        initialValue: _remindMinutesBefore,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: theme.primaryTextTheme.titleSmall,
        decoration: InputDecoration(
          labelText: l10n.eventReminder,
          labelStyle: theme.primaryTextTheme.bodySmall,
          helperText: l10n.eventReminderDeviceOnly,
          helperStyle: theme.primaryTextTheme.displayMedium,
        ),
        items: [
          for (final value in _reminderOffsets)
            DropdownMenuItem(
              value: value,
              child: Text(
                _reminderLabel(l10n, value),
                style: theme.primaryTextTheme.titleSmall,
              ),
            ),
        ],
        onChanged: readOnly ? null : _onReminderChanged,
      ),
    );
  }

  Future<void> _onReminderChanged(int? value) async {
    Haptics.tick();
    setState(() => _remindMinutesBefore = value);
    if (value == null) {
      return;
    }

    final allowed = await ReminderScheduler().requestPermission();
    if (allowed || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.eventNotificationsBlocked)),
    );
  }

  Widget _buildPrivacyRow(
    ThemeData theme,
    AppLocalizations l10n,
    bool readOnly,
  ) {
    final canChange = !readOnly && (_isNew || _isOwnEvent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<PrivacyMode>(
        initialValue: _privacyMode,
        isExpanded: true,
        dropdownColor: theme.cardColor,
        style: theme.primaryTextTheme.titleSmall,
        decoration: InputDecoration(
          labelText: l10n.eventVisibility,
          labelStyle: theme.primaryTextTheme.bodySmall,
          helperText: _privacyMode.description(l10n),
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
                      value.label(l10n),
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
