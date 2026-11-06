# MoneyMesh

**All Your Money in One Place.**

MoneyMesh is a tracking-first personal finance app built with Flutter. It helps users view bank accounts, record transactions, understand income and expenses, and see which payment apps are linked to each bank account.

## Project status
Early frontend prototype using clearly labelled sample data. No real bank or payment-app connection is implemented. This repository contains the Flutter application source; Android platform runner files are generated locally with Flutter.

## Core principles
- Tracking only: no transfers, payments, scan-and-pay, or money movement.
- Count each bank account once, even when linked to multiple payment apps.
- Show the source payment app and underlying bank account for transactions.
- Never collect bank passwords, OTPs, or UPI PINs.
- Sample balances and transactions are illustrative, not real account data.

## Planned modules
Dashboard · Transactions · Income & Expense · Budgets · Reports · Settings

## Technology
- Flutter / Dart — Android app
- Supabase / PostgreSQL — planned backend
- Python / FastAPI — planned statement-processing layer

Backend and bank integrations are not enabled in this starter.

## Run locally (Windows)
1. Install Flutter and Android Studio, then configure an Android emulator or connect an Android device with USB debugging.
2. Clone this repository and open its folder in VS Code.
3. Generate the Android runner files:
   ```bash
   flutter create . --platforms=android
   ```
4. Fetch packages and run:
   ```bash
   flutter pub get
   flutter run
   ```

## Run tests
```bash
flutter test
```

## Roadmap
1. Build the local demo experience.
2. Add transaction entry, editing, filtering, and summaries.
3. Add secure authentication and database persistence.
4. Add CSV statement import and duplicate detection.
5. Evaluate authorized account-data integrations only when eligible partnerships and consent flows are available.

No license has been added yet; all rights are reserved by default.

## Project documentation
- [Product plan and delivery roadmap](docs/PRODUCT_PLAN.md)
- [Data model and security rules](docs/SECURITY_AND_DATA_MODEL.md)
