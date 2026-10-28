# RentTrack

RentTrack is a rental property and tenant management project built around a MySQL database and a PHP web application. It gives landlords a way to review property occupancy, rent charged, payments recorded, and outstanding or overdue balances. Tenants with login accounts can review their lease balances, invoices, and ledger statements.

The database is the source of truth for leases and financial activity. MySQL constraints, stored procedures, views, and triggers keep the financial records connected and apply key business rules; PHP authenticates users, restricts each dashboard to the signed-in role, displays database information, and submits landlord payment records.

## The problem

Rent is often tracked using notebooks, spreadsheets, bank or mobile-money messages, and separate records kept by landlords and tenants. As a portfolio grows, it becomes harder to reliably answer basic questions:

- Which tenant occupies which unit, and under what lease terms?
- What was charged for each rental month?
- Was a payment complete or partial, and which rent invoice did it settle?
- Which invoices are unpaid or overdue, and how much remains?
- How much rent has a landlord collected, and how many units are occupied?
- Can a tenant check their own payment history and balance?

Records maintained separately can become inconsistent. A payment may be recorded without updating the right invoice, balances may be recalculated differently in different places, and a tenant or landlord may have no shared statement to resolve a dispute.

## The solution

RentTrack connects the property, unit, tenant, lease, invoice, payment, allocation, and ledger records in one relational database. A lease connects a tenant to a unit and captures the rent and payment terms agreed for that tenancy. Invoices represent monthly charges; payments represent money received; payment allocations explain which invoice or invoices were paid. The ledger records debits and credits over time, providing the basis for lease balances and tenant statements.

Landlords can use the web interface to review portfolio summaries and record a payment against one of their tenants' leases. The payment procedure validates the amount, allocates it to the oldest outstanding invoices first, updates invoice payment status, and writes the matching ledger credit in one transaction. If a database rule rejects the operation, the transaction is rolled back rather than leaving only part of the payment recorded.

Tenants can sign in to view their own lease balance, invoice history, and a chronological statement with a running balance. Both dashboards read from database views, so financial summaries are calculated from the underlying records rather than separately maintained totals.

### Current application scope

The PHP interface currently provides login, landlord and tenant dashboards, and landlord payment recording. Monthly invoice generation and late-fee application are implemented as MySQL stored procedures and must be run separately by an authorized database operator; there is not currently a PHP screen or scheduled job for them. The web interface does not currently provide forms for creating or editing properties, units, tenants, or leases. Those records must be inserted and managed through the database until those workflows are added.

## Technology

- **Server-side application:** PHP
- **Database:** MySQL 8.0.16 or newer
- **Database access:** PDO with the MySQL driver and prepared statements
- **Interface:** HTML rendered by PHP and shared CSS
- **Currency display:** UGX

## End-to-end project flow

1. **Create the schema.** `schema.sql` creates the `renttrack` database and its tables, keys, indexes, and data constraints.
2. **Load example records.** `seed.sql` inserts sample users, properties, units, tenants, leases, invoices, payments, allocations, and ledger entries. The sample dataset illustrates occupied and vacant units, partial payments, late fees, and overdue rent.
3. **Create reporting views.** `views.sql` defines reusable queries for lease balances, invoice balances, arrears, occupancy, monthly billed and collected totals, and tenant statements.
4. **Install database business logic.** `triggers.sql` defines the payment, monthly invoice, and late-fee procedures, as well as triggers that enforce lease, allocation, and ledger rules.
5. **Configure and run PHP.** The application reads local database credentials from `app/config.php`, connects through PDO, and starts a PHP session for each user.
6. **Authenticate and show role-specific information.** A successful login stores the account ID and role in the session. Landlord pages filter data by landlord ID; tenant pages filter by the tenant account ID.
7. **Record payments safely.** A landlord submits a payment form. PHP checks the input, CSRF token, and lease ownership before calling `sp_record_payment`. MySQL performs the payment, invoice allocations, status updates, and ledger entry together.
8. **Read updated balances and statements.** Dashboards query the views, which derive totals from invoices, allocations, leases, and ledger entries.

## Database design

The ER diagram is included in [`renttrack.png`](./renttrack.png).

### Core tables and how they relate

