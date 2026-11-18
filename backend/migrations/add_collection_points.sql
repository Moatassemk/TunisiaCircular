CREATE TABLE IF NOT EXISTS collection_points (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  point_type VARCHAR(40) NOT NULL DEFAULT 'drop_off'
    CHECK (point_type IN ('drop_off', 'pickup_site', 'recycling_center')),
  description TEXT,
  address TEXT,
  gouvernorat VARCHAR(100) NOT NULL,
  lat DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN 30 AND 38.5),
  lng DOUBLE PRECISION NOT NULL CHECK (lng BETWEEN 7 AND 12.5),
  location GEOMETRY(Point, 4326) NOT NULL,
  accepts_waste_types VARCHAR[] NOT NULL DEFAULT '{}',
  contact_phone VARCHAR(30),
  opening_hours TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE waste_generators ADD COLUMN IF NOT EXISTS is_location_approximate BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE processors ADD COLUMN IF NOT EXISTS is_location_approximate BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_collection_points_location
  ON collection_points USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_collection_points_region
  ON collection_points(gouvernorat);
DROP TRIGGER IF EXISTS update_collection_points_updated_at ON collection_points;
CREATE TRIGGER update_collection_points_updated_at BEFORE UPDATE ON collection_points
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
