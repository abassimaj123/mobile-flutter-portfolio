import 'dart:convert';
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
import '../core/freemium/freemium_service.dart';
import '../core/services/analytics_service.dart';

/// Full detail view for a saved comparison or single offer entry.
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

  // ── Parse comparison JSON if present ────────────────────────────────────────
  Map<String, dynamic>? get _compJson {
    final raw = widget.row['comparison_json'] as String?;
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool get _isComparison => _compJson != null;

  // ── PDF Export ───────────────────────────────────────────────────────────────
  Future<void> _exportPdf(bool isEs) async {
    setState(() => _exporting = true);
    try {
      final comp = _compJson;
      if (comp != null) {
        await _exportComparisonPdf(comp, isEs);
      } else {
        await _exportSinglePdf(isEs);
      }
      AnalyticsService.instance.logPdfExportedEvent();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEs ? 'Error al exportar PDF' : 'PDF export failed'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Full comparison PDF (premium quality) ───────────────────────────────────
  Future<void> _exportComparisonPdf(
      Map<String, dynamic> comp, bool isEs) async {
    final pctFmt = NumberFormat('0.0#', 'en_US');
    final numFmt = NumberFormat('#,##0', 'en_US');
    final dateFmt = DateFormat('MMM d, yyyy');
    final now = dateFmt.format(DateTime.now());

    final offers = (comp['offers'] as List).cast<Map<String, dynamic>>();
    final winner = comp['winner'] as String? ?? 'tie';
    final advantage = (comp['advantage'] as num?)?.toDouble() ?? 0;
    final categories =
        (comp['categories'] as Map<String, dynamic>? ?? {});

    final primary = PdfColor.fromHex('4F46E5');
    final accent = PdfColor.fromHex('F59E0B');
    final green = PdfColor.fromHex('16A34A');
    final grey = PdfColors.grey700;
    final lightGrey = PdfColors.grey200;

    String winLabel() {
      if (winner == 'tie') return isEs ? 'Empate' : 'Tie';
      final idx = winner == 'A' ? 0 : winner == 'B' ? 1 : 2;
      final lbl = offers[idx]['label'] as String? ?? 'Offer $winner';
      return isEs ? '$lbl gana' : '$lbl wins';
    }

    pw.Widget headerCell(String t, {bool right = false}) => pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(t,
              textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget labelCell(String t) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(t,
              style: pw.TextStyle(fontSize: 9, color: grey)),
        );

    pw.Widget valCell(String t,
            {bool bold = false, bool winner = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(t,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: winner ? green : PdfColors.black,
                  fontWeight:
                      bold || winner ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    // Build column widths dynamically
    final numOffers = offers.length;
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(2.8),
      for (var i = 0; i < numOffers; i++)
        i + 1: const pw.FlexColumnWidth(1.6),
    };

    pw.TableRow dataRow(String label, List<String> vals,
        {bool bold = false, String? winnerIdx}) {
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: lightGrey),
        children: [
          labelCell(label),
          for (var i = 0; i < vals.length; i++)
            valCell(vals[i],
                bold: bold,
                winner: winnerIdx != null &&
                    _winnerLetterToIndex(winnerIdx) == i),
        ],
      );
    }

    pw.TableRow sectionHeader(String title) => pw.TableRow(
          decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('EEF2FF')),
          children: [
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: primary)),
            ),
            for (var _ in offers) pw.SizedBox(),
          ],
        );

    String amt(dynamic v) =>
        AmountFormatter.ui((v as num?)?.toDouble() ?? 0, 'USD');
    String pct(dynamic v) => '${pctFmt.format((v as num?)?.toDouble() ?? 0)}%';
    String yrs(dynamic v) => '${numFmt.format((v as num?)?.toDouble() ?? 0)} yrs';

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        // ── Title ──
        pw.Text(
            isEs
                ? 'Comparación Detallada de Ofertas de Trabajo'
                : 'Detailed Job Offer Comparison Report',
            style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: primary)),
        pw.SizedBox(height: 4),
        pw.Text(
            '${isEs ? 'Generado' : 'Generated'}: $now  ·  Job Offer US',
            style: pw.TextStyle(fontSize: 8, color: grey)),
        pw.SizedBox(height: 14),

        // ── Winner banner ──
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                  colors: [primary, PdfColor.fromHex('7C3AED')]),
              borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('★ ${winLabel()}',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                if (winner != 'tie')
                  pw.Text(
                      '+${AmountFormatter.ui(advantage, 'USD')} ${isEs ? "ventaja/año" : "advantage/yr"}',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.white)),
              ]),
        ),
        pw.SizedBox(height: 16),

        // ── Offer summaries header ──
        pw.Row(children: [
          for (var i = 0; i < offers.length; i++) ...[
            if (i > 0) pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _offerColor(i),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                          offers[i]['label'] as String? ?? 'Offer ${_letter(i)}',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      if ((offers[i]['company'] as String? ?? '').isNotEmpty)
                        pw.Text(offers[i]['company'] as String,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.white)),
                      if ((offers[i]['city'] as String? ?? '').isNotEmpty)
                        pw.Text(
                            '${offers[i]['city']} · ${offers[i]['state'] ?? ''}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.white)),
                      pw.SizedBox(height: 6),
                      pw.Text(
                          amt(offers[i]['net']),
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      pw.Text(isEs ? 'neto/año' : 'net/yr',
                          style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.white)),
                    ]),
              ),
            ),
          ],
        ]),
        pw.SizedBox(height: 16),

        // ── Main comparison table ──
        pw.Table(
          border:
              pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
          columnWidths: colWidths,
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: primary),
              children: [
                headerCell(isEs ? 'Métrica' : 'Metric'),
                for (var o in offers)
                  headerCell(o['label'] as String? ?? 'Offer',
                      right: true),
              ],
            ),

            // ── Income ──
            sectionHeader(isEs ? 'INGRESOS' : 'INCOME'),
            dataRow(isEs ? 'Salario bruto' : 'Gross Salary',
                [for (var o in offers) amt(o['base'])],
                bold: true),
            dataRow(isEs ? 'Neto anual' : 'Annual Net Take-Home',
                [for (var o in offers) amt(o['net'])],
                bold: true, winnerIdx: winner),
            dataRow(isEs ? 'Neto mensual' : 'Monthly Net',
                [for (var o in offers) amt(o['monthly'])]),
            dataRow(isEs ? 'Comp. total neta' : 'Total Net Compensation',
                [for (var o in offers) amt(o['total_comp'])],
                bold: true, winnerIdx: categories['total'] as String?),

            // ── Taxes ──
            sectionHeader(isEs ? 'IMPUESTOS' : 'TAXES'),
            dataRow(isEs ? 'Tasa efectiva' : 'Effective Tax Rate',
                [for (var o in offers) pct(o['tax_rate'])]),
            dataRow(isEs ? 'Impuesto federal' : 'Federal Tax',
                [for (var o in offers) amt(o['federal'])]),
            dataRow(isEs ? 'Impuesto estatal' : 'State Tax',
                [for (var o in offers) amt(o['state_tax'])]),
            dataRow('FICA (SS + Medicare)',
                [for (var o in offers) amt(o['fica'])]),
            dataRow(isEs ? 'Total impuestos' : 'Total Taxes',
                [for (var o in offers) amt(o['total_tax'])]),

            // ── Bonuses ──
            sectionHeader(isEs ? 'BONOS' : 'BONUSES'),
            dataRow(isEs ? 'Bono anual (bruto)' : 'Annual Bonus (gross)',
                [for (var o in offers) amt(o['annual_bonus'])],
                winnerIdx: categories['bonus'] as String?),
            dataRow(isEs ? 'Bono anual (neto)' : 'Annual Bonus (after tax)',
                [for (var o in offers) amt(o['bonus_net'])]),
            if (offers.any((o) => ((o['signing'] as num?) ?? 0) > 0))
              dataRow(isEs ? 'Bono contratación (neto)' : 'Signing Bonus (after tax)',
                  [for (var o in offers) amt(o['signing_net'])]),

            // ── Benefits ──
            sectionHeader(isEs ? 'BENEFICIOS' : 'BENEFITS'),
            dataRow(isEs ? 'Match 401k' : '401k Employer Match',
                [for (var o in offers) amt(o['k401k_match_usd'])]),
            dataRow(isEs ? 'Beneficios salud/dental' : 'Health & Dental Savings',
                [for (var o in offers) amt(o['health'])],
                winnerIdx: categories['benefits'] as String?),
            dataRow(isEs ? 'RSU anual' : 'Annual RSU / Equity',
                [for (var o in offers) amt(o['rsu_value'])],
                winnerIdx: categories['rsu'] as String?),
            dataRow(isEs ? 'Valor PTO' : 'PTO Value',
                [for (var o in offers) amt(o['pto_value'])],
                winnerIdx: categories['pto'] as String?),
            if (offers.any((o) => ((o['commute_miles'] as num?) ?? 0) > 0))
              dataRow(isEs ? 'Costo traslado anual' : 'Annual Commute Cost',
                  [for (var o in offers) amt(o['commute_cost'])]),

            // ── Cost of living adjusted ──
            sectionHeader(isEs ? 'PODER ADQUISITIVO' : 'PURCHASING POWER'),
            dataRow(
                isEs
                    ? 'Neto ajustado (costo de vida)'
                    : 'CoL-Adjusted Net Take-Home',
                [for (var o in offers) amt(o['col_adj'])],
                bold: true, winnerIdx: categories['col'] as String?),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── Category winners ──
        if (categories.isNotEmpty) ...[
          pw.Text(isEs ? 'GANADORES POR CATEGORÍA' : 'CATEGORY WINNERS',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primary)),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 8,
            runSpacing: 6,
            children: categories.entries.map((e) {
              final idx = _winnerLetterToIndex(e.value as String);
              final label = idx >= 0 && idx < offers.length
                  ? offers[idx]['label'] as String? ?? 'Offer ${e.value}'
                  : isEs ? 'Empate' : 'Tie';
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('EEF2FF'),
                    borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(
                    '${_categoryLabel(e.key, isEs)}: $label',
                    style: pw.TextStyle(fontSize: 8, color: primary)),
              );
            }).toList(),
          ),
          pw.SizedBox(height: 16),
        ],

        // ── 5-year projection ──
        if (offers.isNotEmpty &&
            offers[0]['5yr'] != null &&
            (offers[0]['5yr'] as List).isNotEmpty) ...[
          pw.Text(isEs ? 'PROYECCIÓN A 5 AÑOS' : '5-YEAR COMPENSATION PROJECTION',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primary)),
          pw.SizedBox(height: 6),
          pw.Table(
            border:
                pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              for (var i = 0; i < offers.length; i++)
                i + 1: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primary),
                children: [
                  headerCell(isEs ? 'Año' : 'Year'),
                  for (var o in offers)
                    headerCell(o['label'] as String? ?? 'Offer',
                        right: true),
                ],
              ),
              for (var yr = 0; yr < 5; yr++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: yr.isOdd ? lightGrey : PdfColors.white),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('${isEs ? "Año" : "Year"} ${yr + 1}',
                            style:
                                pw.TextStyle(fontSize: 9, color: grey))),
                    for (var o in offers)
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              amt((o['5yr'] as List?)
                                      ?.elementAtOrNull(yr) ??
                                  0),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold))),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 16),
        ],

        // ── Disclaimer ──
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(
            isEs
                ? 'Este reporte es solo informativo. Los cálculos son estimaciones basadas en tarifas federales y estatales de 2026. Consulte a un asesor fiscal certificado antes de tomar decisiones financieras.'
                : 'This report is for informational purposes only. Calculations are estimates based on 2026 federal and state tax rates. Consult a certified tax professional before making financial decisions.',
            style: pw.TextStyle(
                fontSize: 7,
                color: grey,
                fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
    ));

    final pdfBytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final pdfFile = File(
        '${tmpDir.path}/job_comparison_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf')]);
  }

  // ── Single offer PDF (legacy rows) ──────────────────────────────────────────
  Future<void> _exportSinglePdf(bool isEs) async {
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
          pw.Text(isEs ? 'Detalle de Oferta de Trabajo' : 'Job Offer Detail',
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
                          style: pw.TextStyle(fontSize: 11, color: grey)),
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
                fontSize: 8, color: grey, fontStyle: pw.FontStyle.italic),
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
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  static int _winnerLetterToIndex(String w) {
    switch (w) {
      case 'offerA':
      case 'A':
        return 0;
      case 'offerB':
      case 'B':
        return 1;
      case 'offerC':
      case 'C':
        return 2;
      default:
        return -1;
    }
  }

  static String _letter(int i) => ['A', 'B', 'C'][i.clamp(0, 2)];

  static PdfColor _offerColor(int i) {
    const colors = ['4F46E5', '0891B2', 'D97706'];
    return PdfColor.fromHex(colors[i.clamp(0, 2)]);
  }

  static String _categoryLabel(String key, bool isEs) {
    const en = {
      'takeHome': 'Take-Home',
      'bonus': 'Bonus',
      'benefits': 'Benefits',
      'pto': 'PTO',
      'rsu': 'RSU/Equity',
      'commute': 'Commute',
      'col': 'Cost of Living',
      'total': 'Total Comp',
    };
    const es = {
      'takeHome': 'Neto',
      'bonus': 'Bono',
      'benefits': 'Beneficios',
      'pto': 'PTO',
      'rsu': 'RSU/Equidad',
      'commute': 'Traslado',
      'col': 'Costo de vida',
      'total': 'Comp. total',
    };
    return (isEs ? es : en)[key] ?? key;
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isEs, __) {
        final comp = _compJson;
        return Scaffold(
          appBar: AppBar(
            title: Text(_isComparison
                ? (isEs ? 'Comparación guardada' : 'Saved Comparison')
                : (isEs ? 'Detalle de Oferta' : 'Offer Detail')),
            leading: const BackButton(),
          ),
          body: comp != null
              ? _ComparisonBody(
                  comp: comp,
                  row: widget.row,
                  isEs: isEs,
                  exporting: _exporting,
                  onExport: () => _exportPdf(isEs),
                )
              : _LegacyBody(
                  row: widget.row,
                  isEs: isEs,
                  exporting: _exporting,
                  onExport: () => _exportPdf(isEs),
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Full comparison body
// ═══════════════════════════════════════════════════════════════════════════════

class _ComparisonBody extends StatelessWidget {
  final Map<String, dynamic> comp;
  final Map<String, dynamic> row;
  final bool isEs;
  final bool exporting;
  final VoidCallback onExport;

  const _ComparisonBody({
    required this.comp,
    required this.row,
    required this.isEs,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final pctFmt = NumberFormat('0.0#', 'en_US');
    final dateFmt = DateFormat('MMM d, yyyy – HH:mm');
    final ct = CalcwiseTheme.of(context);

    final offers = (comp['offers'] as List).cast<Map<String, dynamic>>();
    final winner = comp['winner'] as String? ?? 'tie';
    final advantage = (comp['advantage'] as num?)?.toDouble() ?? 0;
    final categories = (comp['categories'] as Map<String, dynamic>? ?? {});
    final isTie = winner == 'tie';
    final winnerIdx = _HistoryDetailScreenState._winnerLetterToIndex(winner);
    final createdAt =
        DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.now();

    final isPremium = freemiumService.hasFullAccess;

    // Offer colors
    const offerColors = [AppTheme.primary, Color(0xFF0891B2), AppTheme.offerC];

    String amt(dynamic v) =>
        AmountFormatter.ui((v as num?)?.toDouble() ?? 0, 'USD');
    String pct(dynamic v) =>
        '${pctFmt.format((v as num?)?.toDouble() ?? 0)}%';

    int catWinner(String key) {
      final v = categories[key] as String?;
      return _HistoryDetailScreenState._winnerLetterToIndex(v ?? '');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Winner banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isTie
                          ? (isEs ? 'Empate' : 'Tie')
                          : '${offers[winnerIdx.clamp(0, offers.length - 1)]['label'] ?? 'Offer $winner'} ${isEs ? 'gana' : 'wins'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.subtitleSm,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
                if (!isTie) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '+${AmountFormatter.ui(advantage, 'USD')} ${isEs ? "ventaja/año" : "advantage/yr"}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: AppTextSize.md),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${isEs ? "Guardado" : "Saved"}: ${dateFmt.format(createdAt)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: AppTextSize.xs),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Offer summary cards ────────────────────────────────────────────
          Row(children: [
            for (var i = 0; i < offers.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _OfferSummaryCard(
                  offer: offers[i],
                  color: offerColors[i.clamp(0, 2)],
                  isWinner: i == winnerIdx,
                  isEs: isEs,
                  ct: ct,
                ),
              ),
            ],
          ]),
          const SizedBox(height: AppSpacing.lg),

          // ── Income breakdown ───────────────────────────────────────────────
          _SectionCard(
            title: isEs ? 'Ingresos' : 'Income',
            icon: Icons.attach_money_rounded,
            ct: ct,
            children: [
              _CompRow(isEs ? 'Salario bruto' : 'Gross Salary',
                  [for (var o in offers) amt(o['base'])],
                  bold: true, ct: ct),
              _CompRow(isEs ? 'Neto anual' : 'Annual Net Take-Home',
                  [for (var o in offers) amt(o['net'])],
                  bold: true, winnerIdx: winnerIdx, ct: ct),
              _CompRow(isEs ? 'Neto mensual' : 'Monthly Net',
                  [for (var o in offers) amt(o['monthly'])],
                  ct: ct),
              _CompRow(isEs ? 'Comp. total neta' : 'Total Net Comp.',
                  [for (var o in offers) amt(o['total_comp'])],
                  bold: true,
                  winnerIdx: catWinner('total'),
                  ct: ct),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tax breakdown ──────────────────────────────────────────────────
          _SectionCard(
            title: isEs ? 'Impuestos' : 'Taxes',
            icon: Icons.account_balance_rounded,
            ct: ct,
            children: [
              _CompRow(isEs ? 'Tasa efectiva' : 'Effective Rate',
                  [for (var o in offers) pct(o['tax_rate'])],
                  ct: ct),
              _CompRow(isEs ? 'Federal' : 'Federal Tax',
                  [for (var o in offers) amt(o['federal'])],
                  ct: ct),
              _CompRow(isEs ? 'Estatal' : 'State Tax',
                  [for (var o in offers) amt(o['state_tax'])],
                  ct: ct),
              _CompRow('FICA',
                  [for (var o in offers) amt(o['fica'])],
                  ct: ct),
              _CompRow(isEs ? 'Total impuestos' : 'Total Taxes',
                  [for (var o in offers) amt(o['total_tax'])],
                  bold: true, ct: ct),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Bonuses ───────────────────────────────────────────────────────
          _SectionCard(
            title: isEs ? 'Bonos' : 'Bonuses',
            icon: Icons.stars_rounded,
            ct: ct,
            children: [
              _CompRow(isEs ? 'Bono anual (bruto)' : 'Annual Bonus (gross)',
                  [for (var o in offers) amt(o['annual_bonus'])],
                  winnerIdx: catWinner('bonus'), ct: ct),
              _CompRow(isEs ? 'Bono anual (neto)' : 'Annual Bonus (after tax)',
                  [for (var o in offers) amt(o['bonus_net'])],
                  ct: ct),
              if (offers.any(
                  (o) => ((o['signing'] as num?) ?? 0) > 0))
                _CompRow(
                    isEs
                        ? 'Bono contratación (neto)'
                        : 'Signing Bonus (after tax)',
                    [for (var o in offers) amt(o['signing_net'])],
                    ct: ct),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Benefits ──────────────────────────────────────────────────────
          _SectionCard(
            title: isEs ? 'Beneficios' : 'Benefits',
            icon: Icons.health_and_safety_rounded,
            ct: ct,
            children: [
              _CompRow(isEs ? 'Match 401k' : '401k Employer Match',
                  [for (var o in offers) amt(o['k401k_match_usd'])],
                  ct: ct),
              _CompRow(isEs ? 'Salud / Dental' : 'Health & Dental',
                  [for (var o in offers) amt(o['health'])],
                  winnerIdx: catWinner('benefits'), ct: ct),
              _CompRow('RSU / Equity',
                  [for (var o in offers) amt(o['rsu_value'])],
                  winnerIdx: catWinner('rsu'), ct: ct),
              _CompRow('PTO (${isEs ? "valor" : "value"})',
                  [for (var o in offers) amt(o['pto_value'])],
                  winnerIdx: catWinner('pto'), ct: ct),
              if (offers.any(
                  (o) => ((o['commute_miles'] as num?) ?? 0) > 0))
                _CompRow(
                    isEs ? 'Costo traslado' : 'Commute Cost',
                    [for (var o in offers) amt(o['commute_cost'])],
                    ct: ct),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Cost of living ─────────────────────────────────────────────────
          _SectionCard(
            title: isEs ? 'Poder adquisitivo' : 'Purchasing Power',
            icon: Icons.location_city_rounded,
            ct: ct,
            children: [
              _CompRow(
                  isEs
                      ? 'Neto ajustado (costo de vida)'
                      : 'CoL-Adjusted Take-Home',
                  [for (var o in offers) amt(o['col_adj'])],
                  bold: true,
                  winnerIdx: catWinner('col'),
                  ct: ct),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── 5-year projection (premium) ────────────────────────────────────
          if (isPremium &&
              offers.isNotEmpty &&
              (offers[0]['5yr'] as List?)?.isNotEmpty == true) ...[
            _SectionCard(
              title: isEs ? 'Proyección 5 años' : '5-Year Projection',
              icon: Icons.trending_up_rounded,
              ct: ct,
              children: [
                for (var yr = 0; yr < 5; yr++)
                  _CompRow(
                      '${isEs ? "Año" : "Year"} ${yr + 1}',
                      [
                        for (var o in offers)
                          amt((o['5yr'] as List?)?.elementAtOrNull(yr) ?? 0)
                      ],
                      ct: ct),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Category winners ───────────────────────────────────────────────
          if (categories.isNotEmpty) ...[
            _CategoryWinnersCard(
              categories: categories,
              offers: offers,
              isEs: isEs,
              ct: ct,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Export PDF button ──────────────────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: freemiumService.hasFullAccessNotifier,
            builder: (_, isPrem, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: exporting
                        ? null
                        : () {
                            if (!isPrem) {
                              PaywallHard.show(context);
                              return;
                            }
                            onExport();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPrem ? AppTheme.primary : ct.surfaceHigh,
                      foregroundColor:
                          isPrem ? Colors.white : ct.textSecondary,
                      disabledBackgroundColor:
                          AppTheme.primary.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      side: isPrem
                          ? BorderSide.none
                          : BorderSide(color: ct.cardBorder),
                    ),
                    icon: exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            isPrem
                                ? Icons.picture_as_pdf_rounded
                                : Icons.lock_rounded,
                            size: 20),
                    label: Text(
                      exporting
                          ? (isEs ? 'Generando...' : 'Generating...')
                          : isPrem
                              ? (isEs
                                  ? 'Exportar reporte completo PDF'
                                  : 'Export Full PDF Report')
                              : (isEs
                                  ? 'PDF detallado — Premium'
                                  : 'Detailed PDF — Premium'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.md),
                    ),
                  ),
                ),
                if (!isPrem) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isEs
                        ? '5 páginas · Impuestos · Beneficios · Proyección 5 años'
                        : '5 pages · Taxes · Benefits · 5-Year Projection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: ct.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const CalcwiseAdFooter(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Offer summary mini-card ──────────────────────────────────────────────────

class _OfferSummaryCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Color color;
  final bool isWinner;
  final bool isEs;
  final CalcwiseTheme ct;

  const _OfferSummaryCard({
    required this.offer,
    required this.color,
    required this.isWinner,
    required this.isEs,
    required this.ct,
  });

  @override
  Widget build(BuildContext context) {
    final label = offer['label'] as String? ?? 'Offer';
    final company = offer['company'] as String? ?? '';
    final net = (offer['net'] as num?)?.toDouble() ?? 0;
    final taxRate = (offer['tax_rate'] as num?)?.toDouble() ?? 0;
    final pctFmt = NumberFormat('0.0#', 'en_US');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
            color: isWinner
                ? color.withValues(alpha: 0.6)
                : ct.cardBorder,
            width: isWinner ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isWinner)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Text('🏆 ${isEs ? "Ganador" : "Winner"}',
                style: TextStyle(
                    color: color,
                    fontSize: AppTextSize.xs,
                    fontWeight: FontWeight.w700)),
          ),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (company.isNotEmpty)
          Text(company,
              style: TextStyle(
                  fontSize: AppTextSize.xs, color: ct.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(AmountFormatter.ui(net, 'USD'),
              style: TextStyle(
                  color: color,
                  fontSize: AppTextSize.display,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ),
        Text(
            '${isEs ? "neto/año" : "net/yr"} · ${pctFmt.format(taxRate)}% ${isEs ? "imp." : "tax"}',
            style: TextStyle(
                fontSize: AppTextSize.xs, color: ct.textSecondary)),
      ]),
    );
  }
}

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final CalcwiseTheme ct;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.ct,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: ct.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Row(children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(title,
                style: const TextStyle(
                    fontSize: AppTextSize.md, fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: ct.cardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: Column(children: children),
        ),
      ]),
    );
  }
}

// ── Comparison row ────────────────────────────────────────────────────────────

class _CompRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final bool bold;
  final int winnerIdx; // -1 = no winner highlight
  final CalcwiseTheme ct;

  const _CompRow(
    this.label,
    this.values, {
    this.bold = false,
    this.winnerIdx = -1,
    required this.ct,
  });

  @override
  Widget build(BuildContext context) {
    const colors = [AppTheme.primary, Color(0xFF0891B2), AppTheme.offerC];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(label,
              style:
                  TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
        ),
        for (var i = 0; i < values.length; i++) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Text(
              values[i],
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: (bold || i == winnerIdx)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: i == winnerIdx
                      ? colors[i.clamp(0, 2)]
                      : ct.textPrimary),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Category winners card ─────────────────────────────────────────────────────

class _CategoryWinnersCard extends StatelessWidget {
  final Map<String, dynamic> categories;
  final List<Map<String, dynamic>> offers;
  final bool isEs;
  final CalcwiseTheme ct;

  const _CategoryWinnersCard({
    required this.categories,
    required this.offers,
    required this.isEs,
    required this.ct,
  });

  @override
  Widget build(BuildContext context) {
    const colors = [AppTheme.primary, Color(0xFF0891B2), AppTheme.offerC];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: ct.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(isEs ? 'Ganadores por categoría' : 'Category Winners',
                style: const TextStyle(
                    fontSize: AppTextSize.md, fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: ct.cardBorder),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: categories.entries.map((e) {
              final idx =
                  _HistoryDetailScreenState._winnerLetterToIndex(e.value as String);
              final isTie = idx < 0;
              final color =
                  isTie ? ct.textSecondary : colors[idx.clamp(0, 2)];
              final winLabel = isTie
                  ? (isEs ? 'Empate' : 'Tie')
                  : (offers.elementAtOrNull(idx)?['label'] as String? ??
                      'Offer ${e.value}');
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.smPlus, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_HistoryDetailScreenState._categoryLabel(e.key, isEs)}: $winLabel',
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Legacy single-offer body (backward compat with old DB rows)
// ═══════════════════════════════════════════════════════════════════════════════

class _LegacyBody extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isEs;
  final bool exporting;
  final VoidCallback onExport;

  const _LegacyBody({
    required this.row,
    required this.isEs,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final pctFmt = NumberFormat('0.0#', 'en_US');
    final dateFmt = DateFormat('MMM d, yyyy – HH:mm');
    final ct = CalcwiseTheme.of(context);

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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CalcwiseHeroCard(
          label: isEs ? 'Neto anual' : 'Annual net take-home',
          value: AmountFormatter.ui(netSalary, 'USD'),
          secondary: isEs
              ? '${AmountFormatter.ui(monthlyNet, 'USD')}/mes · Imp. ${pctFmt.format(taxRate)}%'
              : '${AmountFormatter.ui(monthlyNet, 'USD')}/mo · Tax ${pctFmt.format(taxRate)}%',
          backgroundColor: AppTheme.primary,
          stats: [
            (label: isEs ? 'Empresa' : 'Company', value: company.isNotEmpty ? company : '—'),
            (label: isEs ? 'Ciudad' : 'City', value: location.isNotEmpty ? location : '—'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _DetailCard(title: isEs ? 'Compensación' : 'Compensation', rows: [
          _RowData(isEs ? 'Salario bruto' : 'Gross Salary', AmountFormatter.ui(salary, 'USD')),
          _RowData(isEs ? 'Ingreso neto anual' : 'Net Annual', AmountFormatter.ui(netSalary, 'USD')),
          _RowData(isEs ? 'Ingreso neto mensual' : 'Net Monthly', AmountFormatter.ui(monthlyNet, 'USD')),
          _RowData(isEs ? 'Tasa efectiva' : 'Effective Tax Rate', '${pctFmt.format(taxRate)}%'),
        ]),
        const SizedBox(height: AppSpacing.md),
        _DetailCard(title: isEs ? 'Beneficios y Extras' : 'Benefits & Extras', rows: [
          if (bonus > 0) _RowData(isEs ? 'Bono anual' : 'Annual Bonus', AmountFormatter.ui(bonus, 'USD')),
          if (benefits > 0) _RowData(isEs ? 'Beneficios salud' : 'Health Benefits', AmountFormatter.ui(benefits, 'USD')),
          if (stockOptions > 0) _RowData('RSU / Stock', AmountFormatter.ui(stockOptions, 'USD')),
          if (pto > 0) _RowData(isEs ? 'Días PTO' : 'PTO Days', '$pto ${isEs ? "días" : "days"}'),
        ]),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('${isEs ? "Guardado" : "Saved"}: ${dateFmt.format(createdAt)}',
              style: TextStyle(fontSize: AppTextSize.xs, color: ct.textSecondary)),
        ),
        const SizedBox(height: AppSpacing.xl),
        ValueListenableBuilder<bool>(
          valueListenable: freemiumService.hasFullAccessNotifier,
          builder: (context, isPremium, __) => Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: exporting
                      ? null
                      : () {
                          if (!isPremium) {
                            PaywallHard.show(context);
                            return;
                          }
                          onExport();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPremium
                        ? AppTheme.primary
                        : ct.surfaceHigh,
                    foregroundColor: isPremium
                        ? Colors.white
                        : ct.textSecondary,
                    disabledBackgroundColor:
                        AppTheme.primary.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl)),
                    side: isPremium
                        ? BorderSide.none
                        : BorderSide(color: ct.cardBorder),
                  ),
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isPremium
                              ? Icons.picture_as_pdf_rounded
                              : Icons.lock_rounded,
                          size: 20),
                  label: Text(
                    exporting
                        ? (isEs ? 'Generando...' : 'Generating...')
                        : (isEs ? 'Exportar PDF' : 'Export PDF'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextSize.md),
                  ),
                ),
              ),
              if (!isPremium) const CalcwiseAdFooter(),
            ],
          ),
        ),
        if (freemiumService.hasFullAccess) ...[
          const SizedBox(height: AppSpacing.lg),
          const CalcwiseAdFooter(),
        ],
      ]),
    );
  }
}

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
          child: Text(title,
              style: const TextStyle(fontSize: AppTextSize.md, fontWeight: FontWeight.w700)),
        ),
        Divider(height: 1, color: ct.cardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: Column(children: rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.label,
                  style: TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
              Text(r.value,
                  style: const TextStyle(fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
            ]),
          )).toList()),
        ),
      ]),
    );
  }
}
