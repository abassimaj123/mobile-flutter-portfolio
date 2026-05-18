import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/data/state_tax_data.dart';
import '../core/data/city_col_data.dart';
import '../core/models/job_offer.dart';
import '../core/theme/app_theme.dart';
import 'offer_parser_dialog.dart';

class OfferFormCard extends StatefulWidget {
  final bool isOfferA;
  final JobOffer value;
  final bool isPremium;
  final bool isSpanish;
  final ValueChanged<JobOffer> onChanged;
  const OfferFormCard({
    super.key,
    required this.isOfferA,
    required this.value,
    required this.isPremium,
    required this.isSpanish,
    required this.onChanged,
  });
  @override
  State<OfferFormCard> createState() => _OfferFormCardState();
}

class _OfferFormCardState extends State<OfferFormCard> {
  bool _expanded = true;
  bool _showBenefits = false;
  late final TextEditingController _salary,
      _label,
      _company,
      _bonus,
      _signing,
      _match,
      _upTo,
      _health,
      _dental,
      _pto,
      _rsu,
      _commute,
      _raise;

  @override
  void initState() {
    super.initState();
    final o = widget.value;
    _salary = _c(o.baseSalary > 0 ? o.baseSalary.toStringAsFixed(0) : '');
    _label = _c(o.label);
    _company = _c(o.company);
    _bonus = _c(o.bonusPct > 0 ? o.bonusPct.toStringAsFixed(0) : '');
    _signing = _c(o.signingBonus > 0 ? o.signingBonus.toStringAsFixed(0) : '');
    _match = _c(o.k401kMatchPct > 0 ? o.k401kMatchPct.toStringAsFixed(0) : '');
    _upTo = _c(o.k401kUpToPct > 0 ? o.k401kUpToPct.toStringAsFixed(0) : '');
    _health = _c(o.healthInsuranceSavings > 0
        ? o.healthInsuranceSavings.toStringAsFixed(0)
        : '');
    _dental = _c(o.dentalVisionSavings > 0
        ? o.dentalVisionSavings.toStringAsFixed(0)
        : '');
    _pto = _c(o.ptoDays > 0 ? o.ptoDays.toString() : '');
    _rsu = _c(o.annualRsuValue > 0 ? o.annualRsuValue.toStringAsFixed(0) : '');
    _commute = _c(o.commuteMilesPerDay > 0
        ? o.commuteMilesPerDay.toStringAsFixed(0)
        : '');
    _raise = _c(o.annualRaisePct.toStringAsFixed(1));
  }

  TextEditingController _c(String v) => TextEditingController(text: v);

  @override
  void dispose() {
    for (final c in [
      _salary,
      _label,
      _company,
      _bonus,
      _signing,
      _match,
      _upTo,
      _health,
      _dental,
      _pto,
      _rsu,
      _commute,
      _raise
    ]) c.dispose();
    super.dispose();
  }

  Color get _c1 => AppTheme.offerColor(widget.isOfferA);
  LinearGradient get _grad => AppTheme.offerGradient(widget.isOfferA);
  String get _offerLabel => widget.isOfferA
      ? (widget.isSpanish ? 'Oferta A' : 'Offer A')
      : (widget.isSpanish ? 'Oferta B' : 'Offer B');

