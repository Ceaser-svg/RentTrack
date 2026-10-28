-- =====================================================
-- RentTrack: sample data (all names and numbers are fake)
-- Run after schema.sql
-- Safe to re-run: it clears the tables first
-- =====================================================

USE renttrack;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ledger;
TRUNCATE TABLE payment_allocations;
TRUNCATE TABLE payments;
TRUNCATE TABLE invoices;
TRUNCATE TABLE leases;
TRUNCATE TABLE tenants;
TRUNCATE TABLE units;
TRUNCATE TABLE properties;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------
-- users (2 landlords, 3 tenants with logins)
-- The hashes are placeholders. Your backend should replace them
-- with real hashes (bcrypt, argon2, etc.) when you set passwords.
-- -----------------------------------------------------
INSERT INTO users (user_id, username, password_hash, role) VALUES
(1, 'jkato',      'REPLACE_WITH_REAL_HASH', 'landlord'),
(2, 'snakato',    'REPLACE_WITH_REAL_HASH', 'landlord'),
(3, 'amukasa',    'REPLACE_WITH_REAL_HASH', 'tenant'),
(4, 'bnamubiru',  'REPLACE_WITH_REAL_HASH', 'tenant'),
(5, 'cokello',    'REPLACE_WITH_REAL_HASH', 'tenant');

-- -----------------------------------------------------
-- properties
-- -----------------------------------------------------
INSERT INTO properties (property_id, landlord_id, name, address, district) VALUES
(1, 1, 'Kato Apartments',  'Plot 12, Main Street',   'Mbarara'),
(2, 1, 'Sunrise Hostel',   'Plot 4, Campus Road',    'Mbarara'),
(3, 2, 'Nakato Court',     'Plot 33, Bukoto Close',  'Kampala');

-- -----------------------------------------------------
-- units (4 occupied, 3 vacant, 1 under maintenance)
-- -----------------------------------------------------
INSERT INTO units (unit_id, property_id, unit_number, unit_type, monthly_rent, status) VALUES
(1, 1, 'A1',  'Single room',     300000, 'occupied'),
(2, 1, 'A2',  'Single room',     300000, 'occupied'),
(3, 1, 'B1',  '2-bedroom',       600000, 'occupied'),
(4, 1, 'B2',  '2-bedroom',       600000, 'vacant'),
(5, 2, '101', 'Self-contained',  450000, 'occupied'),
(6, 2, '102', 'Self-contained',  450000, 'maintenance'),
(7, 3, 'C1',  '3-bedroom',       800000, 'occupied'),
(8, 3, 'C2',  '3-bedroom',       800000, 'vacant');

-- -----------------------------------------------------
-- tenants (tenants 4 and 5 have no login yet)
-- -----------------------------------------------------
INSERT INTO tenants (tenant_id, user_id, full_name, phone, email) VALUES
(1, 3,    'Allan Mukasa',        '0700000001', 'allan@example.com'),
(2, 4,    'Brenda Namubiru',     '0700000002', 'brenda@example.com'),
(3, 5,    'Charles Okello',      '0700000003', 'charles@example.com'),
(4, NULL, 'Diana Atim',          '0700000004', NULL),
(5, NULL, 'Emmanuel Tumusiime',  '0700000005', 'emmanuel@example.com');

-- -----------------------------------------------------
-- leases (all active)
-- -----------------------------------------------------
INSERT INTO leases
  (lease_id, unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, due_day, late_fee_amount, status)
VALUES
(1, 1, 1, '2026-07-01', NULL, 300000, 300000,  5, 20000, 'active'),
(2, 2, 2, '2026-07-01', NULL, 300000, 300000,  5, 20000, 'active'),
(3, 3, 3, '2026-08-01', NULL, 600000, 600000,  5, 30000, 'active'),
(4, 5, 4, '2026-09-01', NULL, 450000, 450000,  5, 25000, 'active'),
(5, 7, 5, '2026-09-01', NULL, 800000, 800000, 10, 40000, 'active');

