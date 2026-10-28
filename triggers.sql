-- =====================================================
-- RentTrack: stored procedures and triggers
-- Run order: schema.sql -> seed.sql -> views.sql -> triggers.sql
-- (the payment procedure reads from the v_invoice_summary view)
-- Needs MySQL 8.0.16+
-- =====================================================

USE renttrack;

DROP PROCEDURE IF EXISTS sp_record_payment;
DROP PROCEDURE IF EXISTS sp_generate_monthly_invoices;
DROP PROCEDURE IF EXISTS sp_apply_late_fees;
DROP TRIGGER IF EXISTS trg_leases_before_insert;
DROP TRIGGER IF EXISTS trg_leases_before_update;
DROP TRIGGER IF EXISTS trg_leases_after_insert;
DROP TRIGGER IF EXISTS trg_leases_after_update;
DROP TRIGGER IF EXISTS trg_alloc_before_insert;
DROP TRIGGER IF EXISTS trg_ledger_before_update;
DROP TRIGGER IF EXISTS trg_ledger_before_delete;

DELIMITER //

-- -----------------------------------------------------
-- sp_record_payment
-- Records a payment and, in ONE transaction:
--   1. inserts the payment
--   2. allocates it to the lease's oldest unpaid invoices first
--   3. updates each invoice's status (partial or paid)
--   4. writes the credit entry in the ledger
-- If anything fails, everything is rolled back.
-- Payments larger than the total outstanding balance are rejected.
-- -----------------------------------------------------
CREATE PROCEDURE sp_record_payment(
  IN  p_lease_id     INT UNSIGNED,
  IN  p_amount       DECIMAL(12,2),
  IN  p_payment_date DATE,
  IN  p_method       VARCHAR(20),
  IN  p_reference    VARCHAR(100),
  IN  p_recorded_by  INT UNSIGNED,
  OUT p_payment_id   INT UNSIGNED
)
BEGIN
  DECLARE v_count       INT DEFAULT 0;
  DECLARE v_outstanding DECIMAL(12,2) DEFAULT 0;
  DECLARE v_remaining   DECIMAL(12,2);
  DECLARE v_apply       DECIMAL(12,2);
  DECLARE v_invoice_id  INT UNSIGNED;
  DECLARE v_balance     DECIMAL(12,2);
  DECLARE v_done        INT DEFAULT 0;
  DECLARE cur CURSOR FOR
    SELECT invoice_id, balance_remaining
    FROM v_invoice_summary
    WHERE lease_id = p_lease_id AND balance_remaining > 0
    ORDER BY due_date, invoice_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
  END IF;

  START TRANSACTION;

  -- Lock the lease and its invoices so two payments cannot over-allocate
  SELECT COUNT(*) INTO v_count FROM leases WHERE lease_id = p_lease_id FOR UPDATE;
  IF v_count = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lease not found';
  END IF;
  SELECT COUNT(*) INTO v_count FROM invoices WHERE lease_id = p_lease_id FOR UPDATE;

  SELECT COALESCE(SUM(balance_remaining), 0) INTO v_outstanding
  FROM v_invoice_summary WHERE lease_id = p_lease_id;
  IF p_amount > v_outstanding THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds the outstanding invoice balance';
  END IF;

  INSERT INTO payments (lease_id, amount, payment_date, method, reference, recorded_by)
  VALUES (p_lease_id, p_amount, p_payment_date, p_method, p_reference, p_recorded_by);
  SET p_payment_id = LAST_INSERT_ID();

  -- Allocate to the oldest unpaid invoices first
  SET v_remaining = p_amount;
  OPEN cur;
  alloc_loop: LOOP
    FETCH cur INTO v_invoice_id, v_balance;
    IF v_done = 1 OR v_remaining <= 0 THEN
      LEAVE alloc_loop;
    END IF;
    SET v_apply = LEAST(v_remaining, v_balance);
    INSERT INTO payment_allocations (payment_id, invoice_id, amount_applied)
    VALUES (p_payment_id, v_invoice_id, v_apply);
    UPDATE invoices
    SET status = IF(v_apply = v_balance, 'paid', 'partial')
    WHERE invoice_id = v_invoice_id;
    SET v_remaining = v_remaining - v_apply;
  END LOOP;
  CLOSE cur;

  INSERT INTO ledger (lease_id, entry_date, entry_type, debit, credit, payment_id, description)
  VALUES (p_lease_id, p_payment_date, 'payment', 0, p_amount, p_payment_id,
          CONCAT('Payment via ', REPLACE(p_method, '_', ' ')));

  COMMIT;
