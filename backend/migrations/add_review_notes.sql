ALTER TABLE collection_points ADD COLUMN IF NOT EXISTS review_note TEXT;

CREATE INDEX IF NOT EXISTS idx_collection_points_review_note
  ON collection_points(is_verified, is_active);