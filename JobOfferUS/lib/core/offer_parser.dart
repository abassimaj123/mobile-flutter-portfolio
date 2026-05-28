/// Lightweight regex-based parser that extracts salary/bonus/equity/benefits
/// from a pasted offer-letter text. No LLM — runs entirely on-device.
///
/// Designed as an MVP "AI-style" extractor: the heuristics cover the most
/// common phrasings used in US offer letters. PDF parsing is deferred to v2.
library;

class ParsedOffer {
  final double? baseSalary;
  final double? signOnBonus;
  final double? annualBonus; // $ amount (computed from % if needed)
  final double? annualBonusPct; // raw percentage if found
  final double? equityValue; // annualized RSU/stock $ value
  final String? equityVesting;
  final double? matchPct; // 401k match %
  final int? ptoDays;
  final String? location;
  final String? title;
  final String? company;
  final Map<String, String> extras;

  const ParsedOffer({
    this.baseSalary,
    this.signOnBonus,
    this.annualBonus,
    this.annualBonusPct,
    this.equityValue,
    this.equityVesting,
    this.matchPct,
    this.ptoDays,
    this.location,
    this.title,
    this.company,
    this.extras = const {},
  });

  /// True when nothing usable was extracted.
  bool get isEmpty =>
      baseSalary == null &&
      signOnBonus == null &&
      annualBonus == null &&
      annualBonusPct == null &&
      equityValue == null &&
      matchPct == null &&
      ptoDays == null &&
      title == null &&
      company == null;

  int get fieldCount {
    int n = 0;
    if (baseSalary != null) n++;
    if (signOnBonus != null) n++;
    if (annualBonus != null || annualBonusPct != null) n++;
    if (equityValue != null) n++;
    if (matchPct != null) n++;
    if (ptoDays != null) n++;
    if (title != null) n++;
    if (company != null) n++;
    return n;
  }
}

class OfferParser {
  static ParsedOffer parse(String rawText) {
    if (rawText.trim().isEmpty) return const ParsedOffer();

    // Normalize whitespace and lowercase for matching.
    final text = rawText.replaceAll(RegExp(r'\s+'), ' ');
    final lower = text.toLowerCase();

    final baseSalary = _parseBaseSalary(lower);
    final signOn = _parseSignOn(lower);
    final bonusResult = _parseBonus(lower, baseSalary);
    final equity = _parseEquity(lower);
    final match = _parseMatch(lower);
    final pto = _parsePto(lower);
    final title = _parseTitle(text);
    final company = _parseCompany(text);

    return ParsedOffer(
      baseSalary: baseSalary,
      signOnBonus: signOn,
      annualBonus: bonusResult.$1,
      annualBonusPct: bonusResult.$2,
      equityValue: equity,
      matchPct: match,
      ptoDays: pto,
      title: title,
      company: company,
    );
  }

  // ── Base salary ───────────────────────────────────────────────────────────

