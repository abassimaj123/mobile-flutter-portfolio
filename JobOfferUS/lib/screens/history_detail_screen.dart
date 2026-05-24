import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/theme/app_theme.dart';
import '../core/language/language_notifier.dart';

/// Full detail view for a single saved offer entry.
class HistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isSpanish;

  const HistoryDetailScreen({
    super.key,
    required this.row,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isEs, __) {
        final fmt = NumberFormat.currency(
            locale: 'en_US', symbol: '\$', decimalDigits: 0);
        final pctFmt = NumberFormat('0.0#', 'en_US');
        final dateFmt = DateFormat('MMM d, yyyy – HH:mm');

        final jobTitle = row['job_title'] as String? ?? '';
        final company = row['company'] as String? ?? '';
        final location = row['location'] as String? ?? '';
        final salary = (row['salary'] as num?)?.toDouble() ?? 0.0;
        final bonus = (row['bonus'] as num?)?.toDouble() ?? 0.0;
        final benefits = (row['benefits'] as num?)?.toDouble() ?? 0.0;
        final stockOptions = (row['stock_options'] as num?)?.toDouble() ?? 0.0;
        final pto = (row['pto'] as num?)?.toInt() ?? 0;
        final netSalary = (row['net_salary'] as num?)?.toDouble() ?? 0.0;
        final monthlyNet = (row['monthly_net'] as num?)?.toDouble() ?? 0.0;
        final taxRate = (row['tax_rate'] as num?)?.toDouble() ?? 0.0;
        final createdAt =
            DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now();

        final ct = CalcwiseTheme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              jobTitle.isNotEmpty
                  ? jobTitle
                  : (isEs ? 'Detalle de Oferta' : 'Offer Detail'),
            ),
            leading: const BackButton(),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ──────────────────────────────────────────────
                CalcwiseHeroCard(
                  label: isEs ? 'Neto anual' : 'Annual net take-home',
                  value: fmt.format(netSalary),
                  secondary: isEs
                      ? '${fmt.format(monthlyNet)}/mes · Imp. ${pctFmt.format(taxRate)}%'
                      : '${fmt.format(monthlyNet)}/mo · Tax ${pctFmt.format(taxRate)}%',
                  backgroundColor: AppTheme.primary,
                  stats: [
                    (
                      label: isEs ? 'Empresa' : 'Company',
                      value: company.isNotEmpty ? company : '—',
                    ),
                    (
                      label: isEs ? 'Ciudad' : 'City',
                      value: location.isNotEmpty ? location : '—',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Details section ──────────────────────────────────────────
                _DetailCard(
                  title: isEs ? 'Compensación' : 'Compensation',
                  rows: [
                    _RowData(isEs ? 'Salario bruto' : 'Gross Salary',
                        fmt.format(salary)),
                    _RowData(isEs ? 'Ingreso neto anual' : 'Net Annual',
                        fmt.format(netSalary)),
                    _RowData(isEs ? 'Ingreso neto mensual' : 'Net Monthly',
                        fmt.format(monthlyNet)),
                    _RowData(isEs ? 'Tasa efectiva' : 'Effective Tax Rate',
                        '${pctFmt.format(taxRate)}%'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Benefits & extras ────────────────────────────────────────
                _DetailCard(
                  title: isEs ? 'Beneficios y Extras' : 'Benefits & Extras',
                  rows: [
                    if (bonus > 0)
                      _RowData(isEs ? 'Bono anual' : 'Annual Bonus',
                          fmt.format(bonus)),
                    if (benefits > 0)
                      _RowData(isEs ? 'Beneficios salud' : 'Health Benefits',
                          fmt.format(benefits)),
                    if (stockOptions > 0)
                      _RowData(isEs ? 'RSU / Stock' : 'RSU / Stock',
                          fmt.format(stockOptions)),
                    if (pto > 0)
                      _RowData(isEs ? 'Días PTO' : 'PTO Days',
                          '$pto ${isEs ? "días" : "days"}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Metadata ─────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    '${isEs ? "Guardado" : "Saved"}: ${dateFmt.format(createdAt)}',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: ct.textSecondary),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Ad footer ────────────────────────────────────────────────
                const CalcwiseAdFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _RowData {
  final String label;
  final String value;
  const _RowData(this.label, this.value);
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<_RowData> rows;

  const _DetailCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final ct = CalcwiseTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: ct.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: AppTextSize.md, fontWeight: FontWeight.w700),
            ),
          ),
          Divider(height: 1, color: ct.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: rows.map((r) => _buildRow(context, r, ct)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _RowData r, CalcwiseTheme ct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(r.label,
              style:
                  TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
          Text(r.value,
              style: const TextStyle(
                  fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