END //

-- -----------------------------------------------------
-- sp_generate_monthly_invoices
-- Creates one invoice per active lease for the given month
-- and the matching ledger debit. Safe to run twice: leases that
-- already have an invoice for that month are skipped.
-- p_billing_month can be any date in the month.
-- -----------------------------------------------------
CREATE PROCEDURE sp_generate_monthly_invoices(
  IN  p_billing_month DATE,
  OUT p_created       INT
)
BEGIN
  DECLARE v_month DATE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET v_month = DATE_SUB(p_billing_month, INTERVAL DAY(p_billing_month) - 1 DAY);

  START TRANSACTION;

  INSERT INTO invoices (lease_id, billing_month, amount_due, late_fee, due_date, status)
  SELECT l.lease_id, v_month, l.monthly_rent, 0,
         DATE_ADD(v_month, INTERVAL l.due_day - 1 DAY), 'unpaid'
  FROM leases l
  WHERE l.status = 'active'
    AND l.start_date <= LAST_DAY(v_month)
    AND (l.end_date IS NULL OR l.end_date >= v_month)
    AND NOT EXISTS (
      SELECT 1 FROM invoices i
      WHERE i.lease_id = l.lease_id AND i.billing_month = v_month
    );
  SET p_created = ROW_COUNT();

  INSERT INTO ledger (lease_id, entry_date, entry_type, debit, credit, invoice_id, description)
  SELECT i.lease_id, i.billing_month, 'invoice', i.amount_due, 0, i.invoice_id,
         CONCAT('Rent invoice for ', DATE_FORMAT(i.billing_month, '%M %Y'))
  FROM invoices i
  WHERE i.billing_month = v_month
    AND NOT EXISTS (
      SELECT 1 FROM ledger g
      WHERE g.invoice_id = i.invoice_id AND g.entry_type = 'invoice'
    );

  COMMIT;
END //

