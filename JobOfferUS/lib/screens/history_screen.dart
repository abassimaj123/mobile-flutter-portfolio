import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:calcwise_core/calcwise_core.dart';
import '../core/db/database_helper.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/language/language_notifier.dart';
import '../core/theme/app_theme.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onSwitchToCompare;
  const HistoryScreen({super.key, this.onSwitchToCompare});

  static final refreshNotifier = ValueNotifier<int>(0);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _firstLoad = true;

  // AmountFormatter replaces _fmtUSD
  final _fmtDate = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _load();
    HistoryScreen.refreshNotifier.addListener(_silentRefresh);
  }

  @override
  void dispose() {
    HistoryScreen.refreshNotifier.removeListener(_silentRefresh);
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getHistory();
    if (mounted) {
      setState(() {
        _history = rows;
        _firstLoad = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    final rows = await DatabaseHelper.instance.getHistory();
    if (mounted) setState(() => _history = rows);
  }

  Future<void> _delete(int id, BuildContext context, bool isEs) async {
    HapticFeedback.mediumImpact();
    final confirm = await _confirmDelete(context, isEs);
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteHistory(id);
        _load();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEs ? 'Error al eliminar' : 'Failed to delete'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CalcwiseSemanticColors.errorDark,
          ),
        );
      }
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, bool isEs) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? '¿Eliminar oferta?' : 'Delete offer?'),
        content: Text(
          isEs
              ? 'Esta entrada será eliminada permanentemente del historial.'
              : 'This entry will be permanently removed from history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isEs ? 'Eliminar' : 'Delete',
              style: const TextStyle(color: CalcwiseSemanticColors.errorDark),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, bool isEs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEs ? '¿Borrar todo?' : 'Clear all?'),
        content: Text(
          isEs ? '¿Eliminar todo el historial?' : 'Delete all saved offers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isEs ? 'Cancelar' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isEs ? 'Borrar' : 'Clear',
              style: const TextStyle(color: CalcwiseSemanticColors.errorDark),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.clearHistory();
        _load();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEs ? 'Error al borrar' : 'Failed to clear'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CalcwiseSemanticColors.errorDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isEs, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isEs ? 'Ofertas Guardadas' : 'Saved Offers'),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.hasFullAccessNotifier,
                builder: (context, isPremium, _) {
                  if (isPremium && _history.isNotEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.delete_sweep,
                          color: CalcwiseSemanticColors.errorDark),
                      tooltip: isEs ? 'Borrar todo' : 'Clear all',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _clearAll(context, isEs);
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _firstLoad
                    ? const _HistorySkeleton()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: CustomScrollView(
                          slivers: [
                            // ── Header with count ─────────────────────────
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.sm),
                                child: ValueListenableBuilder<bool>(
                                  valueListenable:
                                      freemiumService.hasFullAccessNotifier,
                                  builder: (context, isPremium, _) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPremium
                                              ? '${_history.length} ${isEs ? 'ofertas guardadas' : 'offers saved'}'
                                              : '${_history.length} / ${MonetizationConfig.freeCalculationLimit} ${isEs ? 'guardadas' : 'saved'}',
                                          style: TextStyle(
                                            color: CalcwiseTheme.of(context)
                                                .textSecondary,
                                            fontSize: AppTextSize.md,
                                          ),
                                        ),
                                        if (!isPremium) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Row(children: [
                                            const Icon(Icons.lock_outline,
                                                size: 14,
                                                color: CalcwiseSemanticColors
                                                    .warnIcon),
                                            const SizedBox(
                                                width: AppSpacing.xs),
                                            Expanded(
                                              child: Text(
                                                isEs
                                                    ? 'Máximo ${MonetizationConfig.freeCalculationLimit} entradas para usuarios gratuitos'
                                                    : 'Max ${MonetizationConfig.freeCalculationLimit} entries for free users',
                                                style: TextStyle(
                                                    fontSize: AppTextSize.sm,
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  IAPService.instance.buy(),
                                              style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero),
                                              child: Text(
                                                isEs ? 'Desbloquear' : 'Unlock',
                                                style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: AppTextSize.sm),
                                              ),
                                            ),
                                          ]),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),

                            // ── Empty state ───────────────────────────────
                            if (_history.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: CalcwiseEmptyState(
                                  icon: Icons.work_outline,
                                  title: isEs
                                      ? 'No hay ofertas guardadas'
                                      : 'No saved offers',
                                  body: isEs
                                      ? 'Guarda tu primera comparación para verla aquí'
                                      : 'Save your first comparison to see it here',
                                  actionLabel: widget.onSwitchToCompare != null
                                      ? (isEs
                                          ? 'Comparar ahora'
                                          : 'Compare Now')
                                      : null,
                                  onAction: widget.onSwitchToCompare,
                                ),
                              )
                            else
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        AppSpacing.lg,
                                        0,
                                        AppSpacing.lg,
                                        AppSpacing.smPlus),
                                    child:
                                        _buildCard(context, _history[i], isEs),
                                  ),
                                  childCount: _history.length,
                                ),
                              ),

                            const SliverToBoxAdapter(
                                child: SizedBox(height: 80)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> row, bool isEs) {
    final id = row['id'] as int? ?? 0;
    final jobTitle = row['job_title'] as String? ?? '';
    final company = row['company'] as String? ?? '';
    final netSalary = (row['net_salary'] as num?)?.toDouble() ?? 0.0;
    final monthlyNet = (row['monthly_net'] as num?)?.toDouble() ?? 0.0;
    final taxRate = (row['tax_rate'] as num?)?.toDouble() ?? 0.0;
    final createdAt =
        DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now();

    final ct = CalcwiseTheme.of(context);

    return Dismissible(
      key: Key('offer-$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, isEs),
      onDismissed: (_) async {
        await DatabaseHelper.instance.deleteHistory(id);
        await _load();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: CalcwiseSemanticColors.errorDark.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Icon(Icons.delete_outline,
            color: CalcwiseSemanticColors.errorDark, size: 24),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailScreen(row: row, isSpanish: isEs),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: ct.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.mdPlus, vertical: AppSpacing.md),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // ── Left: colored dot ───────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.work_outline,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),

              // ── Center: job info ────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobTitle.isNotEmpty
                          ? jobTitle
                          : (isEs ? 'Oferta' : 'Offer'),
                      style: const TextStyle(
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (company.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(company,
                          style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: ct.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Row(children: [
                      Flexible(
                        child: Text(
                          '${AmountFormatter.ui(monthlyNet, 'USD')}${isEs ? '/mes' : '/mo'}',
                          style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: ct.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '· ${isEs ? 'Imp.' : 'Tax'} ${taxRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: AppTextSize.xs, color: ct.textSecondary),
                      ),
                    ]),
                    const SizedBox(height: 1),
                    Text(
                      _fmtDate.format(createdAt),
                      style: TextStyle(
                          fontSize: AppTextSize.xs, color: ct.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Right: hero net salary ─────────────────────────────────
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        AmountFormatter.ui(netSalary, 'USD'),
                        style: const TextStyle(
                          fontSize: AppTextSize.display,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Text(
                      isEs ? 'neto/año' : 'net/yr',
                      style: TextStyle(
                          fontSize: AppTextSize.xs, color: ct.textSecondary),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ), // InkWell
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
          children: List.generate(
              4,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                        )),
                  ))),
    );
  }
}
