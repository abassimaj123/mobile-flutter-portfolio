#!/usr/bin/env python3
"""
update_skill.py — Applique toutes les sections manquantes au SKILL.md
Usage: python3 /d/mob/.qa/update_skill.py
"""

SKILL_PATH = 'C:/Users/DALI/.claude/skills/flutter-portfolio-master/SKILL.md'

# ── Section 1 : Compléter le portfolio map (TaxeCA, TaxUS, TaxUK) ──
PORTFOLIO_OLD = '| SalaryApp US | #DC2626 | #DC2626 | flavor us |'
PORTFOLIO_NEW = '''| SalaryApp US | #DC2626 | #DC2626 | flavor us |
| TaxeCA | N/A | N/A | **Kotlin natif** — no calcwise_core |
| TaxUS | N/A | N/A | **Kotlin natif** — no calcwise_core |
| TaxUK | N/A | N/A | **Flutter** — calcwise_core TODO |'''

# ── Section 2 : Constantes critiques ── (après le bloc Paths)
PATHS_OLD = '''### Paths

```
D:\\mob\\<AppName>\\                     ← single-flavor app root
D:\\mob\\<AppName>\\android\\app\\src\\main\\res\\   ← shared Android resources
D:\\mob\\<AppName>\\android\\app\\src\\<flavor>\\res\\ ← per-flavor resources (AutoLoan, SalaryApp)
D:\\mob\\packages\\calcwise_core\\        ← shared Flutter library
```

---'''

PATHS_NEW = '''### Paths

```
D:\\mob\\<AppName>\\                     ← single-flavor app root
D:\\mob\\<AppName>\\android\\app\\src\\main\\res\\   ← shared Android resources
D:\\mob\\<AppName>\\android\\app\\src\\<flavor>\\res\\ ← per-flavor resources (AutoLoan, SalaryApp)
D:\\mob\\packages\\calcwise_core\\        ← shared Flutter library
```

### Constantes critiques (ne jamais perdre)

| Constante | Valeur |
|-----------|--------|
| AdMob Publisher ID | `ca-app-pub-5379540026739666` |
| Privacy Policy URL | `https://calqwise.com/privacy` |
| IAP Product ID | `premium_upgrade` (identique toutes les apps) |
| Device test (Android 14) | Samsung SM-S921W — serial `RFCX20661WW` |
| MortgageUS (référence) | `com.mortgageus.calculator` — modèle à répliquer |

### Multi-langue par marché

| Marché | Langues | Parité clés |
|--------|---------|-------------|
| US | EN + ES | 100% EN↔ES obligatoire |
| CA | EN + FR | 100% EN↔FR obligatoire |
| UK | EN only | N/A |

- `attachBaseContext` override dans MainActivity pour appliquer la locale AVANT chargement des resources
- Aucun string hardcodé dans l'UI (sauf symboles universels : $, %, ÷, noms de langues)
- Commande de vérification parité : `grep -c '"' lib/l10n/intl_en.arb` vs `grep -c '"' lib/l10n/intl_fr.arb`

### Disclaimer légal (obligatoire dans TOUTES les apps)

Afficher dans Settings ou About :
> "This app is for informational purposes only. Consult a financial professional."
> (FR) "Cette application est à titre informatif seulement."

---'''