-- -----------------------------------------------------
-- sp_apply_late_fees
-- Run daily. Adds the lease's late fee, once, to every invoice that
-- is past its due date, still has a balance, and has no fee yet.
-- Unpaid invoices become 'overdue'; part-paid ones stay 'partial'.
-- -----------------------------------------------------
CREATE PROCEDURE sp_apply_late_fees(OUT p_fees_applied INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  INSERT INTO ledger (lease_id, entry_date, entry_type, debit, credit, invoice_id, description)
  SELECT i.lease_id, CURDATE(), 'late_fee', l.late_fee_amount, 0, i.invoice_id,
         CONCAT('Late fee for ', DATE_FORMAT(i.billing_month, '%M %Y'))
  FROM invoices i
  JOIN leases l ON l.lease_id = i.lease_id
  WHERE i.due_date < CURDATE()
    AND i.status IN ('unpaid', 'partial', 'overdue')
    AND i.late_fee = 0
    AND l.late_fee_amount > 0;

  UPDATE invoices i
  JOIN leases l ON l.lease_id = i.lease_id
  SET i.late_fee = l.late_fee_amount,
      i.status   = IF(i.status = 'unpaid', 'overdue', i.status)
  WHERE i.due_date < CURDATE()
    AND i.status IN ('unpaid', 'partial', 'overdue')
    AND i.late_fee = 0
    AND l.late_fee_amount > 0;
  SET p_fees_applied = ROW_COUNT();

  COMMIT;
END //

-- -----------------------------------------------------
-- Triggers on leases: one active lease per unit, and keep
-- the unit's status in step with its lease
-- -----------------------------------------------------
CREATE TRIGGER trg_leases_before_insert
BEFORE INSERT ON leases
FOR EACH ROW
BEGIN
  IF NEW.status = 'active' AND EXISTS (
    SELECT 1 FROM leases WHERE unit_id = NEW.unit_id AND status = 'active'
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This unit already has an active lease';
  END IF;
END //

CREATE TRIGGER trg_leases_before_update
BEFORE UPDATE ON leases
FOR EACH ROW
BEGIN
  IF NEW.status = 'active'
     AND (OLD.status <> 'active' OR NEW.unit_id <> OLD.unit_id)
     AND EXISTS (
       SELECT 1 FROM leases
       WHERE unit_id = NEW.unit_id AND status = 'active' AND lease_id <> NEW.lease_id
     ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This unit already has an active lease';
  END IF;
END //

CREATE TRIGGER trg_leases_after_insert
AFTER INSERT ON leases
FOR EACH ROW
BEGIN
  IF NEW.status = 'active' THEN
    UPDATE units SET status = 'occupied' WHERE unit_id = NEW.unit_id;
  END IF;
END //

CREATE TRIGGER trg_leases_after_update
AFTER UPDATE ON leases
FOR EACH ROW
BEGIN
  IF OLD.status = 'active' AND NEW.status <> 'active' THEN
    -- a unit under maintenance is left alone
    UPDATE units SET status = 'vacant'
    WHERE unit_id = NEW.unit_id AND status = 'occupied';
  ELSEIF OLD.status <> 'active' AND NEW.status = 'active' THEN
    UPDATE units SET status = 'occupied' WHERE unit_id = NEW.unit_id;
  END IF;
END //

-- -----------------------------------------------------
-- Trigger on payment_allocations: never allocate more than an
-- invoice's total (rent + late fee), even if the app has a bug
-- -----------------------------------------------------
CREATE TRIGGER trg_alloc_before_insert
BEFORE INSERT ON payment_allocations
FOR EACH ROW
BEGIN
  DECLARE v_total DECIMAL(12,2);
  DECLARE v_paid  DECIMAL(12,2);
  SELECT amount_due + late_fee INTO v_total
  FROM invoices WHERE invoice_id = NEW.invoice_id;
  SELECT COALESCE(SUM(amount_applied), 0) INTO v_paid
  FROM payment_allocations WHERE invoice_id = NEW.invoice_id;
  IF v_paid + NEW.amount_applied > v_total THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Allocation exceeds the invoice total';
  END IF;
END //

-- -----------------------------------------------------
-- Triggers on ledger: entries are never edited or deleted.
-- Mistakes are fixed by adding a new 'adjustment' entry.
-- -----------------------------------------------------
CREATE TRIGGER trg_ledger_before_update
BEFORE UPDATE ON ledger
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ledger entries cannot be changed';
END //

CREATE TRIGGER trg_ledger_before_delete
BEFORE DELETE ON ledger
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ledger entries cannot be deleted';
END //

DELIMITER ;

-- -----------------------------------------------------
-- Try them out (run these one at a time):
--
-- 1. Record a payment that clears lease 1's balance of 170,000
--      CALL sp_record_payment(1, 170000, CURDATE(), 'cash', NULL, 1, @pid);
--      SELECT @pid;
--      SELECT * FROM v_lease_balances;
--
-- 2. Overpaying should fail with an error
--      CALL sp_record_payment(3, 50000, CURDATE(), 'cash', NULL, 1, @pid);
--
-- 3. Generate November invoices (should create 5)
--      CALL sp_generate_monthly_invoices('2026-11-01', @n);
--      SELECT @n;
--
-- 4. Run it again (should create 0)
--      CALL sp_generate_monthly_invoices('2026-11-01', @n);
--      SELECT @n;
--
-- 5. Apply late fees
--      CALL sp_apply_late_fees(@f);
--      SELECT @f;
--
-- 6. The ledger is protected (should fail)
--      DELETE FROM ledger WHERE ledger_id = 1;
-- -----------------------------------------------------
