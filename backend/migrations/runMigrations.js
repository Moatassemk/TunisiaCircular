/**
 * Run database migrations
 */
import pkg from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const { Pool } = pkg;

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'tunisia_circular',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

async function runMigration(filePath) {
  const sql = fs.readFileSync(filePath, 'utf-8');
  console.log(`Running migration: ${filePath}`);
  await pool.query(sql);
  console.log(`✅ Migration complete: ${path.basename(filePath)}`);
}

async function main() {
  try {
    console.log('\n🔄 Starting database migrations...\n');

    // Run all migration SQL files sorted alphabetically
    const migrationPath = path.join(__dirname, 'init.sql');
    await runMigration(migrationPath);

    // Run incremental migrations in alphabetical order
    const extraMigrations = [
      'add_search_and_profile.sql',
      'add_collection_points.sql',
      'add_exchange_workflow.sql',
      'add_listing_details.sql',
      'add_review_notes.sql',
    ];
    for (const name of extraMigrations) {
      const p = path.join(__dirname, name);
      if (fs.existsSync(p)) {
        await runMigration(p);
      }
    }

    console.log('\n✨ All migrations completed successfully!\n');
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

main();
