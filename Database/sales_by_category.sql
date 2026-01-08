-- API: dashboard/salesByCategroy?fromDate=1970-01-01+00:00:00&toDate=2026-01-04+23:59:59&storeId=&regionId=&legalEntityId=&customerClassId=&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: salesByCategroy
-- OLD_TIME FOR ALL DATA: 18-25s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 2-5s




--- OLD QUERY ----

select pc.id id, pc.name name, pc.alt_name altName, 
            ROUND(SUM(CASE
                WHEN s.invoice_type = 'SALES' THEN s.net_amount
                WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount
                ELSE 0
            END)::DECIMAL, 2) :: FLOAT AS amount,
                  SUM(
              CASE
                  WHEN s.invoice_type = 'SALES' THEN quantity
                  WHEN s.invoice_type = 'RETURNS' THEN -return_quantity
                  ELSE 0
              END
          ) AS qty
            FROM sales_invoice_header s
            INNER JOIN sales_invoice_lines sil ON sil.invoice_id = s.id
            INNER JOIN prd_products p ON sil.product_id = p.id
            INNER JOIN prd_product_categories pc ON p.product_category_id = pc.id inner join ent_stores store on s.store_id = store.id  
            WHERE payment_status IS NOT NULL  AND s.invoice_type IN ('SALES', 'RETURNS')
              AND p.product_classification='STANDARD_PRODUCT'
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1)
        group by pc.id, pc.name, pc.alt_name order by qty desc;


---- NEW VIEW SCRIPT ---

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


--- SAMPLE QUERY WITH VIEW ---
SELECT
	V.CATEGORY_ID AS "id",
	V.CATEGORY_NAME AS "name",
	V.CATEGORY_ALT_NAME AS "altname",
	ROUND(SUM(V.NET_AMOUNT)::DECIMAL, 2)::FLOAT AS "amount",
	SUM(V.QUANTITY) AS "qty",
	SUM(SUM(V.QUANTITY)) OVER () AS "totalQty",
	SUM(SUM(V.NET_AMOUNT)) OVER () AS "totalAmount"
FROM
	"view_category_sales_performance" "v"
WHERE
	V.INVOICE_DATE_TIME BETWEEN $1 AND $2
	AND V.PAYMENT_STATUS IS NOT NULL
	AND V.COMPANY_ID IN ($3)
	AND V.COMPANY_ID IN ($4)
	AND V.TENANT_ID IN ($5)
GROUP BY
	V.CATEGORY_ID,
	V.CATEGORY_NAME,
	V.CATEGORY_ALT_NAME
ORDER BY
	QTY DESC
LIMIT
	5 -- PARAMETERS: ["1969-12-31 21:00:00","2026-01-04 20:59:59",1,1,1]