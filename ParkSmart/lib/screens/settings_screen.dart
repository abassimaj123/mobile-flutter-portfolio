import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/freemium_service.dart';
import '../core/services/iap_service.dart';
import '../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return CalcwiseSettingsScaffold(
      title: 'Paramètres',
      children: [
        // ── Affichage ─────────────────────────────────────────────────────
        CalcwiseSettingsSection(
          title: 'Affichage',
          children: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeModeService.notifier,
              builder: (_, __, ___) => CalcwiseSettingsTile(
                icon: themeModeService.icon,
                label: themeModeService.label(isFrench: true),
                onTap: () => themeModeService.toggle(),
              ),
            ),
          ],
        ),
        Divider(height: 1, color: ct.cardBorder),

        // ── Premium ───────────────────────────────────────────────────────
        ValueListenableBuilder<bool>(
          valueListenable: freemiumService.isPremiumNotifier,
          builder: (ctx, isPremium, _) => CalcwiseSettingsSection(
            title: 'Premium',
            children: isPremium
                ? [
                    ListTile(
                      leading: const Icon(Icons.verified_rounded,
                          color: AppTheme.accent),
                      title: Text('Premium activé',
                          style: TextStyle(color: ct.textPrimary)),
                      subtitle: Text(
                          'Toutes les fonctionnalités déverrouillées',
                          style: TextStyle(color: ct.textSecondary)),
                    ),
                  ]
                : [
                    CalcwiseSettingsTile(
                      icon: Icons.star_rounded,
                      label: 'Obtenir Premium',
                      subtitle: 'Supprimer les publicités · Accès complet',
                      trailing: '\$2.99',
                      onTap: () => IAPService.instance.buy(),
                    ),
                    CalcwiseSettingsTile(
                      icon: Icons.restore_rounded,
                      label: "Restaurer l'achat",
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

        // ── Support ───────────────────────────────────────────────────────
        CalcwiseSettingsSection(
          title: 'Support',
          children: [
            const CalcwiseRateAppTile(label: 'Évaluer ParkSmart'),
            CalcwiseSettingsTile(
              icon: Icons.privacy_tip_rounded,
              label: 'Politique de confidentialité',
              onTap: () => _launch('https://calqwise.com/privacy'),
            ),
            CalcwiseSettingsTile(
              icon: Icons.email_rounded,
              label: 'Contacter le support',
              onTap: () => _launch('mailto:support@calqwise.com'),
            ),
          ],
        ),
        Divider(height: 1, color: ct.cardBorder),

        // ── À propos ──────────────────────────────────────────────────────
        CalcwiseSettingsSection(
          title: 'À propos',
          children: [
            CalcwiseSettingsTile(
              icon: Icons.apps_rounded,
              label: 'CalqWise',
              subtitle: 'Découvrez nos autres applications',
              onTap: () => _launch('https://calqwise.com'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Données de stationnement fournies à titre informatif uniquement. '
            'Vérifiez toujours la signalisation locale avant de stationner. '
            'ParkSmart ne peut être tenu responsable d\'une contravention.',
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
  }
}