# ── Section 3 : Processus 4 phases (avant Clean Code Protocol) ──
SECTION1_OLD = '## 1. Clean Code Protocol'
SECTION1_NEW = '''## 0. Processus 4 Phases — Cadre Obligatoire

> **Règle d'or : Phase 1 avant Phase 2. Jamais greffer la monétisation sur une app pas encore compétitive.**

### Phase 1 — App solide et compétitive

Objectif : **égal ou supérieur** à la concurrence, avant toute monétisation.

1. **Audit vs concurrence sur 3 axes**
   - Fonctionnel : calcule-t-on autant/mieux que la concurrence ?
   - UI/UX : aussi propre ou plus ? (splash 1+2, couleurs, icons)
   - Expérience : flow, onboarding, friction perçue
2. **Combler les gaps** — égaler puis dépasser
3. **Coup de magie** — une feature / présentation que la concurrence n'a pas
4. **Validation code + design** — flutter analyze 0 issues, design-audit 3 phases
5. **Tests avec vraies valeurs** — taux officiels, exemples gouvernementaux, pas de valeurs inventées
6. **Parité langue 100%** — EN↔FR ou EN↔ES, aucune clé manquante
7. **iOS portability prep** — logique métier séparée de l'UI Flutter (calculateurs = pure Dart)
8. **Edge cases** — null, zéro, négatif, très grands nombres, tous gérés
9. **Performance** — calc < 100ms, pas de memory leak
10. **Test sur device réel** — Samsung RFCX20661WW minimum

### Phase 2 — Monétisation calibrée

1. Premium gates sur : historique > 5, PDF export, features avancées
2. **Toujours les deux** : rewarded video (60min) ET IAP permanent
3. Paywall progressif (sessions 1-3 libre → 4-6 soft → 7+ hard)
4. `recordAction()` sur tab switch ET calcul (les deux)
5. Soft = "Maybe later" visible et normal / Hard = "Not now" dépriorisé mais présent
6. Test IAP sandbox sur vrai device (pas émulateur)
7. Build release + ProGuard activé → vérifier BillingClient/AdMob/Firebase survivent
8. AAB < 50 MB
9. Simuler crash → vérifier Crashlytics 24h après

### Phase 3 — Validation finale (avant soumission)

1. `flutter analyze --no-pub` → 0 issues
2. Code dead supprimé (imports, variables orphelines, branches mortes)
3. Disclaimer légal présent dans Settings
4. Privacy policy URL `https://calqwise.com/privacy` dans Settings
5. `targetSdk` à jour (année en cours)
6. Screenshots Play Store : 8 minimum (calcul, résultat, dark mode, premium)
7. Version code bumped, versionName sémantique (1.0.0)
8. Internal Testing → inviter 1-2 testeurs réels
9. Skills : `owasp-mobile-security-checker`, `simplify`, `vanity-engineering-review`

### Phase 4 — Production et monitoring

1. `google-services.json` = production Firebase (pas test)
2. AdMob IDs = production (remplacer XXXXXXXXXX)
3. RevenueCat keys réelles (HELOCApp + JobOfferUS — ⚠️ placeholders actuels)
4. Data safety form soumise dans Play Console
5. **Rollout progressif** : 10% → 25% → 50% → 100% (24h monitoring par étape)
6. **Rollback si crash > 1%** — immédiat, pas d'hésitation
7. Post-launch : Crashlytics daily, Firebase KPIs, Play Store reviews (répondre < 24h)

### Cadence d'audit régulier — 7 axes obligatoires

1. **Fonctionnalités** — quoi manque vs. concurrents ?
2. **Affaires / marché** — prix juste ? segment à cibler ?
3. **Monétisation** — taux conversion freemium→premium ?
4. **IAP** — timeout, erreurs silencieuses, restore fonctionnel ?
5. **Firebase** — analytics complets ? funnel visible ? Crashlytics clean ?
6. **Expérience client** — reviews Play Store, friction onboarding, UX paywall
7. **Concurrence** — nouvelles apps ? pricing shift ? features manquantes ?

### Adaptation par complexité d'app

| Type | Approche |
|------|----------|
| App simple (TaxeCA) | share texte suffit, 1 feature premium, paywall basique |
| App complexe (MortgageUS) | PDF A4 + amortissement + comparateur, paywall riche 4 features |
| Règle | Complexité feature ∝ Complexité calcul |

---

## 1. Clean Code Protocol'''

# ── Section 4 : ProGuard + APK size (dans Build & Deploy) ──
PROGUARD_OLD = '### Device\n- Samsung SM-S921W, serial: `RFCX20661WW`'
PROGUARD_NEW = '''### ProGuard — Classes critiques à préserver

```proguard
# proguard-rules.pro — à ajouter dans chaque app
-keep class com.android.billingclient.** { *; }
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.firebase.** { *; }
-keep class io.flutter.** { *; }
-dontwarn com.google.android.gms.**
```

### Vérification taille AAB avant upload

```bash
# Vérifier < 50 MB :
ls -lh build/app/outputs/bundle/release/app-release.aab
# Si > 50MB → flutter build appbundle --release --split-per-abi
```

### Device
- Samsung SM-S921W, serial: `RFCX20661WW`'''

# ── Section 5 : Rollout strategy (dans Production Build) ──
ROLLOUT_OLD = '### Checklist pre-upload AAB'
ROLLOUT_NEW = '''### Rollout Strategy — Play Store

```
Internal Testing (invited)
  → 10% production    (24h monitoring)
  → 25%               (24h monitoring)
  → 50%               (24h monitoring)
  → 100%              (monitoring continu)

Rollback immédiat si :
  - crash rate > 1% dans Crashlytics
  - ANR rate > 0.5%
  - review négatives soudaines
```

**Post-launch monitoring quotidien (première semaine) :**
- Crashlytics → 0 nouveau crash
- Firebase Analytics → funnel conversion normal
- AdMob → impressions normales, pas de ban signal
- Play Store reviews → répondre dans les 24h

### Checklist pre-upload AAB'''