  void _emit() => widget.onChanged(widget.value.copyWith(
        label: _label.text.isEmpty ? _offerLabel : _label.text,
        company: _company.text,
        baseSalary: double.tryParse(_salary.text) ?? 0,
        bonusPct: double.tryParse(_bonus.text) ?? 0,
        signingBonus: double.tryParse(_signing.text) ?? 0,
        k401kMatchPct: double.tryParse(_match.text) ?? 0,
        k401kUpToPct: double.tryParse(_upTo.text) ?? 0,
        healthInsuranceSavings: double.tryParse(_health.text) ?? 0,
        dentalVisionSavings: double.tryParse(_dental.text) ?? 0,
        ptoDays: int.tryParse(_pto.text) ?? 0,
        annualRsuValue: double.tryParse(_rsu.text) ?? 0,
        commuteMilesPerDay: double.tryParse(_commute.text) ?? 0,
        annualRaisePct: double.tryParse(_raise.text) ?? 3,
      ));

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: _expanded ? _c1.withValues(alpha: 0.35) : ct.cardBorder,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: widget.isOfferA
            ? AppTheme.offerACardShadow
            : AppTheme.offerBCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(children: [
          // ── gradient header ──────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.mdPlus, AppSpacing.mdPlus, AppSpacing.mdPlus),
              decoration: BoxDecoration(gradient: _grad),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5),
                  ),
                  child: Center(
                      child: Text(
                    widget.isOfferA ? 'A' : 'B',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: AppTextSize.bodyLg),
                  )),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.value.label.isEmpty
                          ? _offerLabel
                          : widget.value.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.bodyLg),
                    ),
                    if (widget.value.company.isNotEmpty)
                      Text(widget.value.company,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: AppTextSize.sm)),
                    if (widget.value.baseSalary > 0)
                      Text(
                        '\$${widget.value.baseSalary.toStringAsFixed(0)}/yr',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: AppTextSize.md,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                )),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ]),
            ),
          ),
          // ── body ─────────────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paste offer letter (AI-style parser)
                  _pasteOfferButton(),
                  const SizedBox(height: AppSpacing.md),
                  // Name + Company
                  Row(children: [
                    Expanded(
                        child: _tf(
                            ctrl: _label,
                            label: widget.isSpanish ? 'Nombre' : 'Offer name',
                            hint: _offerLabel,
                            icon: Icons.label_outline_rounded)),
                    const SizedBox(width: AppSpacing.smPlus),
                    Expanded(
                        child: _tf(
                            ctrl: _company,
                            label: widget.isSpanish ? 'Empresa' : 'Company',
                            hint: 'Google, Meta…',
                            icon: Icons.business_rounded)),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  // Salary (accent)
                  _salaryField(),
                  const SizedBox(height: AppSpacing.md),
                  _stateDropdown(),
                  const SizedBox(height: AppSpacing.md),
                  // Bonus + PTO
                  Row(children: [
                    Expanded(
                        child: _tf(
                            ctrl: _bonus,
                            label: widget.isSpanish ? 'Bono (%)' : 'Bonus (%)',
                            hint: '10',
                            suffix: '%',
                            num: true,
                            icon: Icons.card_giftcard_rounded,
                            onCh: (_) => _emit())),
                    const SizedBox(width: AppSpacing.smPlus),
                    Expanded(
                        child: _tf(
                            ctrl: _pto,
                            label: widget.isSpanish ? 'Días PTO' : 'PTO days',
                            hint: '15',
                            num: true,
                            icon: Icons.beach_access_rounded,
                            onCh: (_) => _emit())),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  // Signing bonus
                  _tf(
                    ctrl: _signing,
                    label: widget.isSpanish ? 'Bono de contratación (\$)' : 'Signing Bonus (\$)',
                    hint: '10000',
                    prefix: '\$',
                    num: true,
                    icon: Icons.monetization_on_rounded,
                    onCh: (_) => _emit(),
                  ),
                  const SizedBox(height: AppSpacing.mdPlus),
                  // Benefits toggle
                  _BenefitsToggle(
                    expanded: _showBenefits,
                    isSp: widget.isSpanish,
                    color: _c1,
                    onTap: () => setState(() => _showBenefits = !_showBenefits),
                  ),
                  if (_showBenefits) ...[
                    const SizedBox(height: AppSpacing.mdPlus),
                    Row(children: [
                      Expanded(
                          child: _tf(
                              ctrl: _match,
                              label: '401k match (%)',
                              hint: '100',
                              suffix: '%',
                              num: true,
                              icon: Icons.savings_rounded,
                              onCh: (_) => _emit())),
                      const SizedBox(width: AppSpacing.smPlus),
                      Expanded(
                          child: _tf(
                              ctrl: _upTo,
                              label:
                                  widget.isSpanish ? 'Hasta (%)' : 'Up to (%)',
                              hint: '4',
                              suffix: '%',
                              num: true,
                              onCh: (_) => _emit())),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                          child: _tf(
                              ctrl: _health,
                              label: widget.isSpanish
                                  ? 'Salud (\$/año)'
                                  : 'Health (\$/yr)',
                              hint: '3000',
                              prefix: '\$',
                              num: true,
                              isCurrency: true,
                              icon: Icons.health_and_safety_rounded,
                              onCh: (_) => _emit())),
                      const SizedBox(width: AppSpacing.smPlus),
                      Expanded(
                          child: _tf(
                              ctrl: _dental,
                              label: widget.isSpanish
                                  ? 'Dental (\$/año)'
                                  : 'Dental (\$/yr)',
                              hint: '500',
                              prefix: '\$',
                              num: true,
                              isCurrency: true,
                              onCh: (_) => _emit())),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    _tf(
                        ctrl: _rsu,
                        label: widget.isSpanish
                            ? 'RSU/Stock anual (\$)'
                            : 'Annual RSU/Stock (\$)',
                        hint: '20000',
                        prefix: '\$',
                        num: true,
                        isCurrency: true,
                        icon: Icons.trending_up_rounded,
                        onCh: (_) => _emit()),
                    const SizedBox(height: AppSpacing.md),
                    _remoteToggle(),
                    if (!widget.value.isRemote) ...[
                      const SizedBox(height: AppSpacing.md),
                      _tf(
                          ctrl: _commute,
                          label: widget.isSpanish
                              ? 'Km ida al trabajo'
                              : 'Miles one-way commute',
                          hint: '15',
                          suffix: ' mi',
                          num: true,
                          icon: Icons.directions_car_rounded,
                          onCh: (_) => _emit()),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _cityDropdown(),
                    const SizedBox(height: AppSpacing.md),
                    _tf(
                        ctrl: _raise,
                        label: widget.isSpanish
                            ? 'Aumento anual (%)'
                            : 'Annual raise (%)',
                        hint: '3',
                        suffix: '%',
                        num: true,
                        icon: Icons.show_chart_rounded,
                        onCh: (_) => _emit()),
                  ],
                ],
              ),
            ),
        ]),
      ),
    );
  }

  // ── Paste offer letter button (AI-style regex parser) ─────────────────────

  Widget _pasteOfferButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: _openParser,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _c1.withValues(alpha: 0.16),
                _c1.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: _c1.withValues(alpha: 0.32)),
          ),
          child: Row(children: [
            Icon(Icons.auto_awesome_rounded, color: _c1, size: 18),
            const SizedBox(width: AppSpacing.smPlus),
            Expanded(
              child: Text(
                widget.isSpanish
                    ? 'Pegar carta de oferta'
                    : 'Paste offer letter',
                style: TextStyle(
                    color: _c1,
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _c1.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                widget.isSpanish ? 'NUEVO' : 'NEW',
                style: TextStyle(
                  color: _c1,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openParser() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => OfferParserDialog(
        current: widget.value,
        isSpanish: widget.isSpanish,
        onApply: (filled) {
          widget.onChanged(filled);
          // Refresh local controllers so the UI reflects parsed values.
          _salary.text =
              filled.baseSalary > 0 ? filled.baseSalary.toStringAsFixed(0) : '';
          _label.text = filled.label;
          _company.text = filled.company;
          _bonus.text =
              filled.bonusPct > 0 ? filled.bonusPct.toStringAsFixed(0) : '';
          _signing.text =
              filled.signingBonus > 0 ? filled.signingBonus.toStringAsFixed(0) : '';
          _match.text = filled.k401kMatchPct > 0
              ? filled.k401kMatchPct.toStringAsFixed(0)
              : '';
          _pto.text = filled.ptoDays > 0 ? filled.ptoDays.toString() : '';
          _rsu.text = filled.annualRsuValue > 0
              ? filled.annualRsuValue.toStringAsFixed(0)
              : '';
          setState(() {});
        },
      ),
    ));
  }

  // ── Validator for numeric fields ──────────────────────────────────────────

  String? _numValidator(String? v, {bool allowEmpty = true}) {
    if (v == null || v.trim().isEmpty) return allowEmpty ? null : 'Required';
    final n = double.tryParse(v.replaceAll(',', ''));
    if (n == null)
      return widget.isSpanish ? 'Número inválido' : 'Invalid number';
    if (n < 0) return widget.isSpanish ? 'Debe ser ≥ 0' : 'Must be ≥ 0';
    return null;
  }

  // ── Salary field (accent, larger) ─────────────────────────────────────────

  Widget _salaryField() => TextFormField(
        controller: _salary,
        keyboardType: TextInputType.number,
        inputFormatters: [CurrencyInputFormatter(locale: 'en_US')],
        validator: _numValidator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => _emit(),
        style: TextStyle(
          fontSize: AppTextSize.titleMd,
          fontWeight: FontWeight.w700,
          color: _c1,
          letterSpacing: -0.5,
        ),
        decoration: InputDecoration(
          labelText:
              widget.isSpanish ? 'Salario anual (\$)' : 'Annual salary (\$)',
          hintText: '85,000',
          prefixText: '\$  ',
          prefixStyle: TextStyle(
            fontSize: AppTextSize.subtitle,
            fontWeight: FontWeight.w700,
            color: _c1.withValues(alpha: 0.6),
          ),
          labelStyle: TextStyle(
              color: _c1.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
          floatingLabelStyle:
              TextStyle(color: _c1, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: _c1.withValues(alpha: 0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: _c1.withValues(alpha: 0.22)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            borderSide: BorderSide(color: _c1, width: 2),
          ),
          fillColor: _c1.withValues(alpha: 0.08),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  // ── Generic field ─────────────────────────────────────────────────────────

  Widget _tf({
    required TextEditingController ctrl,
    required String label,
    String? hint,
    String? prefix,
    String? suffix,
    IconData? icon,
    bool num = false,
    bool isCurrency = false,
    ValueChanged<String>? onCh,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        inputFormatters: isCurrency
            ? [CurrencyInputFormatter(locale: 'en_US')]
            : (num
                ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                : null),
        validator: num ? _numValidator : null,
        autovalidateMode: num ? AutovalidateMode.onUserInteraction : null,
        onChanged: onCh ?? (_) => _emit(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          suffixText: suffix,
          prefixIcon: icon != null ? Icon(icon, size: 17) : null,
          floatingLabelStyle:
              TextStyle(color: _c1, fontWeight: FontWeight.w600),
        ),
      );

  // ── State dropdown ────────────────────────────────────────────────────────

  Widget _stateDropdown() => DropdownButtonFormField<String>(
        initialValue: widget.value.stateCode,
        decoration: InputDecoration(
          labelText: widget.isSpanish ? 'Estado' : 'State',
          floatingLabelStyle:
              TextStyle(color: _c1, fontWeight: FontWeight.w600),
          prefixIcon: const Icon(Icons.location_on_rounded, size: 17),
        ),
        items: StateTaxData.allStateCodes
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('$s — ${StateTaxData.stateNames[s] ?? s}',
                      style: const TextStyle(fontSize: AppTextSize.md)),
                ))
            .toList(),
        onChanged: (s) {
          if (s != null) widget.onChanged(widget.value.copyWith(stateCode: s));
        },
      );

  // ── City dropdown ─────────────────────────────────────────────────────────

  Widget _cityDropdown() {
    final cities = CityColData.allCities;
    final cur = cities.contains(widget.value.city)
        ? widget.value.city
        : 'National Average';
    return DropdownButtonFormField<String>(
      initialValue: cur,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.isSpanish
            ? 'Ciudad (costo de vida)'
            : 'City (cost of living)',
        floatingLabelStyle: TextStyle(color: _c1, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.location_city_rounded, size: 17),
        suffixIcon:
            widget.isPremium ? null : const Icon(Icons.lock_outline, size: 16),
      ),
      items: cities
          .map((c) => DropdownMenuItem(
                value: c,
                child:
                    Text(c, style: const TextStyle(fontSize: AppTextSize.md)),
              ))
          .toList(),
      onChanged: widget.isPremium
          ? (c) {
              if (c != null) widget.onChanged(widget.value.copyWith(city: c));
            }
          : null,
    );
  }

  // ── Remote toggle ─────────────────────────────────────────────────────────

  Widget _remoteToggle() {
    final active = widget.value.isRemote;
    final ct = CalcwiseTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active ? ct.successGreen.withValues(alpha: 0.1) : ct.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color:
              active ? ct.successGreen.withValues(alpha: 0.35) : ct.cardBorder,
        ),
      ),
      child: Row(children: [
        Icon(
          active ? Icons.home_work_rounded : Icons.directions_car_rounded,
          size: 18,
          color: active ? ct.successGreen : ct.textSecondary,
        ),
        const SizedBox(width: AppSpacing.smPlus),
        Expanded(
            child: Text(
          widget.isSpanish ? 'Trabajo remoto' : 'Remote work',
          style: TextStyle(
            fontSize: AppTextSize.body,
            color: active ? ct.successGreen : ct.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        )),
        Switch(
          value: active,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            widget.onChanged(widget.value.copyWith(isRemote: v));
          },
        ),
      ]),
    );
  }
}

// ── Benefits toggle ───────────────────────────────────────────────────────────

class _BenefitsToggle extends StatelessWidget {
  final bool expanded, isSp;
  final Color color;
  final VoidCallback onTap;
  const _BenefitsToggle({
    required this.expanded,
    required this.isSp,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          Icon(
            expanded ? Icons.expand_less_rounded : Icons.add_circle_outline,
            color: color,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isSp
                ? (expanded
                    ? 'Ocultar beneficios'
                    : '+ Beneficios y transporte')
                : (expanded ? 'Hide benefits' : '+ Benefits & commute'),
            style: TextStyle(
                color: color,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (!expanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.mdPlus),
              ),
              child: Text(
                isSp ? '401k · RSU · Salud' : '401k · RSU · Health',
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      ),
    );
  }
}