-- -----------------------------------------------------
-- invoices (July to October 2026)
-- Lease 1: October partly paid
-- Lease 2: September and October overdue
-- Lease 4: September paid late, so it carries a late fee
-- -----------------------------------------------------
INSERT INTO invoices
  (invoice_id, lease_id, billing_month, amount_due, late_fee, due_date, status)
VALUES
(1,  1, '2026-07-01', 300000,     0, '2026-07-05', 'paid'),
(2,  1, '2026-08-01', 300000,     0, '2026-08-05', 'paid'),
(3,  1, '2026-09-01', 300000,     0, '2026-09-05', 'paid'),
(4,  1, '2026-10-01', 300000, 20000, '2026-10-05', 'partial'),
(5,  2, '2026-07-01', 300000,     0, '2026-07-05', 'paid'),
(6,  2, '2026-08-01', 300000,     0, '2026-08-05', 'paid'),
(7,  2, '2026-09-01', 300000, 20000, '2026-09-05', 'overdue'),
(8,  2, '2026-10-01', 300000, 20000, '2026-10-05', 'overdue'),
(9,  3, '2026-08-01', 600000,     0, '2026-08-05', 'paid'),
(10, 3, '2026-09-01', 600000,     0, '2026-09-05', 'paid'),
(11, 3, '2026-10-01', 600000,     0, '2026-10-05', 'paid'),
(12, 4, '2026-09-01', 450000, 25000, '2026-09-05', 'paid'),
(13, 4, '2026-10-01', 450000,     0, '2026-10-05', 'paid'),
(14, 5, '2026-09-01', 800000,     0, '2026-09-10', 'paid'),
(15, 5, '2026-10-01', 800000,     0, '2026-10-10', 'paid');

-- -----------------------------------------------------
-- payments (recorded_by = the landlord who owns the property)
-- Payment 11 is one payment that settles two invoices
-- -----------------------------------------------------
INSERT INTO payments
  (payment_id, lease_id, amount, payment_date, method, reference, recorded_by)
VALUES
(1,  1, 300000, '2026-07-03', 'mobile_money',  'MM-0001', 1),
(2,  1, 300000, '2026-08-04', 'mobile_money',  'MM-0002', 1),
(3,  1, 300000, '2026-09-05', 'cash',          NULL,      1),
(4,  1, 150000, '2026-10-12', 'mobile_money',  'MM-0004', 1),
(5,  2, 300000, '2026-07-02', 'cash',          NULL,      1),
(6,  2, 300000, '2026-08-05', 'mobile_money',  'MM-0006', 1),
(7,  3, 600000, '2026-08-04', 'bank_transfer', 'BT-0007', 1),
(8,  3, 600000, '2026-09-03', 'bank_transfer', 'BT-0008', 1),
(9,  3, 600000, '2026-10-03', 'bank_transfer', 'BT-0009', 1),
(10, 4, 300000, '2026-09-04', 'mobile_money',  'MM-0010', 1),
(11, 4, 625000, '2026-10-04', 'mobile_money',  'MM-0011', 1),
(12, 5, 800000, '2026-09-09', 'bank_transfer', 'BT-0012', 2),
(13, 5, 800000, '2026-10-08', 'bank_transfer', 'BT-0013', 2);

-- -----------------------------------------------------
-- payment_allocations
-- Payment 10 + 11 together settle invoice 12 (rent + late fee)
-- Payment 11 also settles invoice 13
-- -----------------------------------------------------
INSERT INTO payment_allocations (payment_id, invoice_id, amount_applied) VALUES
(1,  1,  300000),
(2,  2,  300000),
(3,  3,  300000),
(4,  4,  150000),
(5,  5,  300000),
(6,  6,  300000),
(7,  9,  600000),
(8,  10, 600000),
(9,  11, 600000),
(10, 12, 300000),
(11, 12, 175000),
(11, 13, 450000),
(12, 14, 800000),
(13, 15, 800000);

-- -----------------------------------------------------
-- ledger: debit for each invoice and late fee, credit for each payment
-- Balance per lease = SUM(debit) - SUM(credit)
-- -----------------------------------------------------
INSERT INTO ledger
  (lease_id, entry_date, entry_type, debit, credit, invoice_id, payment_id, description)
