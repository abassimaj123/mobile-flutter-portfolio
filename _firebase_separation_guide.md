# Firebase Séparation — 4 Apps partageant le même appId

## Problème
AutoLoan, rideprofit, RentalExpenses, JobOfferUS utilisent le même Firebase project/appId.
Les analytics sont cross-polluées → impossible de comparer les funnels par app.

## Action requise (console Firebase + terminal)

### Étape 1 : Créer les Firebase Android Apps dans la console

1. Ouvrir https://console.firebase.google.com → sélectionner le projet `android-app-54282`
2. Project settings → Tes apps → **Add app** → Android
3. Créer UNE app par package :

| App | Android package |
|-----|----------------|
| AutoLoan | Vérifier dans `android/app/build.gradle` (`applicationId`) |
| rideprofit | Vérifier dans `android/app/build.gradle` |
| RentalExpenses | Vérifier dans `android/app/build.gradle` |
| JobOfferUS | Vérifier dans `android/app/build.gradle` |

4. Télécharger le `google-services.json` pour CHAQUE app

### Étape 2 : Placer les google-services.json

Pour chaque app, remplacer :
```
D:\mob\{AppName}\android\app\google-services.json
```
par le fichier téléchargé pour cette app spécifique.

### Étape 3 : Reconfigurer flutterfire (optionnel mais recommandé)

Dans chaque app directory :
```bash
cd D:/mob/AutoLoan
flutterfire configure --project=android-app-54282

cd D:/mob/rideprofit
flutterfire configure --project=android-app-54282

cd D:/mob/RentalExpenses
flutterfire configure --project=android-app-54282

cd D:/mob/JobOfferUS
flutterfire configure --project=android-app-54282
```

Sélectionner le bon Android app (par package name) quand demandé.
Cela régénère `lib/core/firebase/firebase_options.dart` avec le bon `appId`.

### Étape 4 : Vérifier la séparation

Après rebuild et launch de chaque app :
- Firebase console → Analytics → App Overview
- Chaque app doit apparaître séparément dans le sélecteur d'app

## Résultat attendu

Après séparation :
- Funnel de conversion par app distinct
- Audiences Firebase par app
- Crashlytics séparé (crash rate par app)
- Revenue analytics par app

## Note sur les user properties

Le `app_name` user property est déjà défini dans `CalcwiseAnalytics.initialize()` :
```dart
await _fa.setUserProperty(name: 'app_name', value: appName);
```
Cela permet de filtrer dans BigQuery même AVANT la séparation des appIds.
Mais la séparation propre reste nécessaire pour les audiences et les funnels.
