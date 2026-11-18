import { createServer, request as proxyRequest } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('./build/web/', import.meta.url));
const port = Number(process.env.WEB_PORT || 3001);
const apiTarget = new URL(process.env.API_PROXY_TARGET || 'http://localhost:5001');
const mime = { '.css': 'text/css', '.html': 'text/html', '.ico': 'image/x-icon', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.woff': 'font/woff', '.woff2': 'font/woff2' };

createServer((req, res) => {
  const pathname = new URL(req.url || '/', 'http://localhost').pathname;
  if (pathname === '/api' || pathname.startsWith('/api/') || pathname === '/health') {
    const upstream = proxyRequest({ hostname: apiTarget.hostname, port: apiTarget.port, method: req.method, path: pathname + new URL(req.url, 'http://localhost').search, headers: { ...req.headers, host: apiTarget.host } }, response => {
      res.writeHead(response.statusCode || 502, response.headers);
      response.pipe(res);
    });
    upstream.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end('API unavailable'); });
    req.pipe(upstream);
    return;
  }
  const safePath = normalize(decodeURIComponent(pathname)).replace(/^([.][.][/\\])+/, '').replace(/^[/\\]+/, '');
  let file = join(root, safePath);
  if (!file.startsWith(root) || !existsSync(file) || !statSync(file).isFile()) file = join(root, 'index.html');
  res.writeHead(200, {
    'Content-Type': mime[extname(file)] || 'application/octet-stream',
    'Cache-Control': extname(file) === '.html' ? 'no-cache' : 'public, max-age=3600',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
  });
  createReadStream(file).pipe(res);
}).listen(port, '0.0.0.0', () => console.log(`CLAC Flutter Web: http://localhost:${port} (API: ${apiTarget})`));
