// Port of the Roblox game's CarModel.luau: the car your Roblox game draws (the block car, built from Parts
// and WedgeParts in the browser game's body styles: notchback, hatch, fastback, sedan, roadster) with pop-up
// lamps, ducktails, wings and twin exhausts. Same sizes, offsets, colours and materials, part for part.
// The front of the car is local -Z; wheels spin and the fronts steer through their weld offsets.
import * as THREE from 'three';
import { CFrame, Vector3, Color3 } from '../rbx/types.js';
import { GEO, material as worldMaterial } from '../world/parts.js';

const V = (x, y, z) => new Vector3(x, y, z);
const DARK = Color3.fromRGB(16, 16, 20), GLASS = Color3.fromRGB(70, 88, 108), CHROME = Color3.fromRGB(200, 202, 208);
const STYLE = {
  notch: { roof: 0.27, rearGlass: 0.13, deck: 0.93, cowl: 0.30, ws: 0.16 },
  hatch: { roof: 0.29, rearGlass: 0.27, deck: 0.0, cowl: 0.30, ws: 0.15 },
  fast: { roof: 0.22, rearGlass: 0.30, deck: 0.0, cowl: 0.32, ws: 0.18 },
  sedan: { roof: 0.33, rearGlass: 0.11, deck: 0.95, cowl: 0.29, ws: 0.14 },
  roadster: { roof: 0, rearGlass: 0, deck: 0.9, cowl: 0.36, ws: 0.08 },
};
const lin = (c, t = new THREE.Color()) => t.setRGB(c.R, c.G, c.B, THREE.SRGBColorSpace);

// one Part: its own material (so paint and rim colour can change), placed by its weld C0
function partMaterial(mat, color, transparency) {
  const base = worldMaterial(mat === 'SmoothPlastic' ? 'SmoothPlastic' : mat);
  const m = base.clone();
  if (base.onBeforeCompile) { m.onBeforeCompile = base.onBeforeCompile; m.customProgramCacheKey = base.customProgramCacheKey; }
  if (mat === 'Neon') m.color.copy(lin(color)).multiplyScalar(1.25); else lin(color, m.color);
  if (transparency) { m.transparent = true; m.opacity = 1 - transparency; m.depthWrite = false; }
  return m;
}
const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _s = new THREE.Vector3();
function setC0(mesh, cf) { cf.m.decompose(_p, _q, _s); mesh.position.copy(_p); mesh.quaternion.copy(_q); }

