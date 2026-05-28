import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/parking_rule.dart';
import '../core/models/user_contribution.dart';
import '../core/services/contribution_service.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

// TODO: Add image_picker dependency to pubspec.yaml when ready for photo capture.
//   image_picker: ^1.1.2
// Then replace the placeholder below with:
//   import 'package:image_picker/image_picker.dart';

/// Bottom sheet that lets the user report or correct a parking rule
/// for a given street segment.
///
/// Contributions are stored locally (Layer 3 — unverified).
class ContributionSheet extends StatefulWidget {
  final int osmWayId;
  final String streetName;
  final String cityId;
  final double lat;
  final double lon;

  const ContributionSheet({
    super.key,
    required this.osmWayId,
    required this.streetName,
    required this.cityId,
    required this.lat,
    required this.lon,
  });

  @override
  State<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<ContributionSheet> {
  // ── Form state ─────────────────────────────────────────────────────────────
  RuleType? _selectedRuleType;
  bool _showDetails = false;
  bool _showFreeText = false;

  // Days: 1=Mon … 7=Sun, all pre-selected
  final List<bool> _daySelected = List.filled(7, true);
  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _noteController = TextEditingController();
  String? _photoPath; // TODO: populate from image_picker when available
  bool _submitting = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Quick rule options ─────────────────────────────────────────────────────

  static const _quickRules = [
    _QuickRule(
      label: 'Stationnement interdit',
      type: RuleType.noParking,
      icon: Icons.block,
      color: AppTheme.restricted,
    ),
    _QuickRule(
      label: 'Parcomètre',
      type: RuleType.meter,
      icon: Icons.payment,
      color: AppTheme.meter,
    ),
    _QuickRule(
      label: 'Limité 2h',
      type: RuleType.free,
      icon: Icons.hourglass_bottom_rounded,
      color: AppTheme.free,
      maxMinutes: 120,
    ),
    _QuickRule(
      label: 'Libre',
      type: RuleType.free,
      icon: Icons.check_circle_outline,
      color: AppTheme.free,
    ),
  ];

  void _selectQuickRule(_QuickRule q) {
    setState(() {
      _selectedRuleType = q.type;
      _showDetails = true;
      _showFreeText = false;
    });
  }

  void _selectFreeText() {
    setState(() {
      _selectedRuleType = null;
      _showDetails = false;
      _showFreeText = true;
    });
  }

  // ── Time picker ────────────────────────────────────────────────────────────

  Future<void> _pickTime(TextEditingController ctrl) async {
    final tod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (tod != null) {
      ctrl.text =
          '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
    }
  }

  // ── Photo picker stub ──────────────────────────────────────────────────────

  void _pickPhoto() {
    // TODO: implement with image_picker once dependency is added.
    // Example:
    //   final picker = ImagePicker();
    //   final XFile? img = await picker.pickImage(source: ImageSource.camera);
    //   if (img != null) setState(() => _photoPath = img.path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo: fonctionnalité bientôt disponible'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedRuleType == null && !_showFreeText) return;
    if (_showFreeText && _noteController.text.trim().isEmpty) return;

    setState(() => _submitting = true);

    final selectedDays = <int>[];
    for (var i = 0; i < 7; i++) {
      if (_daySelected[i]) selectedDays.add(i + 1);
    }

    final maxMins = _selectedRuleType == RuleType.free &&
            _quickRules
                .any((q) => q.type == _selectedRuleType && q.maxMinutes != null)
        ? 120
        : null;

    final contribution = UserContribution(
      id: '${DateTime.now().microsecondsSinceEpoch}_${widget.osmWayId}',
      osmWayId: widget.osmWayId,
      streetName: widget.streetName,
      cityId: widget.cityId,
      lat: widget.lat,
      lon: widget.lon,
      type: ContributionType.newRule,
      submittedAt: DateTime.now(),
      ruleType: _selectedRuleType,
      days: _showDetails && selectedDays.isNotEmpty ? selectedDays : null,
      fromTime: _showDetails && _fromController.text.isNotEmpty
          ? _fromController.text
          : null,
      toTime: _showDetails && _toController.text.isNotEmpty
          ? _toController.text
          : null,
      maxMinutes: maxMins,
      ruleDescription: _showFreeText ? _noteController.text.trim() : null,
      note: !_showFreeText && _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      photoPath: _photoPath,
    );

    await ContributionService().submit(contribution);
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Merci ! Votre contribution sera vérifiée.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.mdPlus, AppSpacing.xl, AppSpacing.xxl),
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Signaler une règle',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              widget.streetName,
                              style: TextStyle(
                                fontSize: AppTextSize.sm,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Type de règle',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // ── Quick rule selector ──────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._quickRules.map(
                        (q) => _QuickRuleChip(
                          rule: q,
                          selected:
                              _selectedRuleType == q.type && !_showFreeText,
                          onTap: () => _selectQuickRule(q),
                        ),
                      ),
                      _QuickRuleChip(
                        rule: const _QuickRule(
                          label: 'Autre…',
                          type: null,
                          icon: Icons.edit_rounded,
                          color: AppTheme.primary,
                        ),
                        selected: _showFreeText,
                        onTap: _selectFreeText,
                      ),
                    ],
                  ),

                  // ── Time + day details ───────────────────────────────────
                  if (_showDetails) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Jours concernés',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(7, (i) {
                        final selected = _daySelected[i];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _daySelected[i] = !selected),
                            child: AnimatedContainer(
                              duration: AppDuration.fast,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Text(
                                _dayLabels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppTextSize.xs,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Heures (optionnel)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            controller: _fromController,
                            label: 'De',
                            onTap: () => _pickTime(_fromController),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeField(
                            controller: _toController,
                            label: 'À',
                            onTap: () => _pickTime(_toController),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note (optionnel)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    _NoteField(controller: _noteController),
                  ],

                  // ── Free text mode ───────────────────────────────────────
                  if (_showFreeText) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Décrivez la règle',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    _NoteField(
                      controller: _noteController,
                      hint: 'Ex. Interdit le mardi de 8h à 11h pour nettoyage',
                    ),
                  ],

                  // ── Photo button ─────────────────────────────────────────
                  if (_showDetails || _showFreeText) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(
                        _photoPath != null
                            ? 'Photo ajoutée ✓'
                            : 'Ajouter une photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(
                          color: AppTheme.primary.withAlpha(102),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                    ),
                  ],

                  // ── Submit button ────────────────────────────────────────
                  if (_showDetails || _showFreeText) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Envoyer ma contribution',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppTextSize.bodyMd,
                                ),
                              ),
                      ),
                    ),
                  ],

                  // ── Trust layer indicator ────────────────────────────────
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Les contributions non vérifiées apparaissent en gris sur la carte',
                          style: TextStyle(
                            fontSize: AppTextSize.xs,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────────

class _QuickRule {
  final String label;
  final RuleType? type; // null = free-text option
  final IconData icon;
  final Color color;
  final int? maxMinutes;

  const _QuickRule({
    required this.label,
    required this.type,
    required this.icon,
    required this.color,
    this.maxMinutes,
  });
}

class _QuickRuleChip extends StatelessWidget {
  final _QuickRule rule;
  final bool selected;
  final VoidCallback onTap;

  const _QuickRuleChip({
    required this.rule,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = rule.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withAlpha(30)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color:
                selected ? color : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rule.icon,
                size: 16,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              rule.label,
              style: TextStyle(
                fontSize: AppTextSize.md,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? color : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onTap;

  const _TimeField({
    required this.controller,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(fontSize: AppTextSize.body),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'HH:MM',
        suffixIcon: const Icon(Icons.access_time, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.mdPlus),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;

  const _NoteField({
    required this.controller,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      maxLength: 200,
      style: const TextStyle(fontSize: AppTextSize.md),
      decoration: InputDecoration(
        hintText: hint ?? 'Remarque optionnelle…',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.mdPlus),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }
}
