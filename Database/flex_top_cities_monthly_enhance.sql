-- API: dashboard/flex/top-cities-monthly?fromDate=1970-01-01+00:00:00&toDate=2026-01-05+23:59:59&groupBy=store&storeId=&regionId=&companyId=1&tenantId=1&legalEntityId=1&driverId=
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src\modules\dashboard\dashboard-flex.service.ts
-- METHOD: getTopCitiesMonthly
-- OLD_TIME FOR API ON PRODUCTION: 25-30S
-- OLD_TIME query FOR ALL DATA ON PRODUCTION: 10-13s
-- NEW_TIME query for all DATA On Production: 1-3s


--- OLD QUERY ---

WITH city_orders AS (
          SELECT
            c.id as city_id,
            c.code as city_code,
            c.name as city_name,
            DATE_TRUNC('month', s.invoice_date_time) as order_month,
            COUNT(DISTINCT s.id) as order_count
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          INNER JOIN ent_stores st ON s.store_id = st.id AND COALESCE(st.is_deleted, false) = false
          INNER JOIN ent_city c ON st.city_id = c.id AND COALESCE(c.is_deleted, false) = false
          WHERE s.fulfilment_type = 'DELIVERY'
            AND s.invoice_type = 'SALES'
            AND st.city_id IS NOT NULL
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (1)
          GROUP BY c.id, c.code, c.name, DATE_TRUNC('month', s.invoice_date_time)
        ),
        city_totals AS (
          SELECT
            city_id,
            city_code,
            city_name,
            SUM(order_count) as total_orders
          FROM city_orders
          GROUP BY city_id, city_code, city_name
          ORDER BY total_orders DESC
          LIMIT 5
        ),
        monthly_data AS (
          SELECT
            co.order_month,
            TO_CHAR(co.order_month, 'Mon') as month_label,
            json_object_agg(co.city_name, co.order_count) as city_orders
          FROM city_orders co
          INNER JOIN city_totals ct ON co.city_id = ct.city_id
          GROUP BY co.order_month
          ORDER BY co.order_month
        )
        SELECT
          json_build_object(
            'cities', (
              SELECT json_agg(
                json_build_object(
                  'id', city_id,
                  'code', city_code,
                  'name', city_name,
                  'total_orders', total_orders
                ) ORDER BY total_orders DESC
              )
              FROM city_totals
            ),
            'monthly_data', (
              SELECT COALESCE(json_agg(
                json_build_object(
                  'month', month_label,
                  'date', order_month,
                  'orders', city_orders
                ) ORDER BY order_month
              ), '[]'::json)
              FROM monthly_data
            )
          ) as result;




--- NO SCRIPT FOR NEW VIEW ---



---- USAGE FOR NEW query written with ORM syntax  ----

     WITH
	"city_orders" AS (
		SELECT
			C.ID AS "city_id",
			C.CODE AS "city_code",
			C.NAME AS "city_name",
			TO_CHAR(
				DATE_TRUNC('month', S.INVOICE_DATE_TIME),
				'YYYY-MM-DD"T"HH24:MI:SS'
			) AS "order_month_str",
			DATE_TRUNC('month', S.INVOICE_DATE_TIME) AS "order_month_raw",
			COUNT(S.ID) AS "order_count"
		FROM
			"sales_invoice_header" "s"
			INNER JOIN "ent_stores" "store" ON S.STORE_ID = STORE.ID
			AND COALESCE(STORE.IS_DELETED, FALSE) = FALSE
			INNER JOIN "ent_city" "c" ON STORE.CITY_ID = C.ID
			AND COALESCE(C.IS_DELETED, FALSE) = FALSE
		WHERE
			S.FULFILMENT_TYPE = 'DELIVERY'
			AND S.INVOICE_TYPE = 'SALES'
			AND 1 = 1
			AND S.INVOICE_DATE_TIME BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP  '2026-01-05 23:59:59'
			AND S.COMPANY_ID IN (1)
			AND S.TENANT_ID IN (1)
			AND S.LEGAL_ENTITY_ID IN (1)
		GROUP BY
			C.ID,
			C.CODE,
			C.NAME,
			DATE_TRUNC('month', S.INVOICE_DATE_TIME)
	),
	"top_5_cities" AS (
		SELECT
			CO.CITY_ID AS "city_id"
		FROM
			"city_orders" "co"
		GROUP BY
			CO.CITY_ID
		ORDER BY
			SUM(CAST(CO.ORDER_COUNT AS INT)) DESC
		LIMIT
			5
	)
SELECT
	CO.CITY_ID AS "city_id",
	CO.CITY_CODE AS "city_code",
	CO.CITY_NAME AS "city_name",
	CO.ORDER_MONTH_STR AS "order_month_str",
	CO.ORDER_MONTH_RAW AS "order_month_raw",
	CO.ORDER_COUNT AS "order_count"
