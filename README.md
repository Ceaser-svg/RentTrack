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

Requires **MySQL 8.0.16 or newer** and PHP with the PDO MySQL extension.

1. Create the database objects and sample data from the repository root:
   ```bash
   mysql -u root -p < schema.sql
   mysql -u root -p < seed.sql
   mysql -u root -p < views.sql
   mysql -u root -p < triggers.sql
   ```
2. Configure the app with your local database credentials:
   ```bash
   cp app/config.example.php app/config.php
   ```
   Edit `app/config.php`; it is intentionally excluded from Git.
3. Start the PHP development server:
   ```bash
   cd app
   php -S localhost:8000
   ```
4. Open `http://localhost:8000`.

To verify the database setup, run `SELECT * FROM v_lease_balances;` after selecting the `renttrack` database.

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
app/          PHP application
schema.sql    Database schema
seed.sql      Sample data
views.sql     Reporting views and procedures
triggers.sql  Database triggers
RentTrack/    Existing database scripts and ERD image
```

## Future Improvements

- Mobile money payment integration
- SMS or email rent reminders
- Maintenance request tracking

## License

[e.g. MIT]
