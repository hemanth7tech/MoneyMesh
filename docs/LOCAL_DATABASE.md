# MoneyMesh Local Database

## Current implementation

MoneyMesh uses on-device SQLite through sqflite. The database is created on first access in the platform application database directory. The UI reads from repositories rather than using in-memory account and transaction demo lists.

Tables:

- financial_accounts: one row per real bank account, with opening balance in paise and active/archived status.
- payment_apps: payment app names.
- payment_app_account_links: links an app to an existing account; links never create or add another balance.
- transactions: income and expense entries stored as positive integer paise, with direction, category, date and source.
- categories: reusable income/expense categories.
- budgets: weekly or monthly budget definitions.
- import_batches: statement import audit metadata.

## Repository workflows

- Account repository: create, update, archive and list accounts. Current balances are calculated as opening balance + income − expenses.
- Transaction repository: create, edit, delete, search, filter by account/category/direction/date, and check exact duplicates.
- Category repository: seed defaults and create custom categories.
- Budget repository: create/archive weekly and monthly budgets and calculate current-period progress.
- Payment-app repository: seed a known app directory and link/unlink apps to existing account IDs.
- CSV importer: parses a local CSV, maps each row to an active account name or ID, imports valid rows and skips exact duplicates.
- Data management service: export local records to JSON or delete all local finance data after user confirmation.

## Integrity rules

- INR amounts are stored in paise as integers, not floating-point values.
- Transaction amounts must be positive; direction determines income or expense.
- Foreign keys are enabled for each database connection.
- Unique constraints prevent duplicate payment-app/account links.
- Deleting an account with transaction history is restricted; the UI archives accounts instead.
- Indexes support account/date transaction history queries.
- Payment-app links are relationships only and are excluded from balance aggregation.

## CSV format and limitations

Required headers: date, description, amount, direction, account. Optional header: category.

Dates currently normalize to the calendar day at midnight; intraday timestamps/time zones are not retained. Account matching is case-insensitive exact matching against an existing account display name or ID. Duplicate matching uses account, amount, direction, normalized description and normalized timestamp; ambiguous transactions are not automatically merged.

CSV content is processed locally. The original file is not stored by default; only import-batch metadata and imported ledger rows are stored.

## Current limitations

- No Supabase cloud sync, authentication or backend is configured.
- No live bank or payment-app connection is active.
- No payment execution or money movement exists.
- Currency selection and foreign-exchange conversion are not implemented; current UI and budgets assume INR.
- PDF statement import is not implemented.
- The Android build and on-device persistence still require final device verification before release.

## Setup

Run:

```bash
flutter pub get
flutter analyze
flutter test
```

The first database access creates the SQLite file automatically; no manual database installation is needed.
