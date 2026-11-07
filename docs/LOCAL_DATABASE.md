# MoneyMesh Local Database

## Current implementation

MoneyMesh has an on-device SQLite database foundation using sqflite and path. The database file is created on first access in the platform application database directory.

Tables:
- financial_accounts: one row per real bank account.
- payment_apps: payment app names.
- payment_app_account_links: links an app to an existing account; links never create or add another balance.
- transactions: income and expense entries stored as integer minor units.
- categories: reusable income/expense categories.
- budgets: weekly or monthly budget definitions.
- import_batches: statement import audit metadata.

## Integrity rules

- INR amounts are stored in paise as integers, not floating-point values.
- Transaction amounts must be positive; direction determines income or expense.
- Foreign keys are enabled for each database connection.
- Unique constraints prevent duplicate payment-app/account links.
- Deleting an account with transaction history is restricted.
- Indexes support account/date transaction history queries.

## Current limitations

This is the local database foundation, not a completed app integration. The existing dashboard and manual-entry dialog still use in-memory demo state until the next integration step. No Supabase cloud sync, bank connection, payment execution, or statement import is active.

## Setup

Run flutter pub get, then flutter test. The first database access creates the SQLite file automatically; no manual database installation is needed.
