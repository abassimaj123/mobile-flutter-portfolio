import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import '../core/engines/offer_engine.dart';
import '../core/freemium/freemium_service.dart';
import '../core/language/language_notifier.dart';
import '../core/freemium/iap_service.dart';
import '../core/services/analytics_service.dart';
import '../core/models/job_offer.dart';
import '../core/theme/app_theme.dart';
import '../widgets/offer_form_card.dart';
import '../widgets/paywall_hard.dart';
import '../main.dart' show paywallSession, isSpanishNotifier;
import 'comparison_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _formKey = GlobalKey<FormState>();

  JobOffer _offerA = const JobOffer(
      label: 'Offer A',
      baseSalary: 85000,
      stateCode: 'CA',
      city: 'San Francisco, CA');
  JobOffer _offerB = const JobOffer(
      label: 'Offer B', baseSalary: 90000, stateCode: 'TX', city: 'Austin, TX');
  JobOffer _offerC = const JobOffer(
      label: 'Offer C', baseSalary: 0, stateCode: 'NY', city: 'New York, NY');
  bool _showOfferC = false;

  Timer? _debounce;
  bool _wasPremium = false;

  bool get _canCompare => _offerA.baseSalary > 0 && _offerB.baseSalary > 0;

  @override
  void initState() {
    super.initState();
    _wasPremium = freemiumService.hasFullAccess;
    AnalyticsService.instance.logScreenView('home');
    iapErrorNotifier.addListener(_onIapError);
    freemiumService.isPremiumNotifier.addListener(_onPremiumChange);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) async => await paywallSession.recordSession());
  }

  @override
  void dispose() {
    iapErrorNotifier.removeListener(_onIapError);
    freemiumService.isPremiumNotifier.removeListener(_onPremiumChange);
    _debounce?.cancel();
    super.dispose();
  }

  void _onPremiumChange() {
    final now = freemiumService.hasFullAccess;
    if (now && !_wasPremium && mounted) {
      showPremiumWelcomeSnackBar(context, isSpanish: isSpanishNotifier.value);
    }
    _wasPremium = now;
  }

  void _onIapError() {
    final msg = iapErrorNotifier.value;
    if (msg == null || !mounted) return;
    showIapErrorSnackBar(context, msg);
    iapErrorNotifier.value = null;
  }

  void _debouncedCompare() {
    HapticFeedback.mediumImpact();
    if (!(_formKey.currentState?.validate() ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSpanishNotifier.value
              ? 'Por favor corrige los errores'
              : 'Please fix errors before comparing'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(AppDuration.page, _compare);
  }

  void _compare() async {
    if (!_canCompare) return;
    // 3-offer comparison is a premium-only feature (hard gate).
    // 2-offer comparison is always free — no session gating.
    if (_showOfferC && !freemiumService.hasFullAccess) {
      _showPaywall();
      return;
    }
    AnalyticsService.instance.logCalculationCompleted(params: {
      'salary_a': _offerA.baseSalary.round(),
      'salary_b': _offerB.baseSalary.round(),
    });
    AnalyticsService.instance.logOfferCompared();
    final offerCForCompare = _showOfferC ? _offerC : null;
    final result = OfferEngine.compare(_offerA, _offerB, offerCForCompare);
    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ComparisonScreen(
          offerA: _offerA,
          offerB: _offerB,
          offerC: offerCForCompare,
          result: result),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: AppDuration.base,
    ));
  }

  void _showPaywall() {
    final isSp = isSpanishNotifier.value;
    AnalyticsService.instance.logPaywallViewed('soft_gate_home');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallHard(
        isSpanish: isSp,
        onPurchase: () async {
          Navigator.pop(context);
          AnalyticsService.instance.logPaywallConverted('soft_gate_home');
          IAPService.instance.buy();
          _compare();
        },
        onDismiss: () {
          AnalyticsService.instance.logPaywallDismissed();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSp, __) {
        final screens = [
          _ComparisonTab(
            formKey: _formKey,
            offerA: _offerA,
            offerB: _offerB,
            offerC: _offerC,
            showOfferC: _showOfferC,
            canCompare: _canCompare,
            isSp: isSp,
            isPremium: freemiumService.hasFullAccess,
            onOfferAChanged: (o) => setState(() => _offerA = o),
            onOfferBChanged: (o) => setState(() => _offerB = o),
            onOfferCChanged: (o) => setState(() => _offerC = o),
            onToggleOfferC: () => setState(() => _showOfferC = !_showOfferC),
            onCompare: _debouncedCompare,
            appBar: _appBar(isSp),
          ),
          HistoryScreen(onSwitchToCompare: () => setState(() => _tabIndex = 0)),
        ];

        return Scaffold(
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: IndexedStack(index: _tabIndex, children: screens),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: const CalcwiseAdFooter(),
              ),
              NavigationBar(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    selectedIcon: const Icon(Icons.compare_arrows_rounded),
                    label: isSp ? 'Comparar' : 'Compare',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bookmark_border_rounded),
                    selectedIcon: const Icon(Icons.bookmark_rounded),
                    label: isSp ? 'Historial' : 'History',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(bool isSp) {
    final ct = CalcwiseTheme.of(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            borderRadius: BorderRadius.circular(AppRadius.mdPlus),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: const Icon(Icons.compare_arrows_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                  text: 'Job Offer',
                  style: TextStyle(
                      color: ct.textPrimary,
                      fontSize: AppTextSize.subtitleSm,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4)),
              TextSpan(
                  text: ' US',
                  style: TextStyle(
                      color: ct.accent,
                      fontSize: AppTextSize.subtitleSm,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4)),
            ]),
          ),
        ),
      ]),
      actions: [
        CalcwiseAppBarActions(
          freemium: freemiumService,
          session: paywallSession,
          onSettings: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const SettingsScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: AppDuration.base,
            ),
          ),
          onPremium: () => PaywallHard.show(context),
        ),
      ],
    );
  }
}