  static double? _parseBaseSalary(String t) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:base\s+salary|annual\s+salary|annual\s+base|gross\s+salary|salary\s+of)\s*[:\-]?\s*\$?\s*([\d,]+(?:\.\d+)?)\s*(?:k\b)?',
      ),
      RegExp(
        r'\$\s*([\d,]+(?:\.\d+)?)\s*(?:per\s+year|/\s*year|/\s*yr|annually|yearly)',
      ),
      RegExp(
        r'salary[:\s]+\$?\s*([\d,]+(?:\.\d+)?)\s*(?:k\b)?',
      ),
    ];
    for (final p in patterns) {
      for (final m in p.allMatches(t)) {
        final raw = m.group(1);
        if (raw == null) continue;
        var v = double.tryParse(raw.replaceAll(',', ''));
        if (v == null) continue;
        // Handle "$120k" shorthand.
        final tailIdx = m.end;
        if (tailIdx < t.length && t[tailIdx - 1] == 'k') {
          v *= 1000;
        } else if (v < 1000) {
          v *= 1000; // "120" near "salary" → 120k
        }
        if (v >= 10000 && v < 10000000) return v;
      }
    }
    return null;
  }

  // ── Sign-on bonus ─────────────────────────────────────────────────────────

  static double? _parseSignOn(String t) {
    final p = RegExp(
      r'(?:sign[-\s]?on|signing|hiring|joining)\s+bonus[^$\d]{0,30}\$?\s*([\d,]+(?:\.\d+)?)\s*(k\b)?',
    );
    final m = p.firstMatch(t);
    if (m == null) return null;
    var v = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (v == null) return null;
    if (m.group(2) != null) v *= 1000;
    if (v < 100) return null;
    return v;
  }

  // ── Annual bonus (returns ($, %)) ─────────────────────────────────────────

  static (double?, double?) _parseBonus(String t, double? base) {
    // Percentage form: "target bonus of 15%" / "15% annual bonus"
    final pctPat = RegExp(
      r'(?:target\s+bonus|annual\s+bonus|performance\s+bonus|bonus\s+target)\s*(?:of|is|:)?\s*(\d{1,2}(?:\.\d+)?)\s*%',
    );
    final pctAlt = RegExp(
        r'(\d{1,2}(?:\.\d+)?)\s*%\s+(?:annual\s+|target\s+|performance\s+)?bonus');

    double? pct;
    final m1 = pctPat.firstMatch(t) ?? pctAlt.firstMatch(t);
    if (m1 != null) pct = double.tryParse(m1.group(1)!);

    // Dollar form: "annual bonus of $10,000"
    double? amount;
    final amtPat = RegExp(
      r'(?:annual\s+bonus|target\s+bonus|performance\s+bonus)[^$\d%]{0,20}\$\s*([\d,]+(?:\.\d+)?)\s*(k\b)?',
    );
    final m2 = amtPat.firstMatch(t);
    if (m2 != null) {
      var v = double.tryParse(m2.group(1)!.replaceAll(',', ''));
      if (v != null) {
        if (m2.group(2) != null) v *= 1000;
        amount = v;
      }
    }

    if (amount == null && pct != null && base != null) {
      amount = base * pct / 100.0;
    }
    return (amount, pct);
  }

  // ── Equity (RSU / stock) ──────────────────────────────────────────────────

  static double? _parseEquity(String t) {
    final patterns = [
      RegExp(
        r'(?:rsu|restricted\s+stock|equity\s+grant|stock\s+grant|equity)[^$\d]{0,30}\$\s*([\d,]+(?:\.\d+)?)\s*(k\b)?',
      ),
      RegExp(
        r'\$\s*([\d,]+(?:\.\d+)?)\s*(k\b)?\s+(?:in\s+)?(?:rsu|equity|restricted\s+stock|stock\s+grant)',
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(t);
      if (m == null) continue;
      var v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v == null) continue;
      if (m.group(2) != null) v *= 1000;
      if (v >= 500) return v;
    }
    return null;
  }

  // ── 401k match ────────────────────────────────────────────────────────────

  static double? _parseMatch(String t) {
    // Pattern 1: "401(k) ... matches/matching ... up to X%"
    final p = RegExp(
      r'401\(?k\)?[^%]{0,40}?(?:match(?:es|ing)?)\s*(?:up\s+to\s+)?(\d{1,2}(?:\.\d+)?)\s*%',
    );
    final m = p.firstMatch(t);
    if (m != null) return double.tryParse(m.group(1)!);

    // Pattern 2: "matches/matching 401(k) contributions up to X%"
    final p2 = RegExp(
      r'(?:match(?:es|ing)?)\s+401\(?k\)?[^%]{0,50}?(?:up\s+to\s+)?(\d{1,2}(?:\.\d+)?)\s*%',
    );
    final m2 = p2.firstMatch(t);
    if (m2 != null) return double.tryParse(m2.group(1)!);

    // Pattern 3: "X% 401(k) match"
    final alt = RegExp(r'(\d{1,2}(?:\.\d+)?)\s*%\s+401\(?k\)?\s*match');
    final m3 = alt.firstMatch(t);
    if (m3 != null) return double.tryParse(m3.group(1)!);
    return null;
  }

  // ── PTO ───────────────────────────────────────────────────────────────────

  static int? _parsePto(String t) {
    final daysPat = RegExp(
      r'(\d{1,3})\s+(?:days?)\s+(?:of\s+)?(?:pto|vacation|paid\s+time\s+off)',
    );
    final m = daysPat.firstMatch(t);
    if (m != null) return int.tryParse(m.group(1)!);

    final weeksPat = RegExp(
      r'(\d{1,2})\s+weeks?\s+(?:of\s+)?(?:pto|vacation|paid\s+time\s+off)',
    );
    final w = weeksPat.firstMatch(t);
    if (w != null) {
      final n = int.tryParse(w.group(1)!);
      if (n != null) return n * 5;
    }
    return null;
  }

  // ── Title (line-based, original case) ─────────────────────────────────────

  static String? _parseTitle(String text) {
    // "Title: Senior Software Engineer" / "job title: X" (case-insensitive label)
    final p = RegExp(
      r'(?:position|title|role|job\s+title)\s*[:\-]\s*([A-Z][A-Za-z0-9 ,/\-&]{2,60})',
      caseSensitive: false,
    );
    final m = p.firstMatch(text);
    if (m != null) return m.group(1)?.trim();

    // "position of Senior Software Engineer at …"
    final p2 = RegExp(
      r'position\s+of\s+([A-Z][A-Za-z0-9 ,/\-&]{2,60?})(?:\s+at\s+|\s+with\s+|\s+in\s+)',
      caseSensitive: false,
    );
    final m2 = p2.firstMatch(text);
    return m2?.group(1)?.trim();
  }

  // ── Company ───────────────────────────────────────────────────────────────

  static String? _parseCompany(String text) {
    // "Company: Acme Corp"
    final label = RegExp(
      r'company\s*[:\-]\s*([A-Z][A-Za-z0-9&\.\- ]{1,40})',
      caseSensitive: false,
    );
    final ml = label.firstMatch(text);
    if (ml != null) return ml.group(1)?.trim();

    // "…at Acme Corp…" near offer keywords
    final p = RegExp(
      r'(?:from|at|with|join(?:ing)?)\s+([A-Z][A-Za-z0-9&\.\- ]{2,40}?)\s+(?:as|is\s+pleased|team|inc\.?|llc|corporation)',
    );
    final m = p.firstMatch(text);
    return m?.group(1)?.trim();
  }
}
