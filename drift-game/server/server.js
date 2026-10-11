// Kaido Drift multiplayer server.
// Serves the game (dist/kaido-drift.html) and runs rooms over WebSocket at /ws.
// Run: npm install && npm run build && npm start   (PORT env var, default 8080)
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT) || 8080;
const ROOM_SIZE = Number(process.env.ROOM_SIZE) || 16;
const DIST = path.join(__dirname, '..', 'dist');
const CARS = ['ps13', 'ae8', 'r32', 'fd7', 'z33', 'jza', 'ps15'];

// ---------- chat safety ----------
// A short blocklist; extend BLOCKED_WORDS (comma separated) through the environment.
const BLOCK = ['fuck', 'shit', 'cunt', 'bitch', 'nigger', 'nigga', 'faggot', 'retard', 'whore', 'slut', 'rape', 'kys', 'dick', 'pussy']
  .concat((process.env.BLOCKED_WORDS || '').split(',').map(w => w.trim().toLowerCase()).filter(Boolean));
const leet = t => t.toLowerCase().replace(/[@4]/g, 'a').replace(/3/g, 'e').replace(/[1!|]/g, 'i').replace(/0/g, 'o').replace(/[5$]/g, 's').replace(/7/g, 't');
function clean(text) {
  return text.replace(/[\p{L}\p{N}@$!|]+/gu, w => BLOCK.some(b => leet(w).includes(b)) ? '*'.repeat(w.length) : w);
}
const LINK = /(https?:\/\/|www\.|\b[a-z0-9-]+\.(com|net|org|gg|io|xyz|ru|tk)\b)/i;
function cleanName(n) {
  let s = String(n || '').replace(/[^\p{L}\p{N}_\- ]/gu, '').trim().slice(0, 16);
  if (s.length < 2 || clean(s) !== s) s = 'Driver' + (1000 + Math.floor(Math.random() * 9000));
  return s;
}

// ---------- static files ----------
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/manifest+json', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/health') { res.writeHead(200, { 'content-type': 'application/json' }); return res.end(JSON.stringify({ ok: true, players: wss.clients.size, rooms: rooms.size })); }
  let file = url.pathname === '/' ? 'kaido-drift.html' : path.normalize(url.pathname).replace(/^([/\\])+/, '');
  if (file.includes('..')) { res.writeHead(400); return res.end(); }
  const full = path.join(DIST, file);
  fs.readFile(full, (err, buf) => {
    if (err) { res.writeHead(404, { 'content-type': 'text/plain' }); return res.end('Not found. Run "npm run build" to create dist/.'); }
    res.writeHead(200, { 'content-type': TYPES[path.extname(full)] || 'application/octet-stream', 'cache-control': file === 'sw.js' ? 'no-cache' : 'public, max-age=300', 'x-content-type-options': 'nosniff' });
    res.end(buf);
  });
});

