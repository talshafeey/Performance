-- API: dashboard/salesByPaymentMethod?fromDate=1970-01-01+00:00:00&toDate=2025-12-30+23:59:59&storeId=&regionId=&legalEntityId=1&companyId=1&tenantId=1
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src/modules/dashboard/dashboard-v2-service.ts
-- METHOD: salesByPaymentMethods
-- OLD_TIME FOR ALL DATA: 19-25s
-- NEW_TIME FOR ALL DATA: 1-3s

--- OLD QUERY ---
WITH payment_summary AS (
    SELECT
        p.payment_method_type AS name,
        p.sub_payment_method_id,
        p.payment_method_id,
        p.sales_invoice_header_id,
        SUM(p.amount) AS amount
    FROM payment_transactions p
    WHERE p.transaction_status = 'PAID'
    GROUP BY
        p.payment_method_type,
        p.sub_payment_method_id,
        p.payment_method_id,
        p.sales_invoice_header_id
),

filtered_sales AS (
    SELECT
        s.id AS invoice_id,
        s.invoice_num,
        s.invoice_date_time,
        s.store_id,
        s.region_id,
        s.change_amount
    FROM sales_invoice_header s
    INNER JOIN ent_stores store ON s.store_id = store.id
    WHERE s.payment_status IS NOT NULL
      AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2025-12-30 23:59:59'
      AND s.company_id IN (1)
      AND s.tenant_id IN (1)
      AND s.legal_entity_id IN (1) 
),

sub_payment_methods AS (
    SELECT
        sp.id AS sub_payment_method_id,
        sp.name AS sub_payment_method_type,
        sp.image AS sub_payment_method_image
    FROM ent_sub_payment_method sp
),

payment_methods AS (
    SELECT
        p.id AS payment_method_id,
        p.name AS payment_method_type,
        p.image AS payment_method_image
    FROM ent_payment_methods p
),

-- Compute effective amounts per payment type
aggregated AS (
    SELECT
        CASE
            WHEN ps.name = 'CARD' AND sp.sub_payment_method_type IS NOT NULL
                THEN sp.sub_payment_method_type
            WHEN ps.name != 'CARD'
                THEN ps.name
            ELSE 'CARD'
        END AS name,

        CASE
            WHEN ps.name = 'CARD' AND sp.sub_payment_method_type IS NOT NULL
                THEN sp.sub_payment_method_image
            WHEN ps.name != 'CARD'
                THEN p.payment_method_image
            ELSE ''
        END AS image,

        -- Adjust CASH by subtracting change_amount
        SUM(
            CASE
                WHEN ps.name = 'CASH'
                    THEN ps.amount - COALESCE(fs.change_amount, 0)
                ELSE ps.amount
            END
        ) AS amount
    FROM payment_summary ps
    JOIN filtered_sales fs
        ON ps.sales_invoice_header_id = fs.invoice_id
    LEFT JOIN sub_payment_methods sp
        ON ps.sub_payment_method_id = sp.sub_payment_method_id
    LEFT JOIN payment_methods p
        ON ps.payment_method_id = p.payment_method_id
    GROUP BY
        1, 2 -- Grouping by the CASE result aliases
)

SELECT
    name,
    image,
    amount,
    ROUND(
        (
            (amount::numeric / NULLIF(SUM(amount) OVER ()::numeric, 0)) * 100
        )::numeric,
        2
    ) AS percentage
FROM aggregated
ORDER BY amount DESC;

--------- VIEW SCRIPT ------------

