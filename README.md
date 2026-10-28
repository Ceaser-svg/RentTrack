# RentTrack: Rental Property and Tenant Management System

A web application backed by a relational database that helps landlords manage properties, tenants, rent invoices, and payments.

**Author:** OGWARA CEASER
**Course:** DATABASE PROGRAMMNG
**Institution:** MBARARA UNIVERSIRTY OF SCIENCE AND TECHNOLOGY

## Problem

Many landlords in Uganda track rent in notebooks or mobile money messages. This causes payment disputes, unnoticed arrears, and no clear statements for tenants.

## Solution

RentTrack centralizes rental records in a relational database and automates rent tracking. Monthly invoices are generated automatically, payments (full or partial) are recorded against them, and balances, arrears, and late fees are updated using database transactions so records stay accurate.

## Features

- Register properties, units, and tenants
- Assign tenants to units and track occupancy
- Automatic monthly rent invoice generation
- Record full and partial payments
- Arrears and late fee tracking
- Tenant statements and payment history
- Role-based access (landlord and tenant)
- Reports: outstanding rent, occupancy, payments collected

## Tech Stack

- **Frontend:** HTML
- **Backend:** PHP
- **Database:** MySQL

## Database Design

![ERD](https://github.com/Ceaser-svg/RentTrack/blob/main/RentTrack/renttrack.png)

**Tables:** `users`, `properties`, `units`, `tenants`, `leases`, `invoices`, `payments`, `payment_allocations`, `ledger`

**Views (reports):**
- `v_lease_balances`: what each tenant has been charged, paid, and still owes
- `v_invoice_summary`: each invoice with amount paid and remaining balance
- `v_overdue_invoices`: arrears report
- `v_property_occupancy`: occupied and vacant units per property
- `v_monthly_collections` and `v_monthly_billed`: money received vs invoiced per month
- `v_tenant_statement`: ledger lines with a running balance

**Stored procedures:**
- `sp_record_payment`: records a payment, allocates it to the oldest unpaid invoices, updates invoice status, and writes the ledger entry in one transaction (rolls back on any error)
- `sp_generate_monthly_invoices`: creates a month's invoices for all active leases (safe to run twice)
- `sp_apply_late_fees`: adds late fees once to overdue invoices

**Triggers:**
- One active lease per unit, and unit status (occupied/vacant) follows its lease
- A payment allocation can never exceed the invoice total
- Ledger entries cannot be edited or deleted; mistakes are corrected with an adjustment entry
Key design choices:
- A `ledger` table records every debit and credit, so balances can always be rebuilt.
- `payment_allocations` lets one payment cover several invoices, or an invoice be paid in parts.
- Foreign keys use `ON DELETE RESTRICT` so financial records are never deleted by accident.

## Setup Instructions

Requires **MySQL 8.0.16 or newer**.

1. Clone the repository
   ```bash
   git clone https://github.com/[your-username]/renttrack.git
   cd renttrack
   ```
2. Run the SQL scripts in this order (in DBeaver use **Alt+X**, or from the command line):
   ```bash
   mysql -u root -p < database/schema.sql
   mysql -u root -p < database/seed.sql
   mysql -u root -p < database/views.sql
   mysql -u root -p < database/triggers.sql
   ```
3. Verify with:
   ```sql
   USE renttrack;
   SELECT * FROM v_lease_balances;
   ```
## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/[your-username]/renttrack.git
   cd renttrack
   ```
2. **Create the database**
   ```bash
   [command to create the database]
   ```
3. **Run the SQL scripts in this order**
   - `database/schema.sql`
   - `database/views.sql`
   - `database/triggers.sql`
   - `database/seed.sql`
4. **Configure environment variables**
   Copy `.env.example` to `.env` and fill in your database details.
5. **Install dependencies and start the app**
   ```bash
   [install and run commands]
   ```
6. Open the app at `http://localhost:[port]`.

## Sample Login Accounts

| Role     | Username | Password |
|----------|----------|----------|
| Landlord | [fill in] | [fill in] |
| Tenant   | [fill in] | [fill in] |

(Sample accounts use fake data from `seed.sql`.)

## Screenshots

![Landlord dashboard](docs/screenshots/dashboard.png)
![Tenant statement](docs/screenshots/statement.png)

## Project Structure

```
database/   SQL scripts and ERD
backend/    Server code and database connection
frontend/   User interface
docs/       Requirements, design notes, screenshots
tests/      Test cases
```

## Future Improvements

- Mobile money payment integration
- SMS or email rent reminders
- Maintenance request tracking

## License

[e.g. MIT]
