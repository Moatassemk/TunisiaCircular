/**
 * Dashboard API routes
 */
import express from 'express';
import { query } from '../db.js';
import { getDashboardStats, getCarbonIntensityForecast } from '../services/matchingService.js';

const router = express.Router();

// Get full dashboard data
router.get('/', async (req, res) => {
  try {
    const [stats, forecast] = await Promise.all([
      getDashboardStats(),
      getCarbonIntensityForecast()
    ]);

    res.json({
      stats,
      carbonIntensityForecast: forecast
    });
  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ error: 'Failed to load dashboard data' });
  }
});

// Get quick stats only
router.get('/stats', async (req, res) => {
  try {
    const stats = await getDashboardStats();
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: 'Failed to load stats' });
  }
});

// Get recent transactions
router.get('/recent-transactions', async (req, res) => {
  try {
    const { limit = 10 } = req.query;
    const result = await query(`
      SELECT t.*, wg.name as generator_name, p.name as processor_name
      FROM transactions t
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      ORDER BY t.created_at DESC
      LIMIT $1
    `, [limit]);

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch recent transactions' });
  }
});

// Get waste type distribution
router.get('/waste-types', async (req, res) => {
  try {
    const result = await query(`
      SELECT waste_type, COUNT(*) as count, SUM(amount_kg) as total_kg
      FROM transactions
      GROUP BY waste_type
      ORDER BY total_kg DESC
    `);

    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch waste type statistics' });
  }
});

export default router;
