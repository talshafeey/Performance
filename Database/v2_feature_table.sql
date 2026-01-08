-- CREATE TABLE IF NOT EXISTS feature_flags (
--     id SERIAL PRIMARY KEY,
--     feature_name VARCHAR(100) UNIQUE NOT NULL,
--     enabled BOOLEAN DEFAULT false NOT NULL,
--     description TEXT,
--     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );


-- -- Create index for fast lookups
-- CREATE INDEX IF NOT EXISTS idx_feature_flags_name ON feature_flags(feature_name);

-- -- Insert default feature flags
-- INSERT INTO feature_flags (feature_name, enabled, description) 
-- VALUES 
--     ('dashboard_v2_enabled', true, 'Enable optimized V2 dashboard methods (views & parallel queries)')
-- ON CONFLICT (feature_name) DO NOTHING;

-- -- Function to update timestamp on modification
-- CREATE OR REPLACE FUNCTION update_feature_flag_timestamp()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated_at = CURRENT_TIMESTAMP;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Trigger to auto-update timestamp
-- DROP TRIGGER IF EXISTS trigger_update_feature_flag_timestamp ON feature_flags;
-- CREATE TRIGGER trigger_update_feature_flag_timestamp
--     BEFORE UPDATE ON feature_flags
--     FOR EACH ROW
--     EXECUTE FUNCTION update_feature_flag_timestamp();



select * from feature_flags;

select * from pg_stat_statements;
