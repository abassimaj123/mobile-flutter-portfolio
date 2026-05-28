import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/models/street_segment.dart';
import '../core/models/parking_rule.dart';
import '../core/services/freemium_service.dart';
import '../core/services/iap_service.dart';
import '../core/services/rule_engine.dart';
import '../core/services/session_service.dart';
import '../core/theme/app_theme.dart';
import 'contribution_sheet.dart';

class SegmentBottomSheet extends StatelessWidget {
  final StreetSegment segment;
  final DateTime viewTime;
  final VoidCallback onClose;

  const SegmentBottomSheet({
    super.key,
    required this.segment,
    required this.viewTime,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final result = RuleEngine.evaluate(segment, viewTime);
    final zoneColor = AppTheme.colorForHex(result.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          // Colored accent bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [zoneColor, zoneColor.withAlpha(77)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              segment.streetName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppTheme.primary,
                                    fontSize: AppTextSize.title,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _SideBadge(side: segment.side),
                                const SizedBox(width: 6),
                                Text(
                                  segment.city,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: AppTextSize.md,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClose,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status badge
                  _StatusBadge(result: result, zoneColor: zoneColor),
                  const SizedBox(height: 12),

                  // Next change time
                  if (result.nextChangeTime != null)
                    _NextChangeBanner(
                      nextChange: result.nextChangeTime!,
                      viewTime: viewTime,
                      color: zoneColor,
                    ),

                  // Meter info
                  if (result.activeRule?.type == RuleType.meter &&
                      result.activeRule != null)
                    _MeterInfo(rule: result.activeRule!),

                  // Permit info
                  if (result.activeRule?.type == RuleType.permitOnly &&
                      result.activeRule?.permitZone != null)
                    _PermitInfo(zone: result.activeRule!.permitZone!),

                  // Pair/impair info
                  if (result.activeRule?.isAlternating == true)
                    _AlternatingInfo(
                      rule: result.activeRule!,
                      viewTime: viewTime,
                      allRules: segment.rules,
                    ),

                  if (segment.rules.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Règles de stationnement',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...segment.rules.map(
                        (rule) => _RuleRow(rule: rule, viewTime: viewTime)),
                  ],

                  const SizedBox(height: 16),

                  // Confidence bar
                  _ConfidenceBar(confidence: segment.confidence),
                  const SizedBox(height: 12),

                  // Sources
                  _SourcesRow(sources: segment.sources),
                  const SizedBox(height: 4),
                  Text(
                    'Données du ${_formatDate(segment.sourceDate)}',
                    style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),

                  if (segment.notes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.smPlus),
                      decoration: BoxDecoration(
                        color: CalcwiseSemanticColors.warnBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: CalcwiseSemanticColors.warnIcon),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: CalcwiseSemanticColors.warnIcon),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              segment.notes!,
                              style: TextStyle(
                                fontSize: AppTextSize.sm,
                                color: CalcwiseSemanticColors.warnIcon,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Navigate + Report buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _NavigateButton(segment: segment),
                const SizedBox(width: 4),
                _ReportRuleButton(segment: segment),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.lg),
            child: _StartSessionButton(
              segment: segment,
              viewTime: viewTime,
              result: result,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy', 'fr_CA').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final RuleResult result;
  final Color zoneColor;

  const _StatusBadge({required this.result, required this.zoneColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: zoneColor.withAlpha(31),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: zoneColor.withAlpha(102)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: zoneColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            result.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: zoneColor,
              fontSize: AppTextSize.bodyMd,
            ),
          ),
          if (result.hasTimeLimit && result.activeRule?.maxMinutes != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: zoneColor.withAlpha(38),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'Max ${_formatDuration(result.activeRule!.maxMinutes!)}',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w600,
                  color: zoneColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h${m}min' : '${h}h';
  }
}

class _NextChangeBanner extends StatelessWidget {
  final DateTime nextChange;
  final DateTime viewTime;
  final Color color;

  const _NextChangeBanner({
    required this.nextChange,
    required this.viewTime,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final diff = nextChange.difference(viewTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final label = hours > 0
        ? 'Prochain changement dans ${hours}h${minutes > 0 ? '${minutes}min' : ''}'
        : 'Prochain changement dans ${diff.inMinutes}min';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.timer_rounded,
              size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label (${DateFormat('HH:mm').format(nextChange)})',
            style: TextStyle(
              fontSize: AppTextSize.sm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeterInfo extends StatelessWidget {
  final ParkingRule rule;

  const _MeterInfo({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.meter.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.mdPlus),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppTheme.meter, size: 18),
          const SizedBox(width: 10),
          if (rule.ratePerHour != null)
            Text(
              '${rule.ratePerHour!.toStringAsFixed(2)} \$/h',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.meter,
                fontSize: AppTextSize.body,
              ),
            ),
          if (rule.ratePerHour != null && rule.maxMinutes != null)
            Builder(
                builder: (context) => Text('  ·  ',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
          if (rule.maxMinutes != null)
            Text(
              'Max ${_formatMins(rule.maxMinutes!)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.meter,
                fontSize: AppTextSize.body,
              ),
            ),
        ],
      ),
    );
  }

  String _formatMins(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h${m}min' : '${h}h';
  }
}

class _PermitInfo extends StatelessWidget {
  final String zone;

  const _PermitInfo({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.restricted.withAlpha(26),
        borderRadius: BorderRadius.circular(AppRadius.mdPlus),
        border: Border.all(color: AppTheme.restricted.withAlpha(77)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_rounded, color: AppTheme.restricted, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Zone permis : ',
            style: TextStyle(
              color: AppTheme.restricted,
              fontSize: AppTextSize.body,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.restricted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              zone,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: AppTextSize.md,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stationnement alterné (pair/impair) ────────────────────────────────────
class _AlternatingInfo extends StatelessWidget {
  final ParkingRule rule;
  final DateTime viewTime;
  final List<ParkingRule> allRules;

  const _AlternatingInfo({
    required this.rule,
    required this.viewTime,
    required this.allRules,
  });

  @override
  Widget build(BuildContext context) {
    // Déterminer le libellé de parité du mois ou du jour
    final isMonthly = rule.monthParity != null;
    final cycleLabel = isMonthly
        ? 'Stationnement alterné par mois'
        : 'Stationnement alterné par jour';

    // Trouver la règle complémentaire (l'autre parité)
    final complementary = allRules.firstWhere(
      (r) => r.isAlternating && r != rule,
      orElse: () => rule,
    );

    // Construire les deux lignes côté pair / côté impair
    final currentUnit = isMonthly
        ? 'Mois ${viewTime.month} (${_monthName(viewTime.month)})'
        : 'Jour ${viewTime.day}';
    final currentParity = isMonthly ? viewTime.month % 2 : viewTime.day % 2;

    // Côté pair = monthParity/dayParity == 0 dans le noParking → interdit quand parity=0 actif
    // La règle "active" est celle dont la parité == currentParity
    // Si rule.monthParity == currentParity → ce côté est interdit maintenant
    final forbiddenSideNote = rule.note ?? 'Côté interdit actuellement';
    final freeSideNote = complementary.note ?? 'Côté autorisé actuellement';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: CalcwiseSemanticColors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.mdPlus),
        border: Border.all(color: CalcwiseSemanticColors.warnIcon.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: CalcwiseSemanticColors.warnIcon, size: 18),
              const SizedBox(width: 8),
              Text(
                cycleLabel,
                style: const TextStyle(
                  color: CalcwiseSemanticColors.warnIcon,
                  fontWeight: FontWeight.w700,
                  fontSize: AppTextSize.md,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Indicateur de date/mois actuel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CalcwiseSemanticColors.warnIcon.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$currentUnit · Parité : ${currentParity == 0 ? "pair" : "impair"}',
              style: const TextStyle(
                fontSize: AppTextSize.sm,
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Côté INTERDIT maintenant
          _sideLine(
            context: context,
            icon: Icons.block,
            color: AppTheme.restricted,
            label: forbiddenSideNote,
            suffix: 'INTERDIT maintenant',
          ),
          const SizedBox(height: 6),
          // Côté LIBRE maintenant
          _sideLine(
            context: context,
            icon: Icons.check_circle_outline,
            color: AppTheme.free,
            label: freeSideNote,
            suffix: 'AUTORISÉ maintenant',
          ),
        ],
      ),
    );
  }

  Widget _sideLine({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String suffix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suffix,
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _months = [
    '',
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  String _monthName(int m) => _months[m];
}

class _RuleRow extends StatelessWidget {
  final ParkingRule rule;
  final DateTime viewTime;

  const _RuleRow({required this.rule, required this.viewTime});

  bool get _isActive => rule.appliesAt(viewTime);

  Color get _baseColor {
    switch (rule.type) {
      case RuleType.noParking:
        return AppTheme.restricted;
      case RuleType.permitOnly:
        return AppTheme.restricted;
      case RuleType.permitOrLimit:
        return AppTheme.free;
      case RuleType.meter:
        return AppTheme.meter;
      case RuleType.free:
        return AppTheme.free;
    }
  }

  IconData get _ruleIcon {
    switch (rule.type) {
      case RuleType.noParking:
        return Icons.block;
      case RuleType.permitOnly:
        return Icons.badge_rounded;
      case RuleType.permitOrLimit:
        return Icons.hourglass_bottom_rounded;
      case RuleType.meter:
        return Icons.timer_rounded;
      case RuleType.free:
        return Icons.check_circle_outline;
    }
  }

  String get _typeLabel {
    switch (rule.type) {
      case RuleType.noParking:
        return 'Interdit';
      case RuleType.permitOnly:
        return 'Permis résidents requis';
      case RuleType.permitOrLimit:
        final lim = rule.maxMinutes != null
            ? ' (${_fmtMins(rule.maxMinutes!)} max)'
            : '';
        return '2h max · Permis au-delà$lim';
      case RuleType.meter:
        return 'Parcomètre';
      case RuleType.free:
        return rule.maxMinutes != null
            ? 'Limité ${_fmtMins(rule.maxMinutes!)}'
            : 'Libre';
    }
  }

  String _fmtMins(int m) {
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h${rem}min' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final color =
        active ? _baseColor : Theme.of(context).colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: active ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(active ? 18 : 10),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border(
            left: BorderSide(color: color, width: 4),
            top: BorderSide(color: color.withAlpha(active ? 60 : 35)),
            right: BorderSide(color: color.withAlpha(active ? 60 : 35)),
            bottom: BorderSide(color: color.withAlpha(active ? 60 : 35)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Ligne 1 : type + badge actif/inactif ─────────────────────
            Row(
              children: [
                Icon(_ruleIcon, color: color, size: 15),
                const SizedBox(width: 7),
                Text(
                  _typeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: AppTextSize.md,
                  ),
                ),
                const Spacer(),
                // Badge d'état
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? color.withAlpha(30)
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withAlpha(20),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: active
                          ? color.withAlpha(80)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? color
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withAlpha(128),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        active ? 'En vigueur' : 'Hors période',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? color
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Ligne 2 : jours · heures [· saison] ──────────────────────
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoChip(label: rule.daysLabel, color: color),
                _InfoChip(label: rule.timeLabel, color: color),
                if (rule.monthLabel.isNotEmpty)
                  _InfoChip(
                    label: rule.monthLabel,
                    color: color,
                    bold: true,
                  ),
                if (rule.maxMinutes != null && rule.type == RuleType.free)
                  _InfoChip(
                    label: 'Max ${_fmtMins(rule.maxMinutes!)}',
                    color: color,
                    bold: true,
                  ),
              ],
            ),
            // ── Ligne 3 : note ───────────────────────────────────────────
            if (rule.note != null) ...[
              const SizedBox(height: 4),
              Text(
                rule.note!,
                style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;

  const _InfoChip(
      {required this.label, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;

  const _ConfidenceBar({required this.confidence});

  Color get _color {
    if (confidence >= 0.85) return AppTheme.free;
    if (confidence >= 0.65) return CalcwiseSemanticColors.warnIcon;
    return AppTheme.restricted;
  }

  String get _label {
    if (confidence >= 0.85) return 'Haute fiabilité';
    if (confidence >= 0.65) return 'Fiabilité moyenne';
    return 'Fiabilité faible';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fiabilité',
              style: TextStyle(
                fontSize: AppTextSize.sm,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _label,
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: _color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(confidence * 100).round()}%',
              style: TextStyle(
                fontSize: AppTextSize.xs,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: LinearProgressIndicator(
            value: confidence,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _SourcesRow extends StatelessWidget {
  final List<DataSource> sources;

  const _SourcesRow({required this.sources});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sources
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Text(
                  '${s.icon} ${s.label}',
                  style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _SideBadge extends StatelessWidget {
  final String side;

  const _SideBadge({required this.side});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        side,
        style: const TextStyle(
          fontSize: AppTextSize.xs,
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Navigate to spot ──────────────────────────────────────────────────────────
class _NavigateButton extends StatelessWidget {
  final StreetSegment segment;

  const _NavigateButton({required this.segment});

  (double lat, double lon) get _midpoint {
    if (segment.coordinates.isEmpty) return (0.0, 0.0);
    final lons = segment.coordinates.map((c) => c[0]);
    final lats = segment.coordinates.map((c) => c[1]);
    return (
      lats.reduce((a, b) => a + b) / lats.length,
      lons.reduce((a, b) => a + b) / lons.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.directions_rounded, size: 16),
      label: const Text('Naviguer'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        textStyle: const TextStyle(
            fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
      ),
      onPressed: () async {
        final mid = _midpoint;
        final lat = mid.$1;
        final lon = mid.$2;
        final label = Uri.encodeComponent(segment.streetName);
        // Try Google Maps first, fall back to geo: URI
        final googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
        );
        final geoUrl = Uri.parse('geo:$lat,$lon?q=$label');
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(geoUrl)) {
          await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

class _ReportRuleButton extends StatelessWidget {
  final StreetSegment segment;

  const _ReportRuleButton({required this.segment});

  /// Compute the geographic midpoint of the segment coordinates.
  (double lat, double lon) get _midpoint {
    if (segment.coordinates.isEmpty) return (0.0, 0.0);
    final lons = segment.coordinates.map((c) => c[0]);
    final lats = segment.coordinates.map((c) => c[1]);
    final midLat = lats.reduce((a, b) => a + b) / lats.length;
    final midLon = lons.reduce((a, b) => a + b) / lons.length;
    return (midLat, midLon);
  }

  @override
  Widget build(BuildContext context) {
    final mid = _midpoint;
    return TextButton.icon(
      icon: const Icon(Icons.flag_rounded, size: 16),
      label: const Text('Signaler une règle'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        textStyle: const TextStyle(fontSize: AppTextSize.md),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ContributionSheet(
          osmWayId: segment.osmWayIds.isNotEmpty ? segment.osmWayIds.first : 0,
          streetName: segment.streetName,
          cityId: segment.city,
          lat: mid.$1,
          lon: mid.$2,
        ),
      ),
    );
  }
}

class _StartSessionButton extends StatelessWidget {
  final StreetSegment segment;
  final DateTime viewTime;
  final RuleResult result;

  const _StartSessionButton({
    required this.segment,
    required this.viewTime,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final sessionService = context.watch<SessionService>();
    final hasSession = sessionService.hasActiveSession;

    if (result.color == ParkingColor.restricted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.restricted.withAlpha(26),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, color: AppTheme.restricted, size: 16),
            SizedBox(width: 8),
            Text(
              'Stationnement interdit ici',
              style: TextStyle(
                color: AppTheme.restricted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          if (hasSession) {
            HapticFeedback.mediumImpact();
            sessionService.endSession();
          } else if (freemiumService.hasFullAccess) {
            HapticFeedback.mediumImpact();
            sessionService.startSession(segment, viewTime);
          } else {
            PaywallSoft.show(
              context,
              featureTitle: 'ParkSmart Pro',
              featureSubtitle: 'Unlock session tracking, history & more',
              onUnlock: () => IAPService.instance.buy(),
            );
          }
        },
        icon: Icon(
            hasSession ? Icons.stop_circle_rounded : Icons.play_circle_outline),
        label: Text(
          hasSession ? 'Terminer la session' : 'Débuter une session',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AppTextSize.bodyMd,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: hasSession ? CalcwiseSemanticColors.errorDark : AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
