-- Migration SQL for Views and Indexes
-- Generated from SQL enhancement files

-- Views

CREATE OR REPLACE VIEW v_product_sales_enriched AS
SELECT
    p.id AS product_id,
    p.short_name AS name,
    p.alt_short_name AS altName,
    p.code,
    p.image AS productImage,
    p.hex_code AS productHexCode,
	s.store_id, 
    s.invoice_date_time,
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.payment_status,
    -- Calculate raw amounts here so we can sum them in the final query
    CASE
        WHEN s.invoice_type = 'SALES' THEN sil.net_amount
        WHEN s.invoice_type = 'RETURNS' THEN -sil.net_amount
        ELSE 0
    END AS net_amount,
    sil.quantity
FROM sales_invoice_header s
INNER JOIN sales_invoice_lines sil ON sil.invoice_id = s.id
INNER JOIN prd_products p ON sil.product_id = p.id
WHERE s.invoice_type IN ('SALES', 'RETURNS')
  AND p.product_classification = 'SERVICE_PRODUCT';

CREATE OR REPLACE VIEW view_sales_graph_analytics AS
SELECT 
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.store_id,
    s.invoice_date_time,
    -- Truncate to month for grouping
    DATE_TRUNC('month', s.invoice_date_time) AS "month_date",
    -- Raw Sales Amount
    CASE WHEN s.invoice_type = 'SALES' THEN s.net_amount ELSE 0 END AS raw_sales,
    -- Raw Returns Amount
    CASE WHEN s.invoice_type = 'RETURNS' THEN s.net_amount ELSE 0 END AS raw_returns,
    -- Net Amount (Sales minus Returns)
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
        ELSE 0 
    END AS net_amount
FROM sales_invoice_header s;

CREATE OR REPLACE VIEW view_sales_invoice_analytics AS
SELECT 
    s.id AS invoice_id,
    s.invoice_type,
    s.store_id,
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.invoice_date_time,
    s.payment_status,
    s.net_amount, -- Added the raw column back for the CASE statements
    -- Pre-calculate Net Amount (positive for sales, negative for returns)
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
        ELSE 0 
    END AS effective_net_amount,
    COALESCE(s.tax, 0) AS tax_amount,
    COALESCE(s.total_discount, 0) AS discount_amount,
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.total_discount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.total_discount 
        ELSE 0 
    END AS effective_discount
FROM sales_invoice_header s;

CREATE OR REPLACE VIEW view_dashboard_lost_sales AS
SELECT 
    net_amount AS lost_sale_amount,
    order_date_time AS event_date,
    company_id,
    tenant_id,
    legal_entity_id,
    store_id
FROM sales_order_header
WHERE order_type = 'LOST_SALES';

CREATE OR REPLACE VIEW view_sales_by_customer_performance AS
SELECT
    s.customer_id as id,
    concat(c.first_name, ' ', c.last_name) AS name,
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.store_id,
    s.pos_id,
    s.invoice_date_time,
    s.payment_status,
    -- Pre-calculate effective amount (Sales - Returns)
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
        ELSE 0 
    END AS amount,
    c.customer_class_id,
    store.region_id
FROM sales_invoice_header s
INNER JOIN ent_customer c ON s.customer_id = c.id
INNER JOIN ent_stores store ON s.store_id = store.id;

CREATE OR REPLACE VIEW view_category_sales_performance AS
SELECT 
    pc.id AS category_id,
    pc.name AS category_name,
    pc.alt_name AS category_alt_name,
    s.store_id,
    s.invoice_date_time,
    s.payment_status,
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    -- Amount Calculation
    CASE 
        WHEN s.invoice_type = 'SALES' THEN sil.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -sil.net_amount 
        ELSE 0 
    END AS net_amount,
    -- Quantity Calculation (Logic from your current code)
    CASE 
        WHEN s.invoice_type = 'SALES' THEN sil.quantity
        WHEN s.invoice_type = 'RETURNS' THEN -sil.return_quantity
        ELSE 0
    END AS quantity
FROM sales_invoice_header s
INNER JOIN sales_invoice_lines sil ON sil.invoice_id = s.id
INNER JOIN prd_products p ON sil.product_id = p.id
INNER JOIN prd_product_categories pc ON p.product_category_id = pc.id
WHERE s.invoice_type IN ('SALES', 'RETURNS')
  AND p.product_classification = 'STANDARD_PRODUCT';

CREATE OR REPLACE VIEW view_customer_loyalty_analytics AS
SELECT 
    s.customer_id,
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.store_id,
    s.invoice_date_time,
    -- Calculate effective amount inline
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount
        ELSE 0 
    END AS effective_amount,
    -- This gets the first date without a subquery or CTE
    MIN(s.invoice_date_time) OVER(PARTITION BY s.customer_id) as first_purchase_date
FROM sales_invoice_header s
INNER JOIN ent_stores store ON s.store_id = store.id;

-- Overwritten views from DASHBOARD_OVERWRITE_SQL_SALES_DATA_ENHANCE_AND_SALES_BY_PAYMENT_METHOD_enhance.sql

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
FROM view_dashboard_sales_summary;

-- Indexes

CREATE INDEX idx_sales_header_search 
ON sales_invoice_header (tenant_id, company_id, legal_entity_id, invoice_date_time);

CREATE INDEX idx_payment_transactions_header 
ON payment_transactions (sales_invoice_header_id, transaction_status);