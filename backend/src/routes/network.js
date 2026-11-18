import express from 'express';
import { query } from '../db.js';

const router = express.Router();
const kinds = new Set(['all', 'Seller', 'Recovery partner', 'Collection point']);

router.get('/', async (req, res) => {
  const kind = String(req.query.kind ?? 'all');
  const material = String(req.query.material ?? '').trim();
  const search = String(req.query.q ?? '').trim().slice(0, 120);
  const bounds = String(req.query.bounds ?? '7,30,12.5,38.5').split(',').map(Number);
  const limit = Math.min(500, Math.max(1, Number.parseInt(String(req.query.limit ?? '300'), 10) || 300));
  if (!kinds.has(kind)) return res.status(400).json({ error: 'Invalid network category' });
  if (material.length > 80) return res.status(400).json({ error: 'Material filter is too long' });
  if (bounds.length !== 4 || bounds.some((value) => !Number.isFinite(value)) ||
      bounds[0] < 7 || bounds[2] > 12.5 || bounds[1] < 30 || bounds[3] > 38.5 ||
      bounds[0] >= bounds[2] || bounds[1] >= bounds[3]) {
    return res.status(400).json({ error: 'Map bounds must describe an area inside Tunisia' });
  }

  const values = [bounds[0], bounds[1], bounds[2], bounds[3]];
  const extra = [];
  if (material) extra.push(`%MATERIAL%`);
  if (search) extra.push(`%SEARCH%`);
  const addFilters = (base, materialColumn, alias) => {
    let sql = base;
    const params = [...values];
    if (material) {
      params.push(material);
      sql += ` AND $${params.length} = ANY(${materialColumn})`;
    }
    if (search) {
      params.push(`%${search}%`);
      const p = `$${params.length}`;
      sql += ` AND (${alias}.name ILIKE ${p} OR COALESCE(${alias}.gouvernorat,'') ILIKE ${p} OR COALESCE(${alias}.description,'') ILIKE ${p})`;
    }
    params.push(limit);
    sql += ` ORDER BY ${alias}.name LIMIT $${params.length}`;
    return { sql, params };
  };

  try {
    const jobs = [];
    if (kind === 'all' || kind === 'Seller') {
      const q = addFilters(`SELECT g.*, u.is_verified AS owner_verified, 'Seller' AS _kind FROM waste_generators g JOIN users u ON u.id = g.user_id WHERE u.is_active = true AND u.is_verified = true AND g.location && ST_MakeEnvelope($1,$2,$3,$4,4326)`, 'g.available_waste_types', 'g');
      jobs.push(query(q.sql, q.params));
    }
    if (kind === 'all' || kind === 'Recovery partner') {
      const q = addFilters(`SELECT p.*, u.is_verified AS owner_verified, 'Recovery partner' AS _kind FROM processors p JOIN users u ON u.id = p.user_id WHERE p.location && ST_MakeEnvelope($1,$2,$3,$4,4326) AND p.is_active = true AND u.is_active = true AND u.is_verified = true`, 'p.accepts_waste_types', 'p');
      jobs.push(query(q.sql, q.params));
    }
    if (kind === 'all' || kind === 'Collection point') {
      const q = addFilters(`SELECT c.*, 'Collection point' AS _kind FROM collection_points c WHERE c.location && ST_MakeEnvelope($1,$2,$3,$4,4326) AND c.is_active = true AND c.is_verified = true`, 'c.accepts_waste_types', 'c');
      jobs.push(query(q.sql, q.params));
    }
    const results = await Promise.all(jobs);
    res.set('Cache-Control', 'public, max-age=30, stale-while-revalidate=120');
    res.json(results.flatMap((result) => result.rows));
  } catch (error) {
    console.error('Network directory query failed:', error);
    res.status(500).json({ error: 'Could not load network locations' });
  }
});

export default router;
