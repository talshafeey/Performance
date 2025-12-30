-- API: dashboard/salesData?fromDate=1970-01-01+00:00:00&toDate=2025-12-30+23:59:59&storeId=&regionId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: salesData
-- OLD_TIME FOR ALL DATA: 15-20s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 1-3s
-- NEW_TIME FOR ALL DATA RUNNING 2 QUERIES AND JOING THEIR DATA: 1-2s


--- OLD QUERY ---


SELECT 
    s.id, 
    s.tax, 
    s.invoice_type, 
    s.net_amount,
    s.source, 
    s.total_discount,
    s.invoice_amount,
    s.gross_amount, 
    s.store_id 
FROM sales_invoice_header s 
WHERE s.payment_status IS NOT NULL
  AND s.company_id = 1
  AND s.tenant_id = 1
  AND s.legal_entity_id = 1
  AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-30 23:59:59';




 ----- VIEW FOR SCRIPT -----------

 CREATE OR REPLACE VIEW view_dashboard_sales_summary AS
SELECT 
    s.company_id,
    s.tenant_id,
    s.legal_entity_id,
    s.store_id,
    s.invoice_date_time AS event_date,
    s.payment_status,
    -- Positive raw values
    CASE WHEN s.invoice_type = 'SALES' THEN s.net_amount ELSE 0 END AS sale_amount,
    CASE WHEN s.invoice_type = 'RETURNS' THEN s.net_amount ELSE 0 END AS return_amount,
    -- Net values (Sales minus Returns)
    CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
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

-- drop view view_sales_invoice_analytics;
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

-- drop view view_dashboard_master_analytics;
CREATE OR REPLACE VIEW view_dashboard_master_analytics AS
SELECT 
    company_id, tenant_id, legal_entity_id, store_id, event_date, payment_status,
    sale_amount, return_amount, net_amount, net_discount, net_tax, sale_order_id,
    0 AS lost_sale_amount
FROM view_dashboard_sales_summary

UNION ALL

SELECT 
    company_id, tenant_id, legal_entity_id, store_id, event_date, 'PAID' as payment_status,
    0, 0, 0, 0, 0, NULL,
    lost_sale_amount
FROM view_dashboard_lost_sales;


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




------ QUERY FOR NEW VIEWS ------
SELECT 
    SUM(sale_amount) AS "totalSales",
    SUM(return_amount) AS "totalReturns",
    SUM(net_amount) AS "netSales",
    SUM(net_discount) AS "totalDiscount",
    SUM(net_tax) AS "tax",
    COUNT(DISTINCT sale_order_id) AS "orders",
    COUNT(DISTINCT store_id) AS "activeStores",
    SUM(lost_sale_amount) AS "lostSaledata"
FROM view_dashboard_master_analytics
WHERE company_id = 1
  AND tenant_id = 1
  AND legal_entity_id = 1
  AND event_date BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2025-12-30 23:59:59';


--------  TRY OUT NEW QUERY ----------

SELECT 
    SUM(sale_amount) AS "totalSales",
    SUM(return_amount) AS "totalReturns",
    SUM(net_amount) AS "netSales",
    SUM(net_discount) AS "totalDiscount",
    SUM(net_tax) AS "tax",
    COUNT(DISTINCT sale_order_id) AS "orders",
    COUNT(DISTINCT store_id) AS "activeStores",
    SUM(lost_sale_amount) AS "lostSaledata",
    ROUND(COALESCE(SUM(net_amount) / NULLIF(COUNT(DISTINCT sale_order_id), 0), 0)::numeric, 2) AS "avgSale"
FROM view_dashboard_master_analytics
WHERE company_id = 1
  AND tenant_id = 1
  AND legal_entity_id = 1
  AND event_date BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2025-12-30 23:59:59';

---------- TRY OUT RAW QUERY NO VIEWS -------------

SELECT 
    -- Sales and Returns
    SUM(CASE WHEN invoice_type = 'SALES' THEN net_amount ELSE 0 END) AS "totalSales",
    SUM(CASE WHEN invoice_type = 'RETURNS' THEN net_amount ELSE 0 END) AS "totalReturns",
    
    -- Net Totals (Sales - Returns)
    SUM(CASE WHEN invoice_type = 'SALES' THEN net_amount WHEN invoice_type = 'RETURNS' THEN -net_amount ELSE 0 END) AS "netSales",
    SUM(CASE WHEN invoice_type = 'SALES' THEN total_discount WHEN invoice_type = 'RETURNS' THEN -total_discount ELSE 0 END) AS "totalDiscount",
    SUM(CASE WHEN invoice_type = 'SALES' THEN tax WHEN invoice_type = 'RETURNS' THEN -tax ELSE 0 END) AS "tax",
    
    -- Counts
    COUNT(DISTINCT CASE WHEN invoice_type = 'SALES' THEN id END) AS "orders",
    COUNT(DISTINCT store_id) AS "activeStores"
    
FROM sales_invoice_header
WHERE company_id = 1 
  AND tenant_id = 1 
  AND legal_entity_id = 1
  AND payment_status IS NOT NULL
  AND invoice_date_time BETWEEN '2024-01-01 00:00:00' AND '2025-12-30 23:59:59';



  SELECT 
    COALESCE(SUM(net_amount), 0) AS "lostSaledata"
FROM sales_order_header
WHERE company_id = 1 
  AND tenant_id = 1 
  AND legal_entity_id = 1
  AND order_type = 'LOST_SALES'
  AND order_date_time BETWEEN '2024-01-01 00:00:00' AND '2025-12-30 23:59:59';