// Kaido Drift: the course. Port of the Roblox game's Track.luau: the browser game's Hakone road (studs) as a
// closed Catmull-Rom loop, resampled every SEG studs. Arrays are 1-based like the Luau original (index 0 unused),
// so every ported script can use Track.X[i] with the same i.
import Config from './config.js';
import GAME from '../data/game.json';

const Course = GAME.course;
const src = Course.POINTS;
const cp = [];
for (let i = 0; i < src.length; i += 4) cp.push([src[i], src[i + 1], src[i + 2], src[i + 3]]);
const n = cp.length;

const dense = [];
for (let i = 0; i < n; i++) {
  const p0 = cp[(i - 1 + n) % n], p1 = cp[i], p2 = cp[(i + 1) % n], p3 = cp[(i + 2) % n];
  for (let k = 0; k <= 19; k++) {
    const t = k / 20, t2 = t * t, t3 = t2 * t;
    const cr = c => { const a = p0[c], b = p1[c], cc = p2[c], d = p3[c]; return 0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3); };
    dense.push([cr(0), cr(1), cr(2), t < 0.5 ? p1[3] : p2[3]]);
  }
}
const px = [0], py = [0], pz = [0], zone = [0];
{
  const seg = Config.SEG, m = dense.length;
  let acc = 0;
  px.push(dense[0][0]); py.push(dense[0][1]); pz.push(dense[0][2]); zone.push(dense[0][3]);
  for (let i = 0; i < m; i++) {
    const a = dense[i], b = dense[(i + 1) % m], dx = b[0] - a[0], dz = b[2] - a[2], len = Math.sqrt(dx * dx + dz * dz);
    let pos = 0;
    while (acc + (len - pos) >= seg) {
      pos += seg - acc; acc = 0;
      const f = pos / len;
      px.push(a[0] + dx * f); py.push(a[1] + (b[1] - a[1]) * f); pz.push(a[2] + dz * f); zone.push(a[3]);
    }
    acc += len - pos;
  }
  const l = px.length - 1;
  if (Math.sqrt((px[l] - px[1]) ** 2 + (pz[l] - pz[1]) ** 2) < seg * 0.5) { px.pop(); py.pop(); pz.pop(); zone.pop(); }
}
const N = px.length - 1;
const tx = [0], tz = [0], rx = [0], rz = [0];
for (let i = 1; i <= N; i++) {
  const a = (i - 2 + N) % N + 1, b = i % N + 1, dx = px[b] - px[a], dz = pz[b] - pz[a], l = Math.sqrt(dx * dx + dz * dz);
  tx[i] = dx / l; tz[i] = dz / l; rx[i] = -tz[i]; rz[i] = tx[i];
}

const Track = { N, X: px, Y: py, Z: pz, ZONE: zone, TX: tx, TZ: tz, RX: rx, RZ: rz, LENGTH: N * Config.SEG, Course };
Track.ZONE_NAMES = { 0: '湖尻 · Kojiri village', 1: '箱根 · Hakone hills', 2: '芦ノ湖 · Lake Ashi shore' };

const CELL = 80, hash = new Map();
const key = (cx, cz) => cx * 100000 + cz;
for (let i = 1; i <= N; i++) { const k = key(Math.floor(px[i] / CELL), Math.floor(pz[i] / CELL)); let t = hash.get(k); if (!t) hash.set(k, t = []); t.push(i); }

Track.heading = i => Math.atan2(tx[i], tz[i]);
Track.slope = i => { const a = (i - 2 + N) % N + 1, b = i % N + 1; return (py[b] - py[a]) / (2 * Config.SEG); };
Track.nearest = function (x, z, hint) {
  let best = Infinity, bi = 1;
  if (hint) {
    for (let k = -30; k <= 30; k++) { const i = ((hint - 1 + k) % N + N) % N + 1, d = (px[i] - x) ** 2 + (pz[i] - z) ** 2; if (d < best) { best = d; bi = i; } }
    if (best < 30 * 30) return bi;
  }
  const cx = Math.floor(x / CELL), cz = Math.floor(z / CELL);
  for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) {
    const t = hash.get(key(cx + dx, cz + dz)); if (!t) continue;
    for (const i of t) { const d = (px[i] - x) ** 2 + (pz[i] - z) ** 2; if (d < best) { best = d; bi = i; } }
  }
  if (best === Infinity) for (let i = 1; i <= N; i++) { const d = (px[i] - x) ** 2 + (pz[i] - z) ** 2; if (d < best) { best = d; bi = i; } }
  return bi;
};
Track.near = function (x, z, r) {
  const out = [], cx = Math.floor(x / CELL), cz = Math.floor(z / CELL), span = Math.ceil(r / CELL);
  for (let dx = -span; dx <= span; dx++) for (let dz = -span; dz <= span; dz++) {
    const t = hash.get(key(cx + dx, cz + dz)); if (!t) continue;
    for (const i of t) if ((px[i] - x) ** 2 + (pz[i] - z) ** 2 < r * r) out.push(i);
  }
  return out;
};
Track.at = function (x, z, i) {
  const dx = x - px[i], dz = z - pz[i], along = dx * tx[i] + dz * tz[i];
  return [dx * rx[i] + dz * rz[i], py[i] + Track.slope(i) * along];
};

export default Track;
