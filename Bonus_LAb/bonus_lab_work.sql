DROP PROCEDURE IF EXISTS process_transfer;
DROP PROCEDURE IF EXISTS process_salary_batch;
DROP VIEW IF EXISTS suspicious_activity_view;
DROP VIEW IF EXISTS daily_transaction_report;
DROP VIEW IF EXISTS customer_balance_summary;
DROP TABLE IF EXISTS audit_log, transactions, exchange_rates, accounts, customers CASCADE;

CREATE EXTENSION IF NOT EXISTS pgcrypto;



CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin CHAR(12) UNIQUE NOT NULL CHECK (iin ~ '^[0-9]{12}$'),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    status VARCHAR(20) CHECK (status IN ('active', 'blocked', 'frozen')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt NUMERIC(15, 2) DEFAULT 1000000.00
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    account_number VARCHAR(34) UNIQUE NOT NULL,
    currency CHAR(3) CHECK (currency IN ('KZT', 'USD', 'EUR', 'RUB')),
    balance NUMERIC(15, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ
);

CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency CHAR(3) NOT NULL,
    to_currency CHAR(3) NOT NULL,
    rate NUMERIC(10, 6) NOT NULL,
    valid_from TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMPTZ
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INT REFERENCES accounts(account_id),
    to_account_id INT REFERENCES accounts(account_id),
    amount NUMERIC(15, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    exchange_rate NUMERIC(10, 6) DEFAULT 1.0,
    amount_kzt NUMERIC(15, 2),
    type VARCHAR(20) CHECK (type IN ('transfer', 'deposit', 'withdrawal')),
    status VARCHAR(20) CHECK (status IN ('pending', 'completed', 'failed', 'reversed')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    description TEXT
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INT,
    action VARCHAR(10),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(50) DEFAULT CURRENT_USER,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

-- DATA POPULATION

INSERT INTO exchange_rates (from_currency, to_currency, rate) VALUES
('USD', 'KZT', 460.50), ('EUR', 'KZT', 495.20), ('RUB', 'KZT', 5.10),
('KZT', 'USD', 0.00217), ('KZT', 'EUR', 0.00202), ('KZT', 'RUB', 0.196);

INSERT INTO customers (iin, full_name, email, status) VALUES
('123456789012', 'Company Tech Corp', 'hr@techcorp.kz', 'active'),
('987654321098', 'John Doe', 'john@gmail.com', 'active'),
('111111111111', 'Alice Smith', 'alice@mail.ru', 'active');

INSERT INTO accounts (customer_id, account_number, currency, balance) VALUES
(1, 'KZ010000001', 'KZT', 50000000.00),
(2, 'KZ020000001', 'KZT', 150000.00),
(2, 'KZ020000002', 'USD', 1000.00),
(3, 'KZ030000001', 'KZT', 5000.00);

-- task 1

CREATE OR REPLACE PROCEDURE process_transfer(
    p_from_acc_num VARCHAR,
    p_to_acc_num VARCHAR,
    p_amount NUMERIC,
    p_currency VARCHAR,
    p_description TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id INT;
    v_to_id INT;
    v_from_balance NUMERIC;
    v_cust_status VARCHAR;
    v_cust_id INT;
    v_daily_limit NUMERIC;
    v_current_daily_usage NUMERIC;
    v_from_currency CHAR(3);
    v_to_currency CHAR(3);
    v_exchange_rate NUMERIC := 1.0;
    v_amount_in_kzt NUMERIC;
    v_kzt_rate NUMERIC := 1.0;
BEGIN
    SELECT account_id, balance, currency, customer_id
    INTO v_from_id, v_from_balance, v_from_currency, v_cust_id
    FROM accounts
    WHERE account_number = p_from_acc_num AND is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Sender account not found/inactive'; END IF;

    SELECT account_id, currency INTO v_to_id, v_to_currency
    FROM accounts
    WHERE account_number = p_to_acc_num AND is_active = TRUE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Receiver account not found/inactive'; END IF;

    SELECT status, daily_limit_kzt INTO v_cust_status, v_daily_limit
    FROM customers WHERE customer_id = v_cust_id;

    IF v_cust_status != 'active' THEN RAISE EXCEPTION 'Customer status: %', v_cust_status; END IF;
    IF v_from_balance < p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

    IF v_from_currency != v_to_currency THEN
        SELECT rate INTO v_exchange_rate FROM exchange_rates
        WHERE from_currency = v_from_currency AND to_currency = v_to_currency
        ORDER BY valid_from DESC LIMIT 1;
        IF v_exchange_rate IS NULL THEN RAISE EXCEPTION 'Exchange rate missing'; END IF;
    END IF;

    IF p_currency = 'KZT' THEN v_amount_in_kzt := p_amount;
    ELSE
        SELECT rate INTO v_kzt_rate FROM exchange_rates WHERE from_currency = p_currency AND to_currency = 'KZT' LIMIT 1;
        v_amount_in_kzt := p_amount * COALESCE(v_kzt_rate, 0);
    END IF;

    SELECT COALESCE(SUM(amount_kzt), 0) INTO v_current_daily_usage
    FROM transactions
    WHERE from_account_id = v_from_id AND created_at::DATE = CURRENT_DATE AND status = 'completed';

    IF (v_current_daily_usage + v_amount_in_kzt) > v_daily_limit THEN
        RAISE EXCEPTION 'Daily limit exceeded';
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = v_from_id;
    UPDATE accounts SET balance = balance + (p_amount * v_exchange_rate) WHERE account_id = v_to_id;

    INSERT INTO transactions (from_account_id, to_account_id, amount, currency, exchange_rate, amount_kzt, type, status, description, completed_at)
    VALUES (v_from_id, v_to_id, p_amount, p_currency, v_exchange_rate, v_amount_in_kzt, 'transfer', 'completed', p_description, NOW());

    INSERT INTO audit_log (table_name, record_id, action, new_values, description)
    VALUES ('transactions', lastval(), 'INSERT', jsonb_build_object('amount', p_amount, 'from', p_from_acc_num), 'Transfer processed');

EXCEPTION WHEN OTHERS THEN
    INSERT INTO audit_log (table_name, action, description) VALUES ('transactions', 'FAILURE', SQLERRM);
    RAISE;
END;
$$;

-- task 2

CREATE VIEW customer_balance_summary AS
SELECT
    c.full_name,
    a.account_number,
    a.currency,
    a.balance,
    CASE WHEN a.currency = 'KZT' THEN a.balance
         ELSE a.balance * COALESCE((SELECT rate FROM exchange_rates er WHERE er.from_currency = a.currency AND er.to_currency = 'KZT' LIMIT 1), 0)
    END as balance_in_kzt,
    DENSE_RANK() OVER (ORDER BY SUM(CASE WHEN a.currency = 'KZT' THEN a.balance ELSE a.balance * COALESCE((SELECT rate FROM exchange_rates er WHERE er.from_currency = a.currency AND er.to_currency = 'KZT' LIMIT 1), 0) END) OVER (PARTITION BY c.customer_id) DESC) as wealth_rank
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id;

CREATE VIEW daily_transaction_report AS
SELECT
    created_at::DATE as trans_date,
    type,
    COUNT(*) as trans_count,
    SUM(amount_kzt) as total_volume_kzt,
    AVG(amount_kzt) as avg_amount_kzt,
    SUM(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE) as running_total,
    (SUM(amount_kzt) - LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE)) / NULLIF(LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE), 0) * 100 as growth_pct
FROM transactions
WHERE status = 'completed'
GROUP BY created_at::DATE, type;

CREATE VIEW suspicious_activity_view WITH (security_barrier = true) AS
SELECT t.transaction_id, c.full_name, t.amount_kzt, t.created_at
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount_kzt > 5000000
   OR (SELECT COUNT(*) FROM transactions t2 WHERE t2.from_account_id = t.from_account_id AND t2.created_at BETWEEN t.created_at - INTERVAL '1 hour' AND t.created_at) > 10;

-- task 3

CREATE INDEX idx_accounts_lookup ON accounts(account_number) INCLUDE (balance, currency);

CREATE INDEX idx_active_accounts ON accounts(account_id) WHERE is_active = TRUE;

CREATE INDEX idx_customer_email_lower ON customers(lower(email));

CREATE INDEX idx_audit_json ON audit_log USING GIN (new_values);

CREATE INDEX idx_trans_limit_check ON transactions(from_account_id, created_at);

-- task 4

CREATE OR REPLACE PROCEDURE process_salary_batch(
    p_company_acc_num VARCHAR,
    p_payments JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_company_id INT;
    v_company_balance NUMERIC;
    v_total_batch_amount NUMERIC := 0;
    v_payment JSONB;
    v_emp_iin VARCHAR;
    v_pay_amount NUMERIC;
    v_emp_acc_id INT;
    v_success_count INT := 0;
    v_failed_count INT := 0;
    v_failed_details JSONB := '[]'::JSONB;
    v_actual_deduction NUMERIC := 0;
BEGIN
    IF NOT pg_try_advisory_xact_lock(hashtext(p_company_acc_num)) THEN
        RAISE EXCEPTION 'Batch processing already in progress for this company';
    END IF;

    SELECT account_id, balance INTO v_company_id, v_company_balance
    FROM accounts WHERE account_number = p_company_acc_num FOR UPDATE;

    SELECT SUM((item->>'amount')::numeric) INTO v_total_batch_amount
    FROM jsonb_array_elements(p_payments) AS item;

    IF v_company_balance < v_total_batch_amount THEN
        RAISE EXCEPTION 'Insufficient company funds';
    END IF;

    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        v_emp_iin := v_payment->>'iin';
        v_pay_amount := (v_payment->>'amount')::NUMERIC;

        BEGIN
            SELECT a.account_id INTO v_emp_acc_id
            FROM accounts a JOIN customers c ON a.customer_id = c.customer_id
            WHERE c.iin = v_emp_iin AND a.currency = 'KZT' AND a.is_active = TRUE LIMIT 1;

            IF v_emp_acc_id IS NULL THEN RAISE EXCEPTION 'Employee account not found'; END IF;

            UPDATE accounts SET balance = balance + v_pay_amount WHERE account_id = v_emp_acc_id;

            INSERT INTO transactions (from_account_id, to_account_id, amount, currency, type, status, description, created_at)
            VALUES (v_company_id, v_emp_acc_id, v_pay_amount, 'KZT', 'transfer', 'completed', 'Salary: ' || (v_payment->>'description'), NOW());

            v_success_count := v_success_count + 1;
            v_actual_deduction := v_actual_deduction + v_pay_amount;

        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
            v_failed_details := v_failed_details || jsonb_build_object('iin', v_emp_iin, 'error', SQLERRM);
        END;
    END LOOP;

    UPDATE accounts SET balance = balance - v_actual_deduction WHERE account_id = v_company_id;

    RAISE NOTICE 'Batch Complete. Success: %, Failed: %, Details: %', v_success_count, v_failed_count, v_failed_details;
END;
$$;
