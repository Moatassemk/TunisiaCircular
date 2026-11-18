/**
 * Authentication routes
 */
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query, transaction } from '../db.js';
import { authenticateToken, getJwtSecret } from '../middleware/auth.js';
import {
  validateEmail,
  validateGovernorate,
  validatePassword,
} from '../utils/validation.js';

const router = express.Router();

// Simple in-memory rate limiter for auth endpoints (5 attempts per IP per window)
const authAttempts = new Map(); // ip -> { count, resetAt }
const RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX = 5;

function rateLimitAuth(req, res, next) {
  const ip = req.ip || req.connection.remoteAddress;
  const now = Date.now();
  const record = authAttempts.get(ip);
  if (!record || now > record.resetAt) {
    authAttempts.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return next();
  }
  if (record.count >= RATE_LIMIT_MAX) {
    return res.status(429).json({ error: 'Too many authentication attempts. Try again later.' });
  }
  // Only count failed attempts so a valid login does not burn a slot for
  // every user behind the same proxy IP.
  const wasFailure = req.path === '/api/auth/login' && (!req.body?.email || !req.body?.password);
  if (wasFailure) record.count++;
  next();
}
const governorateCoordinates = {
  Ariana: [36.8625, 10.1956],
  Beja: [36.7256, 9.1817],
  'Ben Arous': [36.753, 10.2189],
  Bizerte: [37.2744, 9.8739],
  Gabes: [33.8815, 10.0982],
  Gafsa: [34.425, 8.7842],
  Jendouba: [36.5011, 8.7802],
  Kairouan: [35.6781, 10.0963],
  Kasserine: [35.1676, 8.8365],
  Kebili: [33.7045, 8.969],
  Kef: [36.1742, 8.7049],
  Mahdia: [35.5047, 11.0622],
  Manouba: [36.8078, 10.1011],
  Medenine: [33.3549, 10.5055],
  Monastir: [35.7643, 10.8113],
  Nabeul: [36.4513, 10.7357],
  Sfax: [34.74, 10.76],
  'Sidi Bouzid': [35.0382, 9.4858],
  Siliana: [36.0849, 9.3708],
  Sousse: [35.8256, 10.637],
  Tataouine: [32.9297, 10.4518],
  Tozeur: [33.9197, 8.1335],
  Tunis: [36.8065, 10.1815],
  Zaghouan: [36.4029, 10.1429],
};

