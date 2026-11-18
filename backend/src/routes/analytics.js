import express from 'express';
import { query } from '../db.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

router.get('/me/impact', authenticateToken, async (req, res) => {
  try {
    let scope;
    const params = [];
    if (req.user.role === 'admin') scope = 'TRUE';
    else if (req.user.role === 'generator') {
      params.push(req.user.userId);
      scope = `wg.user_id = $${params.length}`;
    } else if (req.user.role === 'processor') {
      params.push(req.user.userId);
      scope = `p.user_id = $${params.length}`;
    } else if (req.user.role === 'collector') {
      params.push(req.user.userId);
      scope = `t.collector_id = $${params.length}`;
    } else return res.status(403).json({ error: 'No impact report is available for this account' });

    const [summary, monthly, factors] = await Promise.all([
      query(`
        SELECT COUNT(*)::int AS transactions,
               COALESCE(SUM(t.amount_kg), 0)::numeric AS material_kg,
               COALESCE(SUM(t.total_carbon_saved_kg), 0)::numeric AS estimated_co2e_kg,
               COALESCE(AVG(t.distance_km), 0)::numeric AS average_distance_km
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        WHERE t.status = 'completed' AND ${scope}
      `, params),
      query(`
        SELECT to_char(date_trunc('month', COALESCE(t.completed_at, t.created_at)), 'YYYY-MM') AS month,
               COUNT(*)::int AS transactions,
               COALESCE(SUM(t.amount_kg), 0)::numeric AS material_kg,
               COALESCE(SUM(t.total_carbon_saved_kg), 0)::numeric AS estimated_co2e_kg,
               COALESCE(AVG(t.distance_km), 0)::numeric AS average_distance_km
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        WHERE t.status = 'completed' AND ${scope}
          AND COALESCE(t.completed_at, t.created_at) >= date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'
        GROUP BY date_trunc('month', COALESCE(t.completed_at, t.created_at))
        ORDER BY date_trunc('month', COALESCE(t.completed_at, t.created_at))
      `, params),
      query(`SELECT factor_key, description, source, valid_from, valid_to
             FROM carbon_factors WHERE valid_from <= CURRENT_DATE
               AND (valid_to IS NULL OR valid_to >= CURRENT_DATE)
             ORDER BY factor_key`),
    ]);
    res.json({ summary: summary.rows[0], monthly: monthly.rows, factors: factors.rows });
  } catch (error) {
    console.error('Personal impact report failed:', error);
    res.status(500).json({ error: 'Could not load impact report' });
  }
});

// GET /api/analytics/impact-summary
router.get('/impact-summary', async (req, res) => {
  try {
    const result = await query(`
      SELECT
        SUM(total_carbon_saved_kg) as carbon_saved,
        SUM(amount_kg) as waste_diverted,
        AVG(distance_km) as avg_distance
      FROM transactions
      WHERE status = 'completed'
    `);
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch impact' }); }
});

// GET /api/analytics/monthly-trend
router.get('/monthly-trend', async (req, res) => {
  try {
    const result = await query(`SELECT * FROM v_monthly_activity ORDER BY month ASC LIMIT 12`);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch trend' }); }
});

// GET /api/analytics/top-governorates
router.get('/top-governorates', async (req, res) => {
  try {
    const result = await query(`
      SELECT gouvernorat, COUNT(*) as activity_count
      FROM transactions t
      JOIN waste_generators wg ON wg.id = t.generator_id
      GROUP BY gouvernorat
      ORDER BY activity_count DESC
      LIMIT 5
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch gov stats' }); }
});

// GET /api/analytics/ranking
router.get('/ranking', async (req, res) => {
  try {
    const gen = await query(`SELECT wg.id, wg.name, SUM(t.amount_kg) as total_kg FROM transactions t JOIN waste_generators wg ON wg.id = t.generator_id GROUP BY wg.id, wg.name ORDER BY total_kg DESC LIMIT 5`);
    const proc = await query(`SELECT p.id, p.name, SUM(t.amount_kg) as total_kg FROM transactions t JOIN processors p ON p.id = t.processor_id GROUP BY p.id, p.name ORDER BY total_kg DESC LIMIT 5`);
    res.json({ topGenerators: gen.rows, topProcessors: proc.rows });
  } catch (err) { res.status(500).json({ error: 'Failed to fetch ranking' }); }
});

export default router;
