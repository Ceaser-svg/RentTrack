-- =====================================================
-- RentTrack: reporting views
-- Run after schema.sql (and seed.sql if you want data to look at)
-- Needs MySQL 8.0+ (v_tenant_statement uses a window function)
-- =====================================================

USE renttrack;

-- -----------------------------------------------------
-- v_lease_balances
-- How much each tenant has been charged, has paid, and still owes.
-- landlord_id and tenant_user_id let the backend filter per login.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_lease_balances AS
SELECT
  l.lease_id,
  p.landlord_id,
  t.user_id                            AS tenant_user_id,
  t.full_name                          AS tenant_name,
  p.name                               AS property_name,
  u.unit_number,
  l.status                             AS lease_status,
  COALESCE(SUM(g.debit), 0)            AS total_charged,
  COALESCE(SUM(g.credit), 0)           AS total_paid,
  COALESCE(SUM(g.debit), 0) - COALESCE(SUM(g.credit), 0) AS balance
FROM leases l
JOIN tenants    t ON t.tenant_id   = l.tenant_id
JOIN units      u ON u.unit_id     = l.unit_id
JOIN properties p ON p.property_id = u.property_id
LEFT JOIN ledger g ON g.lease_id   = l.lease_id
GROUP BY l.lease_id, p.landlord_id, t.user_id, t.full_name,
         p.name, u.unit_number, l.status;

-- -----------------------------------------------------
-- v_invoice_summary
-- Each invoice with how much has been paid against it and what remains.
-- Paid amounts come from payment_allocations.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_invoice_summary AS
SELECT
  i.invoice_id,
  i.lease_id,
  i.billing_month,
  i.due_date,
  i.amount_due,
  i.late_fee,
  i.amount_due + i.late_fee                              AS total_due,
  COALESCE(SUM(pa.amount_applied), 0)                    AS amount_paid,
  i.amount_due + i.late_fee - COALESCE(SUM(pa.amount_applied), 0) AS balance_remaining,
  i.status
FROM invoices i
LEFT JOIN payment_allocations pa ON pa.invoice_id = i.invoice_id
GROUP BY i.invoice_id, i.lease_id, i.billing_month, i.due_date,
         i.amount_due, i.late_fee, i.status;

-- -----------------------------------------------------
-- v_overdue_invoices
-- Invoices past their due date that still have a balance (the arrears report).
-- The longest overdue appear first.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_overdue_invoices AS
SELECT
  s.invoice_id,
  s.lease_id,
  p.landlord_id,
  t.user_id                            AS tenant_user_id,
  t.full_name                          AS tenant_name,
  t.phone                              AS tenant_phone,
  p.name                               AS property_name,
  u.unit_number,
  s.billing_month,
  s.due_date,
  DATEDIFF(CURDATE(), s.due_date)      AS days_overdue,
  s.total_due,
  s.amount_paid,
  s.balance_remaining
FROM v_invoice_summary s
JOIN leases     l ON l.lease_id    = s.lease_id
JOIN tenants    t ON t.tenant_id   = l.tenant_id
JOIN units      u ON u.unit_id     = l.unit_id
JOIN properties p ON p.property_id = u.property_id
WHERE s.balance_remaining > 0
  AND s.due_date < CURDATE()
ORDER BY days_overdue DESC;

-- -----------------------------------------------------
-- v_property_occupancy
-- Unit counts and occupancy rate for each property.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_property_occupancy AS
SELECT
  p.property_id,
  p.landlord_id,
  p.name                                                  AS property_name,
  p.district,
  COUNT(u.unit_id)                                        AS total_units,
  COALESCE(SUM(u.status = 'occupied'), 0)                 AS occupied_units,
  COALESCE(SUM(u.status = 'vacant'), 0)                   AS vacant_units,
  COALESCE(SUM(u.status = 'maintenance'), 0)              AS maintenance_units,
  ROUND(100 * COALESCE(SUM(u.status = 'occupied'), 0)
        / NULLIF(COUNT(u.unit_id), 0), 1)                 AS occupancy_rate_pct
FROM properties p
LEFT JOIN units u ON u.property_id = p.property_id
GROUP BY p.property_id, p.landlord_id, p.name, p.district;

-- -----------------------------------------------------
-- v_monthly_collections
-- Money received per landlord per month.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_collections AS
SELECT
  p.landlord_id,
  DATE_FORMAT(pay.payment_date, '%Y-%m') AS month,
  COUNT(pay.payment_id)                  AS payments_count,
  SUM(pay.amount)                        AS total_collected
FROM payments pay
JOIN leases     l ON l.lease_id    = pay.lease_id
JOIN units      u ON u.unit_id     = l.unit_id
JOIN properties p ON p.property_id = u.property_id
GROUP BY p.landlord_id, DATE_FORMAT(pay.payment_date, '%Y-%m');

-- -----------------------------------------------------
-- v_monthly_billed
-- Amount invoiced per landlord per month (compare with collections).
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_monthly_billed AS
SELECT
  p.landlord_id,
  DATE_FORMAT(i.billing_month, '%Y-%m') AS month,
  COUNT(i.invoice_id)                   AS invoices_count,
  SUM(i.amount_due + i.late_fee)        AS total_billed
FROM invoices i
JOIN leases     l ON l.lease_id    = i.lease_id
JOIN units      u ON u.unit_id     = l.unit_id
JOIN properties p ON p.property_id = u.property_id
GROUP BY p.landlord_id, DATE_FORMAT(i.billing_month, '%Y-%m');

-- -----------------------------------------------------
-- v_tenant_statement
-- Every ledger line for a lease with a running balance.
-- This is what a tenant sees as their statement.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW v_tenant_statement AS
SELECT
  g.lease_id,
  t.user_id        AS tenant_user_id,
  p.landlord_id,
  g.entry_date,
  g.entry_type,
  g.description,
  g.debit,
  g.credit,
  SUM(g.debit - g.credit) OVER (
    PARTITION BY g.lease_id
    ORDER BY g.entry_date, g.ledger_id
  ) AS running_balance
FROM ledger g
JOIN leases     l ON l.lease_id    = g.lease_id
JOIN tenants    t ON t.tenant_id   = l.tenant_id
JOIN units      u ON u.unit_id     = l.unit_id
JOIN properties p ON p.property_id = u.property_id;

-- -----------------------------------------------------
-- Try them out:
--   SELECT * FROM v_lease_balances;
--   SELECT * FROM v_overdue_invoices;
--   SELECT * FROM v_property_occupancy;
--   SELECT * FROM v_monthly_collections ORDER BY month;
--   SELECT * FROM v_tenant_statement WHERE lease_id = 4 ORDER BY entry_date;
-- -----------------------------------------------------
