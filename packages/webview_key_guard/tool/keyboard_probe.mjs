import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('./keyboard_probe.html', import.meta.url));
const runs = new Map();
const server = createServer(async (request, response) => {
  response.setHeader('Cache-Control', 'no-store');
  if (request.method === 'GET' && request.url === '/') {
    response.setHeader('Content-Type', 'text/html; charset=utf-8');
    return response.end(page);
  }
  if (request.method === 'GET' && request.url === '/_state') {
    response.setHeader('Content-Type', 'application/json');
    return response.end(JSON.stringify({pid: process.pid, runs: [...runs.values()]}));
  }
  if (request.method === 'POST' && request.url === '/_events') {
    try {
      let body = '';
      for await (const chunk of request) {
        body += chunk;
        if (body.length > 65536) throw new Error('Report too large');
      }
      const report = JSON.parse(body);
      if (typeof report.run !== 'string' || !Number.isInteger(report.keydowns)) {
        throw new Error('Invalid report');
      }
      runs.set(report.run, report);
      if (runs.size > 8) runs.delete(runs.keys().next().value);
      response.writeHead(204);
      return response.end();
    } catch (_) {
      response.writeHead(400);
      return response.end();
    }
  }
  response.writeHead(404);
  response.end();
});
server.listen(0, '127.0.0.1', () => {
  console.log(`KEY_GUARD_PROBE=http://127.0.0.1:${server.address().port}/`);
});
process.on('SIGTERM', () => server.close());
