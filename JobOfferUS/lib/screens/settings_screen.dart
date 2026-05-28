import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/language/language_notifier.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setSpanish(bool value) async {
    isSpanishNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value ? 'es' : 'en');
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isSp, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSp ? 'Ajustes' : 'Settings'),
          ),
          bottomNavigationBar: const CalcwiseAdFooter(),
          body: SafeArea(
            top: false,
            child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // ── Premium ───────────────────────────────────────
              const _SectionHeader('Premium'),
              _Card(
                child: ValueListenableBuilder<bool>(
                  valueListenable: freemiumService.hasFullAccessNotifier,
                  builder: (ctx, isPremium, _) => isPremium
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_rounded,
                              color: CalcwiseSemanticColors.warnIcon),
                          title: Text(
                            isSp ? '¡Eres Premium!' : 'You\'re Premium!',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          _Tile(
                            icon: Icons.workspace_premium_rounded,
                            label: isSp ? 'Obtener Premium' : 'Get Premium',
                            onTap: () => showModalBottomSheet(
                              context: ctx,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => PaywallHard(
                                isSpanish: isSp,
                                onPurchase: () async {
                                  Navigator.pop(ctx);
                                  IAPService.instance.buy();
                                },
                                onDismiss: () => Navigator.pop(ctx),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          _Tile(
                            icon: Icons.restore_rounded,
                            label:
                                isSp ? 'Restaurar compra' : 'Restore Purchase',
                            onTap: () => IAPService.instance.restore(),
                          ),
                        ]),
                ),
              ),

              // ── Language ──────────────────────────────────────
              _SectionHeader(isSp ? 'Idioma' : 'Language'),
              _Card(
                child: Row(children: [
                  Expanded(
                    child: _LangChip(
                      label: 'English',
                      selected: !isSp,
                      onTap: () => _setSpanish(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smPlus),
                  Expanded(
                    child: _LangChip(
                      label: 'Español',
                      selected: isSp,
                      onTap: () => _setSpanish(true),
                    ),
                  ),
                ]),
              ),

              // ── Appearance ────────────────────────────────────
              _SectionHeader(isSp ? 'Apariencia' : 'Appearance'),
              _Card(
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeService.notifier,
                  builder: (_, __, ___) {
                    final ct = CalcwiseTheme.of(context);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(themeModeService.icon, color: AppTheme.primary),
                      title: Text(
                        themeModeService.label(isSpanish: isSp),
                        style: TextStyle(color: ct.textPrimary),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: ct.textSecondary),
                      onTap: () => themeModeService.toggle(),
                    );
                  },
                ),
              ),

              // ── Links ─────────────────────────────────────────
              _SectionHeader(isSp ? 'Más' : 'More'),
              _Card(
                child: Column(children: [
                  _Tile(
                    icon: Icons.privacy_tip_rounded,
                    label: isSp ? 'Política de privacidad' : 'Privacy Policy',
                    onTap: () => _launch('https://calqwise.com/privacy'),
                  ),
                  const Divider(height: 1),
                  CalcwiseRateAppTile(
                      label: isSp ? 'Calificar la app' : 'Rate the App'),
                  const Divider(height: 1),
                  _Tile(
                    icon: Icons.email_rounded,
                    label: isSp ? 'Contactar soporte' : 'Contact Support',
                    onTap: () => _launch('mailto:support@calqwise.com'),
                  ),
                  const Divider(height: 1),
                  _Tile(
                    icon: Icons.apps_rounded,
                    label:
                        isSp ? 'Más apps de CalqWise' : 'More apps by CalqWise',
                    onTap: () => _launch(
                        'https://play.google.com/store/apps/developer?id=CalqWise'),
                  ),
                ]),
              ),

              // ── Legal Disclaimer ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.lg,
                ),
                child: Text(
                  isSp
                      ? 'Esta aplicación es solo para fines informativos. Consulte a un profesional financiero antes de tomar decisiones laborales o de compensación.'
                      : 'This app is for informational purposes only. Consult a financial professional before making any career or compensation decisions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: CalcwiseTheme.of(context).textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: child,
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smPlus),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : ct.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.mdPlus),
          border: Border.all(
            color: selected ? AppTheme.primary : ct.cardBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ct.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: AppTextSize.body,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.primary, size: 22),
      title: Text(label,
          style: TextStyle(color: ct.textPrimary, fontSize: AppTextSize.body)),
      trailing: Icon(Icons.chevron_right_rounded, color: ct.textSecondary),
      onTap: onTap,
    );
  }
}
