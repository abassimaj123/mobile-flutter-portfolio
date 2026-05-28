/// Freemium service — re-exports CalcwiseFreemium from library.
library;

import 'package:calcwise_core/calcwise_core.dart';

final freemiumService = CalcwiseFreemium(
  appKey: 'parksmart',
  rewardedDurationMinutes: MonetizationConfig.rewardedDurationMinutes,
  maxRewardedPerDay: MonetizationConfig.maxRewardedPerDay,
  freeCalculationLimit: MonetizationConfig.freeCalculationLimit,
);
