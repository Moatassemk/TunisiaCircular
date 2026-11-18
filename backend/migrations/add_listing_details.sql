ALTER TABLE waste_generators
  ADD COLUMN IF NOT EXISTS material_condition VARCHAR(100),
  ADD COLUMN IF NOT EXISTS packaging_details VARCHAR(300),
  ADD COLUMN IF NOT EXISTS price_per_kg NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS minimum_order_kg NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS available_until DATE,
  ADD COLUMN IF NOT EXISTS photo_url TEXT;

CREATE INDEX IF NOT EXISTS idx_waste_generators_availability
  ON waste_generators(available_until)
  WHERE available_until IS NOT NULL;
