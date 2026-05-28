import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/db/database_helper.dart';
import '../core/engines/insight_engine.dart';
import '../core/freemium/iap_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/services/analytics_service.dart';
import '../core/language/language_notifier.dart';
import '../core/models/comparison_result.dart';
import '../core/models/job_offer.dart';
import '../core/theme/app_theme.dart';
import '../widgets/comparison_bar.dart';
import '../widgets/insight_card.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../main.dart' show adService;
import 'history_screen.dart';
import '../core/engines/offer_engine.dart' show OfferEngine;

class ComparisonScreen extends StatefulWidget {
  final JobOffer offerA;
  final JobOffer offerB;
  final JobOffer? offerC;
  final ComparisonResult result;

  const ComparisonScreen({
    super.key,
    required this.offerA,
    required this.offerB,
    this.offerC,
    required this.result,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _saved = false;

  Future<void> _onExportCsv(bool isSpanish) async {
    HapticFeedback.mediumImpact();
    if (!freemiumService.isPremium) {
      _showPaywall(context, isSpanish);
      return;
    }
    try {
      final pctFmt = NumberFormat('0.0#', 'en_US');
      final a = widget.result.resultA;
      final b = widget.result.resultB;
      final labelA =
          widget.offerA.label.isNotEmpty ? widget.offerA.label : 'Offer A';
      final labelB =
          widget.offerB.label.isNotEmpty ? widget.offerB.label : 'Offer B';

      final rows = [
        [isSpanish ? 'Campo' : 'Field', labelA, labelB],
        [
          isSpanish ? 'Empresa' : 'Company',
          widget.offerA.company,
          widget.offerB.company
        ],
        [isSpanish ? 'Ciudad' : 'City', widget.offerA.city, widget.offerB.city],
        [
          isSpanish ? 'Estado' : 'State',
          widget.offerA.stateCode,
          widget.offerB.stateCode
        ],
        [
          isSpanish ? 'Salario bruto' : 'Gross Salary',
          AmountFormatter.ui(a.grossSalary, 'USD'),
          AmountFormatter.ui(b.grossSalary, 'USD')
        ],
        [
          isSpanish ? 'Ingreso neto anual' : 'Net Annual Take-Home',
          AmountFormatter.ui(a.netTakeHome, 'USD'),
          AmountFormatter.ui(b.netTakeHome, 'USD')
        ],
        [
          isSpanish ? 'Ingreso neto mensual' : 'Net Monthly',
          AmountFormatter.ui(a.monthlyTakeHome, 'USD'),
          AmountFormatter.ui(b.monthlyTakeHome, 'USD')
        ],
        [
          isSpanish ? 'Tasa efectiva' : 'Effective Tax Rate',
          '${pctFmt.format(a.effectiveTaxRate)}%',
          '${pctFmt.format(b.effectiveTaxRate)}%'
        ],
        [
          isSpanish ? 'Impuesto federal' : 'Federal Tax',
          AmountFormatter.ui(a.federalTax, 'USD'),
          AmountFormatter.ui(b.federalTax, 'USD')
        ],
        [
          isSpanish ? 'Impuesto estatal' : 'State Tax',
          AmountFormatter.ui(a.stateTax, 'USD'),
          AmountFormatter.ui(b.stateTax, 'USD')
        ],
        ['FICA', AmountFormatter.ui(a.ficaTax, 'USD'), AmountFormatter.ui(b.ficaTax, 'USD')],
        [
          isSpanish ? 'Bono anual (neto)' : 'Annual Bonus (after tax)',
          AmountFormatter.ui(a.bonusAfterTax, 'USD'),
          AmountFormatter.ui(b.bonusAfterTax, 'USD')
        ],
        if (a.signingBonusAfterTax > 0 || b.signingBonusAfterTax > 0)
          [
            isSpanish
                ? 'Bono contratación (neto)'
                : 'Signing Bonus (after tax)',
            AmountFormatter.ui(a.signingBonusAfterTax, 'USD'),
            AmountFormatter.ui(b.signingBonusAfterTax, 'USD')
          ],
        [
          isSpanish ? 'Match 401k' : '401k Match',
          AmountFormatter.ui(a.k401kMatch, 'USD'),
          AmountFormatter.ui(b.k401kMatch, 'USD')
        ],
        [
          isSpanish ? 'Beneficios salud' : 'Health Benefits',
          AmountFormatter.ui(a.healthBenefits, 'USD'),
          AmountFormatter.ui(b.healthBenefits, 'USD')
        ],
        [
          isSpanish ? 'Valor PTO' : 'PTO Value',
          AmountFormatter.ui(a.ptoValue, 'USD'),
          AmountFormatter.ui(b.ptoValue, 'USD')
        ],
        [
          isSpanish ? 'RSU anual' : 'Annual RSU',
          AmountFormatter.ui(a.annualRsuValue, 'USD'),
          AmountFormatter.ui(b.annualRsuValue, 'USD')
        ],
        [
          isSpanish ? 'Costo traslado' : 'Commute Cost',
          AmountFormatter.ui(a.commuteCost, 'USD'),
          AmountFormatter.ui(b.commuteCost, 'USD')
        ],
        [
          isSpanish ? 'Compensación total neta' : 'Total Net Compensation',
          AmountFormatter.ui(a.totalCompensation, 'USD'),
          AmountFormatter.ui(b.totalCompensation, 'USD')
        ],
      ];

      final csv =
          rows.map((r) => r.map((cell) => '"$cell"').join(',')).join('\n');
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final filename =
          'job_comparison_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

      await Share.shareXFiles(
        [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
        subject: filename,
      );
      AnalyticsService.instance.logResultShared();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isSpanish ? 'Error al exportar CSV' : 'Failed to export CSV'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CalcwiseSemanticColors.errorDark,
          ),
        );
      }
    }
  }

