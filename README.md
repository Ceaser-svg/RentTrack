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

- **Frontend:** [e.g. HTML, CSS, JavaScript]
- **Backend:** [e.g. PHP / Node.js / Python]
- **Database:** [e.g. MySQL / PostgreSQL]

## Database Design

The database includes these main tables: `users`, `properties`, `units`, `tenants`, `leases`, `invoices`, `payments`, and `ledger`.

See the ERD in `database/erd.png` and design notes in `docs/design.md`.

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