FROM
	"city_orders" "co"
WHERE
	CO.CITY_ID IN (
		SELECT
			CITY_ID
		FROM
			TOP_5_CITIES
	)
ORDER BY
	CO.ORDER_MONTH_RAW ASC



--- RANDOM TESTING ---

WITH city_monthly_base AS (
    -- Step 1: Aggregate all city/month combinations once
    SELECT
        c.id AS city_id,
        c.code AS city_code,
        c.name AS city_name,
        DATE_TRUNC('month', s.invoice_date_time) AS order_month,
        COUNT(s.id) AS order_count
    FROM sales_invoice_header s
    INNER JOIN ent_stores st ON s.store_id = st.id
    INNER JOIN ent_city c ON st.city_id = c.id
    WHERE s.fulfilment_type = 'DELIVERY'
      AND s.invoice_type = 'SALES'
      AND s.company_id = 1 
      AND s.tenant_id = 1 
      AND s.legal_entity_id = 1
      AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2026-01-05 23:59:59'
      AND st.is_deleted = false 
      AND c.is_deleted = false
    GROUP BY 1, 2, 3, 4
),
top_5_cities AS (
    -- Step 2: Identify the top 5 cities based on total volume
    SELECT city_id, city_code, city_name, SUM(order_count) as total_orders
    FROM city_monthly_base
    GROUP BY 1, 2, 3
    ORDER BY total_orders DESC
    LIMIT 5
),
filtered_monthly_data AS (
    -- Step 3: Filter the monthly data to ONLY include those top 5 cities
    SELECT 
        b.order_month,
        b.city_name,
        b.order_count
    FROM city_monthly_base b
    INNER JOIN top_5_cities t ON b.city_id = t.city_id
)
-- Step 4: Final JSON Construction
SELECT json_build_object(
    'cities', (
        SELECT json_agg(json_build_object(
            'id', city_id, 'code', city_code, 'name', city_name, 'total_orders', total_orders
        ) ORDER BY total_orders DESC) FROM top_5_cities
    ),
    'monthly_data', (
        SELECT json_agg(json_build_object(
            'month', TO_CHAR(order_month, 'Mon'),
            'date', order_month,
            'orders', city_counts
        ) ORDER BY order_month)
        FROM (
            SELECT order_month, json_object_agg(city_name, order_count) as city_counts
            FROM filtered_monthly_data
            GROUP BY order_month
        ) sub
    )
) as result;






WITH city_delivery_base AS (
    SELECT
        c.id AS city_id,
        c.code AS city_code,
        c.name AS city_name,
        s.company_id,
        s.tenant_id,
        s.legal_entity_id,
        s.invoice_date_time,
        s.id AS invoice_id
    FROM sales_invoice_header s
    INNER JOIN ent_stores st ON s.store_id = st.id
    INNER JOIN ent_city c ON st.city_id = c.id
    WHERE s.fulfilment_type = 'DELIVERY'
      AND s.invoice_type = 'SALES'
      AND s.payment_status IS NOT NULL
      AND st.is_deleted = false 
      AND c.is_deleted = false
      AND s.company_id = 1
      AND s.tenant_id = 1
      AND s.legal_entity_id = 1
      AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-31 23:59:59'
),
city_monthly_base AS (
    SELECT
        city_id, city_code, city_name,
        DATE_TRUNC('month', invoice_date_time) AS order_month,
        COUNT(DISTINCT invoice_id) AS order_count
    FROM city_delivery_base
    GROUP BY 1, 2, 3, 4
),
top_5_cities AS (
    SELECT 
        city_id, city_code, city_name, 
        SUM(order_count) as total_orders
    FROM city_monthly_base
    GROUP BY 1, 2, 3
    ORDER BY total_orders DESC 
    LIMIT 5
),
monthly_data AS (
    SELECT 
        cmb.order_month,
        TO_CHAR(cmb.order_month, 'Mon') as month_label,
        json_object_agg(cmb.city_name, cmb.order_count) as city_orders
    FROM city_monthly_base cmb
    INNER JOIN top_5_cities t5 ON cmb.city_id = t5.city_id
    GROUP BY cmb.order_month
    ORDER BY cmb.order_month
)
SELECT 
    json_build_object(
        'cities', (SELECT json_agg(json_build_object('id', city_id, 'code', city_code, 'name', city_name, 'total_orders', total_orders) ORDER BY total_orders DESC) FROM top_5_cities),
        'monthly_data', (SELECT COALESCE(json_agg(json_build_object('month', month_label, 'date', order_month, 'orders', city_orders) ORDER BY order_month), '[]'::json) FROM monthly_data)
    ) as result;