  Future<void> _exportPdf(bool isSpanish) async {
    HapticFeedback.mediumImpact();
    try {
      await _exportPdfImpl(isSpanish);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSpanish ? 'PDF generado ✓' : 'PDF generated ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isSpanish ? 'Error al generar PDF' : 'Failed to export PDF'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: CalcwiseSemanticColors.errorDark,
          ),
        );
      }
    }
  }

  Future<void> _exportPdfImpl(bool isSpanish) async {
    final pctFmt = NumberFormat('0.0#', 'en_US');
    final a = widget.result.resultA;
    final b = widget.result.resultB;
    final winner = widget.result.winner;
    final winnerLabel = winner == Winner.offerA
        ? (isSpanish ? 'Oferta A gana' : 'Offer A wins')
        : winner == Winner.offerB
            ? (isSpanish ? 'Oferta B gana' : 'Offer B wins')
            : (isSpanish ? 'Empate' : 'Tie');
    final advantage = AmountFormatter.ui(widget.result.annualAdvantage, 'USD');

    final pdf = pw.Document();
    final primary = PdfColor.fromHex('1565C0');
    final grey = PdfColors.grey700;

    pw.TableRow row(String label, String valA, String valB,
            {bool bold = false}) =>
        pw.TableRow(children: [
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 10, color: grey))),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(valA,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(valB,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        ]);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(AppSpacing.xxxl),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
              isSpanish
                  ? 'Comparación de Ofertas de Trabajo'
                  : 'Job Offer Comparison',
              style: pw.TextStyle(
                  fontSize: AppTextSize.titleMd,
                  fontWeight: pw.FontWeight.bold,
                  color: primary)),
          pw.SizedBox(height: 4),
          pw.Text(
              '${isSpanish ? 'Generado' : 'Generated'}: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: grey)),
          pw.SizedBox(height: 16),
          // Winner banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('E3F2FD'),
              borderRadius: pw.BorderRadius.circular(AppRadius.sm),
            ),
            child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('★ $winnerLabel',
                      style: pw.TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: pw.FontWeight.bold,
                          color: primary)),
                  if (!widget.result.isTie)
                    pw.Text(
                        '+$advantage ${isSpanish ? "ventaja" : "advantage"}',
                        style: pw.TextStyle(
                            fontSize: AppTextSize.xs, color: primary)),
                ]),
          ),
          pw.SizedBox(height: 16),
          // Comparison table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primary),
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(isSpanish ? 'Métrica' : 'Metric',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(isSpanish ? 'Oferta A' : 'Offer A',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(isSpanish ? 'Oferta B' : 'Offer B',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold))),
                ],
              ),
              row(isSpanish ? 'Salario bruto' : 'Gross Salary',
                  AmountFormatter.ui(a.grossSalary, 'USD'), AmountFormatter.ui(b.grossSalary, 'USD'),
                  bold: true),
              row(isSpanish ? 'Ingreso neto anual' : 'Net Take-Home (Annual)',
                  AmountFormatter.ui(a.netTakeHome, 'USD'), AmountFormatter.ui(b.netTakeHome, 'USD'),
                  bold: true),
              row(isSpanish ? 'Ingreso neto mensual' : 'Net Monthly',
                  AmountFormatter.ui(a.monthlyTakeHome, 'USD'), AmountFormatter.ui(b.monthlyTakeHome, 'USD')),
              row(
                  isSpanish ? 'Tasa efectiva' : 'Effective Tax Rate',
                  '${pctFmt.format(a.effectiveTaxRate)}%',
                  '${pctFmt.format(b.effectiveTaxRate)}%'),
              row(isSpanish ? 'Bono anual (neto)' : 'Annual Bonus (after tax)',
                  AmountFormatter.ui(a.bonusAfterTax, 'USD'), AmountFormatter.ui(b.bonusAfterTax, 'USD')),
              if (a.signingBonusAfterTax > 0 || b.signingBonusAfterTax > 0)
                row(
                    isSpanish
                        ? 'Bono contratación (neto)'
                        : 'Signing Bonus (net)',
                    AmountFormatter.ui(a.signingBonusAfterTax, 'USD'),
                    AmountFormatter.ui(b.signingBonusAfterTax, 'USD')),
              row(isSpanish ? 'Match 401k' : '401k Match',
                  AmountFormatter.ui(a.k401kMatch, 'USD'), AmountFormatter.ui(b.k401kMatch, 'USD')),
              row(isSpanish ? 'Beneficios de salud' : 'Health Benefits',
                  AmountFormatter.ui(a.healthBenefits, 'USD'), AmountFormatter.ui(b.healthBenefits, 'USD')),
              row(isSpanish ? 'RSU anual' : 'Annual RSU',
                  AmountFormatter.ui(a.annualRsuValue, 'USD'), AmountFormatter.ui(b.annualRsuValue, 'USD')),
              row(isSpanish ? 'Costo de traslado' : 'Commute Cost',
                  AmountFormatter.ui(a.commuteCost, 'USD'), AmountFormatter.ui(b.commuteCost, 'USD')),
              row(
                  isSpanish ? 'Compensación total' : 'Total Compensation',
                  AmountFormatter.ui(a.totalCompensation, 'USD'),
                  AmountFormatter.ui(b.totalCompensation, 'USD'),
                  bold: true),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            isSpanish
                ? 'Nota: Este reporte es solo informativo. Consulte a un asesor fiscal.'
                : 'Disclaimer: This report is for informational purposes only. Consult a tax professional.',
            style: pw.TextStyle(
                fontSize: 8, color: grey, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    ));

    final pdfBytes = await pdf.save();
    final tmpDir = await getTemporaryDirectory();
    final pdfFile = File(
        '${tmpDir.path}/job_offer_comparison_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    await Share.shareXFiles(
        [XFile(pdfFile.path, mimeType: 'application/pdf')]);
    AnalyticsService.instance.logPdfExportedEvent();
    AnalyticsService.instance.logResultShared();
  }

  void _showExportSheet(BuildContext context, bool isSpanish, bool isPremium) {
    HapticFeedback.lightImpact();
    final ct = CalcwiseTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.of(context).padding.bottom + AppSpacing.lg),
        decoration: BoxDecoration(
          color: ct.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ct.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: AppSpacing.lg),
          Text(isSpanish ? 'Exportar' : 'Export',
              style: TextStyle(
                  fontSize: AppTextSize.subtitle,
                  fontWeight: FontWeight.w700,
                  color: ct.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          // CSV
          _ExportTile(
            icon: Icons.table_chart_outlined,
            label: isSpanish ? 'Exportar CSV' : 'Export CSV',
            subtitle: isSpanish
                ? 'Compatible con Excel y Sheets'
                : 'Open in Excel or Sheets',
            onTap: () {
              Navigator.pop(context);
              _onExportCsv(isSpanish);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // PDF
          _ExportTile(
            icon: Icons.picture_as_pdf_rounded,
            label: isSpanish ? 'Exportar PDF' : 'Export PDF',
            subtitle: isPremium
                ? (isSpanish ? 'Reporte completo' : 'Full report')
                : (isSpanish ? 'Premium — desbloquear' : 'Premium — unlock'),
            isPremium: !isPremium,
            onTap: () {
              Navigator.pop(context);
              if (isPremium)
                _exportPdf(isSpanish);
              else
                _showPaywall(context, isSpanish);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isSpanish ? 'Cancelar' : 'Cancel',
                style: TextStyle(color: ct.textSecondary)),
          ),
        ]),
      ),
    );
  }

  void _showPaywall(BuildContext context, bool isSpanish) {
    AnalyticsService.instance.logPaywallViewed('comparison_history_limit');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallHard(
        isSpanish: isSpanish,
        onPurchase: () async {
          Navigator.pop(context);
          AnalyticsService.instance
              .logPaywallConverted('comparison_history_limit');
          IAPService.instance.buy();
        },
        onDismiss: () {
          AnalyticsService.instance.logPaywallDismissed();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveToHistory(BuildContext context, bool isSpanish) async {
    final isPremium = freemiumService.isPremium;
    final limit = MonetizationConfig.freeCalculationLimit;

    if (!isPremium) {
      final count = await DatabaseHelper.instance.countHistory();
      if (count >= limit) {
        if (!context.mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PaywallSoft(
            featureTitle:
                isSpanish ? 'Historial ilimitado' : 'Unlimited history',
            featureSubtitle: isSpanish
                ? 'Guarda todas tus comparaciones sin límite'
                : 'Save all your comparisons without limit',
            isSpanish: isSpanish,
            onUnlock: () {
              Navigator.pop(context);
              _showPaywall(context, isSpanish);
            },
          ),
        );
        return;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final a = widget.result.resultA;
    final b = widget.result.resultB;
    final c = widget.result.resultC;
    final winner = widget.result.winner;
    final winnerResult = widget.result.winnerResult;
    final winnerOffer = winner == Winner.offerA
        ? widget.offerA
        : winner == Winner.offerC
            ? (widget.offerC ?? widget.offerA)
            : widget.offerB;

    // Build full comparison JSON
    Map<String, dynamic> offerJson(JobOffer o, OfferResult r) => {
          'label': o.label,
          'company': o.company,
          'city': o.city,
          'state': o.stateCode,
          'remote': o.isRemote,
          'base': o.baseSalary,
          'bonus_pct': o.bonusPct,
          'signing': o.signingBonus,
          'rsu': o.annualRsuValue,
          'pto': o.ptoDays,
          'k401k_match_pct': o.k401kMatchPct,
          'commute_miles': o.commuteMilesPerDay,
          'health_savings': o.healthInsuranceSavings + o.dentalVisionSavings,
          // computed
          'gross': r.grossSalary,
          'federal': r.federalTax,
          'state_tax': r.stateTax,
          'local_tax': r.localTax,
          'fica': r.ficaTax,
          'total_tax': r.totalTax,
          'tax_rate': r.effectiveTaxRate,
          'net': r.netTakeHome,
          'monthly': r.monthlyTakeHome,
          'bonus_net': r.bonusAfterTax,
          'annual_bonus': r.annualBonus,
          'signing_net': r.signingBonusAfterTax,
          'k401k_match_usd': r.k401kMatch,
          'health': r.healthBenefits,
          'pto_value': r.ptoValue,
          'rsu_value': r.annualRsuValue,
          'commute_cost': r.commuteCost,
          'total_comp': r.totalCompensation,
          'col_adj': r.colAdjustedTakeHome,
          '5yr': r.fiveYearProjection,
          'cumulative_5yr': r.cumulativeComp5Yr,
          'k401k_wealth_65': r.k401kWealthAt65,
          'net_wealth_5yr': r.netWealthAfter5Yrs,
        };

    final compJson = jsonEncode({
      'v': 2,
      'winner': winner == Winner.offerA
          ? 'A'
          : winner == Winner.offerB
              ? 'B'
              : winner == Winner.offerC
                  ? 'C'
                  : 'tie',
      'advantage': widget.result.annualAdvantage,
      'break_even_months': widget.result.breakEvenMonths,
      'offers': [
        offerJson(widget.offerA, a),
        offerJson(widget.offerB, b),
        if (widget.offerC != null && c != null)
          offerJson(widget.offerC!, c),
      ],
      'categories': widget.result.categoryWinners
          .map((k, v) => MapEntry(k, v.name)),
    });

    try {
      // Save ONE row per comparison (not two separate rows)
      await DatabaseHelper.instance.insertHistory({
        'job_title': '${widget.offerA.label} vs ${widget.offerB.label}'
            '${widget.offerC != null ? ' vs ${widget.offerC!.label}' : ''}',
        'company': winnerOffer.company,
        'location': winnerOffer.city,
        'salary': winnerOffer.baseSalary,
        'bonus': winnerResult.annualBonus,
        'benefits': winnerResult.healthBenefits,
        'stock_options': winnerResult.annualRsuValue,
        'relocation': 0.0,
        'pto': winnerOffer.ptoDays,
        'signing_bonus': winnerOffer.signingBonus,
        'net_salary': winnerResult.netTakeHome,
        'monthly_net': winnerResult.monthlyTakeHome,
        'tax_rate': winnerResult.effectiveTaxRate,
        'created_at': now,
        'comparison_json': compJson,
      });

      adService.onSave();
      AnalyticsService.instance.logResultSaved();
      HistoryScreen.refreshNotifier.value++;

      if (!context.mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSpanish ? 'Comparación guardada ✓' : 'Comparison saved ✓',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSpanish ? 'Error al guardar' : 'Failed to save'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: CalcwiseSemanticColors.errorDark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) => ValueListenableBuilder<bool>(
        valueListenable: freemiumService.hasFullAccessNotifier,
        builder: (_, isPremium, __) => Scaffold(
          appBar: AppBar(
            title: Text(
              '${widget.offerA.label} vs ${widget.offerB.label}${widget.offerC != null ? ' vs ${widget.offerC!.label}' : ''}',
              overflow: TextOverflow.ellipsis,
            ),
            leading: const BackButton(),
            actions: [
              IconButton(
                icon: Icon(
                  _saved ? Icons.bookmark_rounded : Icons.bookmark_add_rounded,
                  color: _saved ? AppTheme.primary : null,
                ),
                onPressed: _saved
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        _saveToHistory(context, isSpanish);
                      },
                tooltip: isSpanish ? 'Guardar' : 'Save',
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: isSpanish ? 'Exportar' : 'Export',
                onPressed: () =>
                    _showExportSheet(context, isSpanish, isPremium),
              ),
            ],
          ),
          body: Column(children: [
            Expanded(child: _buildBody(context, isSpanish, isPremium)),
            const CalcwiseAdFooter(),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isSpanish, bool isPremium) {
    final a = widget.result.resultA;
    final b = widget.result.resultB;
    final c = widget.result.resultC;
    final has3 = c != null;
    final insights =
        InsightEngine.generate(widget.result, isSpanish: isSpanish);

    // Helper: build a bar — 2-way or 3-way depending on offer C presence
    Widget bar({
      required String label,
      required double va,
      required double vb,
      double? vc,
      Winner? winner,
      String Function(double)? formatter,
    }) {
      if (has3) {
        return ThreeWayBar(
          label: label,
          valueA: va,
          valueB: vb,
          valueC: vc ?? 0,
          winner: winner,
          isSpanish: isSpanish,
          formatter: formatter,
        );
      }
      return ComparisonBar(
        label: label,
        valueA: va,
        valueB: vb,
        winner: winner,
        isSpanish: isSpanish,
        formatter: formatter,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Winner banner ──────────────────────────────────────────────
          WinnerBanner(result: widget.result, isSpanish: isSpanish),
          const SizedBox(height: AppSpacing.lg),

          // ── Hero KPI card ──────────────────────────────────────────────
          _HeroKpiCard(
              result: widget.result,
              offerC: widget.offerC,
              isSpanish: isSpanish),
          const SizedBox(height: AppSpacing.lg),

          // ── Offer labels header ────────────────────────────────────────
          _OfferHeader(
            labelA: widget.offerA.label.isNotEmpty
                ? widget.offerA.label
                : (isSpanish ? 'Oferta A' : 'Offer A'),
            labelB: widget.offerB.label.isNotEmpty
                ? widget.offerB.label
                : (isSpanish ? 'Oferta B' : 'Offer B'),
            companyA: widget.offerA.company,
            companyB: widget.offerB.company,
            labelC: has3
                ? (widget.offerC!.label.isNotEmpty
                    ? widget.offerC!.label
                    : (isSpanish ? 'Oferta C' : 'Offer C'))
                : null,
            companyC: has3 ? widget.offerC!.company : null,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Core comparison card ───────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Salario Neto' : 'After-Tax Income',
            children: [
              bar(
                label: isSpanish ? 'Salario neto anual' : 'Annual take-home',
                va: a.netTakeHome,
                vb: b.netTakeHome,
                vc: c?.netTakeHome,
                winner: widget.result.categoryWinners['takeHome'],
              ),
              bar(
                label: isSpanish ? 'Mensual' : 'Monthly',
                va: a.monthlyTakeHome,
                vb: b.monthlyTakeHome,
                vc: c?.monthlyTakeHome,
                winner: widget.result.categoryWinners['takeHome'],
              ),
              bar(
                label: isSpanish
                    ? 'Tasa impositiva efectiva'
                    : 'Effective tax rate',
                va: a.effectiveTaxRate,
                vb: b.effectiveTaxRate,
                vc: c?.effectiveTaxRate,
                winner: widget.result.categoryWinners['takeHome'],
                formatter: (v) => '${v.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tax breakdown ──────────────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Desglose de Impuestos' : 'Tax Breakdown',
            children: [
              bar(
                label: isSpanish ? 'Impuesto federal' : 'Federal tax',
                va: a.federalTax,
                vb: b.federalTax,
                vc: c?.federalTax,
              ),
              bar(
                label: isSpanish ? 'Impuesto estatal' : 'State tax',
                va: a.stateTax,
                vb: b.stateTax,
                vc: c?.stateTax,
              ),
              if (a.localTax > 0 || b.localTax > 0 || (c?.localTax ?? 0) > 0)
                bar(
                  label: isSpanish ? 'Impuesto ciudad' : 'City/local tax',
                  va: a.localTax,
                  vb: b.localTax,
                  vc: c?.localTax,
                ),
              bar(
                label: 'FICA (SS + Medicare)',
                va: a.ficaTax,
                vb: b.ficaTax,
                vc: c?.ficaTax,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Benefits & extras ──────────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Beneficios y Extras' : 'Benefits & Extras',
            children: [
              if (a.annualBonus > 0 ||
                  b.annualBonus > 0 ||
                  (c?.annualBonus ?? 0) > 0)
                bar(
                  label: isSpanish
                      ? 'Bono neto anual'
                      : 'Annual bonus (after tax)',
                  va: a.bonusAfterTax,
                  vb: b.bonusAfterTax,
                  vc: c?.bonusAfterTax,
                  winner: widget.result.categoryWinners['bonus'],
                ),
              if (a.signingBonusAfterTax > 0 ||
                  b.signingBonusAfterTax > 0 ||
                  (c?.signingBonusAfterTax ?? 0) > 0)
                bar(
                  label: isSpanish
                      ? 'Bono de contratación (neto)'
                      : 'Signing bonus (after tax)',
                  va: a.signingBonusAfterTax,
                  vb: b.signingBonusAfterTax,
                  vc: c?.signingBonusAfterTax,
                ),
              if (a.k401kMatch > 0 ||
                  b.k401kMatch > 0 ||
                  (c?.k401kMatch ?? 0) > 0)
                bar(
                  label: isSpanish
                      ? '401k (aporte empleador)'
                      : '401k employer match',
                  va: a.k401kMatch,
                  vb: b.k401kMatch,
                  vc: c?.k401kMatch,
                  winner: widget.result.categoryWinners['benefits'],
                ),
              if (a.healthBenefits > 0 ||
                  b.healthBenefits > 0 ||
                  (c?.healthBenefits ?? 0) > 0)
                bar(
                  label: isSpanish ? 'Salud + dental' : 'Health + dental',
                  va: a.healthBenefits,
                  vb: b.healthBenefits,
                  vc: c?.healthBenefits,
                  winner: widget.result.categoryWinners['benefits'],
                ),
              if (a.ptoValue > 0 || b.ptoValue > 0 || (c?.ptoValue ?? 0) > 0)
                bar(
                  label: isSpanish ? 'Valor vacaciones (PTO)' : 'PTO value',
                  va: a.ptoValue,
                  vb: b.ptoValue,
                  vc: c?.ptoValue,
                  winner: widget.result.categoryWinners['pto'],
                ),
              if (a.annualRsuValue > 0 ||
                  b.annualRsuValue > 0 ||
                  (c?.annualRsuValue ?? 0) > 0)
                bar(
                  label: isSpanish ? 'RSU / Stock anual' : 'Annual RSU / Stock',
                  va: a.annualRsuValue,
                  vb: b.annualRsuValue,
                  vc: c?.annualRsuValue,
                  winner: widget.result.categoryWinners['rsu'],
                ),
              if (a.commuteCost > 0 ||
                  b.commuteCost > 0 ||
                  (c?.commuteCost ?? 0) > 0)
                bar(
                  label:
                      isSpanish ? 'Costo transporte (−)' : 'Commute cost (−)',
                  va: a.commuteCost,
                  vb: b.commuteCost,
                  vc: c?.commuteCost,
                  winner: widget.result.categoryWinners['commute'],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── RSU Vesting Schedule ───────────────────────────────────────
          if (a.annualRsuValue > 0 ||
              b.annualRsuValue > 0 ||
              (c?.annualRsuValue ?? 0) > 0) ...[
            _RsuVestingCard(
              offerA: widget.offerA,
              offerB: widget.offerB,
              offerC: widget.offerC,
              resultA: a,
              resultB: b,
              isSpanish: isSpanish,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Total compensation ─────────────────────────────────────────
          _SectionCard(
            title: isSpanish
                ? 'Compensación Total Neta'
                : 'Net Total Compensation',
            highlight: true,
            children: [
              bar(
                label: isSpanish ? 'Total anual neto' : 'Total annual net',
                va: a.totalCompensation,
                vb: b.totalCompensation,
                vc: c?.totalCompensation,
                winner: widget.result.categoryWinners['total'],
              ),
              bar(
                label: isSpanish ? 'Total mensual neto' : 'Total monthly net',
                va: a.monthlyTotalComp,
                vb: b.monthlyTotalComp,
                vc: c?.monthlyTotalComp,
                winner: widget.result.categoryWinners['total'],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── CoL-adjusted (Premium) ─────────────────────────────────────
          if (isPremium) ...[
            _SectionCard(
              title: isSpanish
                  ? 'Poder Adquisitivo Real'
                  : 'Real Purchasing Power (CoL-adjusted)',
              children: [
                bar(
                  label: isSpanish
                      ? 'Salario ajustado por costo de vida'
                      : 'CoL-adjusted take-home',
                  va: a.colAdjustedTakeHome,
                  vb: b.colAdjustedTakeHome,
                  vc: c?.colAdjustedTakeHome,
                  winner: widget.result.categoryWinners['col'],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            PaywallSoft(
              featureTitle: isSpanish
                  ? 'Poder adquisitivo real por ciudad'
                  : 'Real purchasing power by city',
              featureSubtitle: isSpanish
                  ? '\$100k en NYC ≠ \$100k en Dallas'
                  : '\$100k in NYC ≠ \$100k in Dallas',
              isSpanish: isSpanish,
              onUnlock: () => _showPaywall(context, isSpanish),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Premium wealth analysis ────────────────────────────────────
          if (isPremium) ...[
            // 5-year projection
            if (a.fiveYearProjection.isNotEmpty) ...[
              _ProjectionCard(
                resultA: a,
                resultB: b,
                labelA: widget.offerA.label,
                labelB: widget.offerB.label,
                isSpanish: isSpanish,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Break-even
            if (widget.result.breakEvenMonths != null) ...[
              _BreakEvenCard(
                result: widget.result,
                offerA: widget.offerA,
                offerB: widget.offerB,
                isSpanish: isSpanish,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Wealth building
            _WealthBuildingCard(
              resultA: a,
              resultB: b,
              labelA: widget.offerA.label,
              labelB: widget.offerB.label,
              isSpanish: isSpanish,
            ),
            const SizedBox(height: AppSpacing.md),
          ] else ...[
            PaywallSoft(
              featureTitle: isSpanish
                  ? 'Análisis de riqueza a largo plazo'
                  : 'Long-term wealth analysis',
              featureSubtitle: isSpanish
                  ? 'Proyección 5 años · 401k a jubilación · Riqueza neta · Punto de equilibrio'
                  : '5-year projection · 401k at retirement · Net wealth · Break-even',
              isSpanish: isSpanish,
              onUnlock: () => _showPaywall(context, isSpanish),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Smart insights ─────────────────────────────────────────────
          InsightCard(insights: insights, isSpanish: isSpanish),
          const SizedBox(height: AppSpacing.md),

          // ── Negotiation Tips (only for 2-way) ──────────────────────────
          if (!widget.result.isTie && !has3)
            _NegotiationTipsCard(result: widget.result, isSpanish: isSpanish),
          if (!widget.result.isTie && !has3)
            const SizedBox(height: AppSpacing.md),

          // ── Share / PDF CTA ────────────────────────────────────────────
          if (isPremium)
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _exportPdf(isSpanish);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                  isSpanish ? 'Exportar reporte PDF' : 'Export PDF Report'),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeroKpiCard extends StatelessWidget {
  final ComparisonResult result;
  final JobOffer? offerC;
  final bool isSpanish;

  const _HeroKpiCard(
      {required this.result, this.offerC, required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    final a = result.resultA;
    final b = result.resultB;

    final String heroLabel;
    final String heroValue;
    final String heroSecondary;
    final String statLabelA;
    final String statLabelB;

    if (result.isTie) {
      heroLabel = isSpanish ? 'Compensación total' : 'Total Compensation';
      heroValue = AmountFormatter.ui(a.totalCompensation, 'USD');
      heroSecondary = isSpanish
          ? 'Las dos ofertas son equivalentes'
          : 'Both offers are equivalent';
      statLabelA = isSpanish ? 'Neto anual A' : 'Annual net A';
      statLabelB = isSpanish ? 'Neto anual B' : 'Annual net B';
    } else {
      final isAWinner = result.winner == Winner.offerA;
      final isCWinner = result.winner == Winner.offerC;
      final winnerResult = result.winnerResult;
      final String winnerLabel;
      if (isCWinner) {
        winnerLabel = isSpanish ? 'Oferta C' : 'Offer C';
      } else {
        winnerLabel = isAWinner
            ? (isSpanish ? 'Oferta A' : 'Offer A')
            : (isSpanish ? 'Oferta B' : 'Offer B');
      }
      final bgColor = isCWinner
          ? AppTheme.offerCDeep
          : (isAWinner ? AppTheme.offerADeep : AppTheme.offerBDeep);
      heroLabel =
          isSpanish ? '$winnerLabel — Neto anual' : '$winnerLabel — Annual Net';
      heroValue = AmountFormatter.ui(winnerResult.netTakeHome, 'USD');
      heroSecondary = isSpanish
          ? 'Ventaja: ${AmountFormatter.ui(result.annualAdvantage, 'USD')}/año'
          : 'Advantage: ${AmountFormatter.ui(result.annualAdvantage, 'USD')}/yr';
      statLabelA = isSpanish ? 'Tasa efectiva' : 'Effective rate';
      statLabelB = isSpanish ? 'Comp. total' : 'Total comp';

      return Semantics(
        label: isSpanish
            ? '$winnerLabel gana con ${AmountFormatter.ui(winnerResult.netTakeHome, 'USD')} neto anual, ventaja de ${AmountFormatter.ui(result.annualAdvantage, 'USD')}'
            : '$winnerLabel wins with ${AmountFormatter.ui(winnerResult.netTakeHome, 'USD')} annual net, advantage of ${AmountFormatter.ui(result.annualAdvantage, 'USD')}',
        child: CalcwiseHeroCard(
          label: heroLabel,
          value: heroValue,
          secondary: heroSecondary,
          backgroundColor: bgColor,
          stats: [
            (
              label: statLabelA,
              value: '${winnerResult.effectiveTaxRate.toStringAsFixed(1)}%',
            ),
            (
              label: statLabelB,
              value: AmountFormatter.ui(winnerResult.totalCompensation, 'USD'),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: isSpanish
          ? 'Las dos ofertas son equivalentes. Compensación total: ${AmountFormatter.ui(a.totalCompensation, 'USD')}'
          : 'Both offers are equivalent. Total compensation: ${AmountFormatter.ui(a.totalCompensation, 'USD')}',
      child: CalcwiseHeroCard(
        label: heroLabel,
        value: heroValue,
        secondary: heroSecondary,
        backgroundColor: AppTheme.primary,
        stats: [
          (
            label: statLabelA,
            value: AmountFormatter.ui(a.netTakeHome, 'USD'),
          ),
          (
            label: statLabelB,
            value: AmountFormatter.ui(b.netTakeHome, 'USD'),
          ),
        ],
      ),
    );
  }
}

class _OfferHeader extends StatelessWidget {
  final String labelA, labelB, companyA, companyB;
  final String? labelC, companyC;
  const _OfferHeader({
    required this.labelA,
    required this.labelB,
    required this.companyA,
    required this.companyB,
    this.labelC,
    this.companyC,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _OfferChip(label: labelA, company: companyA, isA: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _OfferChip(label: labelB, company: companyB, isA: false)),
      if (labelC != null) ...[
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: _OfferChip(
                label: labelC!,
                company: companyC ?? '',
                isA: false,
                isC: true)),
      ],
    ]);
  }
}

class _OfferChip extends StatelessWidget {
  final String label, company;
  final bool isA;
  final bool isC;
  const _OfferChip(
      {required this.label,
      required this.company,
      required this.isA,
      this.isC = false});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bgColor;
    final String letter;
    if (isC) {
      color = AppTheme.offerC;
      bgColor = AppTheme.offerCDeep.withValues(alpha: 0.15);
      letter = 'C';
    } else {
      color = AppTheme.offerColor(isA);
      bgColor = AppTheme.offerColorLight(isA);
      letter = isA ? 'A' : 'B';
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.smPlus),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
              child: Text(letter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w700,
                    color: color)),
            if (company.isNotEmpty)
              Text(company,
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: CalcwiseTheme.of(context).textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool highlight;
  const _SectionCard({
    required this.title,
    required this.children,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: highlight
              ? AppTheme.primary.withValues(alpha: 0.4)
              : ct.cardBorder,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
            child: Text(title,
                style: TextStyle(
                  fontSize: AppTextSize.md,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppTheme.primaryLight : ct.textPrimary,
                )),
          ),
          Divider(height: 1, color: ct.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final dynamic resultA, resultB;
  final String labelA, labelB;
  final bool isSpanish;
  const _ProjectionCard({
    required this.resultA,
    required this.resultB,
    required this.labelA,
    required this.labelB,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final projA = (resultA.fiveYearProjection as List<double>);
    final projB = (resultB.fiveYearProjection as List<double>);
    final totalA = projA.fold(0.0, (s, v) => s + v);
    final totalB = projB.fold(0.0, (s, v) => s + v);

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
              isSpanish ? 'Proyección 5 Años' : '5-Year Projection',
              style: const TextStyle(
                  fontSize: AppTextSize.md, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                ...List.generate(
                    5,
                    (i) => Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs),
                          child: ComparisonBar(
                            label: isSpanish ? 'Año ${i + 1}' : 'Year ${i + 1}',
                            valueA: i < projA.length ? projA[i] : 0,
                            valueB: i < projB.length ? projB[i] : 0,
                            winner: (i < projA.length && i < projB.length)
                                ? (projA[i] >= projB[i]
                                    ? Winner.offerA
                                    : Winner.offerB)
                                : null,
                            isSpanish: isSpanish,
                          ),
                        )),
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),
                ComparisonBar(
                  label: isSpanish ? 'TOTAL 5 años' : 'TOTAL 5 years',
                  valueA: totalA,
                  valueB: totalB,
                  winner: totalA >= totalB ? Winner.offerA : Winner.offerB,
                  isSpanish: isSpanish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── RSU Vesting Schedule card ─────────────────────────────────────────────────

class _RsuVestingCard extends StatefulWidget {
  final JobOffer offerA;
  final JobOffer offerB;
  final JobOffer? offerC;
  final dynamic resultA;
  final dynamic resultB;
  final bool isSpanish;

  const _RsuVestingCard({
    required this.offerA,
    required this.offerB,
    this.offerC,
    required this.resultA,
    required this.resultB,
    required this.isSpanish,
  });

  @override
  State<_RsuVestingCard> createState() => _RsuVestingCardState();
}

class _RsuVestingCardState extends State<_RsuVestingCard> {
  bool _expanded = false;

  /// Build 4-year cliff+monthly vesting schedule.
  /// Year 1: 25% cliff. Years 2–4: remaining 75% monthly (1/36 per month per year).
  static List<_VestYear> _schedule(double totalGrant) {
    if (totalGrant <= 0) return [];
    final cliff = totalGrant * 0.25;
    final remainder = totalGrant * 0.75;
    final monthlyVest = remainder / 36;
    return [
      _VestYear(year: 1, vested: cliff, cumulative: cliff),
      _VestYear(
          year: 2,
          vested: monthlyVest * 12,
          cumulative: cliff + monthlyVest * 12),
      _VestYear(
          year: 3,
          vested: monthlyVest * 12,
          cumulative: cliff + monthlyVest * 24),
      _VestYear(year: 4, vested: monthlyVest * 12, cumulative: totalGrant),
    ];
  }

  /// Estimate tax on RSU vesting (taxed as ordinary income on top of salary).
  static double _rsuTaxRate(double salary, double rsuIncome, String stateCode) {
    if (salary <= 0 && rsuIncome <= 0) return 0;
    final total = salary + rsuIncome;
    final taxTotal =
        OfferEngine.federalTax(total) + OfferEngine.stateTax(total, stateCode);
    final taxSalary = OfferEngine.federalTax(salary) +
        OfferEngine.stateTax(salary, stateCode);
    final taxOnRsu = taxTotal - taxSalary;
    return rsuIncome > 0 ? (taxOnRsu / rsuIncome) : 0;
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final isSp = widget.isSpanish;

    final grantA = widget.offerA.annualRsuValue * 4; // total 4-yr grant
    final grantB = widget.offerB.annualRsuValue * 4;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tappable
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl)),
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    AppSpacing.mdPlus, AppSpacing.mdPlus, AppSpacing.mdPlus),
                child: Row(children: [
                  Icon(Icons.trending_up_rounded,
                      color: AppTheme.accent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isSp
                          ? 'Calendario de Adquisición RSU'
                          : 'RSU Vesting Schedule',
                      style: const TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ]),
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: ct.cardBorder),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grant summary row
                  Row(children: [
                    Expanded(
                        child: _GrantChip(
                      label: isSp ? 'Total concesión A' : 'Total grant A',
                      value: AmountFormatter.ui(grantA, 'USD'),
                      color: AppTheme.offerADeep,
                    )),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                        child: _GrantChip(
                      label: isSp ? 'Total concesión B' : 'Total grant B',
                      value: AmountFormatter.ui(grantB, 'USD'),
                      color: AppTheme.offerBDeep,
                    )),
                  ]),
                  const SizedBox(height: AppSpacing.mdPlus),
                  // Vesting table header
                  _VestHeader(isSp: isSp),
                  const Divider(height: 12),
                  // Year rows for Offer A
                  if (grantA > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        isSp ? 'Oferta A' : 'Offer A',
                        style: TextStyle(
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.offerADeep),
                      ),
                    ),
                    ..._schedule(grantA).map((y) {
                      final rate = _rsuTaxRate(widget.offerA.baseSalary,
                          y.vested, widget.offerA.stateCode);
                      final netVested = y.vested * (1 - rate);
                      return _VestRow(
                        year: y.year,
                        vested: y.vested,
                        cumulative: y.cumulative,
                        netVested: netVested,
                        taxRate: rate,
                        total: grantA,
                        color: AppTheme.offerADeep,
                        isSp: isSp,
                      );
                    }),
                  ],
                  // Year rows for Offer B
                  if (grantB > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        isSp ? 'Oferta B' : 'Offer B',
                        style: TextStyle(
                            fontSize: AppTextSize.xs,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.offerBDeep),
                      ),
                    ),
                    ..._schedule(grantB).map((y) {
                      final rate = _rsuTaxRate(widget.offerB.baseSalary,
                          y.vested, widget.offerB.stateCode);
                      final netVested = y.vested * (1 - rate);
                      return _VestRow(
                        year: y.year,
                        vested: y.vested,
                        cumulative: y.cumulative,
                        netVested: netVested,
                        taxRate: rate,
                        total: grantB,
                        color: AppTheme.offerBDeep,
                        isSp: isSp,
                      );
                    }),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppTheme.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isSp
                                ? 'Las RSU se gravan como ingreso ordinario en la fecha de adquisición. Los valores mostrados son estimaciones previas a impuestos. El valor real depende del precio de la acción al momento de la adquisición.'
                                : 'RSU values shown are pre-tax estimates. Actual vesting value depends on stock price at vesting date. RSUs are taxed as ordinary income.',
                            style: TextStyle(
                                fontSize: AppTextSize.xs,
                                color: ct.textSecondary,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VestYear {
  final int year;
  final double vested;
  final double cumulative;
  const _VestYear(
      {required this.year, required this.vested, required this.cumulative});
}

class _GrantChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _GrantChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.smPlus),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: AppTextSize.xs,
                color: color,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w800,
                color: color)),
      ]),
    );
  }
}

class _VestHeader extends StatelessWidget {
  final bool isSp;
  const _VestHeader({required this.isSp});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Row(children: [
      SizedBox(
          width: 48,
          child: Text(isSp ? 'Año' : 'Year',
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                  color: ct.textSecondary))),
      Expanded(
          child: Text(isSp ? 'Vest bruto' : 'Gross vest',
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                  color: ct.textSecondary))),
      Expanded(
          child: Text(isSp ? 'Neto (est.)' : 'Net (est.)',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                  color: ct.textSecondary))),
      SizedBox(
          width: 52,
          child: Text(isSp ? 'Progreso' : 'Progress',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                  color: ct.textSecondary))),
    ]);
  }
}

class _VestRow extends StatelessWidget {
  final int year;
  final double vested, cumulative, netVested, taxRate, total;
  final Color color;
  final bool isSp;

  const _VestRow({
    required this.year,
    required this.vested,
    required this.cumulative,
    required this.netVested,
    required this.taxRate,
    required this.total,
    required this.color,
    required this.isSp,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (cumulative / total) * 100 : 0.0;
    final yearLabel = year == 1
        ? (isSp ? 'Año 1 (cliff)' : 'Year 1 (cliff)')
        : (isSp ? 'Año $year' : 'Year $year');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Text(yearLabel,
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AmountFormatter.ui(vested, 'USD'),
                style: const TextStyle(
                    fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
            Text('${(taxRate * 100).toStringAsFixed(1)}% ${isSp ? 'imp. est.' : 'tax est.'}',
                style: TextStyle(fontSize: AppTextSize.xs, color: CalcwiseTheme.of(context).textSecondary)),
          ]),
        ),
        Expanded(
          child: Text(AmountFormatter.ui(netVested, 'USD'),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
        SizedBox(
          width: 52,
          child: Text('${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w600,
                  color: CalcwiseTheme.of(context).textSecondary)),
        ),
      ]),
    );
  }
}

// ── Negotiation Tips card ────────────────────────────────────────────────────

class _NegotiationTipsCard extends StatelessWidget {
  final ComparisonResult result;
  final bool isSpanish;

  const _NegotiationTipsCard({
    required this.result,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final a = result.resultA;
    final b = result.resultB;
    final isAWinner = result.winner == Winner.offerA;
    final loserNet = isAWinner ? b.netTakeHome : a.netTakeHome;
    final winnerNet = isAWinner ? a.netTakeHome : b.netTakeHome;
    final gap = winnerNet - loserNet;
    final counterTarget = loserNet + gap * 0.5;
    final loserLabel = isAWinner
        ? (isSpanish ? 'Oferta B' : 'Offer B')
        : (isSpanish ? 'Oferta A' : 'Offer A');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
            child: Row(children: [
              const Icon(Icons.handshake_outlined,
                  size: 18, color: AppTheme.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isSpanish ? 'Consejos de Negociación' : 'Negotiation Tips',
                style: const TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent),
              ),
            ]),
          ),
          Divider(height: 1, color: ct.cardBorder),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSpanish ? 'Brecha entre ofertas' : 'Offer gap',
                      style: TextStyle(
                          fontSize: AppTextSize.sm, color: ct.textSecondary),
                    ),
                    Text(
                      AmountFormatter.ui(gap, 'USD'),
                      style: const TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    isSpanish
                        ? 'Si está negociando $loserLabel, pida ${AmountFormatter.ui(counterTarget, 'USD')} neto anual para dividir la diferencia a la mitad.'
                        : 'If negotiating $loserLabel, counter at ${AmountFormatter.ui(counterTarget, 'USD')}/yr net to split the difference.',
                    style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: ct.textPrimary,
                        height: 1.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isSpanish
                      ? 'También considera: PTO extra, trabajo remoto, bono de firma o revisión salarial a 6 meses.'
                      : 'Also consider: extra PTO, remote work, signing bonus, or a 6-month salary review.',
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: ct.textSecondary,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Break-even card ───────────────────────────────────────────────────────────

class _BreakEvenCard extends StatelessWidget {
  final ComparisonResult result;
  final JobOffer offerA, offerB;
  final bool isSpanish;
  const _BreakEvenCard({
    required this.result,
    required this.offerA,
    required this.offerB,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final months = result.breakEvenMonths!;
    final years = months ~/ 12;
    final rem = months % 12;
    final isSp = isSpanish;

    final winnerLabel = result.winner == Winner.offerA ? offerA.label : offerB.label;
    final loserLabel = result.winner == Winner.offerA ? offerB.label : offerA.label;

    String duration;
    if (years == 0) {
      duration = isSp ? '$months meses' : '$months months';
    } else if (rem == 0) {
      duration = isSp ? '$years ${years == 1 ? "año" : "años"}' : '$years ${years == 1 ? "year" : "years"}';
    } else {
      duration = isSp ? '$years a. $rem m.' : '${years}y ${rem}m';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.offerBDeep.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.swap_vert_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isSp ? 'Punto de equilibrio' : 'Break-even analysis',
            style: const TextStyle(
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        // Big number
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(duration,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  letterSpacing: -1)),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              isSp ? '→ $winnerLabel supera a $loserLabel' : '→ $winnerLabel overtakes $loserLabel',
              style: TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isSp
              ? '$loserLabel tiene ventaja de bono inicial. Pero $winnerLabel paga más cada año — después de $duration, $winnerLabel habrá ganado más en total.'
              : '$loserLabel has a signing bonus head start. But $winnerLabel pays more each year — after $duration, $winnerLabel\'s cumulative earnings surpass $loserLabel\'s.',
          style: TextStyle(
              fontSize: AppTextSize.sm,
              color: ct.textSecondary,
              height: 1.5),
        ),
      ]),
    );
  }
}

// ── Wealth building card ──────────────────────────────────────────────────────

class _WealthBuildingCard extends StatelessWidget {
  final dynamic resultA, resultB;
  final String labelA, labelB;
  final bool isSpanish;
  const _WealthBuildingCard({
    required this.resultA,
    required this.resultB,
    required this.labelA,
    required this.labelB,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final isSp = isSpanish;
    final a = resultA;
    final b = resultB;

    final cum5A = a.cumulativeComp5Yr as double;
    final cum5B = b.cumulativeComp5Yr as double;
    final k401kA = a.k401kWealthAt65 as double;
    final k401kB = b.k401kWealthAt65 as double;
    final wealthA = a.netWealthAfter5Yrs as double;
    final wealthB = b.netWealthAfter5Yrs as double;

    final winA_cum = cum5A >= cum5B;
    final winA_k = k401kA >= k401kB;
    final winA_w = wealthA >= wealthB;

    Widget metricRow(String title, String sub, double vA, double vB, bool aWins) {
      final winColor = aWins ? AppTheme.offerADeep : AppTheme.offerBDeep;
      final winLabel = aWins ? labelA : labelB;
      final diff = (vA - vB).abs();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
                Text(sub,
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: ct.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: winColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: Text(
                '+${AmountFormatter.ui(diff, 'USD')} $winLabel',
                style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: winColor,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Expanded(
              child: _MiniBar(
                  label: labelA, value: vA, maxVal: vA > vB ? vA : vB, color: AppTheme.offerADeep),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniBar(
                  label: labelB, value: vB, maxVal: vA > vB ? vA : vB, color: AppTheme.offerBDeep),
            ),
          ]),
        ]),
      );
    }

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
            const Icon(Icons.account_balance_wallet_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isSp ? 'Construcción de riqueza' : 'Wealth Building',
              style: const TextStyle(
                  fontSize: AppTextSize.md, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        Divider(height: 1, color: ct.cardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: Column(children: [
            metricRow(
              isSp ? 'Compensación total — 5 años' : 'Total Earnings — 5 Years',
              isSp
                  ? 'Suma acumulada con aumentos anuales'
                  : 'Cumulative total with annual raises',
              cum5A,
              cum5B,
              winA_cum,
            ),
            Divider(height: 20, color: ct.cardBorder),
            metricRow(
              isSp ? '401k a la jubilación (30 años)' : '401k Balance at Retirement (30 yr)',
              isSp
                  ? '6% aporte + match · 7% retorno compuesto'
                  : '6% contrib + match · 7% compounded return',
              k401kA,
              k401kB,
              winA_k,
            ),
            Divider(height: 20, color: ct.cardBorder),
            metricRow(
              isSp ? 'Riqueza neta en 5 años' : 'Net Investable Wealth — 5 Years',
              isSp
                  ? '20% tasa de ahorro · 6% retorno anual'
                  : '20% savings rate · 6% annual return',
              wealthA,
              wealthB,
              winA_w,
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          decoration: BoxDecoration(
            color: ct.surfaceHigh,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.xl)),
          ),
          child: Text(
            isSp
                ? '* Proyecciones estimativas basadas en tasas 2026. La rentabilidad real puede variar.'
                : '* Projections are estimates based on 2026 rates. Actual returns may vary.',
            style: TextStyle(
                fontSize: AppTextSize.xs,
                color: ct.textSecondary,
                fontStyle: FontStyle.italic),
          ),
        ),
      ]),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxVal;
  final Color color;
  const _MiniBar(
      {required this.label,
      required this.value,
      required this.maxVal,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final ratio = maxVal > 0 ? (value / maxVal).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: AppTextSize.xs, color: ct.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      LayoutBuilder(builder: (_, bc) {
        return Stack(children: [
          Container(
              height: 6,
              width: bc.maxWidth,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3))),
          Container(
              height: 6,
              width: bc.maxWidth * ratio,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
        ]);
      }),
      const SizedBox(height: 2),
      Text(AmountFormatter.ui(value, 'USD'),
          style: TextStyle(
              fontSize: AppTextSize.xs,
              color: color,
              fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Export sheet tile ────────────────────────────────────────────────────────

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isPremium;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: ct.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: ct.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w600,
                      color: ct.textPrimary)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: AppTextSize.sm, color: ct.textSecondary)),
            ],
          )),
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Text('PRO',
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accent)),
            )
          else
            Icon(Icons.chevron_right_rounded, color: ct.textSecondary),
        ]),
      ),
    );
  }
}
