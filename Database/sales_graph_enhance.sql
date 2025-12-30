-- API: dashboard/salesGraph?fromDate=1970-01-01+00:00:00&toDate=2025-12-30+23:59:59&type=SALES&storeId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: customerPie
-- OLD_TIME FOR ALL DATA: 7-14s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 4-6s


--- OLD QUERY ---

SELECT 
    DATE_TRUNC('MONTH', s.invoice_date_time) AS "month", 
    -- 1. Net Sales (Sales - Returns)
    ROUND(SUM(
        CASE 
            WHEN s.invoice_type = 'SALES' THEN s.net_amount 
            WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
            ELSE 0 
        END
    )::NUMERIC, 2) AS "netSales",
    
    -- 2. Returns only
    ROUND(SUM(
        CASE  
            WHEN s.invoice_type = 'RETURNS' THEN s.net_amount 
            ELSE 0 
        END
    )::NUMERIC, 2) AS "returns",

    -- 3. Total Sales only
    ROUND(SUM(
        CASE  
            WHEN s.invoice_type = 'SALES' THEN s.net_amount 
            ELSE 0 
        END
    )::NUMERIC, 2) AS "totalSales"

FROM sales_invoice_header s
-- The "join" part
INNER JOIN ent_stores store ON s.store_id = store.id 

-- The "condition" part
WHERE s.invoice_type IN ('SALES', 'RETURNS')
  AND s.company_id = 1
  AND s.tenant_id = 1
  AND s.legal_entity_id = 1
  AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-30 23:59:59'
  -- Example extra conditions from addConditionsV2
  AND s.payment_status IS NOT NULL
  AND store.region_id IN (5, 12) 

GROUP BY DATE_TRUNC('MONTH', s.invoice_date_time)
ORDER BY "month" ASC;


--- SCRIPT FOR VIEW ----

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



--- SELECT QUERY USING VIEW ---

SELECT 
    month_date AS "month",
    ROUND(SUM(net_amount)::NUMERIC, 2) AS "totalSales"
FROM view_sales_graph_analytics
WHERE company_id = 1
  AND tenant_id = 1
  AND legal_entity_id = 1
  AND invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-30 23:59:59'
GROUP BY month_date
ORDER BY month_date;