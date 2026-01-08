-- API: dashboard/getCustomer?fromDate=1970-01-01+00:00:00&toDate=2026-01-04+23:59:59&storeId=&regionId=&legalEntityId=&customerClassId=&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: getCustomer
-- OLD_TIME FOR ALL DATA: 14-20s
-- NEW_TIME FOR ALL DATA RUNNING THE VIEW: 2-5s


--- OLD QUERY ---
WITH invoice_data AS (
        SELECT COUNT(DISTINCT s.customer_id)::int AS active_customer
        FROM sales_invoice_header s
         inner join ent_customer c on s.customer_id = c.id
        WHERE s.payment_status IS NOT NULL
          AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1)
      ),
      new_customer_data AS (
        SELECT COUNT(*)::int AS new_customer
        FROM ent_customer c

        WHERE c.is_deleted = false
          AND c.customer_created_on::timestamp BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND c.company_id IN (1) AND c.tenant_id IN (1)
      ),
      converted_customer_data AS (
        SELECT COUNT(DISTINCT s.customer_id)::int AS converted_customer
        FROM sales_invoice_header s
         inner join ent_customer c on s.customer_id = c.id
        WHERE s.payment_status IS NOT NULL
          AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1)
          AND s.customer_id IN (
            SELECT c.id
            FROM ent_customer c

            WHERE c.id IS NOT NULL
            -- c.is_deleted = false
              AND c.customer_created_on::timestamp BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-04 23:59:59' AND c.company_id IN (1) AND c.tenant_id IN (1)
          )
      ),
      total_customer_data AS (
        SELECT COUNT(*)::int AS total_customer
        FROM ent_customer c

        WHERE c.is_deleted = false
           AND c.company_id IN (1) AND c.tenant_id IN (1)
      )
      SELECT
        t.total_customer,
        i.active_customer,
        n.new_customer,
        c.converted_customer,
        n.new_customer AS total_visitors,
        CASE WHEN n.new_customer > 0
             THEN ROUND((c.converted_customer::numeric / n.new_customer) * 100, 2)
             ELSE 0 END AS conversion_rate
      FROM invoice_data i, new_customer_data n, converted_customer_data c, total_customer_data t;



--- SCRIPT FOR NEW VIEW --- NO VIEW WAS ADDED HERE

  SELECT
          COUNT(*) FILTER (WHERE is_deleted = false) as "totalCustomer",
          COUNT(*) FILTER (WHERE customer_created_on::timestamp BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59' AND is_deleted = false) as "newCustomer"
        FROM ent_customer
        WHERE company_id = 1 AND tenant_id = 1;
       -- PARAMETERS: ["1969-12-31 21:00:00","2026-01-04 20:59:59","1","1"]
  
  SELECT
          COUNT(DISTINCT s.customer_id) as "activeCustomer",
          COUNT(DISTINCT s.customer_id) FILTER (WHERE c.customer_created_on::timestamp BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59') as "convertedCustomer"
        FROM sales_invoice_header s
        INNER JOIN ent_customer c ON s.customer_id = c.id
        WHERE s.invoice_date_time::timestamp BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59'
          AND s.payment_status IS NOT NULL
          AND s.company_id = 1
          AND s.tenant_id = 1;



--- SAMPLE QUERY WITH VIEW ---

SELECT COUNT(DISTINCT CASE WHEN v.is_deleted = false THEN v.customer_id END) AS "totalCustomer", COUNT(DISTINCT CASE 
            WHEN v.invoice_date_time::timestamp BETWEEN $1 AND $2
                 AND v.payment_status IS NOT NULL
            THEN v.customer_id
        END) AS "activeCustomer", COUNT(DISTINCT CASE
            WHEN v.customer_created_on::timestamp BETWEEN $1 AND $2
                 AND v.is_deleted = false
            THEN v.customer_id
        END) AS "newCustomer", COUNT(DISTINCT CASE
            WHEN v.customer_created_on::timestamp BETWEEN $1 AND $2
                 AND v.invoice_date_time::timestamp BETWEEN $1 AND $2
                 AND v.payment_status IS NOT NULL
            THEN v.customer_id
        END) AS "convertedCustomer" FROM "view_customer_activity_summary" "v" WHERE v.company_id IN ($3) AND v.company_id IN ($4) AND v.tenant_id IN ($5)
 -- PARAMETERS: ["1969-12-31 21:00:00","2026-01-04 20:59:59",1,1,1]

--- RANDOM ---------


SELECT
    -- Part 1: Stats from Customer Table (Fast)
    (SELECT COUNT(*) FROM ent_customer 
     WHERE is_deleted = false AND company_id = 1 AND tenant_id = 1) AS "totalCustomer",
     
    (SELECT COUNT(*) FROM ent_customer 
     WHERE customer_created_on BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59' 
       AND is_deleted = false AND company_id = 1 AND tenant_id = 1) AS "newCustomer",

    -- Part 2: Stats from Invoice Table (Index Optimized)
    stats.activeCustomer,
    stats.convertedCustomer
FROM (
    SELECT 
        COUNT(DISTINCT s.customer_id) AS activeCustomer,
        COUNT(DISTINCT CASE 
            WHEN c.customer_created_on BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59' THEN s.customer_id 
        END) AS convertedCustomer
    FROM sales_invoice_header s
    INNER JOIN ent_customer c ON s.customer_id = c.id
    WHERE s.invoice_date_time BETWEEN '1969-12-31 21:00:00' AND '2026-01-04 20:59:59'
      AND s.payment_status IS NOT NULL
      AND s.company_id = 1
      AND s.tenant_id = 1
) stats;