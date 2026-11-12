# MoneyMesh Product Plan

**Product promise:** All Your Money in One Place.

## Product scope

MoneyMesh is a tracking-first Android personal-finance app. It consolidates a user's manually entered or lawfully imported financial records into one clear view. It does not move money.

### Non-negotiable boundaries

- No payments, transfers, scan-and-pay, add-money, or payment initiation.
- Never request or store bank passwords, OTPs, UPI PINs, card PINs, or internet-banking credentials.
- A bank account is the canonical balance-bearing entity. Payment apps are linked channels, not separate balances.
- Never add the same bank account twice to the combined balance because it appears in multiple UPI apps.
- Demo data must be visibly identified as illustrative.
- Imported records must retain their source and import timestamp.

## Delivery sequence

### Phase 0 — Foundation and product rules
- Confirm app scope, security boundaries, architecture, and data ownership.
- Keep the app buildable as a Flutter Android project.
- Separate presentation, domain models, and persistence.

### Phase 1 — Useful offline MVP
- Dashboard with combined balance from unique accounts.
- Bank-account management: add, edit, archive, and update opening/current balance.
- Payment-app directory with links to existing bank-account IDs.
- Transaction management: add, edit, delete, search, filter, and categorize.
- Income and expense summaries with date ranges.
- Budget creation and progress indicators.
- Settings, currency/date preferences, and demo-data controls.
- Local persistence so user-entered records survive app restarts.
- Empty, loading, validation, and error states.

### Phase 2 — Import and data quality
- CSV statement import with preview and field mapping.
- Duplicate detection using stable source identifiers where available, otherwise a conservative fingerprint.
- Import history, rejected-row explanations, and reversible import batches.
- Explicit account matching before imported transactions affect a balance.
- PDF statement extraction only after a privacy-conscious local/secure processing design is chosen.

### Phase 3 — Secure backend
- Supabase project and PostgreSQL schema.
- Authentication and per-user row-level security.
- Backup/sync strategy and migration handling.
- Secrets kept out of the mobile client and repository.
- Automated database policy tests.

### Phase 4 — Authorized integrations
- Evaluate regulated Account Aggregator / FIU partnerships and consent requirements in India.
- Do not scrape banking apps or use private/unofficial UPI APIs.
- Display source, consent status, and last-updated time for any authorized data.
- Never promise continuous real-time balance refresh unless the provider actually supports it.

### Phase 5 — Release readiness
- Unit, widget, integration, and security tests.
- Accessibility, small-screen, offline, and performance checks.
- Privacy policy, terms, data deletion/export, and support contact.
- Signed Android build and release checklist.

## Initial acceptance criteria

- Combined balance equals the sum of active unique bank accounts only.
- Linking one bank account to multiple payment apps does not change the combined balance.
- A transaction has one canonical account ID and may record a source payment app.
- Income and expenses are not double-counted across imported and manually entered records.
- User-created data persists locally in the offline MVP.
- No screen suggests that demo balances are live bank data.
- No money-movement capability exists in the app.

## Current implementation status

The offline MVP implementation branch contains SQLite-backed accounts and transactions, categories, payment-app links, weekly/monthly budgets, current-month insights, local CSV import, JSON export and confirmation-gated local deletion. The Android project runner/build, real-device behavior, and the latest database-backed widget tests still require verification before release.

Not implemented: Supabase authentication or cloud sync, live bank/payment-app connections, PDF import, foreign-currency conversion, server-side security policies, automated backups, signed release builds or regulatory integrations.

Do not treat this branch as released until the PR is reviewed, CI passes on its latest head, and an Android debug build is verified.
