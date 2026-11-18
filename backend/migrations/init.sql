-- Tunisia Circular Economy - Database Schema
-- Run this against your PostgreSQL instance with PostGIS extension enabled

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('generator', 'processor', 'collector', 'admin')),
    name VARCHAR(255),
    phone VARCHAR(30),
    company_name VARCHAR(255),
    address TEXT,
    gouvernorat VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Waste Generators table
CREATE TABLE IF NOT EXISTS waste_generators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100) NOT NULL,
    description TEXT,
    location GEOMETRY(Point, 4326),
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    available_waste_types VARCHAR[] NOT NULL,
    avg_monthly_volume_kg NUMERIC(10, 2),
    seasonal BOOLEAN DEFAULT false,
    contact_phone VARCHAR(30),
    contact_email VARCHAR(255),
    gouvernorat VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Processors table
CREATE TABLE IF NOT EXISTS processors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100) NOT NULL,
    description TEXT,
    location GEOMETRY(Point, 4326),
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    accepts_waste_types VARCHAR[] NOT NULL,
    max_capacity_kg_per_month NUMERIC(10, 2) NOT NULL,
    current_stock_kg NUMERIC(10, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    price_per_kg NUMERIC(10, 2) NOT NULL,
    price_per_liter NUMERIC(10, 2),
    gouvernorat VARCHAR(100),
    certification TEXT,
    payment_terms TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Carbon Factors table
CREATE TABLE IF NOT EXISTS carbon_factors (
    id SERIAL PRIMARY KEY,
    factor_key VARCHAR(80) UNIQUE NOT NULL,
    kg_co2e_per_kg NUMERIC(10, 4),
    kg_co2e_per_liter NUMERIC(10, 4),
    kg_co2e_saved_per_kg NUMERIC(10, 4),
    kg_co2e_saved_per_liter NUMERIC(10, 4),
    kg_co2e_per_km NUMERIC(10, 4),
    description TEXT,
    source VARCHAR(255),
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_to DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE processors ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE waste_generators ADD COLUMN IF NOT EXISTS gouvernorat VARCHAR(100);
ALTER TABLE processors ADD COLUMN IF NOT EXISTS gouvernorat VARCHAR(100);
ALTER TABLE carbon_factors ADD COLUMN IF NOT EXISTS kg_co2e_per_km NUMERIC(10, 4);
ALTER TABLE carbon_factors ALTER COLUMN valid_from SET DEFAULT CURRENT_DATE;

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    generator_id UUID REFERENCES waste_generators(id) ON DELETE SET NULL,
    processor_id UUID REFERENCES processors(id) ON DELETE SET NULL,
    collector_id UUID REFERENCES users(id) ON DELETE SET NULL,
    waste_type VARCHAR(100) NOT NULL,
    amount_kg NUMERIC(10, 2) NOT NULL,
    amount_liter NUMERIC(10, 2),
    distance_km NUMERIC(10, 2) NOT NULL,
    transport_emissions_kg NUMERIC(10, 4),
    avoided_landfill_kg NUMERIC(10, 4),
    processing_savings_kg NUMERIC(10, 4),
    total_carbon_saved_kg NUMERIC(10, 4) NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('pending', 'matched', 'collected', 'processed', 'completed', 'cancelled')),
    match_score NUMERIC(5, 3),
    transaction_fee_tnd NUMERIC(10, 2),
    payment_status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Matches table (for audit trail)
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    generator_id UUID REFERENCES waste_generators(id) ON DELETE CASCADE,
    processor_id UUID REFERENCES processors(id) ON DELETE CASCADE,
    score NUMERIC(5, 3) NOT NULL,
    distance_km NUMERIC(10, 2) NOT NULL,
    selected BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT false,
    link VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_waste_generators_location ON waste_generators USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_processors_location ON processors USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_transactions_generator ON transactions(generator_id);
CREATE INDEX IF NOT EXISTS idx_transactions_processor ON transactions(processor_id);
CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Index for geo queries (within radius)
CREATE INDEX IF NOT EXISTS idx_waste_generators_gis ON waste_generators USING gist(location);
CREATE INDEX IF NOT EXISTS idx_processors_gis ON processors USING gist(location);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_waste_generators_updated_at ON waste_generators;
CREATE TRIGGER update_waste_generators_updated_at BEFORE UPDATE ON waste_generators
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_processors_updated_at ON processors;
CREATE TRIGGER update_processors_updated_at BEFORE UPDATE ON processors
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed data
INSERT INTO carbon_factors (factor_key, kg_co2e_per_kg, kg_co2e_per_liter, kg_co2e_saved_per_kg, kg_co2e_saved_per_liter, description, source) VALUES
('landfill_organic', 0.52, NULL, NULL, NULL, 'Methane from anaerobic decomposition in landfill', 'IPCC Guidelines'),
('landfill_pomace', 0.48, NULL, NULL, NULL, 'Organic pomace in landfill', 'Local study'),
('dumped_uco', NULL, 0.35, NULL, NULL, 'UCO dumped on soil/water', 'ANPEDDE'),
('biodiesel_from_uco', NULL, NULL, NULL, 2.5, 'Displaces fossil diesel', 'EU Red Diesel Directive'),
('compost_organic', 0.85, NULL, NULL, NULL, 'Avoids methane + displaces synthetic fertilizer', 'Local composting data'),
('compost_pomace', 0.72, NULL, NULL, NULL, 'Soil carbon sequestration', 'ISBA report'),
('biogas_organic', 1.10, NULL, NULL, NULL, 'Displaces natural gas + avoids methane', 'MINAB Tunisie'),
('biogas_pomace', 0.95, NULL, NULL, NULL, 'Displaces natural gas', 'MINAB Tunisie'),
('biomass_fuel', 0.65, NULL, NULL, NULL, 'Displaces coal/fossil fuel in kilns', 'ETAP'),
('polyphenol_extraction', 1.50, NULL, NULL, NULL, 'High-value product, avoids chemical synthesis', 'CRDA'),
('transport_per_km_truck', NULL, NULL, NULL, NULL, 'Medium truck emissions per km', 'EEA default')
ON CONFLICT (factor_key) DO NOTHING;

-- Update transport factor value
UPDATE carbon_factors SET kg_co2e_per_km = 0.62 WHERE factor_key = 'transport_per_km_truck';
