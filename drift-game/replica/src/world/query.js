// Port of the Roblox client's World.luau: the ground under the car (a ray down onto roads, the city, ramps,
// the expressway and terrain) and walls (the car's box swept against buildings, barriers and pillars, then a
// separating-axis push-out). Roblox's raycasts and Blockcast are replaced by the same tests on the part boxes.
import * as THREE from 'three';
import { Vector3 } from '../rbx/types.js';
import { parts } from './parts.js';
import { terrainTop } from './terrain.js';

const CELL = 64;
// spatial hash of part boxes (XZ), one for ground and one for walls
function makeIndex(filter) {
  const grid = new Map(), list = [];
  for (const p of parts) {
    if (!filter(p) || !p.canQuery) continue;
    const e = p.m.elements, hx = p.size.X / 2, hy = p.size.Y / 2, hz = p.size.Z / 2;
    // world AABB of the oriented box
    const ex = Math.abs(e[0]) * hx + Math.abs(e[4]) * hy + Math.abs(e[8]) * hz;
    const ey = Math.abs(e[1]) * hx + Math.abs(e[5]) * hy + Math.abs(e[9]) * hz;
    const ez = Math.abs(e[2]) * hx + Math.abs(e[6]) * hy + Math.abs(e[10]) * hz;
    const q = { p, inv: p.m.clone().invert(), x0: e[12] - ex, x1: e[12] + ex, y0: e[13] - ey, y1: e[13] + ey, z0: e[14] - ez, z1: e[14] + ez, stamp: 0 };
    list.push(q);
    for (let i = Math.floor(q.x0 / CELL); i <= Math.floor(q.x1 / CELL); i++) for (let j = Math.floor(q.z0 / CELL); j <= Math.floor(q.z1 / CELL); j++) {
      const k = i * 100003 + j; let c = grid.get(k); if (!c) grid.set(k, c = []); c.push(q);
    }
  }
  let stamp = 0;
  return {
    query(x0, z0, x1, z1, out) {
      stamp++; out.length = 0;
      for (let i = Math.floor(x0 / CELL); i <= Math.floor(x1 / CELL); i++) for (let j = Math.floor(z0 / CELL); j <= Math.floor(z1 / CELL); j++) {
        const c = grid.get(i * 100003 + j); if (!c) continue;
        for (const q of c) if (q.stamp !== stamp && q.x1 >= x0 && q.x0 <= x1 && q.z1 >= z0 && q.z0 <= z1) { q.stamp = stamp; out.push(q); }
      }
      return out;
    },
    size: list.length,
  };
}
let GROUND = null, WALLS = null;
export function buildIndex() {
  GROUND = makeIndex(p => p.folder === 'Road' || p.folder === 'City/Ground');
  WALLS = makeIndex(p => p.folder === 'City/Solid');
}

// ray straight down through one part (local space slab test); returns [entry y, normal] or null.
// Like Roblox, a ray that starts inside a part doesn't hit it.
const _o = new THREE.Vector3(), _d = new THREE.Vector3();
function rayDown(q, x, top, z, len) {
  const ie = q.inv.elements;
  _o.set(x, top, z).applyMatrix4(q.inv);
  _d.set(ie[4], ie[5], ie[6]).multiplyScalar(-1); // local direction of world -Y
  const s = q.p.size, h = [s.X / 2, s.Y / 2, s.Z / 2], o = [_o.x, _o.y, _o.z], d = [_d.x, _d.y, _d.z];
  let t0 = -Infinity, t1 = Infinity, axis = -1, sign = 0;
  for (let a = 0; a < 3; a++) {
    if (Math.abs(d[a]) < 1e-9) { if (Math.abs(o[a]) > h[a]) return null; continue; }
    let ta = (-h[a] - o[a]) / d[a], tb = (h[a] - o[a]) / d[a], sg = -1;
    if (ta > tb) { const t = ta; ta = tb; tb = t; sg = 1; }
    if (ta > t0) { t0 = ta; axis = a; sign = sg; }
    t1 = Math.min(t1, tb);
    if (t0 > t1) return null;
  }
  if (q.p.shape === 'Wedge') {
    // slope face: local plane through (y=-h, z=-h)…(y=+h, z=+h); solid below it (y/h <= z/h)
    const ny = 1 / s.Y, nz = -1 / s.Z; // plane y/sY - z/sZ = 0 → inside when ny*y + nz*z <= 0
    const dn = ny * d[1] + nz * d[2], on = ny * o[1] + nz * o[2];
    if (Math.abs(dn) > 1e-9) {
      const tp = -on / dn;
      if (dn < 0) { if (tp > t0) { t0 = tp; axis = 3; } } else t1 = Math.min(t1, tp);
    } else if (on > 0) return null;
    if (t0 > t1) return null;
  }
  if (t0 < 0 || t0 > len) return null;
  const n = new THREE.Vector3();
  if (axis === 3) n.set(0, 1 / s.Y, -1 / s.Z).normalize();
  else if (axis >= 0) n.setComponent(axis, sign);
  n.transformDirection(q.p.m);
  return [top - t0, n];
}

