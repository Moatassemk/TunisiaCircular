/**
 * Authentication middleware
 */
import jwt from 'jsonwebtoken';

export function getJwtSecret() {
  const configured = process.env.JWT_SECRET;
  if (configured) return configured;
  if (process.env.NODE_ENV === 'production') {
    throw new Error('JWT_SECRET must be set in production.');
  }
  return 'clac-local-development-secret-only';
}

function cookieToken(req) {
  const cookie = req.headers.cookie?.split(';').map((part) => part.trim())
    .find((part) => part.startsWith('clac_session='));
  if (!cookie) return null;
  try { return decodeURIComponent(cookie.slice('clac_session='.length)); }
  catch { return null; }
}

export function requestToken(req) {
  const authHeader = req.headers.authorization;
  return authHeader?.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length)
    : cookieToken(req);
}

export function authenticateToken(req, res, next) {
  const token = requestToken(req);

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, getJwtSecret());
    req.user = decoded;
    if (req.get('X-CLAC-Client') === 'web' && req.headers.authorization?.startsWith('Bearer ')) {
      res.append('Set-Cookie', `clac_session=${encodeURIComponent(token)}; Path=/api; Max-Age=604800; HttpOnly; SameSite=Lax${process.env.NODE_ENV === 'production' ? '; Secure' : ''}`);
    }
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

export function authorizeRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
}

export default authenticateToken;
