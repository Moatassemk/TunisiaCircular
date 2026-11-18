/**
 * Waste Generators API routes
 */
import express from 'express';
import { query } from '../db.js';
import { authenticateToken, authorizeRole } from '../middleware/auth.js';
import { findMatches } from '../services/matchingService.js';

const router = express.Router();

// Get generator stats
router.get('/stats', async (req, res) => {
  try {
    const result = await query(`
      SELECT
        COUNT(*) as total_listings,
        COALESCE(SUM(avg_monthly_volume_kg), 0) as total_volume_kg,
        type,
        COUNT(*) as count_by_type,
        COALESCE(SUM(avg_monthly_volume_kg), 0) as volume_by_type
      FROM waste_generators
      GROUP BY type
      ORDER BY count_by_type DESC
    `);

    const totalListings = result.rows.reduce((sum, r) => sum + parseInt(r.count_by_type), 0);
    const totalVolume = result.rows.reduce((sum, r) => sum + parseFloat(r.volume_by_type || 0), 0);

    res.json({
      totalListings,
      totalVolumeKg: totalVolume,
      byType: result.rows.map(r => ({
        type: r.type,
        count: parseInt(r.count_by_type),
        volumeKg: parseFloat(r.volume_by_type || 0)
      }))
    });
  } catch (error) {
    console.error('Error fetching generator stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Get all generators (with optional filtering)
router.get('/', async (req, res) => {
  try {
    const { type, gouvernorat, seasonal } = req.query;
    let sql = 'SELECT g.*, u.is_verified AS owner_verified FROM waste_generators g JOIN users u ON u.id = g.user_id WHERE u.is_active = true AND u.is_verified = true';
    const params = [];
    let paramIndex = 1;

    if (type) {
      sql += ` AND g.type = $${paramIndex++}`;
      params.push(type);
    }
    if (gouvernorat) {
      sql += ` AND g.gouvernorat ILIKE $${paramIndex++}`;
      params.push(`%${gouvernorat}%`);
    }
    if (seasonal !== undefined) {
      sql += ` AND g.seasonal = $${paramIndex++}`;
      params.push(seasonal === 'true');
    }

    sql += ' ORDER BY g.name ASC';

    const result = await query(sql, params);
    const generators = result.rows.map(g => ({
      ...g,
      available_waste_types: typeof g.available_waste_types === 'string'
        ? JSON.parse(g.available_waste_types)
        : g.available_waste_types
    }));

    res.json(generators);
  } catch (error) {
    console.error('Error fetching generators:', error);
    res.status(500).json({ error: 'Failed to fetch generators' });
  }
});

// Get listings owned by the authenticated seller
router.get('/mine', authenticateToken, authorizeRole('generator'), async (req, res) => {
  try {
    const result = await query(
      'SELECT g.*, u.is_verified AS owner_verified FROM waste_generators g JOIN users u ON u.id = g.user_id WHERE g.user_id = $1 ORDER BY g.created_at DESC',
      [req.user.userId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching seller listings:', error);
    res.status(500).json({ error: 'Failed to fetch your material listings' });
  }
});

// Get single generator by ID
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query('SELECT g.*, u.is_verified AS owner_verified FROM waste_generators g JOIN users u ON u.id = g.user_id WHERE g.id = $1 AND u.is_active = true AND u.is_verified = true', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Generator not found' });
    }

    const generator = result.rows[0];
    generator.available_waste_types = typeof generator.available_waste_types === 'string'
      ? JSON.parse(generator.available_waste_types)
      : generator.available_waste_types;

    res.json(generator);
  } catch (error) {
    console.error('Error fetching generator:', error);
    res.status(500).json({ error: 'Failed to fetch generator' });
  }
});

// Create a new generator
router.post('/', authenticateToken, authorizeRole('generator'), async (req, res) => {
  try {
    const {
      name, type, description = '', material_condition = null,
      packaging_details = null, price_per_kg = null, minimum_order_kg = null, available_until = null,
      photo_url = null, lat, lng, is_location_approximate, available_waste_types,
      avg_monthly_volume_kg, seasonal, contact_phone, contact_email, gouvernorat
    } = req.body;
    if (typeof name !== 'string' || !name.trim() || name.trim().length > 255) {
      return res.status(400).json({ error: 'Listing name must contain 1 to 255 characters' });
    }
    if (typeof description !== 'string' || description.length > 4000) {
      return res.status(400).json({ error: 'Description must be 4000 characters or fewer' });
    }
    if (material_condition != null && (typeof material_condition !== 'string' || material_condition.length > 100)) {
      return res.status(400).json({ error: 'Condition must be 100 characters or fewer' });
    }
    if (packaging_details != null && (typeof packaging_details !== 'string' || packaging_details.length > 300)) {
      return res.status(400).json({ error: 'Packaging details must be 300 characters or fewer' });
    }
    const price = price_per_kg == null || price_per_kg === '' ? null : Number(price_per_kg);
    if (price !== null && (!Number.isFinite(price) || price < 0 || price > 1000000)) {
      return res.status(400).json({ error: 'Enter a valid price per kilogram' });
    }
    let availabilityDate = null;
    if (available_until) {
      const parsed = new Date(`${available_until}T00:00:00Z`);
      const dateText = String(available_until);
      const today = new Date().toISOString().slice(0, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(dateText) || Number.isNaN(parsed.getTime()) ||
          parsed.toISOString().slice(0, 10) !== dateText || dateText < today) {
        return res.status(400).json({ error: 'Availability must be a valid date' });
      }
      availabilityDate = String(available_until);
    }
    if (photo_url != null && photo_url !== '') {
      try {
        const imageUrl = new URL(photo_url);
        if (imageUrl.protocol !== 'https:' || String(photo_url).length > 2048) throw new Error();
      } catch {
        return res.status(400).json({ error: 'Photo URL must be a valid HTTPS address' });
      }
    }
    const latitude = Number(lat);
    const longitude = Number(lng);
    if (!Number.isFinite(latitude) || latitude < 30 || latitude > 38.5 ||
        !Number.isFinite(longitude) || longitude < 7 || longitude > 12.5) {
      return res.status(400).json({ error: 'Choose coordinates inside Tunisia' });
    }
    if (!Array.isArray(available_waste_types) || available_waste_types.length === 0 ||
        available_waste_types.length > 20 || available_waste_types.some((value) => typeof value !== 'string' || value.length > 80)) {
      return res.status(400).json({ error: 'Choose at least one available material' });
    }
    const volume = Number(avg_monthly_volume_kg);
    if (!Number.isFinite(volume) || volume <= 0 || volume > 10000000) {
      return res.status(400).json({ error: 'Enter a valid monthly volume in kilograms' });
    }
    const minimumOrder = minimum_order_kg == null || minimum_order_kg === ''
      ? null
      : Number(minimum_order_kg);
    if (minimumOrder !== null &&
        (!Number.isFinite(minimumOrder) || minimumOrder <= 0 || minimumOrder > volume)) {
      return res.status(400).json({ error: 'Minimum order must be positive and no greater than monthly volume' });
    }

    const result = await query(`
      INSERT INTO waste_generators (
        user_id, name, type, description, material_condition, packaging_details,
        price_per_kg, minimum_order_kg, available_until, photo_url, lat, lng, is_location_approximate,
        available_waste_types, avg_monthly_volume_kg, seasonal, contact_phone,
        contact_email, gouvernorat, location
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,
        ST_SetSRID(ST_Point($12,$11),4326))
      RETURNING *
    `, [
      req.user.userId, name.trim(), type, description.trim(), material_condition?.trim() || null,
      packaging_details?.trim() || null, price, minimumOrder, availabilityDate,
      photo_url || null, latitude, longitude, is_location_approximate !== false,
      available_waste_types, volume, seasonal === true, contact_phone,
      contact_email, gouvernorat
    ]);

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating generator:', error);
    res.status(500).json({ error: 'Failed to create generator' });
  }
});

// AI Match endpoint
router.get('/:id/match', async (req, res) => {
  try {
    const { id } = req.params;
    const { amount } = req.query;

    const result = await findMatches(id, parseFloat(amount) || null);
    res.json(result);
  } catch (error) {
    console.error('Match error:', error);
    res.status(500).json({ error: 'Failed to calculate matches' });
  }
});

export default router;
