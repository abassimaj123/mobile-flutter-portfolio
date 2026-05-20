/// Calcwise Core — shared services, theme, and UI components.
/// Services: Firebase/Crashlytics, AdMob, IAP, Freemium
/// UI: CalcwiseTheme (per-app brand colors), PaywallSoft, PaywallHard, InsightCard
library;

// Services
export 'services/crashlytics_service.dart';
export 'services/analytics_service.dart';
export 'services/revenuecat_service.dart';
export 'services/remote_config_service.dart';
export 'services/freemium_service.dart';
export 'services/iap_service.dart';
export 'services/ad_service.dart';
export 'services/theme_mode_service.dart';
export 'services/paywall_session_service.dart';
export 'services/review_service.dart';
export 'services/rate_watch_service.dart';

// Config
export 'config/monetization_config.dart';

// Utils
export 'utils/currency_input_formatter.dart';
export 'utils/percent_input_formatter.dart';
export 'utils/consent_helper.dart';
export 'utils/snackbar_helpers.dart';

// Theme
export 'theme/calcwise_theme.dart';
export 'theme/theme_factory.dart';
export 'theme/semantic_colors.dart';

// Design Tokens
export 'theme/tokens/tokens.dart';
export 'theme/chart_tokens.dart';

// Models
export 'models/insight.dart';

// Widgets
export 'widgets/paywall_soft.dart';
export 'widgets/paywall_hard.dart';
export 'widgets/insight_card.dart';
export 'widgets/calcwise_splash.dart';
export 'widgets/page_entrance.dart';
export 'widgets/calcwise_onboarding.dart';
export 'widgets/calcwise_app_bar_actions.dart';
export 'widgets/calcwise_ad_footer.dart';
export 'widgets/calcwise_reward_ad_sheet.dart';
export 'widgets/rate_watch_card.dart';
export 'widgets/calcwise_empty_state.dart';
export 'widgets/calcwise_loading_state.dart';
export 'widgets/calcwise_error_state.dart';
export 'widgets/calcwise_rate_app_tile.dart';
export 'widgets/calcwise_info_tooltip.dart';
export 'widgets/comparison_view.dart';
export 'widgets/pdf_brand_helper.dart';
export 'widgets/reverse_solve_card.dart';
export 'widgets/calcwise_hero_card.dart';
export 'widgets/calcwise_settings.dart';
export 'widgets/section_card.dart';
