import express from 'express';
import { query } from '../db.js';

const router = express.Router();

// GET /api/admin/users
router.get('/users', async (req, res) => {
  try {
    const result = await query(`
      SELECT u.id, u.email, u.role, u.name, u.company_name, u.phone, u.is_active, u.created_at,
             (SELECT COUNT(*) FROM transactions t JOIN waste_generators wg ON wg.id = t.generator_id WHERE wg.user_id = u.id) as transaction_count
      FROM users u
      ORDER BY u.created_at DESC
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch users' }); }
});

// GET /api/admin/stats
router.get('/stats', async (req, res) => {
  try {
    const users = await query('SELECT count(*) FROM users');
    const tx = await query('SELECT count(*) FROM transactions WHERE status = \'completed\'');
    const waste = await query('SELECT COALESCE(SUM(amount_kg), 0)::numeric as total_kg FROM transactions WHERE status = \'completed\'');
    res.json({
      totalUsers: parseInt(users.rows[0].count),
      totalTransactions: parseInt(tx.rows[0].count),
      totalWasteDiverted: parseFloat(waste.rows[0].total_kg),
    });
  } catch (err) { res.status(500).json({ error: 'Failed to fetch platform stats' }); }
});

// POST /api/admin/users/:id/toggle-active
router.post('/users/:id/toggle-active', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(`
      UPDATE users SET is_active = NOT is_active WHERE id = $1 RETURNING id, is_active
    `, [id]);
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: 'Failed to toggle user status' }); }
});

router.post('/collection-points/:id/verify', async (req, res) => {
  try {
    const result = await query(
      'UPDATE collection_points SET is_verified = true, is_active = true, review_note = NULL WHERE id = $1 RETURNING id, name, owner_id, is_verified',
      [req.params.id],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'Collection point not found' });
    const point = result.rows[0];
    await query(`
      INSERT INTO notifications(user_id, type, title, message)
      VALUES ($1, 'collection_point_verified', 'Collection point verified', $2)
    `, [point.owner_id, `Your collection point "${point.name}" is now visible on the CLAC network.`]);
    res.json(point);
  } catch (err) { res.status(500).json({ error: 'Failed to verify collection point' }); }
});

router.get('/collection-points', async (req, res) => {
  try {
    const result = await query(`
      SELECT cp.*, u.name AS submitter_name, u.email AS submitter_email
      FROM collection_points cp
      JOIN users u ON u.id = cp.owner_id
      WHERE cp.is_active = true AND cp.is_verified = false
      ORDER BY cp.created_at ASC
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to load collection point submissions' }); }
});

router.get('/organizations', async (req, res) => {
  try {
    const result = await query(`
      SELECT u.id, u.name, u.company_name, u.email, u.phone, u.role, u.gouvernorat, u.created_at,
             COALESCE(g.name, p.name, u.name) AS profile_name,
             COALESCE(g.lat, p.lat) AS lat, COALESCE(g.lng, p.lng) AS lng,
             COALESCE(g.description, p.description) AS description
      FROM users u
      LEFT JOIN waste_generators g ON g.user_id = u.id
      LEFT JOIN processors p ON p.user_id = u.id
      WHERE u.role IN ('generator', 'processor', 'collector') AND u.is_active = true AND u.is_verified = false
        AND (g.id IS NOT NULL OR p.id IS NOT NULL OR u.role = 'collector')
      ORDER BY u.created_at ASC
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to load organization submissions' }); }
});

router.post('/organizations/:id/verify', async (req, res) => {
  try {
    const result = await query(`
      UPDATE users SET is_verified = true
      WHERE id = $1 AND role IN ('generator', 'processor', 'collector') AND is_verified = false
      RETURNING id, is_verified, name, company_name
    `, [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'Organization not found' });
    await query(`
      INSERT INTO notifications(user_id, type, title, message)
      VALUES ($1, 'organization_verified', 'Organization verified', 'Your CLAC organization profile has been verified.')
    `, [req.params.id]);
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: 'Failed to verify organization' }); }
});

router.post('/organizations/:id/reject', async (req, res) => {
  try {
    const result = await query(`
      UPDATE users SET is_active = false
      WHERE id = $1 AND role IN ('generator', 'processor', 'collector') AND is_verified = false
      RETURNING id, is_active
    `, [req.params.id]);
    if (!result.rowCount) return res.status(404).json({ error: 'Pending organization not found' });
    res.json(result.rows[0]);
  } catch (err) { res.status(500).json({ error: 'Failed to reject organization' }); }
});

router.post('/collection-points/:id/reject', async (req, res) => {
  try {
    const note = typeof req.body?.reason === 'string'
      ? req.body.reason.trim().slice(0, 1000)
      : '';
    const result = await query(
      `UPDATE collection_points SET is_active = false, review_note = $2
       WHERE id = $1 AND is_verified = false
       RETURNING id, name, owner_id, is_active, review_note`,
      [req.params.id, note || null],
    );
    if (!result.rowCount) return res.status(404).json({ error: 'Pending collection point not found' });
    const point = result.rows[0];
    const message = note
      ? `Your collection point "${point.name}" was not approved: ${note}. Edit it and submit it again for review.`
      : `Your collection point "${point.name}" was not approved. Edit it and submit it again for review.`;
    await query(`
      INSERT INTO notifications(user_id, type, title, message)
      VALUES ($1, 'collection_point_rejected', 'Collection point needs changes', $2)
    `, [point.owner_id, message]);
    res.json(point);
  } catch (err) { res.status(500).json({ error: 'Failed to reject collection point' }); }
});

// GET /api/admin/recent-signups
router.get('/recent-signups', async (req, res) => {
  try {
    const result = await query(`
      SELECT id, email, role, name, company_name, created_at FROM users
      WHERE created_at >= NOW() - INTERVAL '7 days'
      ORDER BY created_at DESC
    `);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch recent signups' }); }
});

export default router;
