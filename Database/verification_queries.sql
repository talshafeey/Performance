-- Verification SELECT Queries for Views and Table
-- Run these after applying migration.sql to verify the objects were created successfully

-- Views

-- 1. v_product_sales_enriched
SELECT * FROM v_product_sales_enriched LIMIT 10;

-- 2. view_sales_graph_analytics
SELECT * FROM view_sales_graph_analytics LIMIT 10;

-- 3. view_sales_invoice_analytics
SELECT * FROM view_sales_invoice_analytics LIMIT 10;

-- 4. view_dashboard_lost_sales
SELECT * FROM view_dashboard_lost_sales LIMIT 10;

-- 5. view_sales_by_customer_performance
SELECT * FROM view_sales_by_customer_performance LIMIT 10;

-- 6. view_category_sales_performance
SELECT * FROM view_category_sales_performance LIMIT 10;

-- 7. view_customer_loyalty_analytics
SELECT * FROM view_customer_loyalty_analytics LIMIT 10;

-- 8. view_sales_by_payment_performance
SELECT * FROM view_sales_by_payment_performance LIMIT 10;

-- 9. view_dashboard_sales_summary
SELECT * FROM view_dashboard_sales_summary LIMIT 10;

-- 10. view_dashboard_master_analytics
SELECT * FROM view_dashboard_master_analytics LIMIT 10;

-- Table

-- feature_flags
SELECT * FROM feature_flags;