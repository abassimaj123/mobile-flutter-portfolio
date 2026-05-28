import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

class TimeControlWidget extends StatelessWidget {
  final DateTime? selectedTime; // null = "Maintenant"
  final Function(DateTime?) onTimeChanged;

  const TimeControlWidget({
    super.key,
    required this.selectedTime,
    required this.onTimeChanged,
  });

  static const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  String _jourLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
    if (diff == 0) return '';
    if (diff == 1) return 'Demain ';
    return '${_jours[dt.weekday - 1]} ';
  }

  String get _label {
    if (selectedTime == null) return 'Maintenant ▼';
    return '${_jourLabel(selectedTime!)}${DateFormat('HH:mm').format(selectedTime!)} ▼';
  }

  bool get _isNow => selectedTime == null;

  void _showTimePicker(BuildContext context) {
    final now = DateTime.now();
    DateTime tempTime = selectedTime ?? now;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TimePickerSheet(
        initialTime: tempTime,
        isNow: _isNow,
        onReset: () {
          Navigator.pop(ctx);
          onTimeChanged(null);
        },
        onTimeSelected: (dt) {
          Navigator.pop(ctx);
          onTimeChanged(dt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTimePicker(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.smPlus),
        decoration: BoxDecoration(
          color: _isNow ? AppTheme.primary : AppTheme.accent,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: [
            BoxShadow(
              color:
                  (_isNow ? AppTheme.primary : AppTheme.accent).withAlpha(89),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isNow ? Icons.access_time : Icons.schedule,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: AppTextSize.body,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  final DateTime initialTime;
  final bool isNow;
  final VoidCallback onReset;
  final Function(DateTime) onTimeSelected;

  const _TimePickerSheet({
    required this.initialTime,
    required this.isNow,
    required this.onReset,
    required this.onTimeSelected,
  });

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late DateTime _selectedTime;

  @override
  void initState() {
    super.initState();
    // CupertinoDatePicker requires initialDateTime.minute % minuteInterval == 0.
    // minuteInterval: 5 → snap to nearest 5-min mark to avoid failed assertion.
    final t = widget.initialTime;
    final rawMinute = (t.minute / 5).round() * 5;
    final extraHour = rawMinute ~/ 60;
    _selectedTime = DateTime(
      t.year,
      t.month,
      t.day,
      t.hour + extraHour,
      rawMinute % 60,
    );
  }

  void _addDuration(Duration d) {
    setState(() => _selectedTime = _selectedTime.add(d));
  }

  static const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  /// Formate l'heure avec le nom du jour si différent d'aujourd'hui.
  /// Exemples : "14:30"  /  "Demain 02:00"  /  "Lun 03:15"
  String _formatWithDay(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(dt.year, dt.month, dt.day).difference(today).inDays;
    final hhmm = DateFormat('HH:mm').format(dt);
    if (diff == 0) return hhmm;
    if (diff == 1) return 'Demain $hhmm';
    return '${_jours[dt.weekday - 1]} $hhmm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  'Choisir un horaire',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onReset,
                  icon: const Icon(Icons.gps_fixed, size: 16),
                  label: const Text('Maintenant'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          // Quick offset buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                _QuickButton(
                  label: '+30 min',
                  onTap: () => _addDuration(const Duration(minutes: 30)),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickButton(
                  label: '+1h',
                  onTap: () => _addDuration(const Duration(hours: 1)),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickButton(
                  label: '+2h',
                  onTap: () => _addDuration(const Duration(hours: 2)),
                ),
                const SizedBox(width: AppSpacing.sm),
                _QuickButton(
                  label: '+3h',
                  onTap: () => _addDuration(const Duration(hours: 3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Time picker
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: _selectedTime,
              use24hFormat: true,
              minuteInterval: 5,
              onDateTimeChanged: (dt) {
                setState(() {
                  // CupertinoDatePickerMode.time retourne TOUJOURS la date du jour.
                  // Si l'utilisateur a avancé avec +1h/+2h/+3h au-delà de minuit
                  // (ex: dimanche 23h → lundi 01h), le wheel remettrait dimanche.
                  // On préserve la date accumulée par _addDuration() :
                  // on prend seulement l'heure et la minute du picker.
                  _selectedTime = DateTime(
                    _selectedTime.year,
                    _selectedTime.month,
                    _selectedTime.day,
                    dt.hour,
                    dt.minute,
                  );
                });
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onTimeSelected(_selectedTime),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
                ),
                child: Text(
                  'Voir à ${_formatWithDay(_selectedTime)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: AppTextSize.bodyLg,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + AppSpacing.md),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.mdPlus),
            border: Border.all(
              color: AppTheme.primary.withAlpha(38),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppTextSize.sm,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
