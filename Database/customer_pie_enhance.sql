-- API: dashboard/customerPie?fromDate=1970-01-01+00:00:00&toDate=2025-12-30+23:59:59&storeId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: customerPie
-- OLD_TIME FOR ALL DATA: 7-14s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 4-6s


--- OLD QUERY --- ET: 3s on QA
WITH current_sales AS (
    SELECT 
        s.customer_id,
        SUM(CASE 
            WHEN s.invoice_type = 'SALES' THEN s.net_amount
            WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount
            ELSE 0 
        END) AS sales
    FROM sales_invoice_header s 
    INNER JOIN ent_stores store ON s.store_id = store.id
    WHERE s.invoice_date_time IS NOT NULL
      AND s.invoice_date_time BETWEEN '1969-12-31 21:00:00' AND '2025-12-30 20:59:59'
      AND s.company_id IN (1) 
      AND s.tenant_id IN (1) 
      AND s.legal_entity_id IN (1)
    GROUP BY s.customer_id
	order by s.customer_id desc
)
SELECT 
    cs.customer_id,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM sales_invoice_header s 
            INNER JOIN ent_stores store ON s.store_id = store.id
            WHERE s.customer_id = cs.customer_id
              AND s.invoice_date_time IS NOT NULL
              AND s.invoice_date_time < '1969-12-31 21:00:00'
              AND s.company_id IN (1) 
              AND s.tenant_id IN (1) 
              AND s.legal_entity_id IN (1)
            LIMIT 1
        ) THEN 'Existing Customer'
        ELSE 'New Customer'
    END AS customertype,
    cs.sales
FROM current_sales cs;


---- SCRIPT FOR VIEW ---

drop view view_customer_loyalty_analytics;
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


--- SELECT FROM NEW VIEW ---- ETL 2s


SELECT 
    customer_id,
    SUM(effective_amount) AS sales,
    CASE 
        WHEN MIN(first_purchase_date) < '1969-12-31 21:00:00' THEN 'Existing Customer'
        ELSE 'New Customer'
    END AS customertype
FROM view_customer_loyalty_analytics
WHERE company_id = 1
  AND invoice_date_time BETWEEN '1969-12-31 21:00:00' AND '2025-12-30 20:59:59'
GROUP BY customer_id

order by customer_id desc;

--- RAW QUERY NO VIEWS ---

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






------- RANDOM this can work too but kind of slower --------

WITH current_sales AS (
    SELECT 
        s.customer_id,
        SUM(CASE 
            WHEN s.invoice_type = 'SALES' THEN s.net_amount
            WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount
            ELSE 0 
        END) AS sales
    FROM sales_invoice_header s 
    INNER JOIN ent_stores store ON s.store_id = store.id
    WHERE s.invoice_date_time BETWEEN '1969-12-31 21:00:00' AND '2025-12-30 20:59:59'
      AND s.company_id = 1 
      AND s.tenant_id = 1 
      AND s.legal_entity_id = 1
    GROUP BY s.customer_id
	order by s.customer_id desc
)
SELECT 
    cs.customer_id,
    cs.sales,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM sales_invoice_header h
            WHERE h.customer_id = cs.customer_id
              AND h.invoice_date_time < '1969-12-31 21:00:00'
              AND h.company_id = 1
              AND h.tenant_id = 1
            LIMIT 1
        ) THEN 'Existing Customer'
        ELSE 'New Customer'
    END AS customertype
FROM current_sales cs;