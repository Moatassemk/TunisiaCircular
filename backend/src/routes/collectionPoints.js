import express from 'express';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';
import { validateGovernorate } from '../utils/validation.js';

const router = express.Router();
const pointTypes = new Set(['drop_off', 'pickup_site', 'recycling_center']);
const pointFields = `id, owner_id, name, point_type, description, address, gouvernorat,
  lat, lng, accepts_waste_types, contact_phone, opening_hours, is_active, is_verified,
  review_note, created_at, updated_at`;
const selectColumns = `cp.id, cp.owner_id, cp.name, cp.point_type, cp.description,
  cp.address, cp.gouvernorat, cp.lat, cp.lng, cp.accepts_waste_types,
  cp.contact_phone, cp.opening_hours, cp.is_active, cp.is_verified, cp.review_note,
  cp.created_at, cp.updated_at, u.name AS owner_name,
  u.company_name AS owner_company, u.role AS owner_role`;
const pointSelect = `SELECT ${selectColumns}
  FROM collection_points cp JOIN users u ON u.id = cp.owner_id`;

// A collection point may be opened by a seller in any region or by a
// collection specialist / collecting society. Buyers cannot submit points.
function requirePointManager(req, res, next) {
  if (!['generator', 'collector'].includes(req.user?.role)) {
    return res.status(403).json({
      error: 'Only sellers and collection specialists can manage collection points',
    });
  }
  next();
}

function pointPayload(body) {
  const data = body ?? {};
  const name = typeof data.name === 'string' ? data.name.trim() : '';
  const pointType = data.point_type ?? 'drop_off';
  const gouvernorat = data.gouvernorat;
  const latitude = Number(data.lat);
  const longitude = Number(data.lng);
  const materials = Array.isArray(data.accepts_waste_types)
    ? data.accepts_waste_types
    : null;

  if (!name || name.length > 255) {
    return { error: 'A point name of 1–255 characters is required' };
  }
  if (!pointTypes.has(pointType)) {
    return { error: 'Invalid collection point type' };
  }
  if (!validateGovernorate(gouvernorat)) {
    return { error: 'Choose a valid governorate' };
  }
  if (!Number.isFinite(latitude) || latitude < 30 || latitude > 38.5 ||
      !Number.isFinite(longitude) || longitude < 7 || longitude > 12.5) {
    return { error: 'Choose coordinates inside Tunisia' };
  }
  if (materials === null ||
      materials.some((item) => typeof item !== 'string' || item.length > 80)) {
    return { error: 'Materials must be a list of short text values' };
  }

  const text = (value, max) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';

  return {
    values: {
      name,
      pointType,
      description: text(data.description, 2000),
      address: text(data.address, 500),
      gouvernorat: String(gouvernorat),
      latitude,
      longitude,
      materials: [...new Set(materials.map((item) => item.trim()).filter(Boolean))],
      contactPhone: text(data.contact_phone, 30),
      openingHours: text(data.opening_hours, 300),
    },
  };
}

router.get('/', async (req, res) => {
  try {
    const { gouvernorat, wasteType } = req.query;
    const params = [];
    let sql = `${pointSelect} WHERE cp.is_active = true AND cp.is_verified = true`;
    if (gouvernorat) {
      params.push(String(gouvernorat));
      sql += ` AND cp.gouvernorat ILIKE $${params.length}`;
    }
    if (wasteType) {
      params.push(String(wasteType));
      sql += ` AND $${params.length} = ANY(cp.accepts_waste_types)`;
    }
    sql += ' ORDER BY cp.name ASC LIMIT 1000';
    res.json((await query(sql, params)).rows);
  } catch (error) {
    console.error('Collection point directory error:', error);
    res.status(500).json({ error: 'Could not load collection points' });
  }
});

router.get('/mine', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      `${pointSelect} WHERE cp.owner_id = $1 ORDER BY cp.created_at DESC`,
      [req.user.userId],
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Owner collection point query failed:', error);
    res.status(500).json({ error: 'Could not load your collection points' });
  }
});

router.post('/', authenticateToken, requirePointManager, async (req, res) => {
  const parsed = pointPayload(req.body);
  if (parsed.error) return res.status(400).json({ error: parsed.error });
  const p = parsed.values;
  try {
    const result = await query(`
      INSERT INTO collection_points (
        owner_id, name, point_type, description, address, gouvernorat, lat, lng,
        location, accepts_waste_types, contact_phone, opening_hours
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,ST_SetSRID(ST_Point($8,$7),4326),$9,$10,$11)
      RETURNING ${pointFields}
    `, [
      req.user.userId, p.name, p.pointType, p.description, p.address,
      p.gouvernorat, p.latitude, p.longitude, p.materials, p.contactPhone,
      p.openingHours,
    ]);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Collection point create failed:', error);
    res.status(500).json({ error: 'Could not submit collection point for review' });
  }
});

// Editing an owned point sends it back through review so a verified location
// cannot be moved or changed after approval without an admin seeing it.
router.put('/:id', authenticateToken, requirePointManager, async (req, res) => {
  const parsed = pointPayload(req.body);
  if (parsed.error) return res.status(400).json({ error: parsed.error });
  const p = parsed.values;
  try {
    const result = await query(`
      UPDATE collection_points SET
        name = $1, point_type = $2, description = $3, address = $4,
        gouvernorat = $5, lat = $6, lng = $7,
        location = ST_SetSRID(ST_Point($7,$6),4326),
        accepts_waste_types = $8, contact_phone = $9, opening_hours = $10,
        is_active = true, is_verified = false
      WHERE id = $11 AND owner_id = $12
      RETURNING ${pointFields}
    `, [
      p.name, p.pointType, p.description, p.address, p.gouvernorat,
      p.latitude, p.longitude, p.materials, p.contactPhone, p.openingHours,
      req.params.id, req.user.userId,
    ]);
    if (!result.rowCount) {
      return res.status(404).json({ error: 'Collection point not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Collection point update failed:', error);
    res.status(500).json({ error: 'Could not update collection point' });
  }
});

router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      'DELETE FROM collection_points WHERE id = $1 AND owner_id = $2 RETURNING id',
      [req.params.id, req.user.userId],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'Collection point not found' });
    res.status(204).end();
  } catch (error) {
    console.error('Collection point delete failed:', error);
    res.status(500).json({ error: 'Could not delete collection point' });
  }
});

export default router;
