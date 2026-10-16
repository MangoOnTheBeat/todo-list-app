// Roblox terrain for the replica. The map builder calls Terrain.FillBlock(cframe, size, material) exactly like
// the Roblox server does; each call is applied to a column grid (6-stud cells, lined up with the course's
// 120-stud hill columns): ground top height, top material and water. Drawn as merged flat tops, cliff faces
// where heights change, and water surfaces. Raycasts straight down hit ground or water (Roblox's default).
import * as THREE from 'three';
import { material as partMaterial } from './parts.js';

const C = 6, OX = 1, OZ = 0, CH = 64; // cell size, grid origin (cell edges), chunk size in cells
const MAT = { Grass: 1, LeafyGrass: 2, Ground: 3, Sand: 4, Concrete: 5, Rock: 6, Asphalt: 7, Slate: 8, Snow: 9 };
const MAT_NAME = Object.fromEntries(Object.entries(MAT).map(([k, v]) => [v, k]));
// Roblox's default terrain colours
const MAT_COL = { 1: [106, 127, 63], 2: [115, 132, 74], 3: [102, 92, 59], 4: [143, 126, 96], 5: [127, 102, 63], 6: [102, 108, 111], 7: [115, 123, 107], 8: [63, 127, 107], 9: [195, 199, 218] };
const chunks = new Map(); // "ci,cj" -> { H: Float32Array, M: Uint8Array, W: Float32Array|null }
const ck = (ci, cj) => ci * 65536 + cj;
function chunk(ci, cj, create) {
  let c = chunks.get(ck(ci, cj));
  if (!c && create) { c = { ci, cj, H: new Float32Array(CH * CH).fill(NaN), M: new Uint8Array(CH * CH), W: null }; chunks.set(ck(ci, cj), c); }
  return c;
}
function cellAt(ix, iz, create) {
  const ci = Math.floor(ix / CH), cj = Math.floor(iz / CH), c = chunk(ci, cj, create);
  return c ? [c, (iz - cj * CH) * CH + (ix - ci * CH)] : [null, 0];
}
export const LAKE = { level: null };

export const Terrain = {
  // cf: CFrame, size: Vector3 (studs), material: Enum.Material item or name
  FillBlock(cf, size, mat) {
    const name = mat.Name || mat, M4 = cf.m, inv = new THREE.Matrix4().copy(M4).invert(), e = M4.elements;
    // XZ bounds of the box
    let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
    for (const sx of [-0.5, 0.5]) for (const sy of [-0.5, 0.5]) for (const sz of [-0.5, 0.5]) {
      const v = new THREE.Vector3(sx * size.X, sy * size.Y, sz * size.Z).applyMatrix4(M4);
      x0 = Math.min(x0, v.x); x1 = Math.max(x1, v.x); z0 = Math.min(z0, v.z); z1 = Math.max(z1, v.z);
    }
    const ie = inv.elements, hx = size.X / 2, hy = size.Y / 2, hz = size.Z / 2;
    // a vertical line at (x, z) in box space: p = a + t * d (d = inverse rotation of +Y)
    const dx = ie[4], dy = ie[5], dz = ie[6];
    for (let iz = Math.ceil((z0 - OZ) / C - 0.5); iz <= Math.floor((z1 - OZ) / C - 0.5); iz++) for (let ix = Math.ceil((x0 - OX) / C - 0.5); ix <= Math.floor((x1 - OX) / C - 0.5); ix++) {
      const x = OX + (ix + 0.5) * C, z = OZ + (iz + 0.5) * C;
      const ax = ie[0] * x + ie[8] * z + ie[12], ay = ie[1] * x + ie[9] * z + ie[13], az = ie[2] * x + ie[10] * z + ie[14];
      let t0 = -Infinity, t1 = Infinity, ok = true;
      for (const [a, d, h] of [[ax, dx, hx], [ay, dy, hy], [az, dz, hz]]) {
        if (Math.abs(d) < 1e-9) { if (Math.abs(a) > h) { ok = false; break; } continue; }
        let ta = (-h - a) / d, tb = (h - a) / d; if (ta > tb) [ta, tb] = [tb, ta];
        t0 = Math.max(t0, ta); t1 = Math.min(t1, tb); if (t0 > t1) { ok = false; break; }
      }
      if (!ok) continue;
      apply(ix, iz, t0, t1, name);
    }
  },
  ReadVoxels() { },
};
function apply(ix, iz, y0, y1, name) {
  const create = name !== 'Air';
  const [c, i] = cellAt(ix, iz, create); if (!c) return;
  const H = c.H[i], W = c.W ? c.W[i] : NaN;
  if (name === 'Air') {
    if (H === H && y0 < H && y1 >= H - 0.01) c.H[i] = y0;
    if (W === W && y0 < W) c.W[i] = y0 > c.H[i] ? y0 : NaN;
    return;
  }
  if (name === 'Water') {
    c.H[i] = H === H ? Math.min(H, y0) : y0; if (!c.M[i]) c.M[i] = MAT.Sand;
    if (!c.W) c.W = new Float32Array(CH * CH).fill(NaN);
    c.W[i] = y1; LAKE.level = y1;
    return;
  }
  const m = MAT[name] || MAT.Ground;
  if (H !== H) { c.H[i] = y1; c.M[i] = m; }
  else if (y0 <= H + 0.5 && y1 > H) { c.H[i] = y1; c.M[i] = m; }
  else if (Math.abs(y1 - H) < 0.05) c.M[i] = m;
  if (c.W && c.W[i] === c.W[i] && y1 > c.W[i]) c.W[i] = NaN;
}
// ground height under (x, z): terrain top or water surface, whichever is higher; NaN if there's no terrain
export function terrainTop(x, z) {
  const ix = Math.floor((x - OX) / C), iz = Math.floor((z - OZ) / C);
  const [c, i] = cellAt(ix, iz, false); if (!c) return NaN;
  const H = c.H[i], W = c.W ? c.W[i] : NaN;
  return W === W && !(W < H) ? W : H;
}

