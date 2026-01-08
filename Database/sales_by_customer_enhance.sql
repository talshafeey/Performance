-- API: dashboard/salesByCustomer?fromDate=1970-01-01+00:00:00&toDate=2026-01-04+23:59:59&storeId=&regionId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: byCustomer
-- OLD_TIME FOR ALL DATA: 14-16s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 4-6s


--- OLD QUERY ---


select c.id id, concat(c.first_name, ' ', c.last_name) name, 
             ROUND(SUM(CASE
                WHEN s.invoice_type = 'SALES' THEN s.net_amount
                WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount
                ELSE 0
            END)::DECIMAL, 2) :: FLOAT AS amount
        FROM sales_invoice_header s inner join ent_customer c on c.id = s.customer_id inner join ent_stores store on s.store_id = store.id
        WHERE payment_status IS NOT NULL
        AND invoice_type IN ('SALES', 'RETURNS')
        AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (1)
        group by c.id, concat(c.first_name, ' ', c.last_name) order by amount desc;



--- SCRIPT FOR VIEW ----

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


--- QUERY SAMPLE WITH VIEW ---

SELECT
	V.ID AS "id",
	V.NAME AS "name",
	SUM(V.AMOUNT) AS "amount",
	SUM(SUM(V.AMOUNT)) OVER () AS "totalSum"
FROM
	"view_sales_by_customer_performance" "v"
WHERE
	V.INVOICE_DATE_TIME BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59'
	AND V.PAYMENT_STATUS IS NOT NULL
	AND V.COMPANY_ID IN (1)
	AND V.COMPANY_ID IN (1)
	AND V.TENANT_ID IN (1)
	AND V.LEGAL_ENTITY_ID IN (1)
GROUP BY
	V.ID,
	V.NAME
ORDER BY
	AMOUNT DESC
LIMIT 5;
-- PARAMETERS: ["1969-12-31 21:00:00","2026-01-04 20:59:59",1,1,1,1]

--- RAW WITHOUT VIEWS ---

SELECT 
    s.customer_id as id,
    CONCAT(c.first_name, ' ', c.last_name) AS name,
    -- Calculate Amount
    SUM(CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
        ELSE 0 
    END) AS amount,
    -- Calculate Grand Total (for % calculation) in one pass
    SUM(SUM(CASE 
        WHEN s.invoice_type = 'SALES' THEN s.net_amount 
        WHEN s.invoice_type = 'RETURNS' THEN -s.net_amount 
        ELSE 0 
    END)) OVER() AS "totalSum"
FROM sales_invoice_header s
INNER JOIN ent_customer c ON s.customer_id = c.id
INNER JOIN ent_stores store ON s.store_id = store.id
WHERE s.payment_status IS NOT NULL
  AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2026-01-04 23:59:59' 
  -- Simulate filter conditions (Security Rules)
  AND s.company_id = 1
  AND s.tenant_id = 1
  AND s.legal_entity_id = 1
GROUP BY s.customer_id, c.first_name, c.last_name
ORDER BY amount DESC
LIMIT 5;

	