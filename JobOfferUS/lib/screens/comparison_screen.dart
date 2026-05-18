import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

class ComparisonScreen extends StatefulWidget {
  final JobOffer offerA;
  final JobOffer offerB;
  final ComparisonResult result;

  const ComparisonScreen({
    super.key,
    required this.offerA,
    required this.offerB,
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
      final fmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
      final pctFmt = NumberFormat('0.0#', 'en_US');
      final a = widget.result.resultA;
      final b = widget.result.resultB;
      final labelA = widget.offerA.label.isNotEmpty ? widget.offerA.label : 'Offer A';
      final labelB = widget.offerB.label.isNotEmpty ? widget.offerB.label : 'Offer B';

      final rows = [
        ['Field', labelA, labelB],
        [isSpanish ? 'Empresa' : 'Company', widget.offerA.company, widget.offerB.company],
        [isSpanish ? 'Ciudad' : 'City', widget.offerA.city, widget.offerB.city],
        [isSpanish ? 'Estado' : 'State', widget.offerA.stateCode, widget.offerB.stateCode],
        [isSpanish ? 'Salario bruto' : 'Gross Salary', fmt.format(a.grossSalary), fmt.format(b.grossSalary)],
        [isSpanish ? 'Ingreso neto anual' : 'Net Annual Take-Home', fmt.format(a.netTakeHome), fmt.format(b.netTakeHome)],
        [isSpanish ? 'Ingreso neto mensual' : 'Net Monthly', fmt.format(a.monthlyTakeHome), fmt.format(b.monthlyTakeHome)],
        [isSpanish ? 'Tasa efectiva' : 'Effective Tax Rate', '${pctFmt.format(a.effectiveTaxRate)}%', '${pctFmt.format(b.effectiveTaxRate)}%'],
        [isSpanish ? 'Impuesto federal' : 'Federal Tax', fmt.format(a.federalTax), fmt.format(b.federalTax)],
        [isSpanish ? 'Impuesto estatal' : 'State Tax', fmt.format(a.stateTax), fmt.format(b.stateTax)],
        ['FICA', fmt.format(a.ficaTax), fmt.format(b.ficaTax)],
        [isSpanish ? 'Bono anual (neto)' : 'Annual Bonus (after tax)', fmt.format(a.bonusAfterTax), fmt.format(b.bonusAfterTax)],
        [isSpanish ? 'Match 401k' : '401k Match', fmt.format(a.k401kMatch), fmt.format(b.k401kMatch)],
        [isSpanish ? 'Beneficios salud' : 'Health Benefits', fmt.format(a.healthBenefits), fmt.format(b.healthBenefits)],
        [isSpanish ? 'Valor PTO' : 'PTO Value', fmt.format(a.ptoValue), fmt.format(b.ptoValue)],
        [isSpanish ? 'RSU anual' : 'Annual RSU', fmt.format(a.annualRsuValue), fmt.format(b.annualRsuValue)],
        [isSpanish ? 'Costo traslado' : 'Commute Cost', fmt.format(a.commuteCost), fmt.format(b.commuteCost)],
        [isSpanish ? 'Compensación total neta' : 'Total Net Compensation', fmt.format(a.totalCompensation), fmt.format(b.totalCompensation)],
      ];

      final csv = rows.map((r) => r.map((cell) => '"$cell"').join(',')).join('\n');
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final filename = 'job_comparison_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';

      await Share.shareXFiles(
        [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
        subject: filename,
      );
      AnalyticsService.instance.logResultShared();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSpanish ? 'Error al exportar CSV' : 'Failed to export CSV'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportPdfImpl(bool isSpanish) async {
    final fmt =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final pctFmt = NumberFormat('0.0#', 'en_US');
    final a = widget.result.resultA;
    final b = widget.result.resultB;
    final winner = widget.result.winner;
    final winnerLabel = winner == Winner.offerA
        ? (isSpanish ? 'Oferta A gana' : 'Offer A wins')
        : winner == Winner.offerB
            ? (isSpanish ? 'Oferta B gana' : 'Offer B wins')
            : (isSpanish ? 'Empate' : 'Tie');
    final advantage = fmt.format(widget.result.annualAdvantage);

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
                  pw.Text('🏆 $winnerLabel',
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
                  fmt.format(a.grossSalary), fmt.format(b.grossSalary),
                  bold: true),
              row(isSpanish ? 'Ingreso neto anual' : 'Net Take-Home (Annual)',
                  fmt.format(a.netTakeHome), fmt.format(b.netTakeHome),
                  bold: true),
              row(isSpanish ? 'Ingreso neto mensual' : 'Net Monthly',
                  fmt.format(a.monthlyTakeHome), fmt.format(b.monthlyTakeHome)),
              row(
                  isSpanish ? 'Tasa efectiva' : 'Effective Tax Rate',
                  '${pctFmt.format(a.effectiveTaxRate)}%',
                  '${pctFmt.format(b.effectiveTaxRate)}%'),
              row(isSpanish ? 'Bono anual (neto)' : 'Annual Bonus (after tax)',
                  fmt.format(a.bonusAfterTax), fmt.format(b.bonusAfterTax)),
              row(isSpanish ? 'Match 401k' : '401k Match',
                  fmt.format(a.k401kMatch), fmt.format(b.k401kMatch)),
              row(isSpanish ? 'Beneficios de salud' : 'Health Benefits',
                  fmt.format(a.healthBenefits), fmt.format(b.healthBenefits)),
              row(isSpanish ? 'RSU anual' : 'Annual RSU',
                  fmt.format(a.annualRsuValue), fmt.format(b.annualRsuValue)),
              row(isSpanish ? 'Costo de traslado' : 'Commute Cost',
                  fmt.format(a.commuteCost), fmt.format(b.commuteCost)),
              row(
                  isSpanish ? 'Compensación total' : 'Total Compensation',
                  fmt.format(a.totalCompensation),
                  fmt.format(b.totalCompensation),
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

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'job_offer_comparison_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    AnalyticsService.instance.logPdfExportedEvent();
    AnalyticsService.instance.logResultShared();
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

    try {
      // Save offer A
      await DatabaseHelper.instance.insertHistory({
        'job_title': widget.offerA.label,
        'company': widget.offerA.company,
        'location': widget.offerA.city,
        'salary': widget.offerA.baseSalary,
        'bonus': widget.offerA.baseSalary * widget.offerA.bonusPct / 100,
        'benefits': widget.offerA.healthInsuranceSavings +
            widget.offerA.dentalVisionSavings,
        'stock_options': widget.offerA.annualRsuValue,
        'relocation': 0.0,
        'pto': widget.offerA.ptoDays,
        'net_salary': a.netTakeHome,
        'monthly_net': a.monthlyTakeHome,
        'tax_rate': a.effectiveTaxRate,
        'created_at': now,
      });

      // Save offer B
      await DatabaseHelper.instance.insertHistory({
        'job_title': widget.offerB.label,
        'company': widget.offerB.company,
        'location': widget.offerB.city,
        'salary': widget.offerB.baseSalary,
        'bonus': widget.offerB.baseSalary * widget.offerB.bonusPct / 100,
        'benefits': widget.offerB.healthInsuranceSavings +
            widget.offerB.dentalVisionSavings,
        'stock_options': widget.offerB.annualRsuValue,
        'relocation': 0.0,
        'pto': widget.offerB.ptoDays,
        'net_salary': b.netTakeHome,
        'monthly_net': b.monthlyTakeHome,
        'tax_rate': b.effectiveTaxRate,
        'created_at': now,
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) => ValueListenableBuilder<bool>(
        valueListenable: freemiumService.isPremiumNotifier,
        builder: (_, isPremium, __) => Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Resultado' : 'Comparison'),
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
                icon: const Icon(Icons.table_chart_outlined),
                onPressed: () => _onExportCsv(isSpanish),
                tooltip: isSpanish ? 'Exportar CSV' : 'Export CSV',
              ),
              if (isPremium)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _exportPdf(isSpanish);
                  },
                  tooltip: isSpanish ? 'Exportar PDF' : 'Export PDF',
                )
              else
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  onPressed: () => _showPaywall(context, isSpanish),
                  tooltip: isSpanish ? 'Premium: PDF' : 'Premium: PDF',
                ),
            ],
          ),
          body: _buildBody(context, isSpanish, isPremium),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isSpanish, bool isPremium) {
    final a = widget.result.resultA;
    final b = widget.result.resultB;
    final insights =
        InsightEngine.generate(widget.result, isSpanish: isSpanish);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Winner banner ──────────────────────────────────────────────
          WinnerBanner(result: widget.result, isSpanish: isSpanish),
          const SizedBox(height: AppSpacing.lg),

          // ── Hero KPI card ──────────────────────────────────────────────
          _HeroKpiCard(result: widget.result, isSpanish: isSpanish),
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
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Core comparison card ───────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Salario Neto' : 'After-Tax Income',
            children: [
              ComparisonBar(
                label: isSpanish ? 'Salario neto anual' : 'Annual take-home',
                valueA: a.netTakeHome,
                valueB: b.netTakeHome,
                winner: widget.result.categoryWinners['takeHome'],
                isSpanish: isSpanish,
              ),
              ComparisonBar(
                label: isSpanish ? 'Mensual' : 'Monthly',
                valueA: a.monthlyTakeHome,
                valueB: b.monthlyTakeHome,
                winner: widget.result.categoryWinners['takeHome'],
                isSpanish: isSpanish,
              ),
              ComparisonBar(
                label: isSpanish
                    ? 'Tasa impositiva efectiva'
                    : 'Effective tax rate',
                valueA: a.effectiveTaxRate,
                valueB: b.effectiveTaxRate,
                winner: widget.result.categoryWinners['takeHome'],
                isSpanish: isSpanish,
                formatter: (v) => '${v.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tax breakdown ──────────────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Desglose de Impuestos' : 'Tax Breakdown',
            children: [
              ComparisonBar(
                label: isSpanish ? 'Impuesto federal' : 'Federal tax',
                valueA: a.federalTax,
                valueB: b.federalTax,
                isSpanish: isSpanish,
              ),
              ComparisonBar(
                label: isSpanish ? 'Impuesto estatal' : 'State tax',
                valueA: a.stateTax,
                valueB: b.stateTax,
                isSpanish: isSpanish,
              ),
              ComparisonBar(
                label: 'FICA (SS + Medicare)',
                valueA: a.ficaTax,
                valueB: b.ficaTax,
                isSpanish: isSpanish,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Benefits & extras ──────────────────────────────────────────
          _SectionCard(
            title: isSpanish ? 'Beneficios y Extras' : 'Benefits & Extras',
            children: [
              if (a.annualBonus > 0 || b.annualBonus > 0)
                ComparisonBar(
                  label: isSpanish
                      ? 'Bono neto anual'
                      : 'Annual bonus (after tax)',
                  valueA: a.bonusAfterTax,
                  valueB: b.bonusAfterTax,
                  winner: widget.result.categoryWinners['bonus'],
                  isSpanish: isSpanish,
                ),
              if (a.k401kMatch > 0 || b.k401kMatch > 0)
                ComparisonBar(
                  label: isSpanish
                      ? '401k (aporte empleador)'
                      : '401k employer match',
                  valueA: a.k401kMatch,
                  valueB: b.k401kMatch,
                  winner: widget.result.categoryWinners['benefits'],
                  isSpanish: isSpanish,
                ),
              if (a.healthBenefits > 0 || b.healthBenefits > 0)
                ComparisonBar(
                  label: isSpanish ? 'Salud + dental' : 'Health + dental',
                  valueA: a.healthBenefits,
                  valueB: b.healthBenefits,
                  winner: widget.result.categoryWinners['benefits'],
                  isSpanish: isSpanish,
                ),
              if (a.ptoValue > 0 || b.ptoValue > 0)
                ComparisonBar(
                  label: isSpanish ? 'Valor vacaciones (PTO)' : 'PTO value',
                  valueA: a.ptoValue,
                  valueB: b.ptoValue,
                  winner: widget.result.categoryWinners['pto'],
                  isSpanish: isSpanish,
                ),
              if (a.annualRsuValue > 0 || b.annualRsuValue > 0)
                ComparisonBar(
                  label: isSpanish ? 'RSU / Stock anual' : 'Annual RSU / Stock',
                  valueA: a.annualRsuValue,
                  valueB: b.annualRsuValue,
                  winner: widget.result.categoryWinners['rsu'],
                  isSpanish: isSpanish,
                ),
              if (a.commuteCost > 0 || b.commuteCost > 0)
                ComparisonBar(
                  label:
                      isSpanish ? 'Costo transporte (−)' : 'Commute cost (−)',
                  valueA: a.commuteCost,
                  valueB: b.commuteCost,
                  winner: widget.result.categoryWinners['commute'],
                  isSpanish: isSpanish,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Total compensation ─────────────────────────────────────────
          _SectionCard(
            title: isSpanish
                ? 'Compensación Total Neta'
                : 'Net Total Compensation',
            highlight: true,
            children: [
              ComparisonBar(
                label: isSpanish ? 'Total anual neto' : 'Total annual net',
                valueA: a.totalCompensation,
                valueB: b.totalCompensation,
                winner: widget.result.categoryWinners['total'],
                isSpanish: isSpanish,
              ),
              ComparisonBar(
                label: isSpanish ? 'Total mensual neto' : 'Total monthly net',
                valueA: a.monthlyTotalComp,
                valueB: b.monthlyTotalComp,
                winner: widget.result.categoryWinners['total'],
                isSpanish: isSpanish,
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
                ComparisonBar(
                  label: isSpanish
                      ? 'Salario ajustado por costo de vida'
                      : 'CoL-adjusted take-home',
                  valueA: a.colAdjustedTakeHome,
                  valueB: b.colAdjustedTakeHome,
                  winner: widget.result.categoryWinners['col'],
                  isSpanish: isSpanish,
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

          // ── 5-year projection (Premium) ────────────────────────────────
          if (isPremium && a.fiveYearProjection.isNotEmpty) ...[
            _ProjectionCard(
              resultA: a,
              resultB: b,
              labelA: widget.offerA.label,
              labelB: widget.offerB.label,
              isSpanish: isSpanish,
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (!isPremium) ...[
            PaywallSoft(
              featureTitle: isSpanish
                  ? 'Proyección a 5 años'
                  : '5-year career projection',
              featureSubtitle: isSpanish
                  ? 'Con aumentos anuales, ¿cuál ofrece más a largo plazo?'
                  : 'With annual raises, which pays more long-term?',
              isSpanish: isSpanish,
              onUnlock: () => _showPaywall(context, isSpanish),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Smart insights ─────────────────────────────────────────────
          InsightCard(insights: insights, isSpanish: isSpanish),
          const SizedBox(height: AppSpacing.md),

          // ── Negotiation Tips ───────────────────────────────────────────
          if (!widget.result.isTie)
            _NegotiationTipsCard(result: widget.result, isSpanish: isSpanish),
          if (!widget.result.isTie) const SizedBox(height: AppSpacing.md),

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

          // ── Ad footer ──────────────────────────────────────────────────
          const CalcwiseAdFooter(),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeroKpiCard extends StatelessWidget {
  final ComparisonResult result;
  final bool isSpanish;

  const _HeroKpiCard({required this.result, required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
    final a = result.resultA;
    final b = result.resultB;

    final String heroLabel;
    final String heroValue;
    final String heroSecondary;
    final String statLabelA;
    final String statLabelB;

    if (result.isTie) {
      heroLabel = isSpanish ? 'Compensación total' : 'Total Compensation';
      heroValue = fmt.format(a.totalCompensation);
      heroSecondary = isSpanish ? 'Las dos ofertas son equivalentes' : 'Both offers are equivalent';
      statLabelA = isSpanish ? 'Neto anual A' : 'Annual net A';
      statLabelB = isSpanish ? 'Neto anual B' : 'Annual net B';
    } else {
      final isAWinner = result.winner == Winner.offerA;
      final winnerResult = isAWinner ? a : b;
      final winnerLabel = isAWinner
          ? (isSpanish ? 'Oferta A' : 'Offer A')
          : (isSpanish ? 'Oferta B' : 'Offer B');
      heroLabel = isSpanish
          ? '$winnerLabel — Neto anual'
          : '$winnerLabel — Annual Net';
      heroValue = fmt.format(winnerResult.netTakeHome);
      heroSecondary = isSpanish
          ? 'Ventaja: ${fmt.format(result.annualAdvantage)}/año'
          : 'Advantage: ${fmt.format(result.annualAdvantage)}/yr';
      statLabelA = isSpanish ? 'Tasa efectiva' : 'Effective rate';
      statLabelB = isSpanish ? 'Comp. total' : 'Total comp';

      return Semantics(
        label: isSpanish
            ? '$winnerLabel gana con ${fmt.format(winnerResult.netTakeHome)} neto anual, ventaja de ${fmt.format(result.annualAdvantage)}'
            : '$winnerLabel wins with ${fmt.format(winnerResult.netTakeHome)} annual net, advantage of ${fmt.format(result.annualAdvantage)}',
        child: CalcwiseHeroCard(
          label: heroLabel,
          value: heroValue,
          secondary: heroSecondary,
          backgroundColor: AppTheme.primary,
          stats: [
            (
              label: statLabelA,
              value: '${winnerResult.effectiveTaxRate.toStringAsFixed(1)}%',
            ),
            (
              label: statLabelB,
              value: fmt.format(winnerResult.totalCompensation),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: isSpanish
          ? 'Las dos ofertas son equivalentes. Compensación total: ${fmt.format(a.totalCompensation)}'
          : 'Both offers are equivalent. Total compensation: ${fmt.format(a.totalCompensation)}',
      child: CalcwiseHeroCard(
        label: heroLabel,
        value: heroValue,
        secondary: heroSecondary,
        backgroundColor: AppTheme.primary,
        stats: [
          (
            label: statLabelA,
            value: fmt.format(a.netTakeHome),
          ),
          (
            label: statLabelB,
            value: fmt.format(b.netTakeHome),
          ),
        ],
      ),
    );
  }
}

class _OfferHeader extends StatelessWidget {
  final String labelA, labelB, companyA, companyB;
  const _OfferHeader({
    required this.labelA,
    required this.labelB,
    required this.companyA,
    required this.companyB,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _OfferChip(label: labelA, company: companyA, isA: true)),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: _OfferChip(label: labelB, company: companyB, isA: false)),
    ]);
  }
}

class _OfferChip extends StatelessWidget {
  final String label, company;
  final bool isA;
  const _OfferChip(
      {required this.label, required this.company, required this.isA});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.offerColor(isA);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smPlus),
      decoration: BoxDecoration(
        color: AppTheme.offerColorLight(isA),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
              child: Text(isA ? 'A' : 'B',
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
            child: Text(title,
                style: TextStyle(
                  fontSize: AppTextSize.md,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppTheme.primaryLight : ct.textPrimary,
                )),
          ),
          Divider(height: 1, color: ct.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.lg, AppSpacing.sm),
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
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
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
    final fmt = NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
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
              const Icon(Icons.handshake_outlined, size: 18, color: AppTheme.accent),
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
                      fmt.format(gap),
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
                        ? 'Si está negociando $loserLabel, pida ${fmt.format(counterTarget)} neto anual para dividir la diferencia a la mitad.'
                        : 'If negotiating $loserLabel, counter at ${fmt.format(counterTarget)}/yr net to split the difference.',
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
