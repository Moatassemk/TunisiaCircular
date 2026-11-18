-- Search & Profile enhancements for Tunisia Circular
-- Adds search indexes, profile photo column, and materialization views

-- Add profile photo URL to users
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo TEXT;

-- Full-text search indexes on generator/processor names
CREATE INDEX IF NOT EXISTS idx_waste_generators_name_gin ON waste_generators USING gin(to_tsvector('simple', name));
CREATE INDEX IF NOT EXISTS idx_processors_name_gin ON processors USING gin(to_tsvector('simple', name));

-- Transaction status + created_at composite for common dashboard queries
CREATE INDEX IF NOT EXISTS idx_transactions_status_created ON transactions(status, created_at DESC);

-- View: monthly activity summary
DROP VIEW IF EXISTS v_monthly_activity CASCADE;
CREATE VIEW v_monthly_activity AS
SELECT
  date_trunc('month', created_at)::date AS month,
  COUNT(*)                                                         AS transaction_count,
  COALESCE(SUM(amount_kg), 0)                                      AS total_kg,
  COALESCE(SUM(total_carbon_saved_kg), 0)                          AS carbon_saved_kg
FROM transactions
WHERE status IN ('collected', 'processed', 'completed')
GROUP BY date_trunc('month', created_at)
ORDER BY month DESC;

-- View: top generators by total kg
DROP VIEW IF EXISTS v_top_generators CASCADE;
CREATE VIEW v_top_generators AS
SELECT
  wg.id             AS id,
  wg.name           AS name,
  wg.gouvernorat,
  SUM(t.amount_kg)  AS total_kg,
  SUM(t.total_carbon_saved_kg) AS carbon_saved_kg,
  COUNT(t.id)       AS transactions
FROM waste_generators wg
JOIN transactions t ON t.generator_id = wg.id
WHERE t.status IN ('collected', 'processed', 'completed')
GROUP BY wg.id, wg.name, wg.gouvernorat
ORDER BY total_kg DESC
LIMIT 20;

-- View: top processors by intake
DROP VIEW IF EXISTS v_top_processors CASCADE;
CREATE VIEW v_top_processors AS
SELECT
  p.id            AS id,
  p.name          AS name,
  p.gouvernorat,
  SUM(t.amount_kg) AS total_kg,
  SUM(t.total_carbon_saved_kg) AS carbon_saved_kg,
  COUNT(t.id)     AS transactions
FROM processors p
JOIN transactions t ON t.processor_id = p.id
WHERE t.status IN ('collected', 'processed', 'completed')
GROUP BY p.id, p.name, p.gouvernorat
ORDER BY total_kg DESC
LIMIT 20;
