/**
 * Search Service - Full-text search and proximity search
 */
import { query } from '../db.js';

export async function search({ q = '', type = '', governorate = '', lat, lng, limit = 20, offset = 0 }) {
  const rawTerms = String(q || '').trim().split(/\s+/).filter(Boolean);
  const hasText = rawTerms.length > 0;
  const tsQuery = rawTerms.map((t) => `${t}:*`).join(' & ');
  const hasGeo = lat !== undefined && lng !== undefined && lat !== '' && lng !== '' && !Number.isNaN(Number(lat)) && !Number.isNaN(Number(lng));

  const params = [];
  let idx = 1;

  const textScoreExpr = hasText
    ? `coalesce(ts_rank(to_tsvector('simple', name || ' ' || coalesce(description,'')), plainto_tsquery('simple', $${idx})), 0)`
    : `0`;
  if (hasText) {
    params.push(rawTerms.join(' '));
    idx++;
  }

  let distanceExpr = `NULL::numeric`;
  let distanceFilter = '';
  if (hasGeo) {
    distanceExpr = `round((ST_Distance(
        ST_SetSRID(ST_Point(lng, lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint($${idx}, $${idx + 1}), 4326)::geography
      ) / 1000)::numeric, 2)`;
    params.push(Number(lng), Number(lat));
    idx += 2;
    // optional radius filter 200km
    distanceFilter = `AND ST_DWithin(
        ST_SetSRID(ST_Point(lng, lat), 4326)::geography,
        ST_SetSRID(ST_MakePoint($${idx - 2}, $${idx - 1}), 4326)::geography,
        200000
      )`;
  }

  let sql = `
    WITH combined AS (
      SELECT g.id, g.name, COALESCE(g.type,'') AS type, g.gouvernorat, g.description,
             g.lat, g.lng, 'generator' AS entity_type, g.available_waste_types AS materials,
             g.avg_monthly_volume_kg AS volume
      FROM waste_generators g
      JOIN users u ON u.id = g.user_id AND u.is_active = true AND u.is_verified = true
      UNION ALL
      SELECT p.id, p.name, COALESCE(p.type,'') AS type, p.gouvernorat, p.description,
             p.lat, p.lng, 'processor' AS entity_type, p.accepts_waste_types AS materials,
             p.max_capacity_kg_per_month AS volume
      FROM processors p
      JOIN users u ON u.id = p.user_id AND u.is_active = true AND u.is_verified = true
      WHERE COALESCE(p.is_active, true) = true
    )
    SELECT id, name, type, gouvernorat, description, lat, lng, entity_type, materials, volume,
           ${textScoreExpr} AS text_score,
           ${distanceExpr} AS distance_km
    FROM combined
    WHERE 1=1
  `;

  if (hasText) {
    sql += ` AND to_tsvector('simple', name || ' ' || coalesce(description,'')) @@ plainto_tsquery('simple', $1)`;
  }
  if (distanceFilter) sql += ` ${distanceFilter}`;
  if (type) {
    sql += ` AND entity_type = $${idx++}`;
    params.push(type);
  }
  if (governorate) {
    sql += ` AND gouvernorat ILIKE $${idx++}`;
    params.push(`%${governorate}%`);
  }

  if (hasText && hasGeo) {
    sql += ` ORDER BY text_score DESC, distance_km ASC NULLS LAST`;
  } else if (hasText) {
    sql += ` ORDER BY text_score DESC, name ASC`;
  } else if (hasGeo) {
    sql += ` ORDER BY distance_km ASC NULLS LAST`;
  } else {
    sql += ` ORDER BY name ASC`;
  }

  sql += ` LIMIT $${idx++} OFFSET $${idx++}`;
  params.push(Number(limit) || 20, Number(offset) || 0);

  try {
    const result = await query(sql, params);
    return { results: result.rows, count: result.rows.length, query: q || '' };
  } catch (error) {
    console.error('Search service error:', error);
    throw error;
  }
}
