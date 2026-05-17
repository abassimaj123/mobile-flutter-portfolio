# 🔐 CI/CD Pipeline — Flutter Portfolio

## Overview

This portfolio now has a **strict CI/CD pipeline** that prevents bugs from landing in main/develop:

- ✅ **Flutter Analyze** — Strict lint rules on all 22+ apps
- ✅ **Dart Format** — Consistent code style  
- ✅ **Flutter Test** — Unit tests for critical apps
- ✅ **GitHub Actions** — Automated on every PR and push

---

## What Changed

### 1. Lint Rules (analysis_options.yaml)

**Copied to every app.** Includes strict rules like:
- `avoid_ambiguous_imports` — Catches naming conflicts (the bug we fixed)
- `missing_required_param` → error (not warning)
- `missing_return` → error
- `cancel_subscriptions` — Prevents memory leaks
- And 30+ other strict rules

**Run locally:**
```bash
cd AutoLoan
flutter analyze --fatal-infos
```

### 2. GitHub Actions (.github/workflows/ci.yml)

**Runs on:**
- Every push to `main` or `develop`
- Every pull request

**Jobs:**
1. **Analyze** — `flutter analyze --fatal-infos` on all apps
2. **Format** — `dart format --set-exit-if-changed` on all apps
3. **Test** — `flutter test` on apps with tests
4. **Check Result** — Summary job (must pass all)

**View results:**
→ GitHub Actions tab → "CI — Lint, Format, Test"

### 3. Test Suite

Created test utilities and basic tests:

**Files:**
- `MortgageUS/test/common/test_utils.dart` — Helper functions
- `MortgageUS/test/init_test.dart` — App initialization tests
- `MortgageUS/test/screens_basic_test.dart` — Screen tests
- `AutoLoan/test/init_test.dart` — AutoLoan tests
- `MortgageUK/test/init_test.dart` — MortgageUK tests

**Run locally:**
```bash
cd MortgageUS
flutter test
```

---

## How to Use

### Before submitting a PR:

```bash
# Navigate to your app
cd MortgageUS

# 1. Run analyze (catches errors before push)
flutter analyze --fatal-infos

# 2. Format your code
dart format lib test

# 3. Run tests (if your app has them)
flutter test

# 4. If all pass, commit and push!
git add .
git commit -m "Your message"
git push origin feature-branch
```

### What happens next:

1. GitHub Actions automatically runs all checks
2. If any check fails, you'll see a ❌ on your PR
3. Fix the issues locally, push again
4. Once all checks pass ✅, your PR is ready to merge

---

## Common Issues & Fixes

### Issue: `avoid_ambiguous_imports` error

**Cause:** Two imports expose the same class (e.g., local `SectionCard` + `calcwise_core` `SectionCard`)

**Fix:** Add `hide` to the calcwise_core import:
```dart
import 'package:calcwise_core/calcwise_core.dart' hide SectionCard, ResultTile;
```

### Issue: `missing_required_param` error

**Cause:** Required parameter not provided to a constructor

**Fix:** Provide the parameter:
```dart
// ❌ Wrong
MyWidget()

// ✅ Right
MyWidget(requiredParam: value)
```

### Issue: Format check fails

**Cause:** Code doesn't match Dart formatting standard

**Fix:** Auto-format:
```bash
dart format lib test
```

### Issue: Test fails

**Cause:** Widget not found or assertion failed

**Fix:** 
1. Check that the widget/text actually exists in your screen
2. Use `pumpAndSettle()` to wait for animations
3. Debug with `tester.getSemantics()`

---

## Next Steps

### Phase 1 (DONE ✅)
- [x] Lint rules applied to all apps
- [x] GitHub Actions workflow created
- [x] Basic test utilities created
- [x] Tests for MortgageUS, AutoLoan, MortgageUK

### Phase 2 (Soon)
- [ ] Add tests to all 22 apps (5-10 basic tests each)
- [ ] Set up code coverage reporting
- [ ] Configure branch protection rules (require CI to pass)

### Phase 3 (Next quarter)
- [ ] Add integration tests for critical flows
- [ ] Add performance benchmarks
- [ ] Add automated Dart docs generation

---

## Files Changed

```
.github/workflows/ci.yml                     — GitHub Actions workflow
analysis_options.yaml                        — Global lint config (copied to all apps)
MortgageUS/test/common/test_utils.dart      — Shared test utilities
MortgageUS/test/init_test.dart              — Initialization tests
MortgageUS/test/screens_basic_test.dart     — Screen tests
AutoLoan/test/common/test_utils.dart        — Test utilities
AutoLoan/test/init_test.dart                — Initialization tests
AutoLoan/test/screens_basic_test.dart       — Screen tests
MortgageUK/test/common/test_utils.dart      — Test utilities
MortgageUK/test/init_test.dart              — Initialization tests
MortgageUK/test/screens_basic_test.dart     — Screen tests
```

---

## Questions?

For issues or questions about the CI/CD pipeline, check:
1. GitHub Actions logs (→ Actions tab)
2. Run checks locally first: `flutter analyze --fatal-infos`
3. Check `.github/workflows/ci.yml` for the exact commands being run
