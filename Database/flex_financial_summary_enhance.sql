-- API: dashboard/flex/financial-summary?fromDate=1970-01-01+00:00:00&toDate=2026-01-05+23:59:59&groupBy=store&storeId=&regionId=&companyId=1&tenantId=1&legalEntityId=1&driverId=
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src\modules\dashboard\dashboard-flex.service.ts
-- METHOD: getFinancialSummary
-- OLD_TIME FOR API ON PRODUCTION: 10-14S
-- OLD_TIME query FOR ALL DATA ON PRODUCTION: 5-8s
-- NEW_TIME query for all DATA On Production: 3-5s



--- OLD QUERY ---

WITH daily_financials AS (
          SELECT 
            DATE(s.invoice_date_time) as transaction_date,
            EXTRACT(ISODOW FROM s.invoice_date_time) as day_number,
            TO_CHAR(s.invoice_date_time, 'Dy') as day_of_week,
            SUM(CASE 
              WHEN s.invoice_type = 'SALES' THEN s.invoice_amount 
              ELSE 0 
            END) as sales_amount
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          WHERE s.invoice_type IN ('SALES', 'RETURNS')
            AND s.fulfilment_type IN ('DELIVERY', 'HOME_DELIVERY')
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (1)
          GROUP BY DATE(s.invoice_date_time), EXTRACT(ISODOW FROM s.invoice_date_time), TO_CHAR(s.invoice_date_time, 'Dy')
        ),
        weekly_grouped AS (
          SELECT
            day_number,
            day_of_week,
            SUM(sales_amount) as total_sales
          FROM daily_financials
          GROUP BY day_number, day_of_week
        ),
        all_days_of_week AS (
          SELECT
            day_num as day_number,
            CASE day_num
              WHEN 1 THEN 'Mon'
              WHEN 2 THEN 'Tue'
              WHEN 3 THEN 'Wed'
              WHEN 4 THEN 'Thu'
              WHEN 5 THEN 'Fri'
              WHEN 6 THEN 'Sat'
              WHEN 7 THEN 'Sun'
            END as day_of_week
          FROM generate_series(1, 7) as day_num
        ),
        combined_data AS (
          SELECT
            ad.day_number,
            ad.day_of_week,
            ROUND(COALESCE(wg.total_sales, 0)::NUMERIC, 2) as sales_value
          FROM all_days_of_week ad
          LEFT JOIN weekly_grouped wg ON ad.day_number = wg.day_number
          ORDER BY ad.day_number
        ),
        current_period AS (
          SELECT
            ROUND(CAST(SUM(
              CASE
                WHEN s.invoice_type = 'SALES' THEN s.invoice_amount
                ELSE 0
              END
            ) AS NUMERIC), 2) AS total_order_value,
            COUNT(DISTINCT CASE
              WHEN s.invoice_type = 'SALES' THEN s.id
            END) as total_orders,
            ROUND(CAST(SUM(
              CASE
                WHEN s.invoice_type = 'RETURNS' THEN s.invoice_amount
                ELSE 0
              END
            ) AS NUMERIC), 2) AS total_returns_value,
            ROUND(CAST(SUM(
              CASE
                WHEN s.invoice_type = 'SALES' THEN s.invoice_amount
                WHEN s.invoice_type = 'RETURNS' THEN -s.invoice_amount
                ELSE 0
              END
            ) AS NUMERIC), 2) AS total_sale_value
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          WHERE s.invoice_type IN ('SALES', 'RETURNS')
            AND s.fulfilment_type IN ('DELIVERY')
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (1)
        )
        SELECT
          cp.total_order_value,
          CASE
            WHEN cp.total_orders > 0
            THEN ROUND((cp.total_order_value / cp.total_orders)::NUMERIC, 2)
            ELSE 0
          END as average_order_value,
          cp.total_returns_value as returns_value,
          cp.total_sale_value,
          json_agg(
            json_build_object(
              'day_of_week', cd.day_of_week,
              'sales_value', cd.sales_value
            ) ORDER BY cd.day_number
          ) as weekly_data
        FROM combined_data cd
        CROSS JOIN current_period cp
        GROUP BY cp.total_order_value, cp.total_orders, cp.total_returns_value, cp.total_sale_value;


--- NEW QUERY WRITTEN IN ORM SYNTAX ---
WITH "base_metrics" AS (SELECT EXTRACT(ISODOW FROM s.invoice_date_time) AS "day_number", SUM(CASE WHEN s.invoice_type = 'SALES' 
THEN s.invoice_amount ELSE 0 END) AS "daily_sales", SUM(CASE WHEN s.invoice_type = 'SALES' AND s.fulfilment_type = 'DELIVERY' 
THEN s.invoice_amount ELSE 0 END) AS "daily_delivery_sales", COUNT(DISTINCT CASE WHEN s.invoice_type = 'SALES' AND s.fulfilment_type = 'DELIVERY' 
THEN s.id END) AS "daily_delivery_orders", SUM(CASE WHEN s.invoice_type = 'RETURNS' AND s.fulfilment_type = 'DELIVERY'
THEN s.invoice_amount ELSE 0 END) AS "daily_delivery_returns", SUM(CASE WHEN s.fulfilment_type = 'DELIVERY' 
THEN (CASE WHEN s.invoice_type = 'SALES' THEN s.invoice_amount WHEN s.invoice_type = 'RETURNS' 
THEN -s.invoice_amount ELSE 0 END) ELSE 0 END) AS "daily_net_value" FROM "sales_invoice_header" "s" 
INNER JOIN "ent_stores" "store" ON s.store_id = store.id AND COALESCE(store.is_deleted, false) = false WHERE s.invoice_type IN ('SALES', 'RETURNS') AND s.fulfilment_type IN ('DELIVERY', 'HOME_DELIVERY') AND 1=1 AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (1) GROUP BY EXTRACT(ISODOW FROM s.invoice_date_time)),
"all_days" AS (
        SELECT ds.d as day_num,
          CASE ds.d
            WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed'
            WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat'
            WHEN 7 THEN 'Sun'
          END as day_of_week
        FROM generate_series(1, 7) as ds(d)
      ) SELECT ad.day_num AS "day_num", ad.day_of_week AS "day_of_week", ROUND(COALESCE(bm.daily_sales, 0)::NUMERIC, 2) 
      AS "sales_value", SUM(COALESCE(bm.daily_delivery_sales, 0)) OVER () AS "total_order_value",
      SUM(COALESCE(bm.daily_delivery_orders, 0)) OVER () AS "total_orders",
      SUM(COALESCE(bm.daily_delivery_returns, 0)) OVER () AS "total_returns_value",
      SUM(COALESCE(bm.daily_net_value, 0)) OVER () AS "total_sale_value" FROM "all_days" "ad" 
      LEFT JOIN "base_metrics" "bm" ON ad.day_num = bm.day_number ORDER BY ad.day_num asc; 

	  ------- RANDOM ---------


SELECT 
    day_num, 
    day_name
FROM (
    VALUES
        (1, 'Mon'),
        (2, 'Tue'),
        (3, 'Wed'),
        (4, 'Thu'),
        (5, 'Fri'),
        (6, 'Sat'),
        (7, 'Sun')
) AS days(day_num, day_name);