function normalizedGovernorate(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

// Login endpoint
router.post('/login', rateLimitAuth, async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    // Find user
    const result = await query(`
      SELECT u.id, u.email, u.role, u.name, u.company_name, u.gouvernorat, u.phone,
        u.created_at, u.last_login, u.profile_photo, u.is_verified, u.password_hash,
        p.id AS processor_id, p.accepts_waste_types, p.lat, p.lng, p.is_location_approximate,
        p.max_capacity_kg_per_month
      FROM users u
      LEFT JOIN processors p ON p.user_id = u.id
      WHERE u.email = $1 AND u.is_active = true
    `, [email]);
    const user = result.rows[0];

    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      getJwtSecret(),
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    // Update last login
    await query('UPDATE users SET last_login = NOW() WHERE id = $1', [user.id]);

    const webClient = req.get('X-CLAC-Client') === 'web';
    const cookie = `clac_session=${encodeURIComponent(token)}; Path=/api; Max-Age=604800; HttpOnly; SameSite=Lax${process.env.NODE_ENV === 'production' ? '; Secure' : ''}`;
    res.append('Set-Cookie', cookie);
    res.json({
      message: 'Login successful',
      ...(!webClient ? { token } : {}),
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.name,
        company_name: user.company_name,
        gouvernorat: user.gouvernorat,
        created_at: user.created_at,
        processor_id: user.processor_id,
        accepts_waste_types: user.accepts_waste_types || [],
        max_capacity_kg_per_month: user.max_capacity_kg_per_month,
        lat: user.lat,
        lng: user.lng,
        is_location_approximate: user.is_location_approximate,
        profile_photo: user.profile_photo,
        is_verified: user.is_verified === true,
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

router.post('/logout', (req, res) => {
  res.append('Set-Cookie', `clac_session=; Path=/api; Max-Age=0; HttpOnly; SameSite=Lax${process.env.NODE_ENV === 'production' ? '; Secure' : ''}`);
  res.json({ message: 'Signed out' });
});

// Register endpoint (sellers, buyers and collection specialists)
router.post('/register', rateLimitAuth, async (req, res) => {
  try {
    const {
      email,
      password,
      role,
      name,
      company_name,
      phone,
      gouvernorat,
      accepts_waste_types = [],
      max_capacity_kg_per_month,
    } = req.body;

    // Validate input
    if (!email || !password || !role || !name || !company_name || !gouvernorat) {
      return res.status(400).json({ error: 'Name, organization, email, password, role, and governorate are required' });
    }
    if (!validateEmail(email)) return res.status(400).json({ error: 'Invalid email format' });
    if (!validatePassword(password)) return res.status(400).json({ error: 'Password must be at least 8 characters' });
    if (!validateGovernorate(gouvernorat)) return res.status(400).json({ error: 'Invalid governorate' });

    if (!['generator', 'processor', 'collector'].includes(role)) {
      return res.status(400).json({ error: 'Choose sell materials, buy materials, or manage collection points' });
    }
    if (role === 'processor' && (!Array.isArray(accepts_waste_types) || accepts_waste_types.length === 0 || Number(max_capacity_kg_per_month) <= 0)) {
      return res.status(400).json({ error: 'Buyers must choose materials and provide monthly capacity' });
    }

    // Check if user already exists
    const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Email already registered' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await transaction(async (client) => {
      const result = await client.query(`
        INSERT INTO users (email, password_hash, role, name, company_name, phone, gouvernorat, is_active)
        VALUES ($1, $2, $3, $4, $5, $6, $7, true)
        RETURNING id, email, role, name, company_name, gouvernorat, created_at
      `, [email, hashedPassword, role, name, company_name, phone, gouvernorat]);
      const user = result.rows[0];

      if (role === 'processor') {
        const governorate = normalizedGovernorate(gouvernorat);
        const [lat, lng] = governorateCoordinates[governorate] || governorateCoordinates.Tunis;
        const processor = await client.query(`
          INSERT INTO processors (
            user_id, name, type, description, lat, lng, accepts_waste_types,
            max_capacity_kg_per_month, current_stock_kg, price_per_kg, gouvernorat
          ) VALUES ($1, $2, 'buyer', $3, $4, $5, $6, $7, 0, 0, $8)
          RETURNING id, accepts_waste_types, lat, lng, is_location_approximate
        `, [
          user.id,
          company_name,
          'Buyer profile; location is approximated at the governorate center.',
          lat,
          lng,
          accepts_waste_types,
          Number(max_capacity_kg_per_month),
          gouvernorat,
        ]);
        user.processor_id = processor.rows[0].id;
        user.accepts_waste_types = processor.rows[0].accepts_waste_types;
        user.lat = processor.rows[0].lat;
        user.lng = processor.rows[0].lng;
        user.is_location_approximate = processor.rows[0].is_location_approximate;
      }
      return user;
    });

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        ...user,
        processor_id: user.processor_id || null,
        accepts_waste_types: user.accepts_waste_types || [],
        is_verified: false,
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Get current user profile (requires auth)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      `SELECT u.id, u.email, u.role, u.name, u.company_name, u.phone,
        u.gouvernorat, u.created_at, u.last_login, p.id AS processor_id,
        u.profile_photo, u.is_verified, p.accepts_waste_types, p.lat, p.lng, p.is_location_approximate,
        p.max_capacity_kg_per_month
       FROM users u
       LEFT JOIN processors p ON p.user_id = u.id
       WHERE u.id = $1`,
      [req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Current user lookup failed:', error);
    res.status(500).json({ error: 'Could not load your profile' });
  }
});

router.get('/me/summary', authenticateToken, async (req, res) => {
  try {
    let ownership = '';
    const params = [];
    if (req.user.role === 'generator') {
      ownership = 'WHERE wg.user_id = $1';
      params.push(req.user.userId);
    } else if (req.user.role === 'processor') {
      ownership = 'WHERE p.user_id = $1';
      params.push(req.user.userId);
    } else if (req.user.role === 'collector') {
      ownership = 'WHERE t.collector_id = $1';
      params.push(req.user.userId);
    } else if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Profile summary is not available for this role' });
    }
    const [transactions, listings, activity, points] = await Promise.all([
      query(`
        SELECT COUNT(t.id)::int AS count,
          COALESCE(SUM(t.amount_kg), 0)::float AS total_kg,
          COALESCE(SUM(t.total_carbon_saved_kg), 0)::float AS carbon_saved_kg
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        ${ownership}
      `, params),
      req.user.role === 'generator'
        ? query('SELECT COUNT(*)::int AS count, COALESCE(SUM(avg_monthly_volume_kg),0)::float AS monthly_kg FROM waste_generators WHERE user_id = $1', [req.user.userId])
        : Promise.resolve({ rows: [{ count: 0, monthly_kg: 0 }] }),
      query(`
        SELECT t.id, t.waste_type, t.amount_kg, t.status, t.created_at,
          wg.name AS generator_name, p.name AS processor_name
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        ${ownership}
        ORDER BY t.created_at DESC
        LIMIT 5
      `, params),
      query(`
        SELECT COUNT(*)::int AS count,
          COUNT(*) FILTER (WHERE is_verified = true)::int AS verified
        FROM collection_points WHERE owner_id = $1
      `, [req.user.userId]),
    ]);
    res.json({
      transaction_count: transactions.rows[0].count,
      transaction_kg: transactions.rows[0].total_kg,
      carbon_saved_kg: transactions.rows[0].carbon_saved_kg,
      listing_count: listings.rows[0].count,
      monthly_listing_kg: listings.rows[0].monthly_kg,
      collection_point_count: points.rows[0].count,
      verified_collection_point_count: points.rows[0].verified,
      recent_activity: activity.rows,
    });
  } catch (error) {
    console.error('Profile summary query failed:', error);
    res.status(500).json({ error: 'Could not load your activity summary' });
  }
});

// ==== Profile update ====
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const { name, phone, company_name, profile_photo, lat, lng } = req.body;
    const hasCoordinates = lat !== undefined || lng !== undefined;
    if (hasCoordinates && (lat === undefined || lng === undefined || req.user.role !== 'processor')) {
      return res.status(400).json({ error: 'Provide both coordinates for a buyer profile' });
    }
    const latitude = Number(lat);
    const longitude = Number(lng);
    if (hasCoordinates && (!Number.isFinite(latitude) || latitude < 30 || latitude > 38.5 || !Number.isFinite(longitude) || longitude < 7 || longitude > 12.5)) {
      return res.status(400).json({ error: 'Choose coordinates inside Tunisia' });
    }
    const fields = [];
    const values = [];
    let idx = 1;

    if (name) { fields.push(`name = $${idx++}`); values.push(name); }
    if (phone) { fields.push(`phone = $${idx++}`); values.push(phone); }
    if (company_name) { fields.push(`company_name = $${idx++}`); values.push(company_name); }
    if (profile_photo) {
      try { new URL(profile_photo); if (profile_photo.length > 2048) throw new Error(); }
      catch { return res.status(400).json({ error: 'Profile photo URL must be a valid web address' }); }
      fields.push(`profile_photo = $${idx++}`); values.push(profile_photo);
    }

    if (fields.length === 0 && !hasCoordinates) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    let profile;
    if (fields.length) {
      values.push(req.user.userId);
      const queryStr = `UPDATE users SET ${fields.join(', ')} WHERE id = $${idx} RETURNING id, email, role, name, company_name, phone, profile_photo`;
      profile = (await query(queryStr, values)).rows[0];
    } else {
      profile = (await query('SELECT id, email, role, name, company_name, phone, profile_photo FROM users WHERE id = $1', [req.user.userId])).rows[0];
    }
    if (hasCoordinates) {
      const location = await query(`
        UPDATE processors SET lat = $1, lng = $2, location = ST_SetSRID(ST_Point($2,$1),4326),
          is_location_approximate = false WHERE user_id = $3
        RETURNING lat, lng, is_location_approximate
      `, [latitude, longitude, req.user.userId]);
      if (!location.rowCount) return res.status(404).json({ error: 'Buyer location profile not found' });
      Object.assign(profile, location.rows[0]);
    }
    res.json(profile);
  } catch (err) {
    console.error('Profile update error:', err);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

export default router;