// ---- drawing ----
const lin = (c, k) => { const t = new THREE.Color().setRGB(c[0] / 255 * k, c[1] / 255 * k, c[2] / 255 * k, THREE.SRGBColorSpace); return [t.r, t.g, t.b]; };
export function buildTerrainMeshes(scene) {
  const out = [];
  const height = (ix, iz) => { const [c, i] = cellAt(ix, iz, false); return c ? c.H[i] : NaN; };
  const matAt = (ix, iz) => { const [c, i] = cellAt(ix, iz, false); return c ? c.M[i] : 0; };
  const col = new THREE.Color();
  const water = new THREE.MeshStandardMaterial({ color: new THREE.Color().setRGB(12 / 255, 84 / 255, 92 / 255, THREE.SRGBColorSpace), roughness: 0.06, metalness: 0.15, transparent: true, opacity: 0.82, envMapIntensity: 1.6 });
  // chunks are merged into tiles of 6×6 chunks (~2,300 studs) so the whole map is a few dozen draws
  const tiles = new Map();
  for (const c of chunks.values()) {
    const tk = Math.floor(c.ci / 6) * 4096 + Math.floor(c.cj / 6);
    let t = tiles.get(tk); if (!t) tiles.set(tk, t = { pos: [], cols: [], nrm: [], wpos: [] });
    const { pos, cols, nrm, wpos } = t;
    const bx = c.ci * CH, bz = c.cj * CH;
    const used = new Uint8Array(CH * CH);
    const quad = (ax, ay, az, bx2, by, bz2, cx, cy, cz, dx, dy, dz, n, rgb) => {
      pos.push(ax, ay, az, bx2, by, bz2, cx, cy, cz, ax, ay, az, cx, cy, cz, dx, dy, dz);
      for (let k = 0; k < 6; k++) { cols.push(rgb[0], rgb[1], rgb[2]); nrm.push(n[0], n[1], n[2]); }
    };
    // tops: greedy rectangles of equal height and material
    for (let j = 0; j < CH; j++) for (let i = 0; i < CH; i++) {
      const k = j * CH + i, h = c.H[k]; if (h !== h || used[k]) continue;
      const m = c.M[k]; let w = 1, d = 1;
      while (i + w < CH && !used[k + w] && c.H[k + w] === h && c.M[k + w] === m) w++;
      outer: while (j + d < CH) { for (let q = 0; q < w; q++) { const kk = (j + d) * CH + i + q; if (used[kk] || c.H[kk] !== h || c.M[kk] !== m) break outer; } d++; }
      for (let dd = 0; dd < d; dd++) for (let q = 0; q < w; q++) used[(j + dd) * CH + i + q] = 1;
      const X0 = OX + (bx + i) * C, Z0 = OZ + (bz + j) * C, X1 = X0 + w * C, Z1 = Z0 + d * C;
      const base = MAT_COL[m] || MAT_COL[3], rgb = lin(base, 1);
      quad(X0, h, Z0, X0, h, Z1, X1, h, Z1, X1, h, Z0, [0, 1, 0], rgb);
    }
    // cliff faces toward lower (or missing) neighbours, on the +X / -X / +Z / -Z sides
    for (let j = 0; j < CH; j++) for (let i = 0; i < CH; i++) {
      const k = j * CH + i, h = c.H[k]; if (h !== h) continue;
      const gx = bx + i, gz = bz + j, m = c.M[k], base = MAT_COL[m] || MAT_COL[3], rgb = lin(base, 0.74);
      const X0 = OX + gx * C, Z0 = OZ + gz * C, X1 = X0 + C, Z1 = Z0 + C;
      for (const [nx, nz, n] of [[1, 0, [1, 0, 0]], [-1, 0, [-1, 0, 0]], [0, 1, [0, 0, 1]], [0, -1, [0, 0, -1]]]) {
        let nh = height(gx + nx, gz + nz); if (nh !== nh) nh = h - 12;
        if (nh >= h - 0.01) continue;
        if (nx === 1) quad(X1, h, Z1, X1, nh, Z1, X1, nh, Z0, X1, h, Z0, n, rgb);
        else if (nx === -1) quad(X0, h, Z0, X0, nh, Z0, X0, nh, Z1, X0, h, Z1, n, rgb);
        else if (nz === 1) quad(X0, h, Z1, X0, nh, Z1, X1, nh, Z1, X1, h, Z1, n, rgb);
        else quad(X1, h, Z0, X1, nh, Z0, X0, nh, Z0, X0, h, Z0, n, rgb);
      }
    }
    // water: merged rows
    if (c.W) for (let j = 0; j < CH; j++) for (let i = 0; i < CH; i++) {
      const k = j * CH + i, w = c.W[k]; if (w !== w) continue;
      let e = i; while (e + 1 < CH && c.W[j * CH + e + 1] === w) e++;
      const X0 = OX + (bx + i) * C, Z0 = OZ + (bz + j) * C, X1 = OX + (bx + e + 1) * C, Z1 = Z0 + C;
      wpos.push(X0, w, Z0, X0, w, Z1, X1, w, Z1, X0, w, Z0, X1, w, Z1, X1, w, Z0);
      i = e;
    }
  }
  for (const { pos, cols, nrm, wpos } of tiles.values()) {
    if (pos.length) {
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nrm, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
      g.computeBoundingSphere();
      const mesh = new THREE.Mesh(g, terrainMaterial()); mesh.receiveShadow = true; scene.add(mesh); out.push(mesh);
    }
    if (wpos.length) {
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(wpos, 3)); g.computeVertexNormals(); g.computeBoundingSphere();
      const mesh = new THREE.Mesh(g, water); mesh.renderOrder = 1; scene.add(mesh); out.push(mesh);
    }
  }
  return out;
}
let tmat = null;
function terrainMaterial() {
  if (tmat) return tmat;
  // the part material's grass detail, with vertex colours carrying each material's colour
  const base = partMaterial('Grass');
  tmat = base.clone(); tmat.vertexColors = true; tmat.onBeforeCompile = base.onBeforeCompile; tmat.customProgramCacheKey = () => 'terrain';
  return tmat;
}
export const TERRAIN_GRID = { C, OX, OZ };
export { MAT_NAME };
