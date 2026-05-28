import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/offer_parser.dart';
import '../core/models/job_offer.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';

/// Full-screen dialog that lets the user paste an offer letter, parses it
/// with [OfferParser], and applies a confirmed subset of fields back to the
/// caller through [onApply].
class OfferParserDialog extends StatefulWidget {
  final JobOffer current;
  final bool isSpanish;
  final ValueChanged<JobOffer> onApply;

  const OfferParserDialog({
    super.key,
    required this.current,
    required this.isSpanish,
    required this.onApply,
  });

  @override
  State<OfferParserDialog> createState() => _OfferParserDialogState();
}

class _OfferParserDialogState extends State<OfferParserDialog> {
  static const _quotaKey = 'offer_parser_last_use';
  static const _quotaCountKey = 'offer_parser_count_today';

  final _ctrl = TextEditingController();
  ParsedOffer? _parsed;
  final Map<String, bool> _checks = {};
  bool _busy = false;
  String? _error;

  bool get _isSp => widget.isSpanish;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _canParse() async {
    if (freemiumService.hasFullAccess) return true;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_quotaKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final count = prefs.getInt(_quotaCountKey) ?? 0;
    if (last == today && count >= 3) return false;
    return true;
  }

  Future<void> _recordUse() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final last = prefs.getString(_quotaKey);
    final count = (last == today) ? (prefs.getInt(_quotaCountKey) ?? 0) : 0;
    await prefs.setString(_quotaKey, today);
    await prefs.setInt(_quotaCountKey, count + 1);
  }

  Future<void> _parse() async {
    HapticFeedback.lightImpact();
    setState(() {
      _busy = true;
      _error = null;
    });

    if (!await _canParse()) {
      setState(() {
        _busy = false;
        _error = _isSp
            ? 'Límite gratuito: 3 análisis por día. Premium para ilimitado.'
            : 'Free limit: 3 parses per day. Premium for unlimited.';
      });
      return;
    }

    final result = OfferParser.parse(_ctrl.text);
    await _recordUse();

    if (!mounted) return;
    setState(() {
      _parsed = result;
      _busy = false;
      _checks
        ..clear()
        ..addAll({
          'baseSalary': result.baseSalary != null,
          'signOnBonus': result.signOnBonus != null,
          'annualBonus':
              result.annualBonus != null || result.annualBonusPct != null,
          'equityValue': result.equityValue != null,
          'matchPct': result.matchPct != null,
          'ptoDays': result.ptoDays != null,
          'title': result.title != null,
          'company': result.company != null,
        });
      if (result.isEmpty) {
        _error = _isSp
            ? 'No se encontraron datos. Pega más contexto.'
            : 'No data found. Paste more of the letter.';
      }
    });
  }

  void _applySelected() {
    final p = _parsed;
    if (p == null) return;
    var o = widget.current;

    if (_checks['baseSalary'] == true && p.baseSalary != null) {
      o = o.copyWith(baseSalary: p.baseSalary);
    }
    if (_checks['signOnBonus'] == true && p.signOnBonus != null) {
      o = o.copyWith(signingBonus: p.signOnBonus);
    }
    if (_checks['annualBonus'] == true && p.annualBonusPct != null) {
      o = o.copyWith(bonusPct: p.annualBonusPct);
    } else if (_checks['annualBonus'] == true &&
        p.annualBonus != null &&
        (o.baseSalary > 0)) {
      // Convert $ to % using base salary so it fits the form model.
      o = o.copyWith(bonusPct: (p.annualBonus! / o.baseSalary) * 100);
    }
    if (_checks['equityValue'] == true && p.equityValue != null) {
      o = o.copyWith(annualRsuValue: p.equityValue);
    }
    if (_checks['matchPct'] == true && p.matchPct != null) {
      o = o.copyWith(k401kMatchPct: p.matchPct);
    }
    if (_checks['ptoDays'] == true && p.ptoDays != null) {
      o = o.copyWith(ptoDays: p.ptoDays);
    }
    if (_checks['title'] == true && p.title != null) {
      o = o.copyWith(label: p.title!);
    }
    if (_checks['company'] == true && p.company != null) {
      o = o.copyWith(company: p.company!);
    }

    widget.onApply(o);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSp ? 'Analizar carta de oferta' : 'Parse Offer Letter'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.22)),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _isSp
                          ? 'Pega el texto de tu oferta. Detectaremos salario, bono, equity y más.'
                          : 'Paste your offer text. We will detect salary, bonus, equity, and more.',
                      style: TextStyle(
                          fontSize: AppTextSize.sm,
                          color: ct.textSecondary,
                          height: 1.35),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: _isSp
                        ? 'Pega aquí el texto de la oferta…'
                        : 'Paste offer letter text here…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.smPlus),
                Text(_error!,
                    style: TextStyle(
                        color: ct.errorRed, fontSize: AppTextSize.sm)),
              ],
              if (_parsed != null && !_parsed!.isEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _resultsCard(ct),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _parse,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_isSp ? 'Analizar' : 'Parse'),
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_parsed != null && !_parsed!.isEmpty)
                        ? _applySelected
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(_isSp ? 'Rellenar' : 'Fill Form'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultsCard(CalcwiseTheme ct) {
    final p = _parsed!;
    final rows = <Widget>[];
    void add(String key, String label, String value) {
      rows.add(CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _checks[key] ?? false,
        onChanged: (v) => setState(() => _checks[key] = v ?? false),
        title: Text(label,
            style: const TextStyle(
                fontSize: AppTextSize.md, fontWeight: FontWeight.w600)),
        subtitle: Text(value,
            style:
                TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
      ));
    }

    if (p.baseSalary != null) {
      add('baseSalary', _isSp ? 'Salario base' : 'Base salary',
          '\$${p.baseSalary!.toStringAsFixed(0)}/yr');
    }
    if (p.signOnBonus != null) {
      add('signOnBonus', _isSp ? 'Bono de firma' : 'Sign-on bonus',
          '\$${p.signOnBonus!.toStringAsFixed(0)}');
    }
    if (p.annualBonus != null || p.annualBonusPct != null) {
      final pct = p.annualBonusPct;
      final amt = p.annualBonus;
      add(
        'annualBonus',
        _isSp ? 'Bono anual' : 'Annual bonus',
        pct != null
            ? '${pct.toStringAsFixed(0)}%${amt != null ? ' (~\$${amt.toStringAsFixed(0)})' : ''}'
            : '\$${amt!.toStringAsFixed(0)}',
      );
    }
    if (p.equityValue != null) {
      add('equityValue', _isSp ? 'Equity / RSU' : 'Equity / RSU',
          '\$${p.equityValue!.toStringAsFixed(0)}');
    }
    if (p.matchPct != null) {
      add('matchPct', '401k match', '${p.matchPct!.toStringAsFixed(0)}%');
    }
    if (p.ptoDays != null) {
      add('ptoDays', _isSp ? 'Días PTO' : 'PTO days',
          '${p.ptoDays} ${_isSp ? "días" : "days"}');
    }
    if (p.title != null) {
      add('title', _isSp ? 'Puesto' : 'Title', p.title!);
    }
    if (p.company != null) {
      add('company', _isSp ? 'Empresa' : 'Company', p.company!);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      decoration: BoxDecoration(
        color: ct.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: ct.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: ct.successGreen, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _isSp
                    ? '${p.fieldCount} campos detectados'
                    : '${p.fieldCount} fields detected',
                style: TextStyle(
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w700,
                    color: ct.textPrimary),
              ),
            ]),
          ),
          ...rows,
        ],
      ),
    );
  }
}