-- drop view view_sales_by_payment_performance;
CREATE OR REPLACE VIEW view_sales_by_payment_performance AS
SELECT
    -- Final display name (Sub-payment name for cards, or main method name)
    CASE
        WHEN pt.payment_method_type = 'CARD' AND sp.name IS NOT NULL THEN sp.name
        WHEN pt.payment_method_type != 'CARD' THEN pt.payment_method_type
        ELSE 'CARD'
    END AS name,
    -- Final display image
    CASE
        WHEN pt.payment_method_type = 'CARD' AND sp.name IS NOT NULL THEN sp.image
        WHEN pt.payment_method_type != 'CARD' THEN pm.image
        ELSE ''
    END AS image,
    -- The "Effective Amount" (Deducts change from Cash automatically)
    (CASE
        WHEN pt.payment_method_type = 'CASH' 
        THEN pt.amount - COALESCE(s.change_amount, 0)
        ELSE pt.amount
    END) AS amount,
    -- Filter columns for your ORM's .where() clause.
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
LEFT JOIN ent_payment_methods pm ON pt.payment_method_id = pm.id;

-------- INDEXES RAN ---------

CREATE INDEX idx_sales_header_search 
ON sales_invoice_header (tenant_id, company_id, legal_entity_id, invoice_date_time);

CREATE INDEX idx_payment_transactions_header 
ON payment_transactions (sales_invoice_header_id, transaction_status);


------- ANALYZE RAN ----------

ANALYZE sales_invoice_header;
ANALYZE payment_transactions;

------ NEW QUERY SELECT SAMPLE WITH NEW VIEW ---------- ET: 1.2-3s

explain analyze
SELECT 
    name, 
    image, 
    total_amount AS amount,
    ROUND(((total_amount / NULLIF(SUM(total_amount) OVER (), 0)) * 100)::numeric, 2) AS percentage
FROM (
    -- This inner part acts like the WITH clause
    SELECT 
        name, 
        image, 
        SUM(amount) AS total_amount
    FROM view_sales_by_payment_performance
    WHERE transaction_status = 'PAID'
      AND company_id = 1
      AND tenant_id = 1
      AND legal_entity_id = 1
      AND invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-30 23:59:59'
    GROUP BY name, image
) AS aggregated_data
ORDER BY amount DESC;


---- RAW FAST QUERY WITH NO VIEW  ---- ET: 1-3s
SELECT
    CASE
        WHEN ps.payment_method_type = 'CARD' AND sp.name IS NOT NULL THEN sp.name
        WHEN ps.payment_method_type != 'CARD' THEN ps.payment_method_type
        ELSE 'CARD'
    END AS name,
    CASE
        WHEN ps.payment_method_type = 'CARD' AND sp.name IS NOT NULL THEN sp.image
        WHEN ps.payment_method_type != 'CARD' THEN pm.image
        ELSE ''
    END AS image,
    -- Perform the Cash/Change adjustment in one pass
    SUM(
        CASE
            WHEN ps.payment_method_type = 'CASH' 
            THEN ps.amount - COALESCE(s.change_amount, 0)
            ELSE ps.amount
        END
    ) AS amount,
    ROUND(
        (SUM(CASE WHEN ps.payment_method_type = 'CASH' THEN ps.amount - COALESCE(s.change_amount, 0) ELSE ps.amount END)::numeric 
        / NULLIF(SUM(SUM(CASE WHEN ps.payment_method_type = 'CASH' THEN ps.amount - COALESCE(s.change_amount, 0) ELSE ps.amount END)) OVER ()::numeric, 0)) * 100,
        2
    ) AS percentage
FROM sales_invoice_header s
INNER JOIN payment_transactions ps 
    ON s.id = ps.sales_invoice_header_id
LEFT JOIN ent_sub_payment_method sp 
    ON ps.sub_payment_method_id = sp.id
LEFT JOIN ent_payment_methods pm 
    ON ps.payment_method_id = pm.id
WHERE s.payment_status IS NOT NULL
  AND ps.transaction_status = 'PAID'
  AND s.invoice_date_time BETWEEN '1970-01-01 00:00:00' AND '2025-12-30 23:59:59'
  AND s.company_id = 1
  AND s.tenant_id = 1
  AND s.legal_entity_id = 1 
GROUP BY 1, 2
ORDER BY amount DESC;
