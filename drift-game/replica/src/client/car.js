// Port of the Roblox game's CarMesh.luau (the browser car models, packed as triangles per material) plus the
// CarModel helpers the client uses (paint, cabin visibility) and Main.client's applyStyle (rim colour, stance
// kit, underglow). Front of the car is local -Z; wheels spin and the fronts steer through their offsets.
import * as THREE from 'three';
import MESHES from '../data/carmeshes.json';
import { CFrame, Vector3, Color3 } from '../rbx/types.js';

const K = 3.5;
const lin = (c, t = new THREE.Color()) => t.setRGB(c.R, c.G, c.B, THREE.SRGBColorSpace);
const geoCache = new Map();
function decode(data) {
  let g = geoCache.get(data); if (g) return g;
  const bin = atob(data), buf = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
  const dv = new DataView(buf.buffer), nv = dv.getUint16(0, true), ni = dv.getUint16(2, true);
  const pos = new Float32Array(nv * 3), nrm = new Float32Array(nv * 3), idx = new Uint16Array(ni);
  const po = 4, no = 4 + nv * 6, io = 4 + nv * 9;
  for (let k = 0; k < nv * 3; k++) { pos[k] = dv.getInt16(po + k * 2, true) / 2000; nrm[k] = dv.getInt8(no + k) / 127; }
  for (let k = 0; k < ni; k++) idx[k] = dv.getUint16(io + k * 2, true);
  g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.BufferAttribute(nrm, 3)); g.setIndex(new THREE.BufferAttribute(idx, 1));
  g.computeBoundingSphere();
  geoCache.set(data, g);
  return g;
}

// CarMesh's style(): paint (Reflectance 0.08), glass, lamps (Neon), metal (Reflectance 0.3), plastic
function material(kind, color, glow, opacity) {
  const c = Color3.fromHex(kind === 'lamp' && glow ? glow : color);
  if (kind === 'lamp') { const m = new THREE.MeshBasicMaterial({ toneMapped: false }); lin(c, m.color).multiplyScalar(1.25); return m; }
  const m = new THREE.MeshStandardMaterial({ color: lin(c), roughness: 0.62, metalness: 0 });
  if (kind === 'paint') { m.roughness = 0.28; m.metalness = 0.05; m.envMapIntensity = 0.9; }
  if (kind === 'metal') { m.roughness = 0.3; m.metalness = 0.8; m.envMapIntensity = 1; }
  if (kind === 'glass') { m.transparent = true; m.opacity = 1 - Math.min(0.85, Math.max(0.15, 1 - (opacity ?? 0.7))); m.roughness = 0.05; m.metalness = 0.4; m.envMapIntensity = 1.4; m.depthWrite = false; }
  return m;
}

export const CarMesh = { lastError: null };
// build the browser model of car `def` (special cars reuse a browser body), painted `paint`
CarMesh.build = function (def, name, paint) {
  const src = MESHES[def.mesh || def.id];
  if (!src) { CarMesh.lastError = 'no mesh for ' + def.id; return null; }
  const group = new THREE.Group(); group.name = name;
  const body = new THREE.Group(); group.add(body); // lowered by the stance kit
  const m = { group, body, parts: [], wheels: [], def, cf: CFrame.new(0, 1e4, 0), glow: null };
  for (const g of src.body) {
    const mesh = new THREE.Mesh(decode(g.data), material(g.kind, g.color, g.glow, g.opacity));
    mesh.position.set(g.center[0], g.center[1], g.center[2]);
    mesh.castShadow = g.kind !== 'glass'; mesh.receiveShadow = g.kind !== 'lamp';
    if (g.kind === 'glass') mesh.renderOrder = 2;
    mesh.userData = { kind: g.kind, Paint: g.kind === 'paint', Cabin: g.kind === 'glass' };
    if (g.kind === 'paint' && paint) lin(paint, mesh.material.color);
    body.add(mesh); m.parts.push(mesh);
  }
  src.wheels.forEach((w, k) => {
    const hub = new THREE.Group(); hub.position.set(w.pos[0], w.pos[1], w.pos[2]);
    const spin = new THREE.Group(); hub.add(spin);
    const still = new THREE.Group(); hub.add(still);
    for (const g of w.parts) {
      const mesh = new THREE.Mesh(decode(g.data), material(g.kind, g.color));
      mesh.position.set(g.center[0], g.center[1], g.center[2]); mesh.castShadow = true;
      mesh.userData = { kind: g.kind, Wheel: k + 1 };
      (g.spin ? spin : still).add(mesh); m.parts.push(mesh);
    }
    group.add(hub);
    m.wheels.push({ hub, spin, front: w.front });
  });
  // smoke points (as in CarMesh.build)
  const hw = def.b.wid * K / 2, rz = def.b.wb * K / 2;
  m.smoke = [new Vector3(-(hw - 0.6), 0.5, rz + 0.4), new Vector3(hw - 0.6, 0.5, rz + 0.4)];
  return m;
};

// ground point cf, front wheel angle (+ = right), wheel roll angles (front, rear)
const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _s = new THREE.Vector3();
CarMesh.place = function (m, cf, steer, rollF, rollR) {
  m.cf = cf;
  cf.m.decompose(_p, _q, _s);
  m.group.position.copy(_p); m.group.quaternion.copy(_q);
  for (const w of m.wheels) {
    w.hub.rotation.set(0, w.front ? -steer : 0, 0);
    w.spin.rotation.set(-(w.front ? rollF : rollR), 0, 0);
  }
};
CarMesh.destroy = function (m) { if (m && m.group.parent) m.group.parent.remove(m.group); for (const p of m.parts) p.material.dispose(); };

export const CarModel = {
  paint(m, color) { for (const p of m.parts) if (p.userData.Paint) lin(color, p.material.color); },
  setCabinVisible(m, visible) { for (const p of m.parts) if (p.userData.Cabin) p.visible = visible; },
};

// Main.client's applyStyle: underglow, rim colour, stance kit
export function applyStyle(m, def, cs, Config) {
  const size = new Vector3(def.b.wid * K, 1, def.b.len * K);
  underglow(m, cs && cs.glowOwned && cs.glow > 0 ? Config.GlowColors[cs.glow - 1] : null, size);
  const rim = cs && cs.rimsOwned && cs.rims > 0 ? Config.RimColors[cs.rims - 1] : def.rim;
  for (const p of m.parts) if (p.userData.Wheel && p.userData.kind === 'metal') lin(rim, p.material.color);
  m.body.position.y = cs && cs.kit ? -0.35 : 0;
}
// Fx.underglow: a neon strip under the car that lights the road around it (colour null = off)
function underglow(m, color, size) {
  if (m.glow) { m.group.remove(m.glow.mesh); m.glow.mesh.material.dispose(); m.glow = null; }
  if (!color) return;
  const mat = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.75, toneMapped: false });
  lin(color, mat.color).multiplyScalar(1.25);
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(size.X * 0.8, 0.12, size.Z * 0.75), mat);
  mesh.position.y = 0.35;
  // the PointLight and SurfaceLight become a soft pool on the road
  const pool = new THREE.Mesh(new THREE.PlaneGeometry(size.X * 2.6, size.Z * 1.5).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: glowTex(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
  lin(color, pool.material.color).multiplyScalar(0.9);
  pool.position.y = -0.28; pool.renderOrder = 4;
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
