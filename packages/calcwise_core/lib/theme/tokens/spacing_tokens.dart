/// Calcwise spacing scale — 4pt base grid.
///
/// Usage:
///   SizedBox(height: AppSpacing.md)
///   EdgeInsets.all(AppSpacing.lg)
///   EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm)
class AppSpacing {
  AppSpacing._();

  /// 2px — hair gap
  static const double xxs = 2.0;

  /// 4px — micro gap
  static const double xs = 4.0;

  /// 8px — tight gap (between list items, icon+label)
  static const double sm = 8.0;

  /// 10px — between sm and md
  static const double smPlus = 10.0;

  /// 12px — default gap (card rows, section items)
  static const double md = 12.0;

  /// 14px — between md and lg
  static const double mdPlus = 14.0;

  /// 16px — comfortable gap (card padding, screen edges)
  static const double lg = 16.0;

  /// 20px — generous gap
  static const double xl = 20.0;

  /// 24px — section separator
  static const double xxl = 24.0;

  /// 28px — between xxl and xxxl
  static const double xxlPlus = 28.0;

  /// 32px — screen-level section gap
  static const double xxxl = 32.0;

  /// 80px — bottom list padding to clear CalcwiseAdFooter height
  static const double listBottomInset = 80.0;
}
