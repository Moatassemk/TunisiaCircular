/**
 * Transactions API routes
 */
import express from 'express';
import { query, transaction } from '../db.js';
import { authenticateToken, authorizeRole } from '../middleware/auth.js';
import { createTransaction } from '../services/matchingService.js';

const router = express.Router();

// Get all transactions (with optional filtering)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { limit = 20, status } = req.query;
    let sql = `
      SELECT t.*, wg.name as generator_name, p.name as processor_name, ug.name as collector_name
      FROM transactions t
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      LEFT JOIN users ug ON ug.id = t.collector_id
      WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;

    if (req.user.role === 'generator') {
      sql += ` AND wg.user_id = $${paramIndex++}`;
      params.push(req.user.userId);
    } else if (req.user.role === 'processor') {
      sql += ` AND p.user_id = $${paramIndex++}`;
      params.push(req.user.userId);
    } else if (req.user.role === 'collector') {
      sql += ` AND t.collector_id = $${paramIndex++}`;
      params.push(req.user.userId);
    } else if (!['admin', 'collector'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }

    if (status) {
      sql += ` AND t.status = $${paramIndex++}`;
      params.push(status);
    }

    sql += ` ORDER BY t.created_at DESC LIMIT $${paramIndex++}`;
    params.push(parseInt(limit));

    const result = await query(sql, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching transactions:', error);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// Get single transaction
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(`
      SELECT t.*, wg.name as generator_name, p.name as processor_name,
             wg.user_id AS generator_user_id, p.user_id AS processor_user_id
      FROM transactions t
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      WHERE t.id = $1 AND (
        $2 = 'admin'::varchar OR
        ($2 = 'generator' AND wg.user_id = $3) OR
        ($2 = 'processor' AND p.user_id = $3) OR
        ($2 = 'collector' AND t.collector_id = $3)
      )
    `, [id, req.user.role, req.user.userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const exchange = result.rows[0];
    const events = await query(`
      SELECT e.id, e.actor_id, e.from_status, e.to_status, e.note, e.created_at,
             u.name AS actor_name
      FROM transaction_events e
      LEFT JOIN users u ON u.id = e.actor_id
      WHERE e.transaction_id = $1
      ORDER BY e.created_at ASC, e.id ASC
    `, [id]);
    exchange.events = events.rows;
    res.json(exchange);
  } catch (error) {
    console.error('Error fetching transaction:', error);
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

router.get('/:id/messages', authenticateToken, async (req, res) => {
  try {
    const result = await query(`
      SELECT m.id, m.body, m.created_at, m.sender_id, u.name AS sender_name
      FROM transaction_messages m
      JOIN users u ON u.id = m.sender_id
      JOIN transactions t ON t.id = m.transaction_id
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      WHERE m.transaction_id = $1 AND (
        $2 = 'admin'::varchar OR wg.user_id = $3 OR p.user_id = $3 OR t.collector_id = $3
      )
      ORDER BY m.created_at ASC, m.id ASC
      LIMIT 500
    `, [req.params.id, req.user.role, req.user.userId]);
    if (!result.rowCount) {
      const exists = await query('SELECT id FROM transactions WHERE id = $1', [req.params.id]);
      if (!exists.rowCount) return res.status(404).json({ error: 'Transaction not found' });
      const access = await query(`
        SELECT 1 FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        WHERE t.id = $1 AND ($2::varchar = 'admin' OR wg.user_id = $3 OR p.user_id = $3 OR t.collector_id = $3)
      `, [req.params.id, req.user.role, req.user.userId]);
      if (!access.rowCount) return res.status(403).json({ error: 'Not a participant in this exchange' });
    }
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching exchange messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

router.post('/:id/messages', authenticateToken, async (req, res) => {
  const body = typeof req.body?.body === 'string' ? req.body.body.trim() : '';
  if (!body || body.length > 4000) return res.status(400).json({ error: 'Message must contain 1 to 4000 characters' });
  try {
    const participant = await query(`
      SELECT t.id, wg.user_id AS generator_user_id, p.user_id AS processor_user_id,
             u.name AS sender_name
      FROM transactions t
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      JOIN users u ON u.id = $3
      WHERE t.id = $1 AND ($2::varchar = 'admin' OR wg.user_id = $3 OR p.user_id = $3)
    `, [req.params.id, req.user.role, req.user.userId]);
    if (!participant.rowCount) return res.status(404).json({ error: 'Exchange not found' });
    const result = await query(`
      INSERT INTO transaction_messages(transaction_id, sender_id, body)
      VALUES ($1, $2, $3)
      RETURNING id, transaction_id, sender_id, body, created_at
    `, [req.params.id, req.user.userId, body]);
    const row = result.rows[0];
    row.sender_name = participant.rows[0].sender_name;
    const otherParty = req.user.userId === participant.rows[0].generator_user_id
      ? participant.rows[0].processor_user_id
      : participant.rows[0].generator_user_id;
    if (otherParty) {
      await query(`
        INSERT INTO notifications(user_id, type, title, message, link)
        VALUES ($1, 'exchange_message', 'New exchange message', 'Your exchange partner sent a message.', $2)
      `, [otherParty, `/transactions/${req.params.id}`]);
    }
    res.status(201).json(row);
  } catch (error) {
    console.error('Error sending exchange message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

router.patch('/:id/schedule', authenticateToken, authorizeRole('generator', 'processor', 'admin'), async (req, res) => {
  const pickupAt = new Date(req.body?.scheduled_pickup_at);
  if (!Number.isFinite(pickupAt.getTime()) || pickupAt.getTime() < Date.now()) {
    return res.status(400).json({ error: 'Choose a pickup time in the future' });
  }
  try {
    const result = await query(`
      UPDATE transactions t SET scheduled_pickup_at = $1
      WHERE t.id = $2 AND t.status IN ('pending', 'matched') AND (
        $3::varchar = 'admin' OR
        ($3 = 'generator' AND EXISTS (SELECT 1 FROM waste_generators wg WHERE wg.id = t.generator_id AND wg.user_id = $4)) OR
        ($3 = 'processor' AND EXISTS (SELECT 1 FROM processors p WHERE p.id = t.processor_id AND p.user_id = $4))
      )
      RETURNING t.id, t.scheduled_pickup_at
    `, [pickupAt.toISOString(), req.params.id, req.user.role, req.user.userId]);
    if (!result.rowCount) return res.status(404).json({ error: 'Open exchange not found' });
    if (req.user.role !== 'admin') {
      const peers = await query(`
        SELECT wg.user_id AS generator_user_id, p.user_id AS processor_user_id
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        WHERE t.id = $1
      `, [req.params.id]);
      const peerId = req.user.role === 'generator'
        ? peers.rows[0]?.processor_user_id
        : peers.rows[0]?.generator_user_id;
      if (peerId) await query(`
        INSERT INTO notifications(user_id, type, title, message, link)
        VALUES ($1, 'pickup_scheduled', 'Pickup time updated', 'Your exchange partner scheduled a pickup.', $2)
      `, [peerId, `/transactions/${req.params.id}`]);
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Pickup scheduling failed:', error);
    res.status(500).json({ error: 'Could not schedule pickup' });
  }
});

// Create a new transaction
router.post('/', authenticateToken, authorizeRole('processor'), async (req, res) => {
  try {
    const ownedProcessor = await query(
      'SELECT id FROM processors WHERE id = $1 AND user_id = $2',
      [req.body.processorId, req.user.userId]
    );
    if (ownedProcessor.rows.length === 0) {
      return res.status(403).json({ error: 'Buyer profile not found for this account' });
    }
    const amount = Number(req.body.amountKg);
    if (!Number.isFinite(amount) || amount <= 0 || amount > 10000000) {
      return res.status(400).json({ error: 'Request a valid material quantity' });
    }
    const listing = await query(
      `SELECT g.user_id, g.avg_monthly_volume_kg, g.minimum_order_kg, g.available_waste_types, g.available_until
       FROM waste_generators g
       JOIN users u ON u.id = g.user_id
       WHERE g.id = $1 AND u.is_active = true AND u.is_verified = true`,
      [req.body.generatorId],
    );
    if (!listing.rowCount) return res.status(404).json({ error: 'Material listing not found' });
    if (listing.rows[0].user_id === req.user.userId) {
      return res.status(400).json({ error: 'You cannot request materials from your own organization' });
    }
    if (listing.rows[0].available_until && new Date(listing.rows[0].available_until) < new Date()) {
      return res.status(400).json({ error: 'This listing is no longer available' });
    }
    if (Number(listing.rows[0].avg_monthly_volume_kg) > 0 && amount > Number(listing.rows[0].avg_monthly_volume_kg)) {
      return res.status(400).json({ error: 'Requested quantity exceeds the listed monthly volume' });
    }
    if (listing.rows[0].minimum_order_kg != null &&
        amount < Number(listing.rows[0].minimum_order_kg)) {
      return res.status(400).json({ error: 'Requested quantity is below the seller minimum order' });
    }
    // Cap cumulative requests against the listing's monthly volume so a seller
    // cannot be over-committed by many small requests.
    const committed = await query(
      `SELECT COALESCE(SUM(amount_kg), 0) AS committed_kg
       FROM transactions
       WHERE generator_id = $1 AND status IN ('pending', 'matched', 'collected', 'processed')`,
      [req.body.generatorId],
    );
    const monthlyLimit = Number(listing.rows[0].avg_monthly_volume_kg);
    if (monthlyLimit > 0 && Number(committed.rows[0].committed_kg) + amount > monthlyLimit) {
      return res.status(400).json({ error: 'Requested quantity would exceed the available monthly volume' });
    }
    const compatible = await query(
      `SELECT 1 FROM waste_generators g JOIN processors p ON p.id = $2
       WHERE g.id = $1 AND g.available_waste_types && p.accepts_waste_types AND p.is_active = true`,
      [req.body.generatorId, req.body.processorId],
    );
    if (!compatible.rowCount) return res.status(400).json({ error: 'This buyer does not accept the listed material' });
    const transaction = await createTransaction(req.body);
    await query(`
      INSERT INTO transaction_events(transaction_id, actor_id, from_status, to_status)
      VALUES ($1, $2, NULL, 'pending')
    `, [transaction.id, req.user.userId]);
    res.status(201).json(transaction);
  } catch (error) {
    console.error('Error creating transaction:', error);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

// Update transaction status
router.patch('/:id/status', authenticateToken, authorizeRole('generator', 'processor', 'admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const current = await query(`
      SELECT t.*, wg.user_id AS generator_user_id, p.user_id AS processor_user_id
      FROM transactions t
      LEFT JOIN waste_generators wg ON wg.id = t.generator_id
      LEFT JOIN processors p ON p.id = t.processor_id
      WHERE t.id = $1
    `, [id]);
    if (!current.rowCount) return res.status(404).json({ error: 'Transaction not found' });
    const exchange = current.rows[0];
    const isAdmin = req.user.role === 'admin';
    const isSeller = req.user.role === 'generator' && exchange.generator_user_id === req.user.userId;
    const isBuyer = req.user.role === 'processor' && exchange.processor_user_id === req.user.userId;
    if (!isAdmin && !isSeller && !isBuyer) return res.status(403).json({ error: 'Not a participant in this exchange' });

    const transitions = {
      pending: { generator: ['matched', 'cancelled'], processor: ['cancelled'] },
      matched: { generator: ['collected', 'cancelled'], processor: ['collected', 'cancelled'] },
      collected: { processor: ['processed'], generator: ['processed'] },
      processed: { generator: ['completed'], processor: ['completed'] },
    };
    const allowed = isAdmin
      ? ['pending', 'matched', 'collected', 'processed', 'completed', 'cancelled']
      : transitions[exchange.status]?.[isSeller ? 'generator' : 'processor'] ?? [];
    if (!allowed.includes(status)) return res.status(409).json({ error: `Cannot move an exchange from ${exchange.status} to ${status}` });

    const completedAt = status === 'completed' ? new Date() : exchange.completed_at;
    const updatedExchange = await transaction(async (client) => {
      const result = await client.query(`
        UPDATE transactions
        SET status = $1, completed_at = $2
        WHERE id = $3 AND status = $4
        RETURNING *
      `, [status, completedAt, id, exchange.status]);
      if (!result.rowCount) return null;
      // Only record the event and move stock when the status actually changed.
      // Admins can force any status, so an idempotent "completed" → "completed"
      // repeat must not double-count the intake.
      if (exchange.status !== status) {
        await client.query(`
          INSERT INTO transaction_events(transaction_id, actor_id, from_status, to_status)
          VALUES ($1, $2, $3, $4)
        `, [id, req.user.userId, exchange.status, status]);
        if (status === 'completed') {
          await client.query(
            'UPDATE processors SET current_stock_kg = current_stock_kg + $1 WHERE id = $2',
            [exchange.amount_kg, exchange.processor_id],
          );
        }
      }
      return result.rows[0];
    });
    if (!updatedExchange) return res.status(409).json({ error: 'Exchange changed; refresh and try again' });
    const otherParty = isSeller ? exchange.processor_user_id : isBuyer ? exchange.generator_user_id : null;
    if (otherParty) {
      await query(`
        INSERT INTO notifications(user_id, type, title, message, link)
        VALUES ($1, 'exchange_status', 'Exchange updated', $2, $3)
      `, [otherParty, `The exchange status is now ${status}.`, `/transactions/${id}`]);
    }
    res.json(updatedExchange);
  } catch (error) {
    console.error('Error updating transaction status:', error);
    res.status(500).json({ error: 'Failed to update transaction status' });
  }
});

export default router;
