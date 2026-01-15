-- API: dashboard/topSellingProducts?fromDate=1970-01-01+00:00:00&toDate=2025-12-30+23:59:59&storeId=&regionId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: topSellingProducts
-- OLD_TIME FOR ALL DATA: 26-35s
-- NEW_TIME FOR ALL DATA: 3-5s

-- OLD QUERY --
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT -- 625-700 ms
    p.id AS id,
    p.short_name AS name,
    p.alt_short_name AS "altName",
    p.code,
    p.image AS "productImage",
    p.hex_code AS "productHexCode",
    ROUND(
        SUM(
            CASE
                WHEN s.invoice_type = 'SALES' THEN sil.net_amount
                WHEN s.invoice_type = 'RETURNS' THEN -sil.net_amount
                ELSE 0
            END
        )::DECIMAL,
        2
    )::FLOAT AS amount,
    SUM(quantity) AS qty
FROM sales_invoice_header s
INNER JOIN sales_invoice_lines sil
    ON sil.invoice_id = s.id
INNER JOIN prd_products p
    ON sil.product_id = p.id
WHERE s.payment_status IS NOT NULL
  AND s.invoice_type IN ('SALES', 'RETURNS')
  AND s.invoice_date_time BETWEEN
      TIMESTAMP '2021-10-01 00:00:00'
      AND TIMESTAMP '2025-12-30 23:59:59'
  AND s.company_id IN (1)
  AND s.tenant_id IN (1)
  AND s.legal_entity_id IN (1)
  And p.product_classification = 'STANDARD_PRODUCT'
GROUP BY
    p.id,
    p.short_name,
    p.alt_short_name,
    p.code
ORDER BY amount desc limit 5;


-- SCRIPT FOR THE NEW VIEW --
-- drop VIEW v_product_sales_enriched;
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
    s.customer_id,
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


-- SAMPLE QUERY FOR THE NEW VIEW -- 
  SELECT 
    product_id AS id,
    name,
    altName,
    code,
    productImage,
    productHexCode,
    ROUND(SUM(net_amount)::DECIMAL, 2)::FLOAT AS amount,
    SUM(quantity) AS qty
FROM v_product_sales_enriched
WHERE payment_status IS NOT NULL
  AND company_id = 1
  AND tenant_id = 1
  AND legal_entity_id = 1
  AND invoice_date_time BETWEEN
      TIMESTAMP '2021-10-01 00:00:00'
      AND TIMESTAMP '2025-12-30 23:59:59'
GROUP BY 
    product_id, name, altName, code, productImage, productHexCode
ORDER BY amount DESC 
LIMIT 5;



SELECT v.product_id AS "id", 
v.name AS "name", v.altName AS "altName",
v.code AS "code", v.productImage AS "productImage", 
v.productHexCode AS "productHexCode", 
ROUND(SUM(v.net_amount)::DECIMAL, 2)::FLOAT AS "amount", 
SUM(v.quantity) AS "qty" 
FROM "v_product_sales_enriched" "v" 
WHERE v.invoice_date_time 
BETWEEN '1969-12-31 21:00:00' AND '2025-12-30 20:59:59' AND v.payment_status IS NOT NULL AND
v.company_id IN (1) AND v.company_id IN (1) AND
v.tenant_id IN (1) AND v.legal_entity_id IN (1) GROUP BY
v.product_id, v.name, v.altName, v.code, v.productImage, 
v.productHexCode ORDER BY amount DESC LIMIT 5; -- PARAMETERS: ["1969-12-31 21:00:00","2025-12-30 20:59:59",1,1,1,1]


