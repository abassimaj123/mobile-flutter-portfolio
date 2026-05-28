/// Represents a single job offer's input parameters.
class JobOffer {
  final String label; // Display name e.g. "Offer A"
  final String company; // Company name (optional)
  final double baseSalary; // Annual gross salary USD (always stored annual)
  final String stateCode; // 2-letter US state e.g. 'CA'
  final String city; // City name for CoL adjustment (premium)
  final double bonusPct; // Annual bonus as % of base (e.g. 10 = 10%)
  final double k401kMatchPct; // Employer 401k match % (e.g. 4 = 4%)
  final double k401kUpToPct; // Match applies up to X% of salary
  final double healthInsuranceSavings; // Annual $ vs buying on marketplace
  final double dentalVisionSavings; // Annual $ dental+vision savings
  final int ptoDays; // Paid time off days per year
  final double annualRsuValue; // Annual RSU/stock grant value USD
  final double commuteMilesPerDay; // One-way miles (0 if remote)
  final double annualRaisePct; // Expected annual raise % for projection
  final bool isRemote; // Eliminates commute cost
  final double signingBonus; // One-time signing/sign-on bonus USD
  // Feature 1: hourly toggle
  final bool isHourly; // Show salary as hourly rate in UI (stored annual)
  final double hoursPerWeek; // Hours per week when isHourly = true
  // Feature 2: deadline
  final DateTime? deadline; // Offer deadline (optional)

  const JobOffer({
    this.label = 'Offer',
    this.company = '',
    required this.baseSalary,
    this.stateCode = 'TX',
    this.city = 'Dallas, TX',
    this.bonusPct = 0,
    this.k401kMatchPct = 0,
    this.k401kUpToPct = 0,
    this.healthInsuranceSavings = 0,
    this.dentalVisionSavings = 0,
    this.ptoDays = 10,
    this.annualRsuValue = 0,
    this.commuteMilesPerDay = 0,
    this.annualRaisePct = 3,
    this.isRemote = false,
    this.signingBonus = 0,
    this.isHourly = false,
    this.hoursPerWeek = 40.0,
    this.deadline,
  });

  JobOffer copyWith({
    String? label,
    String? company,
    double? baseSalary,
    String? stateCode,
    String? city,
    double? bonusPct,
    double? k401kMatchPct,
    double? k401kUpToPct,
    double? healthInsuranceSavings,
    double? dentalVisionSavings,
    int? ptoDays,
    double? annualRsuValue,
    double? commuteMilesPerDay,
    double? annualRaisePct,
    bool? isRemote,
    double? signingBonus,
    bool? isHourly,
    double? hoursPerWeek,
    DateTime? deadline,
    bool clearDeadline = false,
  }) =>
      JobOffer(
        label: label ?? this.label,
        company: company ?? this.company,
        baseSalary: baseSalary ?? this.baseSalary,
        stateCode: stateCode ?? this.stateCode,
        city: city ?? this.city,
        bonusPct: bonusPct ?? this.bonusPct,
        k401kMatchPct: k401kMatchPct ?? this.k401kMatchPct,
        k401kUpToPct: k401kUpToPct ?? this.k401kUpToPct,
        healthInsuranceSavings:
            healthInsuranceSavings ?? this.healthInsuranceSavings,
        dentalVisionSavings: dentalVisionSavings ?? this.dentalVisionSavings,
        ptoDays: ptoDays ?? this.ptoDays,
        annualRsuValue: annualRsuValue ?? this.annualRsuValue,
        commuteMilesPerDay: commuteMilesPerDay ?? this.commuteMilesPerDay,
        annualRaisePct: annualRaisePct ?? this.annualRaisePct,
        isRemote: isRemote ?? this.isRemote,
        signingBonus: signingBonus ?? this.signingBonus,
        isHourly: isHourly ?? this.isHourly,
        hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
      );
}
