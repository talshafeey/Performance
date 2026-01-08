-- API: dashboard/flex/average-delivery-time?fromDate=1970-01-01+00:00:00&toDate=2026-01-05+23:59:59&storeId=&regionId=34,10,9,8,7,6,5,4,3,2,1&companyId=1&tenantId=1&legalEntityId=157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175&driverId=866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991
-- REPO: dashboard-api
-- RELATIVE PATH AT REPO FOR EXECUTOR CODE: src\modules\dashboard\dashboard-flex.service.ts
-- METHOD: getFinancialSummary
-- OLD_TIME FOR API ON PRODUCTION: 10-18S
-- OLD_TIME query FOR ALL DATA ON PRODUCTION: 5-11s
-- NEW_TIME query for all DATA On Production: 2.3-4s



--- OLD QUERY ----

WITH current_period AS (
          SELECT
            AVG(
              CASE
                WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                  AND s.on_delivered_time > s.on_in_transit_time
                THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
                ELSE NULL
              END
            ) as avg_delivery_time_minutes,
            COUNT(DISTINCT CASE
              WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                AND s.on_delivered_time > s.on_in_transit_time
              THEN s.id
            END) as total_completed_deliveries
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          WHERE s.fulfilment_type = 'DELIVERY'
            AND s.invoice_type = 'SALES'
            AND s.fulfilment_status = 'DELIVERED'
            AND s.on_delivered_time IS NOT NULL
            AND s.on_in_transit_time IS NOT NULL
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175) AND store.region_id IN (34,10,9,8,7,6,5,4,3,2,1) AND s.delivery_partner_id IN (866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991)
        ),
        previous_period AS (
          SELECT
            AVG(
              CASE
                WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                  AND s.on_delivered_time > s.on_in_transit_time
                THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
                ELSE NULL
              END
            ) as avg_delivery_time_minutes,
            COUNT(DISTINCT CASE
              WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                AND s.on_delivered_time > s.on_in_transit_time
              THEN s.id
            END) as total_completed_deliveries
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          WHERE s.fulfilment_type = 'DELIVERY'
            AND s.invoice_type = 'SALES'
            AND s.fulfilment_status = 'DELIVERED'
            AND s.on_delivered_time IS NOT NULL
            AND s.on_in_transit_time IS NOT NULL
            AND s.invoice_date_time BETWEEN TIMESTAMP '1913-12-26 00:00:00' AND TIMESTAMP '1969-12-30 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175) AND store.region_id IN (34,10,9,8,7,6,5,4,3,2,1) AND s.delivery_partner_id IN (866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991)
        ),
        hourly_trend AS (
          SELECT
            EXTRACT(HOUR FROM s.invoice_date_time) as hour,
            AVG(
              CASE
                WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                  AND s.on_delivered_time > s.on_in_transit_time
                THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
                ELSE NULL
              END
            ) as avg_time
          FROM sales_invoice_header s
          INNER JOIN ent_stores store ON s.store_id = store.id
          WHERE s.fulfilment_type = 'DELIVERY'
            AND s.invoice_type = 'SALES'
            AND s.fulfilment_status = 'DELIVERED'
            AND s.on_delivered_time IS NOT NULL
            AND s.on_in_transit_time IS NOT NULL
            AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175) AND store.region_id IN (34,10,9,8,7,6,5,4,3,2,1) AND s.delivery_partner_id IN (866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991)
          GROUP BY EXTRACT(HOUR FROM s.invoice_date_time)
          HAVING AVG(
            CASE
              WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
                AND s.on_delivered_time > s.on_in_transit_time
              THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
              ELSE NULL
            END
          ) IS NOT NULL
          ORDER BY hour
        )
        SELECT
          ROUND(COALESCE(cp.avg_delivery_time_minutes, 0)::NUMERIC, 0) as avg_delivery_time,
          CASE
            WHEN pp.avg_delivery_time_minutes > 0 AND cp.avg_delivery_time_minutes IS NOT NULL
            THEN ROUND(((cp.avg_delivery_time_minutes - pp.avg_delivery_time_minutes) / pp.avg_delivery_time_minutes) * 100, 2)
            ELSE 0
          END as percentage_change,
          cp.total_completed_deliveries,
          COALESCE(
            json_agg(
              json_build_object(
                'hour', ht.hour,
                'avg_time', ROUND(ht.avg_time::NUMERIC, 2)
              ) ORDER BY ht.hour
            ) FILTER (WHERE ht.hour IS NOT NULL),
            '[]'::json
          ) as hourly_trend
        FROM current_period cp, previous_period pp
        LEFT JOIN hourly_trend ht ON true
        GROUP BY cp.avg_delivery_time_minutes, pp.avg_delivery_time_minutes, cp.total_completed_deliveries


