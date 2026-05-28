import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';
import '../core/language/language_notifier.dart';
import '../core/services/analytics_service.dart';

/// Full detail view for a single saved offer entry.
class HistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool isSpanish;

  const HistoryDetailScreen({
    super.key,
    required this.row,
    required this.isSpanish,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf(bool isEs) async {
    setState(() => _exporting = true);
    try {
      final pctFmt = NumberFormat('0.0#', 'en_US');
      final row = widget.row;
      final jobTitle = row['job_title'] as String? ?? '';
      final company = row['company'] as String? ?? '';
      final salary = (row['salary'] as num?)?.toDouble() ?? 0.0;
      final bonus = (row['bonus'] as num?)?.toDouble() ?? 0.0;
      final netSalary = (row['net_salary'] as num?)?.toDouble() ?? 0.0;
      final monthlyNet = (row['monthly_net'] as num?)?.toDouble() ?? 0.0;
      final taxRate = (row['tax_rate'] as num?)?.toDouble() ?? 0.0;

      final primary = PdfColor.fromHex('4F46E5');
      final grey = PdfColors.grey700;

      pw.TableRow pdfRow(String label, String value, {bool bold = false}) =>
          pw.TableRow(children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(label,
                    style: pw.TextStyle(fontSize: 10, color: grey))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: bold
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal))),
          ]);

      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
                isEs ? 'Detalle de Oferta de Trabajo' : 'Job Offer Detail',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primary)),
            pw.SizedBox(height: 4),
            pw.Text(
                '${isEs ? 'Generado' : 'Generated'}: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: grey)),
            pw.SizedBox(height: 16),
            if (jobTitle.isNotEmpty || company.isNotEmpty)
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('EEF2FF'),
                    borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (jobTitle.isNotEmpty)
                        pw.Text(jobTitle,
                            style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: primary)),
                      if (company.isNotEmpty)
                        pw.Text(company,
                            style:
                                pw.TextStyle(fontSize: 11, color: grey)),
                    ]),
              ),
            pw.SizedBox(height: 16),
            pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primary),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(isEs ? 'Métrica' : 'Metric',
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(isEs ? 'Valor' : 'Value',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pdfRow(isEs ? 'Salario bruto' : 'Gross Salary',
                    AmountFormatter.ui(salary, 'USD'),
                    bold: true),
                pdfRow(isEs ? 'Neto anual' : 'Annual Net Take-Home',
                    AmountFormatter.ui(netSalary, 'USD'),
                    bold: true),
                pdfRow(isEs ? 'Neto mensual' : 'Monthly Net',
                    AmountFormatter.ui(monthlyNet, 'USD')),
                if (bonus > 0)
                  pdfRow(isEs ? 'Bono' : 'Bonus',
                      AmountFormatter.ui(bonus, 'USD')),
                pdfRow(isEs ? 'Tasa impositiva' : 'Effective Tax Rate',
                    '${pctFmt.format(taxRate)}%'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              isEs
                  ? 'Este reporte es solo informativo. Consulte a un asesor fiscal.'
                  : 'This report is for informational purposes only. Consult a tax professional.',
              style: pw.TextStyle(
                  fontSize: 8,
                  color: grey,
                  fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      ));

      final pdfBytes = await pdf.save();
      final tmpDir = await getTemporaryDirectory();
      final slug = jobTitle.isNotEmpty
          ? jobTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase()
          : 'offer';
      final pdfFile = File(
          '${tmpDir.path}/${slug}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await pdfFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
          [XFile(pdfFile.path, mimeType: 'application/pdf')]);
      AnalyticsService.instance.logPdfExportedEvent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEs ? 'Error al exportar PDF' : 'PDF export failed'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isEs, __) {
        final pctFmt = NumberFormat('0.0#', 'en_US');
        final dateFmt = DateFormat('MMM d, yyyy – HH:mm');

        final row = widget.row;
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
                  value: AmountFormatter.ui(netSalary, 'USD'),
                  secondary: isEs
                      ? '${AmountFormatter.ui(monthlyNet, 'USD')}/mes · Imp. ${pctFmt.format(taxRate)}%'
                      : '${AmountFormatter.ui(monthlyNet, 'USD')}/mo · Tax ${pctFmt.format(taxRate)}%',
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
                        AmountFormatter.ui(salary, 'USD')),
                    _RowData(isEs ? 'Ingreso neto anual' : 'Net Annual',
                        AmountFormatter.ui(netSalary, 'USD')),
                    _RowData(isEs ? 'Ingreso neto mensual' : 'Net Monthly',
                        AmountFormatter.ui(monthlyNet, 'USD')),
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
                          AmountFormatter.ui(bonus, 'USD')),
                    if (benefits > 0)
                      _RowData(isEs ? 'Beneficios salud' : 'Health Benefits',
                          AmountFormatter.ui(benefits, 'USD')),
                    if (stockOptions > 0)
                      _RowData(isEs ? 'RSU / Stock' : 'RSU / Stock',
                          AmountFormatter.ui(stockOptions, 'USD')),
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

                // ── Export PDF button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _exporting ? null : () => _exportPdf(isEs),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.primary.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                    ),
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: Text(
                      _exporting
                          ? (isEs ? 'Generando...' : 'Generating...')
                          : (isEs ? 'Exportar PDF' : 'Export PDF'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.md),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

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