| Table | Purpose and relationships |
|---|---|
| `users` | Login accounts and roles (`landlord` or `tenant`). A landlord account owns properties; a tenant account may be connected to a tenant record. Passwords are stored as hashes, not plaintext. |
| `properties` | Property/building records. Each property belongs to a landlord through `landlord_id`. |
| `units` | Rentable spaces within properties. A unit belongs to one property and has a unit number, unit type, monthly rent, and occupancy/maintenance status. Unit numbers are unique within each property. |
| `tenants` | Tenant contact records, linked to a login account by optional, unique `user_id`. A tenant can therefore be registered before receiving an application login. |
| `leases` | Connects a tenant to a unit for a date range. Stores the agreed monthly rent, deposit, rent due day, late-fee amount, and active/ended/terminated status. Rent is copied onto the lease so changing a unit's advertised rent does not silently change an existing agreement. |
| `invoices` | Monthly rent charge for a lease. Each invoice stores its billing month, rent due, due date, late fee, and payment status. A unique constraint allows at most one invoice per lease and billing month. |
| `payments` | Money received for a lease. Records the amount, date, method, optional transaction reference, and user who recorded it. |
| `payment_allocations` | Associates a payment with one or more invoices and stores the amount applied to each. This supports partial payments and a single payment covering several invoices. |
| `ledger` | Append-only financial history per lease. A debit increases the tenant's balance; a credit reduces it. Invoice and late-fee entries are debits; payment entries are credits. The balance is the sum of debits minus credits. |

Foreign keys connect these records and generally restrict deletion of records that have financial history. The schema also validates non-negative rents, deposits, invoice amounts, and late fees; positive payment and allocation amounts; valid due days; and lease date ranges.

### Views: shared reporting calculations

[`views.sql`](./views.sql) centralizes the calculations used by the app and makes them available for direct database queries:

- `v_lease_balances` joins leases to tenants, units, and properties, then totals ledger debits and credits. It returns charged, paid, and remaining balance figures together with landlord and tenant account IDs for dashboard access filtering.
- `v_invoice_summary` calculates each invoice's total due (rent plus late fee), amount paid from allocations, and remaining amount.
- `v_overdue_invoices` selects invoices whose due date has passed and that still have a balance; it includes tenant, property, unit, and days-overdue details.
- `v_property_occupancy` counts total, occupied, vacant, and maintenance units and calculates occupancy percentage per property.
- `v_monthly_collections` groups payment records by landlord and payment month.
- `v_monthly_billed` groups invoice rent and late fees by landlord and billing month.
- `v_tenant_statement` presents ledger entries with a running balance per lease, ordered by entry date and ledger ID.

### Procedures and triggers: financial workflow and safeguards

[`triggers.sql`](./triggers.sql) installs three procedures:

- `sp_record_payment` rejects invalid or excessive payments, locks the lease and its invoices while it works, inserts the payment, and allocates it to the oldest outstanding invoices first. It updates invoice statuses and writes a ledger credit in one transaction. A failure rolls back the transaction.
- `sp_generate_monthly_invoices` creates one rent invoice for each active lease that covers the requested month and writes the corresponding ledger debit. Existing invoices for that lease and month are skipped, so running it again does not duplicate that month's charges. It accepts any date in the month and normalizes it to the first day.
- `sp_apply_late_fees` applies a lease's configured late fee once to eligible overdue invoices that still have a balance, updates invoice late-fee data, and writes the corresponding ledger debit.

The triggers complement those procedures and the schema:

- An active lease cannot be added to a unit that already has an active lease. Activating or ending a lease also updates the unit's occupancy status.
- A payment allocation cannot make total allocations exceed an invoice's rent plus late fee.
- Ledger rows cannot be updated or deleted. Corrections should be represented by a new adjustment entry so the original audit trail remains intact.

## PHP application files

All web application files are in [`app/`](./app/). The PHP pages render HTML directly; shared helpers and the PDO connection are included by pages that need them.

