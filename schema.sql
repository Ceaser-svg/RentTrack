-- =====================================================
-- RentTrack: Rental Property and Tenant Management System
-- MySQL 8.0.16+ (needed for CHECK constraints)
-- Run order: schema.sql -> views.sql -> triggers.sql -> seed.sql
-- =====================================================

CREATE DATABASE IF NOT EXISTS renttrack
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE renttrack;

-- Drop in reverse dependency order so the script can be re-run
DROP TABLE IF EXISTS ledger;
DROP TABLE IF EXISTS payment_allocations;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS leases;
DROP TABLE IF EXISTS tenants;
DROP TABLE IF EXISTS units;
DROP TABLE IF EXISTS properties;
DROP TABLE IF EXISTS users;

-- -----------------------------------------------------
-- users: login accounts (landlords and tenants)
-- -----------------------------------------------------
CREATE TABLE users (
  user_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username       VARCHAR(50)  NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,          -- store a hash, never plain text
  role           ENUM('landlord','tenant') NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- properties: buildings owned by a landlord
-- -----------------------------------------------------
CREATE TABLE properties (
  property_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  landlord_id    INT UNSIGNED NOT NULL,
  name           VARCHAR(100) NOT NULL,
  address        VARCHAR(255) NOT NULL,
  district       VARCHAR(100) NOT NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_properties_landlord
    FOREIGN KEY (landlord_id) REFERENCES users(user_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_properties_landlord (landlord_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- units: rentable units inside a property
-- -----------------------------------------------------
CREATE TABLE units (
  unit_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  property_id    INT UNSIGNED NOT NULL,
  unit_number    VARCHAR(20)  NOT NULL,
  unit_type      VARCHAR(50)  NULL,              -- e.g. single room, 2-bedroom
  monthly_rent   DECIMAL(12,2) NOT NULL,         -- default rent in UGX
  status         ENUM('vacant','occupied','maintenance') NOT NULL DEFAULT 'vacant',
  CONSTRAINT chk_units_rent CHECK (monthly_rent >= 0),
  CONSTRAINT uq_unit_per_property UNIQUE (property_id, unit_number),
  CONSTRAINT fk_units_property
    FOREIGN KEY (property_id) REFERENCES properties(property_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_units_status (status)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- tenants: people renting units
-- user_id is optional: a tenant may exist before getting a login
-- -----------------------------------------------------
CREATE TABLE tenants (
  tenant_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id        INT UNSIGNED NULL UNIQUE,
  full_name      VARCHAR(120) NOT NULL,
  phone          VARCHAR(20)  NOT NULL,
  email          VARCHAR(120) NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenants_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_tenants_name (full_name)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- leases: a tenant occupying a unit for a period
-- monthly_rent is copied here so later rent changes
-- on the unit do not alter existing agreements
-- -----------------------------------------------------
CREATE TABLE leases (
  lease_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  unit_id          INT UNSIGNED NOT NULL,
  tenant_id        INT UNSIGNED NOT NULL,
  start_date       DATE NOT NULL,
  end_date         DATE NULL,
  monthly_rent     DECIMAL(12,2) NOT NULL,
  deposit_amount   DECIMAL(12,2) NOT NULL DEFAULT 0,
  due_day          TINYINT UNSIGNED NOT NULL DEFAULT 5,   -- day of month rent is due
  late_fee_amount  DECIMAL(12,2) NOT NULL DEFAULT 0,
  status           ENUM('active','ended','terminated') NOT NULL DEFAULT 'active',
  CONSTRAINT chk_leases_rent CHECK (monthly_rent >= 0),
  CONSTRAINT chk_leases_deposit CHECK (deposit_amount >= 0),
  CONSTRAINT chk_leases_due_day CHECK (due_day BETWEEN 1 AND 28),
  CONSTRAINT chk_leases_dates CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT fk_leases_unit
    FOREIGN KEY (unit_id) REFERENCES units(unit_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_leases_tenant
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_leases_status (status),
  INDEX idx_leases_unit (unit_id),
  INDEX idx_leases_tenant (tenant_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- invoices: one rent invoice per lease per month
-- -----------------------------------------------------
CREATE TABLE invoices (
  invoice_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lease_id       INT UNSIGNED NOT NULL,
  billing_month  DATE NOT NULL,                  -- first day of the billed month
  amount_due     DECIMAL(12,2) NOT NULL,
  late_fee       DECIMAL(12,2) NOT NULL DEFAULT 0,
  due_date       DATE NOT NULL,
  status         ENUM('unpaid','partial','paid','overdue') NOT NULL DEFAULT 'unpaid',
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_invoices_amount CHECK (amount_due >= 0),
  CONSTRAINT chk_invoices_late_fee CHECK (late_fee >= 0),
  CONSTRAINT uq_invoice_per_month UNIQUE (lease_id, billing_month),
  CONSTRAINT fk_invoices_lease
    FOREIGN KEY (lease_id) REFERENCES leases(lease_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_invoices_status (status),
  INDEX idx_invoices_due_date (due_date)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- payments: money received from a tenant under a lease
-- -----------------------------------------------------
CREATE TABLE payments (
  payment_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lease_id       INT UNSIGNED NOT NULL,
  amount         DECIMAL(12,2) NOT NULL,
  payment_date   DATE NOT NULL,
  method         ENUM('cash','mobile_money','bank_transfer') NOT NULL,
  reference      VARCHAR(100) NULL,              -- e.g. mobile money transaction ID
  recorded_by    INT UNSIGNED NOT NULL,          -- user who entered the payment
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_payments_amount CHECK (amount > 0),
  CONSTRAINT fk_payments_lease
    FOREIGN KEY (lease_id) REFERENCES leases(lease_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_payments_recorded_by
    FOREIGN KEY (recorded_by) REFERENCES users(user_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE KEY uq_payment_reference (reference),
  INDEX idx_payments_lease_date (lease_id, payment_date)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- payment_allocations: how a payment is split across invoices
-- (handles partial payments and one payment covering many invoices)
-- -----------------------------------------------------
CREATE TABLE payment_allocations (
  allocation_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_id     INT UNSIGNED NOT NULL,
  invoice_id     INT UNSIGNED NOT NULL,
  amount_applied DECIMAL(12,2) NOT NULL,
  CONSTRAINT chk_alloc_amount CHECK (amount_applied > 0),
  CONSTRAINT uq_alloc UNIQUE (payment_id, invoice_id),
  CONSTRAINT fk_alloc_payment
    FOREIGN KEY (payment_id) REFERENCES payments(payment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_alloc_invoice
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_alloc_invoice (invoice_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- ledger: running record of every debit and credit per lease
-- Debit  = tenant owes more (invoice, late fee)
-- Credit = tenant paid or was credited (payment, adjustment)
-- A tenant's balance = SUM(debit) - SUM(credit)
-- -----------------------------------------------------
CREATE TABLE ledger (
  ledger_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  lease_id       INT UNSIGNED NOT NULL,
  entry_date     DATE NOT NULL,
  entry_type     ENUM('invoice','payment','late_fee','deposit','adjustment') NOT NULL,
  debit          DECIMAL(12,2) NOT NULL DEFAULT 0,
  credit         DECIMAL(12,2) NOT NULL DEFAULT 0,
  invoice_id     INT UNSIGNED NULL,
  payment_id     INT UNSIGNED NULL,
  description    VARCHAR(255) NULL,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_ledger_amounts CHECK (
    debit >= 0 AND credit >= 0 AND (debit > 0 OR credit > 0)
  ),
  CONSTRAINT fk_ledger_lease
    FOREIGN KEY (lease_id) REFERENCES leases(lease_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ledger_invoice
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ledger_payment
    FOREIGN KEY (payment_id) REFERENCES payments(payment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_ledger_lease_date (lease_id, entry_date)
) ENGINE=InnoDB;