VALUES
-- Lease 1
(1, '2026-07-01', 'invoice',  300000,      0,  1, NULL, 'Rent invoice for July 2026'),
(1, '2026-07-03', 'payment',       0, 300000, NULL,  1, 'Mobile money payment'),
(1, '2026-08-01', 'invoice',  300000,      0,  2, NULL, 'Rent invoice for August 2026'),
(1, '2026-08-04', 'payment',       0, 300000, NULL,  2, 'Mobile money payment'),
(1, '2026-09-01', 'invoice',  300000,      0,  3, NULL, 'Rent invoice for September 2026'),
(1, '2026-09-05', 'payment',       0, 300000, NULL,  3, 'Cash payment'),
(1, '2026-10-01', 'invoice',  300000,      0,  4, NULL, 'Rent invoice for October 2026'),
(1, '2026-10-06', 'late_fee',  20000,      0,  4, NULL, 'Late fee for October 2026'),
(1, '2026-10-12', 'payment',       0, 150000, NULL,  4, 'Part payment, mobile money'),
-- Lease 2
(2, '2026-07-01', 'invoice',  300000,      0,  5, NULL, 'Rent invoice for July 2026'),
(2, '2026-07-02', 'payment',       0, 300000, NULL,  5, 'Cash payment'),
(2, '2026-08-01', 'invoice',  300000,      0,  6, NULL, 'Rent invoice for August 2026'),
(2, '2026-08-05', 'payment',       0, 300000, NULL,  6, 'Mobile money payment'),
(2, '2026-09-01', 'invoice',  300000,      0,  7, NULL, 'Rent invoice for September 2026'),
(2, '2026-09-06', 'late_fee',  20000,      0,  7, NULL, 'Late fee for September 2026'),
(2, '2026-10-01', 'invoice',  300000,      0,  8, NULL, 'Rent invoice for October 2026'),
(2, '2026-10-06', 'late_fee',  20000,      0,  8, NULL, 'Late fee for October 2026'),
-- Lease 3
(3, '2026-08-01', 'invoice',  600000,      0,  9, NULL, 'Rent invoice for August 2026'),
(3, '2026-08-04', 'payment',       0, 600000, NULL,  7, 'Bank transfer'),
(3, '2026-09-01', 'invoice',  600000,      0, 10, NULL, 'Rent invoice for September 2026'),
(3, '2026-09-03', 'payment',       0, 600000, NULL,  8, 'Bank transfer'),
(3, '2026-10-01', 'invoice',  600000,      0, 11, NULL, 'Rent invoice for October 2026'),
(3, '2026-10-03', 'payment',       0, 600000, NULL,  9, 'Bank transfer'),
-- Lease 4
(4, '2026-09-01', 'invoice',  450000,      0, 12, NULL, 'Rent invoice for September 2026'),
(4, '2026-09-04', 'payment',       0, 300000, NULL, 10, 'Part payment, mobile money'),
(4, '2026-09-06', 'late_fee',  25000,      0, 12, NULL, 'Late fee for September 2026'),
(4, '2026-10-01', 'invoice',  450000,      0, 13, NULL, 'Rent invoice for October 2026'),
(4, '2026-10-04', 'payment',       0, 625000, NULL, 11, 'Settles September balance and October rent'),
-- Lease 5
(5, '2026-09-01', 'invoice',  800000,      0, 14, NULL, 'Rent invoice for September 2026'),
(5, '2026-09-09', 'payment',       0, 800000, NULL, 12, 'Bank transfer'),
(5, '2026-10-01', 'invoice',  800000,      0, 15, NULL, 'Rent invoice for October 2026'),
(5, '2026-10-08', 'payment',       0, 800000, NULL, 13, 'Bank transfer');

-- -----------------------------------------------------
-- Check: balance per lease (expected 170000, 640000, 0, 0, 0)
-- -----------------------------------------------------
SELECT lease_id, SUM(debit) - SUM(credit) AS balance
FROM ledger
GROUP BY lease_id
ORDER BY lease_id;