# ── Section 6 : MortgageUS référence (dans calcwise_core) ──
REFERENCE_OLD = '### After calcwise_core Change'
REFERENCE_NEW = '''### MortgageUS — Modèle de référence à répliquer

Architecture cible pour toutes les apps du portfolio :

| Élément | MortgageUS | Standard |
|---------|-----------|---------|
| Navigation | `NavigationBar` 5 tabs | ≥ 3 tabs |
| AppBar | Titre + Premium badge + Settings | identique |
| Save | SQLite `sqflite`, FIFO 5 free → illimité premium | identique |
| Share | Texte gratuit / PDF premium | adapter selon complexité |
| Gate amortisation | 24 mois free, complet premium | adapter |
| Gate historique | 5 entrées free (FIFO delete) | identique |
| Gate PDF | Hard paywall | si app complexe |
| Analytics | 11 events minimum + `is_premium` user property | identique |
| IAP | `premium_upgrade`, timeout 10s, iapErrorNotifier surfacé | identique |
| ReviewService | Post-achat + post X calculs, clé `review_v2` | identique |

**Fichiers clés de référence** : `D:/mob/MortgageUS/lib/`
- `main.dart` — shell, paywall trigger, langue toggle
- `core/freemium/paywall_service.dart` — session/action counter
- `core/freemium/iap_service.dart` — IAP flow complet
- `core/services/analytics_service.dart` — events

### After calcwise_core Change'''

# ──────────────────────────────────────────────────────────────────

import sys

def apply_replacement(content, old, new, label):
    if old in content:
        content = content.replace(old, new, 1)
        print(f'  OK {label}')
        return content, True
    else:
        print(f'  SKIP {label} -- marqueur introuvable (deja applique?)')
        return content, False

print('=== update_skill.py — Flutter Portfolio Master ===')
print(f'Fichier : {SKILL_PATH}')
print()

with open(SKILL_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

original = content
changes = 0

content, ok = apply_replacement(content, PORTFOLIO_OLD, PORTFOLIO_NEW, 'Portfolio map (TaxeCA/TaxUS/TaxUK)')
if ok: changes += 1

content, ok = apply_replacement(content, PATHS_OLD, PATHS_NEW, 'Constantes critiques + multi-langue + disclaimer')
if ok: changes += 1

content, ok = apply_replacement(content, SECTION1_OLD, SECTION1_NEW, 'Processus 4 phases (§0 avant §1)')
if ok: changes += 1

content, ok = apply_replacement(content, PROGUARD_OLD, PROGUARD_NEW, 'ProGuard + APK size check')
if ok: changes += 1

content, ok = apply_replacement(content, ROLLOUT_OLD, ROLLOUT_NEW, 'Rollout strategy 10→100%')
if ok: changes += 1

content, ok = apply_replacement(content, REFERENCE_OLD, REFERENCE_NEW, 'MortgageUS modèle de référence')
if ok: changes += 1

# §13 Post-Edit Validation
if '## 13. Post-Edit Validation' not in content:
    old13 = '## 13. Production Build'
    new13 = '''## 13. Post-Edit Validation — Protocole Obligatoire

### Règle absolue
> **Après toute modification dans D:/mob/<App>/ → valider avant de passer à l'app suivante.**

### Gate obligatoire
```bash
cd /d/mob/<AppName> && flutter analyze --no-pub 2>&1 | tail -3
# calcwise_core uniquement : dart analyze lib/ && flutter test
```

### Hooks actifs (depuis ~/.claude/hooks/)
- PostToolUse → trace app modifiée silencieusement (< 5ms)
- Stop → flutter analyze toutes apps touchées → D:/mob/.qa/regression_log.md

### Règles
- ❌ JAMAIS committer avec issues
- ❌ JAMAIS passer à la phase suivante avec issues
- ❌ JAMAIS modifier calcwise_core sans flutter test vert

---

## 13. Production Build'''
    content, ok = apply_replacement(content, old13, new13, '§13 Post-Edit Validation')
    if ok: changes += 1

print()
if changes > 0:
    with open(SKILL_PATH, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'DONE: {changes} section(s) ajoutees au skill')
else:
    print('SKIP: Aucun changement applique -- tout etait peut-etre deja present')

# ── Renumbering pass ──
print()
print('--- Renumbering pass ---')
with open(SKILL_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

renumber = [
    ('## 8. Common Mistakes to Never Repeat',            '## 13. Common Mistakes to Never Repeat'),
    ('## 13. Post-Edit Validation',                      '## 14. Post-Edit Validation'),
    ('## 13. Production Build & Release (AAB + Signing)','## 15. Production Build & Release (AAB + Signing)'),
    ('## 14. QA',                                        '## 16. QA'),
    ('## 15. Analytics Validation & KPIs Business',      '## 17. Analytics Validation & KPIs Business'),
]

rn_changes = 0
for old, new in renumber:
    if old in content:
        content = content.replace(old, new, 1)
        print(f'  OK {old[:55]}')
        rn_changes += 1
    else:
        print(f'  SKIP {old[:55]}')

if rn_changes > 0:
    with open(SKILL_PATH, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'DONE: {rn_changes} numeros corriges')

# ── Verification finale ──
import re
print()
print('--- Sections finales ---')
sections = re.findall(r'^## \d+\..*', content, re.MULTILINE)
for s in sections:
    print(f'  {s}')
print(f'\nTaille totale: {len(content):,} chars')
print()
print('Termine.')