export const CarModel = {};
CarModel.build = function (car, name, paint) {
  const group = new THREE.Group(); group.name = name;
  const model = { group, parts: [], wheels: [], def: car, cf: CFrame.new(0, 1e4, 0), glow: null, block: true };
  const weldPart = (shape, nm, size, offset, color, mat, opts) => {
    const mesh = new THREE.Mesh(GEO[shape], partMaterial(mat || 'SmoothPlastic', color, opts && opts.transparency));
    mesh.scale.set(size.X, size.Y, size.Z);
    setC0(mesh, offset);
    mesh.castShadow = !(opts && opts.transparency); mesh.receiveShadow = mat !== 'Neon';
    if (opts && opts.transparency) mesh.renderOrder = 2;
    mesh.name = nm;
    mesh.userData = { name: nm, material: mat || 'SmoothPlastic', Paint: !!(opts && opts.paint), Cabin: !!(opts && opts.cabin), C0: offset, BaseC0: offset };
    group.add(mesh); model.parts.push(mesh);
    return mesh;
  };
  const bd = car.b, st = STYLE[bd.style] || STYLE.notch;
  const L = bd.len * 3.5, W = bd.wid * 3.5, H = bd.h * 3.5, WB = bd.wb * 3.5;
  const body = paint || car.color, mat = 'SmoothPlastic';
  const P = (nm, size, off, col, mt, o) => weldPart(o && o.shape === 'Cylinder' ? 'Cylinder' : 'Block', nm, size, off, col, mt || mat, o);
  const Wd = (nm, size, off, col, mt, o) => weldPart('Wedge', nm, size, off, col, mt || mat, o);
  const paintO = { paint: true };

  const sill = 0.62, shoulder = H * 0.55, roofY = H;
  const front = -L / 2, rear = L / 2, zf = -WB / 2, zr = WB / 2, tire = 2.25;
  const archHalf = tire / 2 + 0.35, archTop = tire + 0.25;
  const slab = (nm, z0, z1, y0, y1) => { if (z1 - z0 > 0.05 && y1 - y0 > 0.05) P(nm, V(W, y1 - y0, z1 - z0), CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2), body, mat, paintO); };
  slab('BodyF', front + 0.6, zf - archHalf, sill, shoulder);
  slab('BodyM', zf + archHalf, zr - archHalf, sill, shoulder);
  slab('BodyR', zr + archHalf, rear - 0.6, sill, shoulder);
  for (const z of [zf, zr]) {
    slab('Arch', z - archHalf, z + archHalf, archTop, shoulder);
    P('Flare', V(W + 0.2, 0.32, archHalf * 2 + 0.2), CFrame.new(0, archTop + 0.12, z), body, mat, paintO);
    P('Well', V(W - 0.25, 0.1, archHalf * 2 - 0.1), CFrame.new(0, archTop - 0.05, z), DARK);
  }
  P('Skirt', V(W + 0.06, 0.3, (zr - archHalf) - (zf + archHalf)), CFrame.new(0, sill + 0.02, (zf + zr) / 2), DARK);
  const hoodTop = shoulder * 0.98;
  const noseLen = Math.max(L / 2 + zf - 0.4, 1.5);
  Wd('Nose', V(W - 0.1, 0.55, noseLen), CFrame.new(0, hoodTop - 0.27, front + 0.6 + noseLen / 2), body, mat, paintO);
  const noseEnd = front + 0.6 + noseLen, cowlZ0 = front + L * st.cowl;
  const hoodLen = Math.max(0.4, cowlZ0 - noseEnd + 0.15);
  P('Hood', V(W - 0.15, 0.22, hoodLen), CFrame.new(0, hoodTop + 0.1, noseEnd + hoodLen / 2 - 0.1), body, mat, paintO);
  P('FrontBumper', V(W, 1.05, 0.9), CFrame.new(0, sill + 0.55, front + 0.45), body, mat, paintO);
  P('Lip', V(W - 0.3, 0.18, 0.7), CFrame.new(0, sill - 0.05, front + 0.45), DARK);
  P('Intake', V(W * 0.5, 0.35, 0.1), CFrame.new(0, sill + 0.45, front - 0.02), DARK);
  P('PlateF', V(1.5, 0.4, 0.06), CFrame.new(0, sill + 0.75, front - 0.03), Color3.fromRGB(235, 235, 225));
  const lampCol = Color3.fromRGB(255, 244, 214);
  if (bd.popups) {
    for (const x of [-1, 1]) {
      P('Popup', V(1.35, 0.32, 1.0), CFrame.new(x * (W / 2 - 1.0), hoodTop + 0.3, front + 1.3), body, mat, paintO);
      P('Lamp', V(1.2, 0.08, 0.05), CFrame.new(x * (W / 2 - 1.0), hoodTop + 0.3, front + 0.78), lampCol, 'Neon');
    }
    for (const x of [-1, 1]) P('Indicator', V(1.0, 0.22, 0.06), CFrame.new(x * (W / 2 - 0.8), sill + 0.95, front - 0.02), Color3.fromRGB(255, 170, 60), 'Neon');
  } else {
    for (const x of [-1, 1]) P('Lamp', V(1.3, 0.38, 0.12), CFrame.new(x * (W / 2 - 0.95), shoulder - 0.25, front + 0.62), lampCol, 'Neon');
  }
  const cabW = W * 0.84, cowlZ = front + L * st.cowl, wsLen = L * st.ws;
  const glassO = { transparency: 0.35, cabin: true };
  if (bd.style === 'roadster') {
    Wd('Windscreen', V(cabW, 1.1, wsLen), CFrame.new(0, shoulder + 0.55, cowlZ + wsLen / 2), GLASS, 'Glass', glassO);
    P('Seats', V(cabW - 0.4, 0.9, 2.6), CFrame.new(0, shoulder + 0.2, cowlZ + wsLen + 1.6), DARK, 'Fabric');
    P('Hoop', V(cabW - 0.6, 0.25, 0.25), CFrame.new(0, shoulder + 1.1, cowlZ + wsLen + 3.0), CHROME, 'Metal');
    P('Deck', V(W - 0.15, 0.3, rear - (cowlZ + wsLen + 3.2)), CFrame.new(0, shoulder * st.deck + 0.05, (rear + cowlZ + wsLen + 3.2) / 2), body, mat, paintO);
  } else {
    const roofLen = L * st.roof, rgLen = L * st.rearGlass, roofZ0 = cowlZ + wsLen, roofZ1 = roofZ0 + roofLen;
    Wd('Windscreen', V(cabW, roofY - hoodTop, wsLen), CFrame.new(0, (roofY + hoodTop) / 2, cowlZ + wsLen / 2), GLASS, 'Glass', glassO);
    P('Cabin', V(cabW + 0.02, roofY - hoodTop - 0.2, roofLen), CFrame.new(0, (roofY + hoodTop) / 2 - 0.1, (roofZ0 + roofZ1) / 2), GLASS, 'Glass', glassO);
    P('Pillar', V(cabW + 0.06, roofY - hoodTop - 0.2, 0.35), CFrame.new(0, (roofY + hoodTop) / 2 - 0.1, roofZ0 + roofLen * (bd.style === 'sedan' ? 0.48 : 0.62)), body, mat, { paint: true, cabin: true });
    P('Roof', V(cabW - 0.1, 0.24, roofLen + 0.3), CFrame.new(0, roofY, (roofZ0 + roofZ1) / 2), body, mat, { paint: true, cabin: true });
    const deckY = st.deck > 0 ? shoulder * st.deck : shoulder * 0.9;
    Wd('RearGlass', V(cabW, roofY - deckY, rgLen), CFrame.new(0, (roofY + deckY) / 2, roofZ1 + rgLen / 2).mul(CFrame.Angles(0, Math.PI, 0)), GLASS, 'Glass', glassO);
    if (st.deck > 0) P('Deck', V(W - 0.15, 0.26, rear - (roofZ1 + rgLen) - 0.2), CFrame.new(0, deckY, (rear - 0.2 + roofZ1 + rgLen) / 2), body, mat, paintO);
    for (const x of [-1, 1]) P('Mirror', V(0.5, 0.35, 0.3), CFrame.new(x * (cabW / 2 + 0.3), hoodTop + 0.35, cowlZ + wsLen * 0.6), body, mat, paintO);
  }
  P('RearBumper', V(W, 1.05, 0.9), CFrame.new(0, sill + 0.55, rear - 0.45), body, mat, paintO);
  P('Diffuser', V(W - 0.6, 0.2, 0.6), CFrame.new(0, sill - 0.05, rear - 0.45), DARK);
  P('Tail', V(W - 0.3, 0.42, 0.08), CFrame.new(0, shoulder - 0.35, rear - 0.17), Color3.fromRGB(60, 10, 14));
  for (const x of [-1, 1]) P('TailLamp', V(1.5, 0.36, 0.06), CFrame.new(x * (W / 2 - 1.0), shoulder - 0.35, rear - 0.12), Color3.fromRGB(255, 30, 40), 'Neon');
  P('PlateR', V(1.5, 0.4, 0.06), CFrame.new(0, sill + 0.8, rear + 0.03), Color3.fromRGB(235, 235, 225));
  if (bd.duck) Wd('Duck', V(W - 0.4, 0.4, 0.7), CFrame.new(0, shoulder * (st.deck > 0 ? st.deck : 0.9) + 0.32, rear - 0.55), body, mat, paintO);
  if (bd.wing) {
    const wy = shoulder * 0.95 + 1.1;
    P('Wing', V(W - 0.4, 0.14, 1.0), CFrame.new(0, wy, rear - 0.75).mul(CFrame.Angles(-6 * Math.PI / 180, 0, 0)), body, mat, paintO);
    for (const x of [-1, 1]) {
      P('WingStand', V(0.14, 1.0, 0.5), CFrame.new(x * (W / 2 - 1.3), wy - 0.55, rear - 0.75), DARK);
      P('WingPlate', V(0.08, 0.6, 1.1), CFrame.new(x * (W / 2 - 0.2), wy, rear - 0.75), DARK);
    }
  }
  for (let k = 1; k <= bd.exhaust; k++) {
    const x = bd.exhaust === 1 ? (W / 2 - 1.2) : (k === 1 ? -(W / 2 - 1.2) : (W / 2 - 1.2));
    P('Exhaust', V(0.7, 0.42, 0.42), CFrame.new(x, sill + 0.15, rear + 0.05).mul(CFrame.Angles(0, Math.PI / 2, 0)), CHROME, 'Metal', { shape: 'Cylinder' });
  }
  // wheels: tyre, rim, hub, caliper; they spin and the fronts steer (see place)
  for (const w of [['FL', -1, zf], ['FR', 1, zf], ['RL', -1, zr], ['RR', 1, zr]]) {
    const x = w[1] * (W / 2 - 0.42), base = CFrame.new(x, tire / 2, w[2]);
    const t = P('Tyre' + w[0], V(0.95, tire, tire), base, Color3.fromRGB(22, 22, 24), 'SmoothPlastic', { shape: 'Cylinder' });
    const r = P('Rim' + w[0], V(0.97, tire * 0.66, tire * 0.66), base, car.rim, 'Metal', { shape: 'Cylinder' });
    const spoke = P('Spoke' + w[0], V(0.99, tire * 0.6, 0.18), base, car.rim, 'Metal');
    const spoke2 = P('Spoke2' + w[0], V(0.99, 0.18, tire * 0.6), base, car.rim, 'Metal');
    const hub = P('Hub' + w[0], V(1.0, 0.45, 0.45), base, DARK, 'Metal', { shape: 'Cylinder' });
    P('Caliper' + w[0], V(0.3, 0.55, 0.7), CFrame.new(x - w[1] * 0.15, tire / 2 + 0.45, w[2] - 0.25), Color3.fromRGB(200, 30, 30), 'SmoothPlastic');
    model.wheels.push({ parts: [t, r, spoke, spoke2, hub], base, front: w[2] < 0 });
  }
  // rear smoke points (Attachments SmokeL / SmokeR on the root)
  model.smoke = [V(-(W / 2 - 0.4), 0.5, zr + 0.4), V(W / 2 - 0.4, 0.5, zr + 0.4)];
  return model;
};