// ---------- rooms ----------
const rooms = new Map(); // name -> { players: Map<id, player>, chat: [] }
let nextId = 1;
function pickRoom() {
  for (const [name, r] of rooms) if (r.players.size < ROOM_SIZE) return name;
  let n = 1; while (rooms.has(`Kojiri ${n}`)) n++;
  const name = `Kojiri ${n}`; rooms.set(name, { players: new Map(), chat: [] }); return name;
}
const pub = p => ({ id: p.id, name: p.name, car: p.car, color: p.color });
function broadcast(room, msg, except) {
  const data = JSON.stringify(msg);
  for (const p of room.players.values()) if (p !== except && p.ws.readyState === 1) p.ws.send(data);
}

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 2048 });
const perIp = new Map();
wss.on('connection', (ws, req) => {
  const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
  if ((perIp.get(ip) || 0) >= 4) { ws.send(JSON.stringify({ t: 'err', text: 'Too many connections from your network.' })); return ws.close(); }
  perIp.set(ip, (perIp.get(ip) || 0) + 1);
  let me = null, roomName = null, msgs = 0, chatTokens = 3, lastChatRefill = Date.now();
  ws.isAlive = true; ws.on('pong', () => { ws.isAlive = true; });
  ws.on('message', raw => {
    if (++msgs > 40) return; // flood guard, reset every second
    let m; try { m = JSON.parse(raw); } catch (e) { return; }
    if (!m || typeof m !== 'object') return;
    if (m.t === 'hello' && !me) {
      roomName = pickRoom(); const room = rooms.get(roomName);
      me = { id: nextId++, ws, name: cleanName(m.name), car: CARS.includes(m.car) ? m.car : 'ps13', color: /^#[0-9a-f]{6}$/i.test(m.color) ? m.color : '#cccccc', s: null };
      // make names unique in the room
      const taken = new Set([...room.players.values()].map(p => p.name.toLowerCase()));
      if (taken.has(me.name.toLowerCase())) me.name = me.name.slice(0, 12) + '_' + (me.id % 1000);
      ws.send(JSON.stringify({ t: 'welcome', id: me.id, room: roomName, players: [...room.players.values()].map(pub), chat: room.chat.slice(-15) }));
      room.players.set(me.id, me);
      broadcast(room, { t: 'j', p: pub(me) }, me);
      return;
    }
    if (!me) return;
    const room = rooms.get(roomName);
    if (m.t === 's' && Array.isArray(m.p) && m.p.length === 8) {
      const q = m.p.map(Number); if (q.some(v => !Number.isFinite(v))) return;
      const lim = (v, a) => Math.max(-a, Math.min(a, v));
      me.s = [me.id, lim(q[0], 50000), lim(q[1], 50000), lim(q[2], 5000), lim(q[3], 1e4), lim(q[4], 4), lim(q[5], 120), q[6] ? 1 : 0, Math.max(0, Math.min(1e9, Math.floor(q[7])))];
    } else if (m.t === 'c' && typeof m.text === 'string') {
      const now = Date.now(); chatTokens = Math.min(3, chatTokens + (now - lastChatRefill) / 2000); lastChatRefill = now;
      if (chatTokens < 1) return ws.send(JSON.stringify({ t: 'sys', text: 'Slow down a little before sending another message.' }));
      chatTokens -= 1;
      let text = m.text.replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim().slice(0, 120);
      if (!text) return;
      if (LINK.test(text)) return ws.send(JSON.stringify({ t: 'sys', text: 'Links are not allowed in chat.' }));
      text = clean(text);
      const msg = { t: 'c', id: me.id, name: me.name, text };
      room.chat.push({ name: me.name, text }); if (room.chat.length > 30) room.chat.shift();
      broadcast(room, msg);
    }
  });
  const flood = setInterval(() => { msgs = 0; }, 1000);
  ws.on('close', () => {
    clearInterval(flood);
    perIp.set(ip, Math.max(0, (perIp.get(ip) || 1) - 1)); if (!perIp.get(ip)) perIp.delete(ip);
    if (!me) return;
    const room = rooms.get(roomName); if (!room) return;
    room.players.delete(me.id); broadcast(room, { t: 'l', id: me.id });
    if (!room.players.size) rooms.delete(roomName);
  });
});

// positions: 10 times a second, one message per room
setInterval(() => {
  for (const room of rooms.values()) {
    const all = [...room.players.values()].filter(p => p.s).map(p => p.s);
    if (!all.length) continue;
    for (const p of room.players.values()) if (p.ws.readyState === 1) p.ws.send(JSON.stringify({ t: 'S', p: all.filter(s => s[0] !== p.id) }));
  }
}, 100);
// drop dead connections
setInterval(() => { for (const ws of wss.clients) { if (!ws.isAlive) { ws.terminate(); continue; } ws.isAlive = false; ws.ping(); } }, 20000);

server.listen(PORT, () => console.log(`Kaido Drift server on http://localhost:${PORT}  (WebSocket at /ws)`));