const cand = [];
// highest surface hit by a ray from top going down `len` studs: [y, normal] or null
function cast(x, top, z, len) {
  let best = null;
  GROUND.query(x - 0.01, z - 0.01, x + 0.01, z + 0.01, cand);
  for (const q of cand) {
    if (q.y1 < top - len || q.y0 > top) continue;
    const r = rayDown(q, x, top, z, len);
    if (r && (!best || r[0] > best[0])) best = r;
  }
  const t = terrainTop(x, z);
  if (t === t && t <= top && t >= top - len && (!best || t > best[0])) best = [t, new THREE.Vector3(0, 1, 0)];
  return best;
}

export const World = {
  // ground below (x, z) starting a little above y; returns [height, normal Vector3] or [null, null]
  ground(x, y, z) {
    let top = y + 7;
    for (let k = 0; k < 4; k++) {
      const hit = cast(x, top, z, (top - y) + 73);
      if (!hit) return [null, null];
      if (hit[0] <= y + 3.2) return [hit[0], new Vector3(hit[1].x, hit[1].y, hit[1].z)];
      top = hit[0] - 0.6;
      if (top <= y - 70) return [null, null];
    }
    return [null, null];
  },
  // sweep the car's box (size in studs) from a to b; returns { Distance, Normal, Position } or null
  sweep(a, b, heading, size) {
    const d = b.sub(a), len = d.Magnitude;
    if (len < 1e-3) return null;
    // like Roblox's Blockcast, walls the box already touches at the start don't count (pushOut handles those),
    // so a car resting against a wall can always drive or reverse away from it
    const skip = new Set(); overlap(a, heading, size, false, null, skip);
    const step = Math.max(0.4, Math.min(size.X, size.Z) * 0.25), n = Math.ceil(len / step);
    for (let k = 1; k <= n; k++) {
      const t = Math.min(len, k * step), p = a.add(d.mul(t / len));
      const hit = overlap(p, heading, size, true, skip);
      if (hit) {
        // back off to the last clear spot
        let lo = (k - 1) * step, hi = t;
        for (let it = 0; it < 6; it++) { const mid = (lo + hi) / 2; if (overlap(a.add(d.mul(mid / len)), heading, size, true, skip)) hi = mid; else lo = mid; }
        const at = a.add(d.mul(lo / len));
        const nrm = hit.normal;
        const ext = Math.abs(Math.sin(heading) * nrm.X + Math.cos(heading) * nrm.Z) * size.Z / 2 + Math.abs(Math.cos(heading) * nrm.X - Math.sin(heading) * nrm.Z) * size.X / 2;
        return { Distance: lo, Normal: nrm, Position: at.sub(nrm.mul(ext)) };
      }
    }
    return null;
  },
  // if the car's box overlaps any wall: the smallest push in the ground plane that clears it, and the normal
  pushOut(p, heading, size) {
    const r = overlap(p, heading, size, false);
    return r ? [r.total, r.normal] : [null, null];
  },
};

// separating-axis test of the car's box against wall boxes seen from above (World.pushOut in Roblox)
const wc = [];
function overlap(p, heading, size, first, skip, touched) {
  const fx = Math.sin(heading), fz = Math.cos(heading), hl = size.Z / 2, hw = size.X / 2, hy = size.Y / 2;
  const ex = Math.abs(fx) * hl + Math.abs(fz) * hw, ez = Math.abs(fz) * hl + Math.abs(fx) * hw;
  WALLS.query(p.X - ex, p.Z - ez, p.X + ex, p.Z + ez, wc);
  let tx = 0, tz = 0, normal = null;
  for (const q of [...wc]) {
    if (q.y1 < p.Y - hy || q.y0 > p.Y + hy) continue;
    if (skip && skip.has(q)) continue;
    const e = q.p.m.elements;
    let rx = e[0], rz = e[2], lx = -e[8], lz = -e[10]; // RightVector, LookVector (-Z)
    const rl = Math.hypot(rx, rz), ll = Math.hypot(lx, lz);
    if (rl < 0.2 || ll < 0.2) continue; // lying on its side: not a wall seen from above
    rx /= rl; rz /= rl; lx /= ll; lz /= ll;
    const bx = q.p.size.X / 2, bz = q.p.size.Z / 2;
    const dx = p.X + tx - e[12], dz = p.Z + tz - e[14];
    let best = Infinity, nx0 = 0, nz0 = 0;
    for (const [nx, nz] of [[fx, fz], [fz, -fx], [rx, rz], [lx, lz]]) {
      const rA = hl * Math.abs(fx * nx + fz * nz) + hw * Math.abs(fz * nx - fx * nz);
      const rB = bx * Math.abs(rx * nx + rz * nz) + bz * Math.abs(lx * nx + lz * nz);
      const dd = dx * nx + dz * nz, o = rA + rB - Math.abs(dd);
      if (o <= 0) { best = null; break; }
      if (o < best) { const sg = dd >= 0 ? 1 : -1; best = o; nx0 = nx * sg; nz0 = nz * sg; }
    }
    if (best !== null) {
      if (touched) touched.add(q);
      normal = new Vector3(nx0, 0, nz0);
      if (first) return { normal };
      tx += nx0 * (best + 0.03); tz += nz0 * (best + 0.03);
    }
  }
  return normal ? { total: new Vector3(tx, 0, tz), normal } : null;
}