// ── Comparison tab widget ─────────────────────────────────────────────────────

class _ComparisonTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final JobOffer offerA;
  final JobOffer offerB;
  final JobOffer offerC;
  final bool showOfferC;
  final bool canCompare;
  final bool isSp;
  final bool isPremium;
  final ValueChanged<JobOffer> onOfferAChanged;
  final ValueChanged<JobOffer> onOfferBChanged;
  final ValueChanged<JobOffer> onOfferCChanged;
  final VoidCallback onToggleOfferC;
  final VoidCallback onCompare;
  final PreferredSizeWidget appBar;

  const _ComparisonTab({
    required this.formKey,
    required this.offerA,
    required this.offerB,
    required this.offerC,
    required this.showOfferC,
    required this.canCompare,
    required this.isSp,
    required this.isPremium,
    required this.onOfferAChanged,
    required this.onOfferBChanged,
    required this.onOfferCChanged,
    required this.onToggleOfferC,
    required this.onCompare,
    required this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: _body(context),
      bottomNavigationBar: _cta(context),
    );
  }

  Widget _body(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: formKey,
            child: CalcwisePageEntrance(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero ──────────────────────────────────────────────────────
                CalcwiseStaggerItem(
                    index: 0,
                    child: _HeroBanner(isSp: isSp, showOfferC: showOfferC)),
                const SizedBox(height: AppSpacing.xxl),
                ValueListenableBuilder<bool>(
                  valueListenable: freemiumService.hasFullAccessNotifier,
                  builder: (_, isPremium, __) => Column(children: [
                    CalcwiseStaggerItem(
                        index: 1,
                        child: OfferFormCard(
                          isOfferA: true,
                          value: offerA,
                          isPremium: isPremium,
                          isSpanish: isSp,
                          onChanged: onOfferAChanged,
                        )),
                    const SizedBox(height: AppSpacing.lg),
                    _VsDivider(),
                    const SizedBox(height: AppSpacing.lg),
                    CalcwiseStaggerItem(
                        index: 2,
                        child: OfferFormCard(
                          isOfferA: false,
                          value: offerB,
                          isPremium: isPremium,
                          isSpanish: isSp,
                          onChanged: onOfferBChanged,
                        )),
                    const SizedBox(height: AppSpacing.lg),
                    // ── Offer C toggle / card ────────────────────────
                    if (showOfferC) ...[
                      _VsDivider(isSecond: true),
                      const SizedBox(height: AppSpacing.lg),
                      CalcwiseStaggerItem(
                          index: 3,
                          child: OfferFormCard(
                            isOfferA: false,
                            isOfferC: true,
                            value: offerC,
                            isPremium: isPremium,
                            isSpanish: isSp,
                            onChanged: onOfferCChanged,
                          )),
                      const SizedBox(height: AppSpacing.sm),
                      _RemoveOfferCChip(isSp: isSp, onTap: onToggleOfferC),
                    ] else
                      Center(
                          child: _AddOfferCChip(
                              isSp: isSp, onTap: onToggleOfferC)),
                  ]),
                ),
              ],
            )), // CalcwisePageEntrance closes
          ), // Form closes
        ),
      ), // ConstrainedBox + Center closes
    );
  }

  Widget _cta(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        color: ct.surface,
        border: Border(top: BorderSide(color: ct.cardBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: InkWell(
        onTap: canCompare ? onCompare : null,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppDuration.base,
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey<bool>(canCompare),
                height: 56,
                decoration: BoxDecoration(
                  gradient: canCompare
                      ? AppTheme.ctaGradient
                      : LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.3),
                            AppTheme.offerBDeep.withValues(alpha: 0.3),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: canCompare ? AppTheme.ctaShadow : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows_rounded,
                        color: canCompare
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isSp ? 'Comparar ofertas' : 'Compare Offers',
                      style: TextStyle(
                        color: canCompare
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        fontSize: AppTextSize.bodyXl,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isPremium) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.star_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 16),
                    ],
                  ],
                ),
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                isSp ? 'Función premium' : 'Premium feature',
                style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool isSp;
  final bool showOfferC;
  const _HeroBanner({required this.isSp, this.showOfferC = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryDark.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _LetterBadge('A', AppTheme.offerALight, AppTheme.offerADeep),
            const SizedBox(width: AppSpacing.sm),
            _LetterBadge('B', AppTheme.offerBLight, AppTheme.offerBDeep),
            if (showOfferC) ...[
              const SizedBox(width: AppSpacing.sm),
              _LetterBadge('C', AppTheme.offerCLight, AppTheme.offerCDeep),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.smPlus, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.verified_rounded, color: AppTheme.accent, size: 13),
                SizedBox(width: AppSpacing.xs),
                Text('2026',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: AppTextSize.sm,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isSp
                ? 'Compara tu compensación real'
                : 'Know your true compensation',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTextSize.titleMd,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isSp
                ? 'Salario neto, impuestos, beneficios y más'
                : 'After-tax salary, benefits, commute & more',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: AppTextSize.body,
                height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(spacing: AppSpacing.sm, runSpacing: 6, children: [
            _HChip(isSp ? '51 estados' : '51 States'),
            _HChip('FICA · IRS 2026'),
            _HChip(isSp ? '3 Ofertas' : '3 Offers',
                color: AppTheme.offerC.withValues(alpha: 0.22)),
            _HChip(isSp ? '⏰ Vencimiento' : '⏰ Deadlines',
                color: AppTheme.accent.withValues(alpha: 0.25)),
          ]),
        ],
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final String l;
  final Color bg, border;
  const _LetterBadge(this.l, this.bg, this.border);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: bg.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Center(
        child: Text(l,
            style: TextStyle(
                color: bg,
                fontSize: AppTextSize.bodyLg,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _HChip extends StatelessWidget {
  final String t;
  final Color? color;
  const _HChip(this.t, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smPlus, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(t,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ── Add/Remove Offer C chips ──────────────────────────────────────────────────

class _AddOfferCChip extends StatelessWidget {
  final bool isSp;
  final VoidCallback onTap;
  const _AddOfferCChip({required this.isSp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.smPlus),
        decoration: BoxDecoration(
          color: AppTheme.offerC.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
              color: AppTheme.offerC.withValues(alpha: 0.35),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignOutside),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_circle_outline, color: AppTheme.offerC, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isSp ? 'Agregar 3ª oferta' : 'Add 3rd offer',
            style: const TextStyle(
              color: AppTheme.offerC,
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}

class _RemoveOfferCChip extends StatelessWidget {
  final bool isSp;
  final VoidCallback onTap;
  const _RemoveOfferCChip({required this.isSp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.smPlus),
        decoration: BoxDecoration(
          color: ct.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: ct.cardBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.remove_circle_outline, color: ct.textSecondary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isSp ? 'Quitar 3ª oferta' : 'Remove 3rd offer',
            style: TextStyle(
              color: ct.textSecondary,
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── VS divider ────────────────────────────────────────────────────────────────

class _VsDivider extends StatelessWidget {
  final bool isSecond;
  const _VsDivider({this.isSecond = false});

  @override
  Widget build(BuildContext context) {
    final leftColor = isSecond ? AppTheme.offerBDeep : AppTheme.offerADeep;
    final rightColor = isSecond ? AppTheme.offerCDeep : AppTheme.offerBDeep;
    return Row(children: [
      Expanded(
          child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, leftColor],
                ),
              ))),
      const SizedBox(width: AppSpacing.sm),
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: isSecond ? AppTheme.offerCGradient : AppTheme.ctaGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isSecond ? AppTheme.offerCDeep : AppTheme.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Center(
          child: Text('VS',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              )),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
          child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rightColor, Colors.transparent],
                ),
              ))),
    ]);
  }
}
