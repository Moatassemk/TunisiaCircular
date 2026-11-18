/**
 * Processors API routes
 */
import express from 'express';
import { query } from '../db.js';

const router = express.Router();

// Get all processors (with optional filtering)
router.get('/', async (req, res) => {
  try {
    const { wasteType, type, gouvernorat, capacityMin, capacityMax } = req.query;
    let sql = 'SELECT p.*, u.is_verified AS owner_verified FROM processors p JOIN users u ON u.id = p.user_id WHERE p.is_active = true AND u.is_active = true AND u.is_verified = true';
    const params = [];
    let paramIndex = 1;

    if (wasteType) {
      sql += ` AND EXISTS (SELECT 1 FROM unnest(p.accepts_waste_types) AS t WHERE t = $${paramIndex++})`;
      params.push(wasteType);
    }
    if (type) {
      sql += ` AND p.type = $${paramIndex++}`;
      params.push(type);
    }
    if (gouvernorat) {
      sql += ` AND p.gouvernorat ILIKE $${paramIndex++}`;
      params.push(`%${gouvernorat}%`);
    }
    if (capacityMin) {
      sql += ` AND p.max_capacity_kg_per_month >= $${paramIndex++}`;
      params.push(capacityMin);
    }
    if (capacityMax) {
      sql += ` AND p.max_capacity_kg_per_month <= $${paramIndex++}`;
      params.push(capacityMax);
    }

    sql += ' ORDER BY p.name ASC';

    const result = await query(sql, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching processors:', error);
    res.status(500).json({ error: 'Failed to fetch processors' });
  }
});

// Get single processor by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query('SELECT p.*, u.is_verified AS owner_verified FROM processors p JOIN users u ON u.id = p.user_id WHERE p.id = $1 AND p.is_active = true AND u.is_active = true AND u.is_verified = true', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Processor not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching processor:', error);
    res.status(500).json({ error: 'Failed to fetch processor' });
  }
});

export default router;