--- NEW ORM FRIENDLY QUERY ---

 WITH "current_metrics" AS (SELECT EXTRACT(HOUR FROM s.invoice_date_time) AS "hour", SUM(
        CASE
          WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
            AND s.on_delivered_time > s.on_in_transit_time
          THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
          ELSE NULL
        END
      ) AS "hourly_sum", COUNT(CASE WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL AND s.on_delivered_time > s.on_in_transit_time THEN s.id END) AS "hourly_count" FROM "sales_invoice_header" "s" INNER JOIN "ent_stores" "store" ON s.store_id = store.id AND COALESCE(store.is_deleted, false) = false WHERE s.fulfilment_type = 'DELIVERY' AND s.invoice_type = 'SALES' AND s.fulfilment_status = 'DELIVERED' AND s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL AND s.on_delivered_time > s.on_in_transit_time AND 1=1 AND s.invoice_date_time BETWEEN TIMESTAMP '1970-01-01 00:00:00' AND TIMESTAMP '2026-01-05 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175) AND store.region_id IN (34,10,9,8,7,6,5,4,3,2,1) AND s.delivery_partner_id IN (866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991) GROUP BY EXTRACT(HOUR FROM s.invoice_date_time)), "previous_metrics" AS (SELECT AVG(   
        CASE
          WHEN s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL
            AND s.on_delivered_time > s.on_in_transit_time
          THEN EXTRACT(EPOCH FROM (s.on_delivered_time - s.on_in_transit_time)) / 60
          ELSE NULL
        END
      ) AS "avg_time" FROM "sales_invoice_header" "s" INNER JOIN "ent_stores" "store" ON s.store_id = store.id AND COALESCE(store.is_deleted, false) = false WHERE s.fulfilment_type = 'DELIVERY' AND s.invoice_type = 'SALES' AND s.fulfilment_status = 'DELIVERED' AND s.on_delivered_time IS NOT NULL AND s.on_in_transit_time IS NOT NULL AND s.on_delivered_time > s.on_in_transit_time AND 1=1 AND s.invoice_date_time BETWEEN TIMESTAMP '1913-12-26 00:00:00' AND TIMESTAMP '1969-12-30 23:59:59' AND s.company_id IN (1) AND s.tenant_id IN (1) AND s.legal_entity_id IN (157,33,7,125,153,126,86,80,1,117,32,165,63,85,57,243,52,149,146,84,123,154,31,186,180,64,203,89,129,244,192,138,197,22,79,49,245,121,169,137,172,193,141,99,26,88,16,247,92,43,55,136,131,116,27,111,248,107,145,5,14,29,108,124,61,119,93,50,74,196,35,246,147,25,3,174,11,12,90,21,187,34,238,109,30,191,41,178,45,38,44,6,97,39,87,198,120,28,82,15,105,60,37,100,76,18,134,10,240,36,19,81,237,42,122,110,135,96,104,158,130,115,190,77,143,51,9,46,183,188,184,8,173,181,59,239,102,24,40,127,194,118,195,185,170,101,163,62,73,182,177,47,95,199,75,53,144,17,103,139,200,142,133,179,128,23,94,83,13,113,171,132,106,98,140,176,91,189,112,175) AND store.region_id IN (34,10,9,8,7,6,5,4,3,2,1) AND s.delivery_partner_id IN (866,975,973,865,810,984,963,844,986,988,990,981,966,976,980,974,968,965,972,967,977,962,978,845,970,964,969,971,991)) SELECT cm.hour AS "hour", CASE WHEN cm.hourly_count > 0 THEN cm.hourly_sum / cm.hourly_count ELSE 0 END AS "hour_avg_time", SUM(cm.hourly_sum) OVER() / SUM(cm.hourly_count) OVER() AS "total_avg_time", SUM(cm.hourly_count) OVER() AS "total_completed_deliveries", pm.avg_time AS "prev_avg_time" FROM "current_metrics" "cm" INNER JOIN "previous_metrics" "pm" ON 1=1 ORDER BY cm.hour ASC ;
 
 