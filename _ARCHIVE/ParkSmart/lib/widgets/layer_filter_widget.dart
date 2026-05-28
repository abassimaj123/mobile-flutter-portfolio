import 'package:flutter/material.dart';
import '../core/services/rule_engine.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

class LayerFilterWidget extends StatelessWidget {
  final Map<ParkingColor, bool> filters;
  final Function(Map<ParkingColor, bool>) onFiltersChanged;

  const LayerFilterWidget({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(
        filters: Map.from(filters),
        onFiltersChanged: (newFilters) {
          Navigator.pop(ctx);
          onFiltersChanged(newFilters);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = filters.values.where((v) => v).length;
    final allActive = activeCount == filters.length;

    return GestureDetector(
      onTap: () => _showFilterSheet(context),
      child: Semantics(
        button: true,
        enabled: true,
        label: 'Filtrer les zones de stationnement',
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: allActive ? Colors.white : AppTheme.accent.withAlpha(26),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(31),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: allActive
                  ? null
                  : Border.all(color: AppTheme.accent, width: 2),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.layers_rounded,
                  color: allActive ? AppTheme.primary : AppTheme.accent,
                  size: 22,
                ),
                if (!allActive)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: AppTextSize.xs,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final Map<ParkingColor, bool> filters;
  final Function(Map<ParkingColor, bool>) onFiltersChanged;

  const _FilterSheet({
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Map<ParkingColor, bool> _filters;

  static const Map<ParkingColor, _FilterInfo> _filterInfo = {
    ParkingColor.free: _FilterInfo(
      label: 'Stationnement libre',
      description: 'Libre maintenant (gratuit ou parcomètre hors heures)',
      color: AppTheme.free,
      icon: Icons.check_circle_outline,
    ),
    ParkingColor.meter: _FilterInfo(
      label: 'Parcomètre',
      description: 'Paiement requis pendant les heures affichées',
      color: AppTheme.meter,
      icon: Icons.timer_rounded,
    ),
    ParkingColor.restricted: _FilterInfo(
      label: 'Stationnement interdit',
      description: 'Interdit maintenant (SRRR ou interdiction directe)',
      color: AppTheme.restricted,
      icon: Icons.block,
    ),
    ParkingColor.noData: _FilterInfo(
      label: 'Sans données',
      description: 'Zone non couverte — carte naturelle',
      color: AppTheme.noData,
      icon: Icons.help_outline,
    ),
  };

  @override
  void initState() {
    super.initState();
    _filters = Map.from(widget.filters);
  }

  bool get _allActive => _filters.values.every((v) => v);
  bool get _noneActive => _filters.values.every((v) => !v);

  void _toggleAll(bool value) {
    setState(() {
      for (final key in _filters.keys) {
        _filters[key] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                Text(
                  'Filtres de zones',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _allActive ? null : () => _toggleAll(true),
                  child: const Text('Tout afficher'),
                ),
                TextButton(
                  onPressed: _noneActive ? null : () => _toggleAll(false),
                  child: Text(
                    'Masquer tout',
                    style: TextStyle(
                      color: _noneActive ? const Color(0xFF64748B) : CalcwiseSemanticColors.errorDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...ParkingColor.values.map((color) {
            final info = _filterInfo[color];
            if (info == null) return const SizedBox.shrink();
            return _FilterRow(
              info: info,
              value: _filters[color] ?? true,
              onChanged: (val) {
                setState(() {
                  _filters[color] = val;
                });
              },
            );
          }),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onFiltersChanged(_filters),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
                ),
                child: const Text(
                  'Appliquer',
                  style: TextStyle(
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

class _FilterRow extends StatelessWidget {
  final _FilterInfo info;
  final bool value;
  final Function(bool) onChanged;

  const _FilterRow({
    required this.info,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: info.color.withAlpha(38),
          shape: BoxShape.circle,
        ),
        child: Icon(info.icon, color: info.color, size: 18),
      ),
      title: Text(
        info.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: value ? Colors.black87 : const Color(0xFF64748B),
        ),
      ),
      subtitle: Text(
        info.description,
        style: TextStyle(
          fontSize: AppTextSize.sm,
          color: value ? const Color(0xFF475569) : const Color(0xFF94A3B8),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: info.color,
      ),
    );
  }
}

class _FilterInfo {
  final String label;
  final String description;
  final Color color;
  final IconData icon;

  const _FilterInfo({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });
}
