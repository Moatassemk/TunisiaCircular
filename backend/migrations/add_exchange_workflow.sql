CREATE TABLE IF NOT EXISTS transaction_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS transaction_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  from_status VARCHAR(50),
  to_status VARCHAR(50) NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS scheduled_pickup_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_transaction_messages_thread
  ON transaction_messages(transaction_id, created_at, id);
CREATE INDEX IF NOT EXISTS idx_transaction_events_thread
  ON transaction_events(transaction_id, created_at, id);
CREATE INDEX IF NOT EXISTS idx_generators_materials
  ON waste_generators USING GIN(available_waste_types);
CREATE INDEX IF NOT EXISTS idx_processors_materials
  ON processors USING GIN(accepts_waste_types);
