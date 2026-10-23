import 'dart:async';
import 'package:flutter/material.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Rebuild the existing Material date dialog only when Baghdad's date changes.
/// Its bounds never keep yesterday selectable after midnight or an app resume.
Future<DateTime?> showAdDatePicker(
        {required BuildContext context,
        required DateTime Function() now,
        DateTime? initialDate}) =>
    showDialog<DateTime>(
        context: context,
        builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: _AdDateDialog(now: now, initialDate: initialDate)));

class _AdDateDialog extends StatefulWidget {
  const _AdDateDialog({required this.now, this.initialDate});
  final DateTime Function() now;
  final DateTime? initialDate;
  @override
  State<_AdDateDialog> createState() => _AdDateDialogState();
}

class _AdDateDialogState extends State<_AdDateDialog>
    with WidgetsBindingObserver {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTick();
  }

  void _scheduleTick() {
    _tick?.cancel();
    final now = widget.now();
    _tick = Timer(
        Duration(milliseconds: 60000 - now.second * 1000 - now.millisecond),
        () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.now());
    final last = today.add(const Duration(days: 90));
    var initial = widget.initialDate == null
        ? today
        : DateUtils.dateOnly(widget.initialDate!);
    if (initial.isBefore(today) || initial.isAfter(last)) initial = today;
    return DatePickerDialog(
        key: ValueKey(today),
        initialDate: initial,
        currentDate: today,
        firstDate: today,
        lastDate: last);
  }
}

/// Both ad modes use the same date control and this bounded Material time
/// control. Material's clock picker has no predicate for disabling elapsed
/// minutes, so the hour/minute menus expose those options as disabled rows.
Future<TimeOfDay?> showAdTimePicker({
  required BuildContext context,
  required DateTime date,
  required DateTime Function() now,
  TimeOfDay? initialTime,
}) =>
    showDialog<TimeOfDay>(
      context: context,
      builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: _AdTimeDialog(date: date, now: now, initialTime: initialTime)),
    );

bool adTimeAvailable(DateTime date, int hour, int minute, DateTime now) =>
    DateTime.utc(date.year, date.month, date.day, hour, minute).isAfter(now);

class _AdTimeDialog extends StatefulWidget {
  const _AdTimeDialog(
      {required this.date, required this.now, this.initialTime});
  final DateTime date;
  final DateTime Function() now;
  final TimeOfDay? initialTime;
  @override
  State<_AdTimeDialog> createState() => _AdTimeDialogState();
}

class _AdTimeDialogState extends State<_AdTimeDialog>
    with WidgetsBindingObserver {
  late int _hour, _minute;
  Timer? _tick;
  bool _available(int hour, int minute) =>
      adTimeAvailable(widget.date, hour, minute, widget.now());
  bool _hourAvailable(int hour) => _available(hour, 59);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = widget.now();
    final suggested = now.add(const Duration(minutes: 1));
    _hour = widget.initialTime?.hour ?? suggested.hour;
    _minute = widget.initialTime?.minute ?? suggested.minute;
    _scheduleTick();
  }

  void _scheduleTick() {
    _tick?.cancel();
    final now = widget.now();
    _tick = Timer(
        Duration(milliseconds: 60000 - now.second * 1000 - now.millisecond),
        () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _scheduleTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _number(int value) => value.toString().padLeft(2, '0');
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const ProxoText('کات هەڵبژێرە'),
        content: SizedBox(
            width: 280,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(children: [
                        Expanded(
                            child: DropdownButtonFormField<int>(
                          key: ValueKey('schedule-hour-$_hour'),
                          initialValue: _hour,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'کاتژمێر'),
                          style: AdUi.text(context),
                          items: [
                            for (var hour = 0; hour < 24; hour++)
                              DropdownMenuItem(
                                  value: hour,
                                  enabled: _hourAvailable(hour),
                                  child: Text(_number(hour),
                                      style: AdUi.text(context,
                                          color: _hourAvailable(hour)
                                              ? AdUi.ink
                                              : Theme.of(context)
                                                  .disabledColor)))
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _hour = value);
                          },
                        )),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(':')),
                        Expanded(
                            child: DropdownButtonFormField<int>(
                          key: ValueKey('schedule-minute-$_hour-$_minute'),
                          initialValue: _minute,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'خولەک'),
                          style: AdUi.text(context),
                          items: [
                            for (var minute = 0; minute < 60; minute++)
                              DropdownMenuItem(
                                  value: minute,
                                  enabled: _available(_hour, minute),
                                  child: Text(_number(minute),
                                      style: AdUi.text(context,
                                          color: _available(_hour, minute)
                                              ? AdUi.ink
                                              : Theme.of(context)
                                                  .disabledColor)))
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _minute = value);
                          },
                        )),
                      ])),
                  if (!_available(_hour, _minute)) ...[
                    const SizedBox(height: 12),
                    ProxoText('کاتی دەستپێک دەبێت لە داهاتوودا بێت',
                        style: AdUi.text(context,
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const ProxoText('پاشگەزبوونەوە')),
          TextButton(
              key: const ValueKey('confirm-ad-time'),
              onPressed: !_available(_hour, _minute)
                  ? null
                  : () => Navigator.pop(
                      context, TimeOfDay(hour: _hour, minute: _minute)),
              child: const ProxoText('دڵنیاکردنەوە')),
        ],
      );
}
