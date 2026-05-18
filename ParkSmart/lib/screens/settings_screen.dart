import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/language/language_notifier.dart';
import '../core/services/freemium_service.dart';
import '../core/services/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setLanguage(bool isSpanish) async {
    isSpanishNotifier.value = isSpanish;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', isSpanish ? 'es' : 'en');
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
        final ct = CalcwiseTheme.of(context);
        final sEn = AppStringsEN();
        final sEs = AppStringsES();
        return CalcwiseSettingsScaffold(
          title: isSp ? sEs.navSettings : sEn.navSettings,
          children: [
            // ── Language ──────────────────────────────────────────────────
            CalcwiseSettingsSection(
              title: isSp ? sEs.language : sEn.language,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Expanded(
                      child: _LangButton(
                        label: 'English',
                        selected: !isSp,
                        onTap: () => _setLanguage(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LangButton(
                        label: 'Español',
                        selected: isSp,
                        onTap: () => _setLanguage(true),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
            Divider(height: 1, color: ct.cardBorder),

            // ── Appearance ────────────────────────────────────────────────
            CalcwiseSettingsSection(
              title: isSp ? 'Apariencia' : 'Appearance',
              children: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeModeService.notifier,
                  builder: (_, __, ___) => CalcwiseSettingsTile(
                    icon: themeModeService.icon,
                    label: themeModeService.label(isSpanish: isSp),
                    onTap: () => themeModeService.toggle(),
                  ),
                ),
              ],
            ),
            Divider(height: 1, color: ct.cardBorder),

            // ── Premium ───────────────────────────────────────────────────
            ValueListenableBuilder<bool>(
              valueListenable: freemiumService.isPremiumNotifier,
              builder: (ctx, isPremium, _) => CalcwiseSettingsSection(
                title: isSp ? sEs.premium : sEn.premium,
                children: isPremium
                    ? [
                        ListTile(
                          leading: const Icon(Icons.verified_rounded,
                              color: AppTheme.accent),
                          title: Text(
                              isSp ? 'Premium activado' : 'Premium Active',
                              style: TextStyle(color: ct.textPrimary)),
                          subtitle: Text(
                              isSp
                                  ? 'Todas las funciones desbloqueadas'
                                  : 'All features unlocked',
                              style: TextStyle(color: ct.textSecondary)),
                        ),
                      ]
                    : [
                        CalcwiseSettingsTile(
                          icon: Icons.star_rounded,
                          label: isSp ? sEs.buyPremium : sEn.buyPremium,
                          subtitle: isSp
                              ? 'Sin anuncios · Acceso completo'
                              : 'Remove ads · Full access',
                          trailing: isSp ? sEs.price : sEn.price,
                          onTap: () => IAPService.instance.buy(),
                        ),
                        CalcwiseSettingsTile(
                          icon: Icons.restore_rounded,
                          label: isSp ? 'Restaurar compra' : 'Restore Purchase',
                          onTap: () => IAPService.instance.restore(),
                        ),
                        if (kDebugMode)
                          CalcwiseSettingsTile(
                            icon: Icons.bug_report_rounded,
                            label: 'Force Premium (DEV)',
                            // ignore: invalid_use_of_visible_for_testing_member
                            onTap: () => freemiumService.debugUnlockPremium(),
                          ),
                      ],
              ),
            ),
            Divider(height: 1, color: ct.cardBorder),

            // ── Support ───────────────────────────────────────────────────
            CalcwiseSettingsSection(
              title: 'Support',
              children: [
                CalcwiseRateAppTile(
                    label: isSp ? 'Calificar ParkSmart' : 'Rate ParkSmart'),
                CalcwiseSettingsTile(
                  icon: Icons.privacy_tip_rounded,
                  label: isSp ? 'Política de privacidad' : 'Privacy Policy',
                  onTap: () => _launch('https://calqwise.com/privacy'),
                ),
                CalcwiseSettingsTile(
                  icon: Icons.email_rounded,
                  label: isSp ? 'Contactar soporte' : 'Contact Support',
                  onTap: () => _launch('mailto:support@calqwise.com'),
                ),
              ],
            ),
            Divider(height: 1, color: ct.cardBorder),

            // ── About ─────────────────────────────────────────────────────
            CalcwiseSettingsSection(
              title: isSp ? 'Acerca de' : 'About',
              children: [
                CalcwiseSettingsTile(
                  icon: Icons.apps_rounded,
                  label: 'CalqWise',
                  subtitle: isSp
                      ? 'Descubre nuestras otras apps'
                      : 'Discover our other apps',
                  onTap: () => _launch('https://calqwise.com'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                isSp
                    ? 'Datos de estacionamiento proporcionados solo con fines informativos. '
                        'Verifique siempre la señalización local antes de estacionar. '
                        'ParkSmart no se hace responsable de multas.'
                    : 'Parking data provided for informational purposes only. '
                        'Always check local signage before parking. '
                        'ParkSmart is not liable for any parking fines.',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  fontStyle: FontStyle.italic,
                  color: ct.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : ct.surfaceHigh,
          border: Border.all(color: selected ? AppTheme.accent : ct.cardBorder),
          borderRadius: BorderRadius.circular(AppRadius.mdPlus),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ct.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
