/**
 * CLAC - Main Server
 * Tunisia Circular Economy Platform
 */
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';

import generatorRoutes from './src/routes/generators.js';
import processorRoutes from './src/routes/processors.js';
import transactionRoutes from './src/routes/transactions.js';
import authRoutes from './src/routes/auth.js';
import dashboardRoutes from './src/routes/dashboard.js';
import notificationRoutes from './src/routes/notifications.js';
import collectionPointRoutes from './src/routes/collectionPoints.js';
import analyticsRoutes from './src/routes/analytics.js';
import adminRoutes from './src/routes/admin.js';
import networkRoutes from './src/routes/network.js';
import { query } from './src/db.js';
import { search } from './src/services/searchService.js';
import { getDashboardStats, getCarbonIntensityForecast } from './src/services/matchingService.js';
import { authenticateToken, authorizeRole } from './src/middleware/auth.js';

dotenv.config();

const app = express();
// Trust the first hop so the nginx/ingress proxy forwards the real client IP.
// Without this, every request arrives from the proxy's own IP and the auth
// rate limiter locks out all users combined after 5 attempts per window.
app.set('trust proxy', 1);
const PORT = process.env.PORT || 5000;
const isProduction = process.env.NODE_ENV === 'production';
const allowedOrigins = (process.env.CORS_ORIGINS || process.env.CORS_ORIGIN || '')
  .split(',').map((origin) => origin.trim()).filter(Boolean);
if (isProduction && (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32)) {
  throw new Error('Set JWT_SECRET to a random value of at least 32 characters in production.');
}
if (isProduction && (!process.env.DB_PASSWORD || process.env.DB_PASSWORD === 'postgres')) {
  throw new Error('Set a unique DB_PASSWORD in production.');
}
if (isProduction && !allowedOrigins.length) {
  throw new Error('Set CORS_ORIGINS to the production web origin(s).');
}

// Security middleware
app.use(helmet());
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin) || (!isProduction && allowedOrigins.includes('*'))) {
      return callback(null, true);
    }
    if (!isProduction && /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin is not allowed by CORS.'));
  },
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'CLAC API'
  });
});

// API routes
// Dashboard and analytics expose aggregate transaction data; require a signed-in
// account so unauthenticated scrapers cannot harvest every exchange.
app.get('/api/dashboard', authenticateToken, async (req, res) => {
  try {
    const [stats, forecast] = await Promise.all([
      getDashboardStats(),
      getCarbonIntensityForecast()
    ]);
    res.json({ stats, carbonIntensityForecast: forecast });
  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ error: 'Failed to load dashboard data' });
  }
});

app.get('/api/dashboard/recent-transactions', authenticateToken, async (req, res) => {
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
    console.error('Recent transactions error:', error);
    res.status(500).json({ error: 'Failed to fetch recent transactions' });
  }
});

app.get('/api/search', async (req, res) => {
  try {
    const results = await search(req.query);
    res.json(results);
  } catch (error) {
    console.error('Search endpoint error:', error);
    res.status(500).json({ error: 'Search failed' });
  }
});

app.use('/api/auth', authRoutes);
app.use('/api/generators', generatorRoutes);
app.use('/api/processors', processorRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/dashboard', authenticateToken, dashboardRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/collection-points', collectionPointRoutes);
app.use('/api/network', networkRoutes);
app.use('/api/analytics', authenticateToken, analyticsRoutes);
app.use('/api/admin', authenticateToken, authorizeRole('admin'), adminRoutes);

// Keep unknown API and root requests explicit; Flutter Web is served separately.
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🌿 CLAC API running on http://localhost:${PORT}`);
  console.log(`   📊 Health: http://localhost:${PORT}/health`);
  console.log(`   🔌 API Docs: http://localhost:${PORT}/api`);
  console.log(`\n   Status: ${process.env.NODE_ENV || 'development'} mode\n`);
});

export default app;
