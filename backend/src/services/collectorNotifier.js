import { query } from '../db.js';

/**
 * Notify active collectors when a new match is created.
 * Collectors are matched by proximity to the generator/processor location.
 * Falls back to all active collectors if no location data is available.
 * @param {string} generatorId
 * @param {string} processorId
 */
export async function notifyCollectors(generatorId, processorId) {
  try {
    // Get generator and processor locations
    const result = await query(`
      SELECT
        (SELECT lat FROM waste_generators WHERE id = $1) as gen_lat,
        (SELECT lng FROM waste_generators WHERE id = $1) as gen_lng,
        (SELECT lat FROM processors WHERE id = $2) as proc_lat,
        (SELECT lng FROM processors WHERE id = $2) as proc_lng
    `, [generatorId, processorId]);

    const row = result.rows[0] || {};
    const genLat = row.gen_lat;
    const genLng = row.gen_lng;
    const procLat = row.proc_lat;
    const procLng = row.proc_lng;

    // Find active collectors. If we have location data, use PostGIS proximity;
    // otherwise fall back to all active collectors.
    let collectorQuery, collectorParams;
    if (genLat && genLng) {
      collectorQuery = `
        SELECT DISTINCT u.id
        FROM users u
        JOIN processors p ON p.user_id = u.id
        WHERE u.role = 'collector' AND u.is_active = true
          AND p.lat IS NOT NULL AND p.lng IS NOT NULL
          AND ST_DWithin(
            ST_SetSRID(ST_Point(p.lng, p.lat), 4326)::geography,
            ST_SetSRID(ST_Point($1::numeric, $2::numeric), 4326)::geography,
            50000
          )
      `;
      collectorParams = [genLng, genLat];
    } else if (procLat && procLng) {
      collectorQuery = `
        SELECT DISTINCT u.id
        FROM users u
        JOIN processors p ON p.user_id = u.id
        WHERE u.role = 'collector' AND u.is_active = true
          AND p.lat IS NOT NULL AND p.lng IS NOT NULL
          AND ST_DWithin(
            ST_SetSRID(ST_Point(p.lng, p.lat), 4326)::geography,
            ST_SetSRID(ST_Point($1::numeric, $2::numeric), 4326)::geography,
            50000
          )
      `;
      collectorParams = [procLng, procLat];
    } else {
      collectorQuery = `SELECT id FROM users WHERE role = 'collector' AND is_active = true`;
      collectorParams = [];
    }

    const collectors = await query(collectorQuery, collectorParams);

    if (!collectors.rows.length) return;

    // Insert a notification for each collector
    for (const c of collectors.rows) {
      await query(`
        INSERT INTO notifications (user_id, type, title, message, link, created_at)
        VALUES ($1, 'new_match', 'New match nearby', 'A new material match has been created near your area.', '/transactions', NOW())
      `, [c.id]);
    }
  } catch (err) {
    console.error('Notify collectors error:', err);
  }
}