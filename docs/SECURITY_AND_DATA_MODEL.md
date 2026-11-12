# MoneyMesh Data Model and Security Rules

## Core entities

### FinancialAccount
- id: stable internal UUID
- ownerId: authenticated user ID when cloud sync is enabled
- institutionName
- displayName
- maskedAccountReference (optional; never full credentials)
- currencyCode (default INR)
- openingBalanceMinor
- currentBalanceMinor or a derived ledger balance, with one documented source of truth
- status: active or archived
- createdAt, updatedAt

### PaymentApp
- id
- ownerId
- name (for example, Google Pay, PhonePe, or Paytm)
- status
- createdAt, updatedAt

### PaymentAppAccountLink
- id
- paymentAppId
- financialAccountId
- optional user-defined label
- createdAt

A payment app link references an existing FinancialAccount. It must never create a second copy of that account or contribute another balance.

### Transaction
- id
- ownerId
- financialAccountId
- amountMinor (positive integer; no floating-point money arithmetic)
- currencyCode
- direction: income or expense
- categoryId
- description
- occurredAt
- sourceType: manual or statement_import
- sourcePaymentAppId (nullable)
- externalReference (nullable)
- importBatchId (nullable)
- createdAt, updatedAt

### Budget
- id
- ownerId
- categoryId (or an explicit all-categories scope)
- limitMinor
- period: weekly or monthly
- startDate
- status
- createdAt, updatedAt

### ImportBatch
- id
- ownerId
- sourceFileName (display metadata only; avoid retaining the original file by default)
- importedAt
- status
- totalRows, acceptedRows, rejectedRows
- account mapping and reversible import outcome

## Money and balance rules

- Store monetary values as integer minor units (paise for INR), never binary floating-point.
- Use an explicit currency code for every account and transaction.
- Do not sum unlike currencies without an explicit, timestamped conversion rate.
- Combined INR balance is the sum of active, unique INR financial accounts.
- PaymentAppAccountLink rows are relationships only; they never contribute to totals.
- Decide and document whether current balance is user-entered or ledger-derived before implementing reconciliation.
- A transaction must belong to exactly one financial account.
- Transfers between a user's own accounts, if later supported for tracking, must be represented as a matched pair and excluded from income/expense totals. No transfer execution is permitted.

## Duplicate detection

Prefer a bank/provider transaction ID when supplied by an authorized statement source. Otherwise compute a conservative fingerprint from account ID, normalized date/time, amount in minor units, direction, normalized description, and source. Do not silently discard ambiguous matches; show them for user review.

## Security and privacy

- Never collect bank login credentials, OTPs, UPI PINs, card PINs, or security answers.
- Keep Supabase service-role keys and all backend secrets server-side only.
- Enable Row Level Security on every user-owned table before exposing it to a client.
- Policies must scope reads, writes, updates, and deletes to the authenticated owner.
- Validate amounts, dates, ownership, and account references on the server.
- Use least-privilege access and avoid logging transaction descriptions or sensitive account data.
- The local app provides an explicit JSON export and a confirmation-gated delete-all flow, with SQLite secure-delete mode and database compaction. These are best-effort database cleanup controls, not a guarantee of forensic erasure from flash storage or external backups. Cloud data export/deletion and account-level cloud retention must be implemented before cloud sync or a multi-user release.
- Do not claim RBI/Account Aggregator compliance without qualified legal and regulatory review.

## Implementation note

This document is a target design for cloud security. Local SQLite repositories, CSV import, JSON export and confirmation-gated local deletion exist in the offline MVP branch; Supabase, cloud RLS, cloud backup, server validation and financial-data integrations are not implemented.
