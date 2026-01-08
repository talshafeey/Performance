DROP VIEW IF EXISTS view_sales_by_payment_performance CASCADE;
DROP VIEW IF EXISTS view_dashboard_master_analytics CASCADE;
DROP VIEW IF EXISTS view_dashboard_sales_summary CASCADE;


CREATE OR REPLACE VIEW view_sales_by_payment_performance AS
WITH ranked_payments AS (
    SELECT 
        s.id AS invoice_id,
        pt.payment_method_type,
        pt.amount,
        ROW_NUMBER() OVER (PARTITION BY s.id, pt.payment_method_type ORDER BY pt.id) as rn,
        s.change_amount,
        sp.name AS sub_payment_name,
        sp.image AS sub_payment_image,
        pm.image AS main_payment_image,
        s.store_id,
        s.customer_id,
        s.invoice_date_time,
        s.company_id,
        s.tenant_id,
        s.legal_entity_id,
        s.payment_status,
        pt.transaction_status
    FROM sales_invoice_header s
    INNER JOIN payment_transactions pt ON s.id = pt.sales_invoice_header_id
    LEFT JOIN ent_sub_payment_method sp ON pt.sub_payment_method_id = sp.id
    LEFT JOIN ent_payment_methods pm ON pt.payment_method_id = pm.id
)
SELECT
    -- Final display name (Sub-payment name for cards, or main method name)
    CASE
        WHEN payment_method_type = 'CARD' AND sub_payment_name IS NOT NULL THEN sub_payment_name
        WHEN payment_method_type != 'CARD' THEN payment_method_type
        ELSE 'CARD'
    END AS name,
    -- Final display image
    CASE
        WHEN payment_method_type = 'CARD' AND sub_payment_name IS NOT NULL THEN sub_payment_image
        WHEN payment_method_type != 'CARD' THEN main_payment_image
        ELSE ''
    END AS image,
    -- The "Effective Amount" (Deducts change from Cash once per invoice to avoid double-counting)
    CASE
        WHEN payment_method_type = 'CASH' AND rn = 1
        THEN amount - COALESCE(change_amount, 0)
        ELSE amount
    END AS amount,
    -- Filter columns
    store_id,
    customer_id,
    invoice_date_time,
    company_id,
    tenant_id,
    legal_entity_id,
    payment_status,
    transaction_status
FROM ranked_payments;



----------- 
CREATE OR REPLACE VIEW view_dashboard_sales_summary AS
SELECT 
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.store_id,
    s.customer_id,
    s.invoice_date_time AS event_date,
    s.payment_status,
    -- Gross values (Net + Tax) for high-level reconciliation with payment methods
    CASE WHEN s.invoice_type = 'SALES' THEN (s.net_amount + COALESCE(s.tax, 0)) ELSE 0 END AS sale_amount,
    CASE WHEN s.invoice_type = 'RETURNS' THEN (s.net_amount + COALESCE(s.tax, 0)) ELSE 0 END AS return_amount,
    -- Net values (Sales minus Returns) - uses Gross for total consistency
    CASE 
        WHEN s.invoice_type = 'SALES' THEN (s.net_amount + COALESCE(s.tax, 0))
        WHEN s.invoice_type = 'RETURNS' THEN -(s.net_amount + COALESCE(s.tax, 0))
        ELSE 0 
    END AS net_amount,
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.total_discount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.total_discount 
        ELSE 0 
    END AS net_discount,
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.tax 
        WHEN s.invoice_type = 'RETURNS' THEN -s.tax 
        ELSE 0 
    END AS net_tax,
    -- For unique order counting
    CASE WHEN s.invoice_type = 'SALES' THEN s.id ELSE NULL END AS sale_order_id
FROM sales_invoice_header s;

CREATE OR REPLACE VIEW view_dashboard_master_analytics AS
SELECT 
    company_id, tenant_id, legal_entity_id, store_id, customer_id, event_date, payment_status,
    sale_amount, return_amount, net_amount, net_discount, net_tax, sale_order_id,
    0::numeric AS lost_sale_amount
FROM view_dashboard_sales_summary

UNION ALL

SELECT 
    company_id, tenant_id, legal_entity_id, store_id, 
    NULL::integer as customer_id, -- Using NULL if sales_order_header doesn't have customer_id
    order_date_time AS event_date, 'PAID' as payment_status,
    0, 0, 0, 0, 0, NULL,
    net_amount AS lost_sale_amount
FROM sales_order_header
WHERE order_type = 'LOST_SALES';







SELECT 
    COUNT(*) as total_mismatches,
    SUM((s.net_amount + s.tax) - pay.pay_total) as total_gap_amount,
    SUM(s.change_amount) as total_change_given
FROM sales_invoice_header s
JOIN (
    SELECT sales_invoice_header_id, SUM(amount) as pay_total 
    FROM payment_transactions 
    WHERE transaction_status = 'PAID'
    GROUP BY sales_invoice_header_id
) pay ON s.id = pay.sales_invoice_header_id
WHERE ABS((s.net_amount + s.tax) - pay.pay_total) > 0.01;








------------------------


CREATE OR REPLACE VIEW view_sales_by_payment_performance AS
WITH ranked_payments AS (
    SELECT 
        s.id AS invoice_id,
        s.invoice_type, -- Added to distinguish Sales vs Returns
        pt.payment_method_type,
        pt.amount,
        -- We rank payments per invoice so we only subtract "change" from the first Cash entry
        ROW_NUMBER() OVER (PARTITION BY s.id, pt.payment_method_type ORDER BY pt.id) as rn,
        s.change_amount,
        sp.name AS sub_payment_name,
        sp.image AS sub_payment_image,
        pm.image AS main_payment_image,
        s.store_id,
        s.customer_id,
        s.invoice_date_time,
        s.company_id,
        s.tenant_id,
        s.legal_entity_id,
        s.payment_status,
        pt.transaction_status
    FROM sales_invoice_header s
    INNER JOIN payment_transactions pt ON s.id = pt.sales_invoice_header_id
    LEFT JOIN ent_sub_payment_method sp ON pt.sub_payment_method_id = sp.id
    LEFT JOIN ent_payment_methods pm ON pt.payment_method_id = pm.id
)
SELECT
    -- 1. Display Name Logic
    CASE
        WHEN payment_method_type = 'CARD' AND sub_payment_name IS NOT NULL THEN sub_payment_name
        WHEN payment_method_type != 'CARD' THEN payment_method_type
        ELSE 'CARD'
    END AS name,

    -- 2. Display Image Logic
    CASE
        WHEN payment_method_type = 'CARD' AND sub_payment_name IS NOT NULL THEN sub_payment_image
        WHEN payment_method_type != 'CARD' THEN main_payment_image
        ELSE ''
    END AS image,

    -- 3. THE FIX: Effective Amount Logic
    -- This ensures Returns are negative and Cash Change is deducted
    CASE
        -- If it is a Return, the whole payment impact must be negative
        WHEN invoice_type = 'RETURNS' 
        THEN -ABS(amount) 
        
        -- If it is Cash, subtract the change given to the customer (only on the first cash row)
        WHEN payment_method_type = 'CASH' AND rn = 1
        THEN amount - COALESCE(change_amount, 0)
        
        -- Standard Sales payment
        ELSE amount
    END AS amount,

    -- 4. Metadata for filtering
    store_id,
    customer_id,
    invoice_date_time,
    company_id,
    tenant_id,
    legal_entity_id,
    payment_status,
    transaction_status
FROM ranked_payments;