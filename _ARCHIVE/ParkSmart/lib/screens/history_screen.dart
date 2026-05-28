import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import '../core/db/database_helper.dart';
import '../core/services/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await DatabaseHelper.instance.getHistory();
    if (mounted) {
      setState(() {
        _entries = rows;
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    await DatabaseHelper.instance.deleteHistory(id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrée supprimée'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Vider l'historique ?"),
        content:
            const Text('Toutes les entrées sauvegardées seront supprimées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider',
                style: TextStyle(color: AppTheme.restricted)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.clearHistory();
      await _load();
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Vider tout',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _EmptyState(ct: ct)
                    : _buildList(ct),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildList(CalcwiseTheme ct) {
    return ValueListenableBuilder<bool>(
      valueListenable: freemiumService.isPremiumNotifier,
      builder: (_, isPremium, __) {
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _entries.length + (!isPremium ? 1 : 0),
          itemBuilder: (_, i) {
            if (!isPremium && i == _entries.length) {
              return _UpgradeCTA(ct: ct);
            }
            final e = _entries[i];
            final id = e['id'] as int?;
            final location = e['location'] as String? ?? '—';
            final hourlyRate = (e['hourly_rate'] as num?)?.toDouble() ?? 0.0;
            final hoursParked = (e['hours_parked'] as num?)?.toInt() ?? 0;
            final totalCost = (e['total_cost'] as num?)?.toDouble() ?? 0.0;
            final createdAt = e['created_at'] as String?;

            return Dismissible(
              key: ValueKey('history_${id}_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppTheme.restricted.withAlpha(31),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: const Icon(Icons.delete_rounded,
                    color: AppTheme.restricted),
              ),
              onDismissed: (_) {
                if (id != null) _delete(id);
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.local_parking_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                  title: Text(
                    location,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTextSize.bodyMd),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        '\$${totalCost.toStringAsFixed(2)} · '
                        '${hoursParked}h · '
                        '\$${hourlyRate.toStringAsFixed(2)}/h',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                            fontSize: AppTextSize.sm, color: ct.textSecondary),
                      ),
                    ],
                  ),
                  trailing: id != null
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.restricted, size: 20),
                          tooltip: 'Supprimer',
                          onPressed: () => _delete(id),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final CalcwiseTheme ct;
  const _EmptyState({required this.ct});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 72, color: AppTheme.primary.withAlpha(76)),
            const SizedBox(height: 16),
            const Text(
              'Aucun historique',
              style: TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos calculs de stationnement apparaîtront ici après les avoir sauvegardés.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ct.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upgrade CTA ───────────────────────────────────────────────────────────────

class _UpgradeCTA extends StatelessWidget {
  final CalcwiseTheme ct;
  const _UpgradeCTA({required this.ct});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.primary.withAlpha(13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: AppTheme.primary.withAlpha(51), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.lock_open_rounded,
                color: AppTheme.primary.withAlpha(153), size: 32),
            const SizedBox(height: 8),
            const Text(
              'Débloquez Premium pour un historique illimité',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: AppTextSize.body),
            ),
            const SizedBox(height: 4),
            Text(
              'Supprimez les publicités et accédez à toutes les fonctionnalités.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: ct.textSecondary, fontSize: AppTextSize.md),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => PaywallHard.show(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('Obtenir Premium — \$2.99'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