| File | Role in the application |
|---|---|
| [`index.php`](./app/index.php) | Entry point. Redirects an authenticated user to the dashboard for their role; otherwise sends them to login. |
| [`login.php`](./app/login.php) | Displays the login form, queries the user by username using a prepared statement, verifies the submitted password against the stored hash, regenerates the session ID on success, and redirects by role. Failed attempts use a generic error message. |
| [`logout.php`](./app/logout.php) | Clears the session data, destroys the session, and returns the user to the login page. |
| [`auth.php`](./app/auth.php) | Starts the session and defines shared authentication helpers: `require_login()` checks authentication and optional role, `redirect_to_dashboard()` sends a user to the correct dashboard, and `e()` escapes text for HTML output. |
| [`db.php`](./app/db.php) | Loads local configuration and creates the shared PDO connection with UTF-8, exception-based errors, associative fetches, and native prepared statements. Logs connection details on the server while showing visitors a generic failure message. |
| [`config.example.php`](./app/config.example.php) | Safe configuration template. Copy it to `config.php` and supply local MySQL connection details. The real `config.php` is intentionally ignored by Git and must not be committed. |
| [`csrf.php`](./app/csrf.php) | Provides session-backed CSRF token generation and validation for state-changing form submissions. The payment form includes and checks this token. |
| [`landlord_dashboard.php`](./app/landlord_dashboard.php) | Requires a landlord session and filters every dashboard query by the logged-in landlord ID. Displays current-month collections, outstanding and overdue balances, tenant balances, and property occupancy using database views. |
| [`tenant_dashboard.php`](./app/tenant_dashboard.php) | Requires a tenant session and filters lease, invoice, and statement queries by the logged-in tenant account ID. Displays balances, invoices, paid/overdue labels, and ledger history with a running balance. |
| [`record_payment.php`](./app/record_payment.php) | Landlord-only payment form and handler. Validates the CSRF token, lease, amount, date, method, and reference; verifies that the lease belongs to the landlord; calls `sp_record_payment`; and shows validation or database errors without silently treating a rejected payment as successful. |
| [`header.php`](./app/header.php) | Shared navigation and page opening markup. Shows the signed-in username and role, a landlord payment link, and one-time flash messages. Also formats amounts in UGX. |
| [`footer.php`](./app/footer.php) | Closes the shared page's main and document elements. |
| [`style.css`](./app/style.css) | Shared styling for the navigation, dashboards, cards, tables, forms, status labels, and error/success messages. |
| [`set_passwords.php`](./app/set_passwords.php) | Command-line-only helper that replaces the placeholder sample password values with hashes for the demo accounts. Intended only for local sample data. |
| [`test_db.php`](./app/test_db.php) | Simple development page that reads `v_lease_balances` to check the PHP-to-MySQL connection and display sample balances. Do not expose this diagnostic page on a public deployment. |
| [`test.php`](./app/test.php) | Minimal PHP runtime check that prints the PHP version. Development diagnostic, not part of the application workflow. |

## Setup

### Requirements

- MySQL 8.0.16 or newer
- PHP with the PDO MySQL extension
- A MySQL account that can create/use the `renttrack` database and create views, triggers, and stored procedures during setup

### 1. Create the database and load sample data

Run these commands from the repository root, in order:

```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
mysql -u root -p < views.sql
mysql -u root -p < triggers.sql
```

`schema.sql` drops and recreates the project tables. **`seed.sql` truncates the project tables and reloads the demonstration records.** Do not run these scripts against a database containing records you need to keep.

### 2. Configure the PHP application

```bash
cp app/config.example.php app/config.php
```

Edit `app/config.php` with the host, database name, MySQL username, and password for your environment. Use a database account appropriate for your setup and keep the real configuration file private; it is excluded from Git.

### 3. Set passwords for the sample accounts

`seed.sql` uses placeholder password hashes, so sample users cannot log in until the helper replaces them. From the `app` directory, run:

```bash
php set_passwords.php
```

The helper sets these **demo-only** credentials:

| Role | Username(s) | Demo password |
|---|---|---|
| Landlord | `jkato`, `snakato` | `landlord123` |
| Tenant | `amukasa`, `bnamubiru`, `cokello` | `tenant123` |

These are public demonstration credentials, not secure production passwords. Do not use them for a deployed system. The other two sample tenants have no login account.

### 4. Start the local PHP server

```bash
cd app
php -S localhost:8000
```

Open [http://localhost:8000](http://localhost:8000) in a browser. This built-in server is for local development, not production hosting.

### 5. Generate monthly invoices and apply late fees

These routines are currently run directly in MySQL by a database operator. For example:

```sql
USE renttrack;

CALL sp_generate_monthly_invoices('2026-11-01', @created);
SELECT @created;

CALL sp_apply_late_fees(@fees_applied);
SELECT @fees_applied;
```

Choose the billing month that is appropriate for your data. In production, schedule these operations deliberately and monitor their results; the repository does not currently include a scheduler.

To inspect calculated balances after setup, run:

```sql
USE renttrack;
SELECT * FROM v_lease_balances;
SELECT * FROM v_overdue_invoices;
```

## Repository layout

```text
app/                  PHP pages, shared helpers, and local configuration template
RentTrack/            Existing copy of the SQL scripts and ER diagram
renttrack.png         ER diagram used by this README
schema.sql            Database and table definitions
seed.sql              Destructive reload of fictional sample records
views.sql             Reporting views
triggers.sql          Stored procedures and database triggers
start                 Local MySQL/PHP startup commands
README.md             Project and setup documentation
```

The root SQL files are the setup files referenced above. `RentTrack/` is an earlier nested copy retained in the repository.

## Current limitations and possible next steps

- Add authenticated workflows for managing properties, units, tenants, and leases.
- Add an admin interface or scheduled task for generating invoices and applying late fees.
- Replace demo credentials and add a production deployment configuration.
- Integrate payment-provider or mobile-money reconciliation; the current app records a payment and optional reference but does not process a transaction with a provider.
- Add automated tests and deployment-specific monitoring.

## License

No license is currently specified.
