import 'package:flutter/material.dart';
import '../services/rate_watch_service.dart';
import '../theme/calcwise_theme.dart';

/// Shared Rate Watch card widget.
/// [isSpanish] — true for ES locale (US apps)
/// [isFrench]  — true for FR locale (CA apps)
/// [defaultTarget] — default rate target (e.g. 5.0 for CA, 6.0 for US, 4.5 for UK)
class RateWatchCard extends StatefulWidget {
  final bool   isSpanish;
  final bool   isFrench;
  final double defaultTarget;

  const RateWatchCard({
    super.key,
    this.isSpanish    = false,
    this.isFrench     = false,
    this.defaultTarget = 6.0,
  });

  @override
  State<RateWatchCard> createState() => _RateWatchCardState();
}

class _RateWatchCardState extends State<RateWatchCard> {
  bool   _enabled = false;
  double _target  = 6.0;
  bool   _loading = true;

  // ── Inline translations ────────────────────────────────────────────────────
  String get _title =>
      widget.isFrench ? 'Alerte taux' : widget.isSpanish ? 'Alerta de tasa' : 'Rate Watch';

  String get _enabledSub =>
      widget.isFrench
          ? 'Alerte si taux ≤ ${_target.toStringAsFixed(2)}% — toucher pour changer'
          : widget.isSpanish
              ? 'Alerta si tasa ≤ ${_target.toStringAsFixed(2)}% — toca para cambiar'
              : 'Alert when rate ≤ ${_target.toStringAsFixed(2)}% — tap to change';

  String get _disabledSub =>
      widget.isFrench
          ? 'Toucher pour définir une alerte de taux'
          : widget.isSpanish
              ? 'Toca para configurar una alerta de tasa'
              : 'Tap to set a rate alert';

  String get _dialogTitle =>
      widget.isFrench ? 'Définir le taux cible' : widget.isSpanish ? 'Establecer tasa objetivo' : 'Set Target Rate';

  String get _dialogLabel =>
      widget.isFrench ? 'Taux cible (%)' : widget.isSpanish ? 'Tasa objetivo (%)' : 'Target rate (%)';

  String get _dialogHint =>
      widget.isFrench ? 'ex. 5.25' : widget.isSpanish ? 'ej. 5.25' : 'e.g. 5.25';

  String get _cancelLbl =>
      widget.isFrench ? 'Annuler' : widget.isSpanish ? 'Cancelar' : 'Cancel';

  String get _setLbl =>
      widget.isFrench ? 'Définir' : widget.isSpanish ? 'Establecer' : 'Set';

  @override
  void initState() {
    super.initState();
    _target = widget.defaultTarget;
    _load();
  }

  Future<void> _load() async {
    final e = await RateWatchService.instance.isEnabled();
    final t = await RateWatchService.instance.getTarget() ?? widget.defaultTarget;
    if (mounted) setState(() { _enabled = e; _target = t; _loading = false; });
  }

  Future<void> _toggle(bool val) async {
    await RateWatchService.instance.setTarget(_target, enabled: val);
    if (mounted) setState(() => _enabled = val);
  }

  Future<void> _setTarget() async {
    final ctrl = TextEditingController(text: _target.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_dialogTitle),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _dialogLabel,
            hintText:  _dialogHint,
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_cancelLbl)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: Text(_setLbl),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && result < 30) {
      await RateWatchService.instance.setTarget(result, enabled: _enabled);
      if (mounted) setState(() => _target = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final theme   = CalcwiseTheme.of(context);
    final primary = theme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _enabled
            ? primary.withValues(alpha: 0.06)
            : const Color(0xFFF8FAFC),
        border: Border.all(
          color: _enabled ? primary.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(
          Icons.notifications_rounded,
          color: _enabled ? primary : const Color(0xFF94A3B8),
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_title,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: theme.textPrimary)),
            GestureDetector(
              onTap: _setTarget,
              child: Text(
                _enabled ? _enabledSub : _disabledSub,
                style: TextStyle(
                    fontSize: 11,
                    color: _enabled ? primary : theme.textSecondary),
              ),
            ),
          ]),
        ),
        Switch.adaptive(
          value:  _enabled,
          onChanged: _toggle,
          activeTrackColor: primary,
        ),
      ]),
    );
  }
}
