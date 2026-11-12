# MoneyMesh

**All Your Money in One Place.**

MoneyMesh is a tracking-first personal finance app built with Flutter. It consolidates manually entered and locally imported records into an offline dashboard for accounts, transactions, budgets and spending insights.

## Current project status

MoneyMesh is being developed as an **offline-first MVP**. Account records, transactions, categories, budgets and payment-app links are stored in an on-device SQLite database. CSV statement import, local JSON export and local data deletion are included in the current implementation branch.

The offline MVP does not connect to banks or payment apps. It does not initiate payments, transfers or UPI transactions. Cloud sync and authorized financial-data integrations are future work, not active features.

## Core principles

- Tracking only: no payments, transfers, scan-and-pay, add-money or money movement.
- A bank account is the balance-bearing entity. Payment apps are linked channels, not separate balances.
- Combined balances use opening balance plus ledger income and expenses, counting each account once.
- Money is stored as integer paise to avoid floating-point arithmetic.
- Never request bank passwords, OTPs, UPI PINs, card PINs or internet-banking credentials.
- Imported transactions retain their source type and import-batch reference.

## Implemented offline workflows

- Add, edit and archive bank accounts.
- Record, edit and delete income and expense transactions.
- Search transactions and filter by account or direction.
- Organize records with built-in and custom categories.
- View current-month income, expenses, net activity and spending by category.
- Create weekly and monthly budgets with progress.
- Link Google Pay, PhonePe, Paytm or BHIM as channels to existing bank accounts without duplicating balances.
- Import CSV statements locally, map rows to an existing account name or ID, skip exact duplicates and review rejected-row messages.
- Export local finance data as JSON and delete all local data after confirmation.

## Technology

- Flutter / Dart — Android application
- SQLite / sqflite — local persistence
- material_ui — Material widgets
- file_picker — local CSV import and JSON export
- Supabase / PostgreSQL — planned future cloud backend; not configured

## CSV import format

The current importer expects a header row with these columns:

| Column | Required | Accepted values |
|---|---|---|
| date | Yes | YYYY-MM-DD or DD/MM/YYYY |
| description | Yes | Transaction description |
| amount | Yes | Rupees with up to 2 decimal places |
| direction | Yes | income/credit/cr or expense/debit/dr |
| account | Yes | Existing MoneyMesh account display name or internal ID |
| category | No | Category name; a matching or new category is used |

CSV rows are processed locally on the device. The current implementation normalizes imported dates to the date (midnight) and uses a conservative exact-match duplicate check; review the import summary before relying on the imported ledger.

## Run locally

1. Install Flutter and Android Studio, then configure an Android emulator or connect an Android device with USB debugging.
2. Clone this repository and open the folder in VS Code.
3. Generate the Android runner files if they are not present:
   ```bash
   flutter create . --platforms=android
   ```
4. Fetch dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

## Run checks

```bash
flutter analyze
flutter test
```

## Roadmap

1. Complete offline MVP validation on Android devices and improve import preview/reconciliation.
2. Add date-range reports, recurring budget management and data-quality tools.
3. Design secure optional cloud sync with Supabase authentication and per-user RLS.
4. Evaluate authorized Account Aggregator / FIU integrations only after eligibility, consent and compliance review.

No license has been added yet; all rights are reserved by default.

## Project documentation

- [Product plan and delivery roadmap](docs/PRODUCT_PLAN.md)
- [Data model and security rules](docs/SECURITY_AND_DATA_MODEL.md)
- [Local database implementation](docs/LOCAL_DATABASE.md)