// place the car at ground point cf; steer = front wheel angle (rad, + = right); roll = wheel turn (rad)
CarModel.place = function (m, cf, steer, roll) {
  m.cf = cf;
  cf.m.decompose(_p, _q, _s);
  m.group.position.copy(_p); m.group.quaternion.copy(_q);
  const spin = CFrame.Angles(-(roll || 0), 0, 0), turn = CFrame.Angles(0, -steer, 0);
  for (const w of m.wheels) {
    const c0 = w.front ? w.base.mul(turn).mul(spin) : w.base.mul(spin);
    for (const p of w.parts) setC0(p, c0);
  }
};
CarModel.destroy = function (m) { if (m && m.group.parent) m.group.parent.remove(m.group); for (const p of m.parts) p.material.dispose(); if (m.glow) m.glow.mesh.material.dispose(); };
// repaint the body panels
CarModel.paint = function (m, color) { for (const p of m.parts) if (p.userData.Paint) lin(color, p.material.color); };
// hide the cabin for the first-person view (LocalTransparencyModifier)
CarModel.setCabinVisible = function (m, visible) { for (const p of m.parts) if (p.userData.Cabin) p.visible = visible; };

// Main.client's applyStyle: underglow, rim colour on the metal wheel parts, stance kit (body welds 0.35 lower)
const WHEEL = /^(Rim|Spoke|Tire|Tyre|Hub|Caliper)/;
export function applyStyle(m, def, cs, Config) {
  underglow(m, cs && cs.glowOwned && cs.glow > 0 ? Config.GlowColors[cs.glow - 1] : null, V(def.b.wid * 3.5, 1, def.b.len * 3.5));
  const rim = cs && cs.rimsOwned && cs.rims > 0 ? Config.RimColors[cs.rims - 1] : def.rim;
  const drop = cs && cs.kit ? 0.35 : 0;
  for (const p of m.parts) {
    const n = p.userData.name, wheel = WHEEL.test(n);
    if (wheel && p.userData.material === 'Metal' && !/^(Hub|Caliper)/.test(n)) lin(rim, p.material.color);
    if (!wheel) setC0(p, CFrame.new(0, -drop, 0).mul(p.userData.BaseC0));
  }
}
// Fx.underglow: a neon strip under the car (Transparency 0.25) whose lights wash the road in its colour
function underglow(m, color, size) {
  if (m.glow) { m.group.remove(m.glow.mesh); m.glow.mesh.material.dispose(); m.glow = null; }
  if (!color) return;
  const mat = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.75, toneMapped: false });
  lin(color, mat.color).multiplyScalar(1.25);
  const mesh = new THREE.Mesh(GEO.Block, mat);
  mesh.scale.set(size.X * 0.8, 0.12, size.Z * 0.75); mesh.position.y = 0.35;
  const pool = new THREE.Mesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: glowTex(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
  lin(color, pool.material.color).multiplyScalar(0.9);
  pool.scale.set(2.6 / 0.8, 1, 1.5 / 0.75); pool.position.y = -0.28 / 0.12; pool.renderOrder = 4;
  mesh.add(pool);
  m.group.add(mesh);
  m.glow = { mesh, color };
}
let _gt = null;
function glowTex() {
  if (_gt) return _gt;
  const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  return (_gt = new THREE.CanvasTexture(c));
}
