// Parts for the replica's world: every Roblox Part the map builders create becomes one instance in a batch
// (same material, shape and role), drawn with InstancedMesh in 2048-stud tiles so off-screen tiles are skipped.
// Materials get a grey detail texture in world space (like Roblox's material textures tiling per stud),
// multiplied by the part colour. Parts keep their box so the world queries (ground, walls) can use them.
import * as THREE from 'three';
import { CFrame, Color3 } from '../rbx/types.js';

const TILE = 2048;
// ---- material detail textures (grey, mean ~0.5) ----
function canvasTex(size, draw) {
  const c = document.createElement('canvas'); c.width = c.height = size; const g = c.getContext('2d');
  g.fillStyle = '#808080'; g.fillRect(0, 0, size, size); draw(g, size);
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.NoColorSpace; t.anisotropy = 4; return t;
}
function rnd(seed) { let a = seed >>> 0; return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function noise(g, n, amt, seed, cell = 1) {
  const r = rnd(seed), img = g.getImageData(0, 0, n, n), d = img.data;
  for (let y = 0; y < n; y += cell) for (let x = 0; x < n; x += cell) {
    const v = (r() - 0.5) * amt * 255;
    for (let yy = 0; yy < cell; yy++) for (let xx = 0; xx < cell; xx++) { const i = ((y + yy) * n + x + xx) * 4; d[i] += v; d[i + 1] += v; d[i + 2] += v; }
  }
  g.putImageData(img, 0, 0);
}
const TEX = {};
function detail(name) {
  if (TEX[name] !== undefined) return TEX[name];
  const n = 256;
  const t = {
    Asphalt: () => canvasTex(n, g => { noise(g, n, 0.35, 1); noise(g, n, 0.2, 2, 4); }),
    Concrete: () => canvasTex(n, g => { noise(g, n, 0.18, 3, 2); noise(g, n, 0.1, 4, 8); }),
    Pavement: () => canvasTex(n, g => { noise(g, n, 0.14, 5, 2); g.strokeStyle = 'rgba(40,40,40,0.55)'; g.lineWidth = 3; for (let k = 0; k <= 4; k++) { g.beginPath(); g.moveTo(k * n / 4, 0); g.lineTo(k * n / 4, n); g.moveTo(0, k * n / 4); g.lineTo(n, k * n / 4); g.stroke(); } }),
    Slate: () => canvasTex(n, g => { const r = rnd(6); for (let y = 0; y < n; y += 16) { g.fillStyle = `rgb(${110 + r() * 50 | 0},${110 + r() * 50 | 0},${110 + r() * 50 | 0})`; g.fillRect(0, y, n, 14); } noise(g, n, 0.15, 7, 2); }),
    Rock: () => canvasTex(n, g => { noise(g, n, 0.3, 8, 4); noise(g, n, 0.2, 9, 1); }),
    Granite: () => canvasTex(n, g => { noise(g, n, 0.4, 10, 1); }),
    WoodPlanks: () => canvasTex(n, g => { const r = rnd(11); for (let y = 0; y < n; y += 32) { g.fillStyle = `rgb(${120 + r() * 30 | 0},${120 + r() * 30 | 0},${120 + r() * 30 | 0})`; g.fillRect(0, y, n, 30); g.fillStyle = 'rgb(60,60,60)'; g.fillRect(0, y + 30, n, 2); const x = r() * n | 0; g.fillRect(x, y, 2, 30); } noise(g, n, 0.12, 12, 1); }),
    Wood: () => canvasTex(n, g => { for (let x = 0; x < n; x += 4) { g.fillStyle = `rgba(0,0,0,${0.05 + 0.08 * Math.sin(x * 0.3) ** 2})`; g.fillRect(x, 0, 3, n); } noise(g, n, 0.1, 13, 1); }),
    Brick: () => canvasTex(n, g => { g.fillStyle = 'rgb(150,150,150)'; g.fillRect(0, 0, n, n); g.fillStyle = 'rgb(60,60,60)'; for (let y = 0; y < n; y += 32) { g.fillRect(0, y, n, 4); for (let x = (y / 32) % 2 ? 32 : 0; x < n; x += 64) g.fillRect(x, y, 4, 32); } noise(g, n, 0.15, 14, 2); }),
    Cobblestone: () => canvasTex(n, g => { const r = rnd(15); g.fillStyle = 'rgb(70,70,70)'; g.fillRect(0, 0, n, n); for (let k = 0; k < 90; k++) { g.fillStyle = `rgb(${120 + r() * 60 | 0},${120 + r() * 60 | 0},${120 + r() * 60 | 0})`; g.beginPath(); g.ellipse(r() * n, r() * n, 10 + r() * 12, 8 + r() * 10, r() * 3, 0, 7); g.fill(); } }),
    DiamondPlate: () => canvasTex(n, g => { g.fillStyle = 'rgb(140,140,140)'; g.fillRect(0, 0, n, n); g.fillStyle = 'rgb(190,190,190)'; for (let y = 0; y < n; y += 32) for (let x = (y / 32) % 2 ? 16 : 0; x < n; x += 32) { g.save(); g.translate(x + 8, y + 8); g.rotate(0.78); g.fillRect(-9, -2, 18, 4); g.restore(); } }),
    Metal: () => canvasTex(n, g => { for (let y = 0; y < n; y++) { g.fillStyle = `rgba(255,255,255,${Math.random() * 0.08})`; g.fillRect(0, y, n, 1); } }),
    Grass: () => canvasTex(n, g => { noise(g, n, 0.3, 16, 1); noise(g, n, 0.2, 17, 8); }),
    LeafyGrass: () => canvasTex(n, g => { noise(g, n, 0.35, 18, 2); noise(g, n, 0.2, 19, 8); }),
    Fabric: () => canvasTex(n, g => { for (let k = 0; k < n; k += 4) { g.fillStyle = 'rgba(0,0,0,0.12)'; g.fillRect(k, 0, 2, n); g.fillRect(0, k, n, 2); } }),
    Plaster: () => canvasTex(n, g => { noise(g, n, 0.08, 20, 2); noise(g, n, 0.06, 21, 16); }),
    CeramicTiles: () => canvasTex(n, g => { g.fillStyle = 'rgb(150,150,150)'; g.fillRect(0, 0, n, n); g.fillStyle = 'rgb(80,80,80)'; for (let k = 0; k < n; k += 32) { g.fillRect(k, 0, 2, n); g.fillRect(0, k, n, 2); } noise(g, n, 0.06, 22, 2); }),
    ClayRoofTiles: () => canvasTex(n, g => { for (let y = 0; y < n; y += 24) { const gr = g.createLinearGradient(0, y, 0, y + 24); gr.addColorStop(0, 'rgb(170,170,170)'); gr.addColorStop(1, 'rgb(80,80,80)'); g.fillStyle = gr; g.fillRect(0, y, n, 24); for (let x = 0; x < n; x += 24) { g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(x, y, 2, 24); } } }),
    Snow: () => canvasTex(n, g => { noise(g, n, 0.08, 23, 2); }),
    Sand: () => canvasTex(n, g => { noise(g, n, 0.2, 24, 1); }),
    Ground: () => canvasTex(n, g => { noise(g, n, 0.25, 25, 2); noise(g, n, 0.15, 26, 8); }),
  }[name];
  return (TEX[name] = t ? t() : null);
}
// studs per texture repeat, as Roblox's materials roughly tile
const SCALE = { Asphalt: 8, Concrete: 8, Pavement: 8, Slate: 6, Rock: 10, Granite: 6, WoodPlanks: 6, Wood: 4, Brick: 6, Cobblestone: 6, DiamondPlate: 3, Metal: 4, Grass: 10, LeafyGrass: 10, Fabric: 2, Plaster: 10, CeramicTiles: 6, ClayRoofTiles: 5, Snow: 10, Sand: 10, Ground: 10 };
const ROUGH = { Metal: 0.38, DiamondPlate: 0.4, Glass: 0.08, SmoothPlastic: 0.62, Plastic: 0.7, Neon: 1, Granite: 0.6, CeramicTiles: 0.45 };
const METAL = { Metal: 0.75, DiamondPlate: 0.7, Glass: 0.4 };

// one shared material per (Roblox material, mode); detail texture applied in world space
const MATS = new Map();
export function material(name, mode = '') {
  const key = name + '|' + mode;
  let m = MATS.get(key); if (m) return m;
  if (name === 'Neon' && mode !== 'plain') {
    m = new THREE.MeshBasicMaterial({ toneMapped: false });
    m.color.setScalar(1.25); // a little over 1 so bloom catches it, like Roblox neon
  } else {
    m = new THREE.MeshStandardMaterial({ roughness: ROUGH[name] ?? 0.85, metalness: METAL[name] ?? 0, envMapIntensity: name === 'Glass' ? 1.4 : 0.6 });
    const tex = detail(name);
    if (tex) {
      const uni = { uDetail: { value: tex }, uDetailScale: { value: 1 / (SCALE[name] || 8) } };
      m.onBeforeCompile = sh => {
        Object.assign(sh.uniforms, uni);
        sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nvarying vec3 vWPosD; varying vec3 vWNrmD;')
          .replace('#include <project_vertex>', `#include <project_vertex>
            #ifdef USE_INSTANCING
              vec4 wpD = modelMatrix * instanceMatrix * vec4(transformed, 1.0); vWNrmD = normalize(mat3(modelMatrix) * mat3(instanceMatrix) * objectNormal);
            #else
              vec4 wpD = modelMatrix * vec4(transformed, 1.0); vWNrmD = normalize(mat3(modelMatrix) * objectNormal);
            #endif
            vWPosD = wpD.xyz;`);
        sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying vec3 vWPosD; varying vec3 vWNrmD; uniform sampler2D uDetail; uniform float uDetailScale;')
          .replace('#include <map_fragment>', `#include <map_fragment>
            vec3 anD = abs(vWNrmD);
            vec2 tuvD = (anD.y > anD.x && anD.y > anD.z) ? vWPosD.xz : (anD.x > anD.z ? vWPosD.zy : vWPosD.xy);
            diffuseColor.rgb *= texture2D(uDetail, tuvD * uDetailScale).r * 2.0;`);
      };
      m.customProgramCacheKey = () => 'detail-' + name;
    }
  }
  if (mode === 'glass') { m.transparent = true; m.opacity = 0.5; m.depthWrite = false; }
  if (mode.startsWith('t')) { m.transparent = true; m.opacity = 1 - Number(mode.slice(1)) / 10; m.depthWrite = false; }
  MATS.set(key, m); return m;
}

// ---- shapes (unit size; Roblox cylinders run along X, wedges slope down toward -Z) ----
export const GEO = {
  Block: new THREE.BoxGeometry(1, 1, 1),
  Ball: new THREE.SphereGeometry(0.5, 10, 7),
  Cylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 14).rotateZ(Math.PI / 2),
  Wedge: (() => {
    const g = new THREE.BufferGeometry(), v = [-0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
    g.setAttribute('position', new THREE.Float32BufferAttribute(v, 3)); g.setIndex([0, 1, 2, 0, 2, 3, 3, 2, 5, 3, 5, 4, 0, 4, 5, 0, 5, 1, 0, 3, 4, 1, 5, 2]);
    const n = g.toNonIndexed(); n.computeVertexNormals(); return n;
  })(),
};

// ---- the part registry ----
export const parts = [];          // every part: { folder, name, size, cf (Matrix4), color, material, shape, ... }
const batches = new Map();        // key -> { mat, shape, mode, group, items: [] }
export const groups = new Map();  // group name -> [InstancedMesh] (toggled by day/night and graphics level)
const _m = new THREE.Matrix4(), _s = new THREE.Vector3();
// add a part. size: {X,Y,Z} or Vector3; cf: CFrame or Matrix4; color: Color3; material: Roblox material name.
// opts: { name, folder, group (e.g. 'win2', 'nightNeon', 'tree1'), shadow, transparency, collide (false), query (false) }
export function addPart(folder, size, cf, color, material = 'SmoothPlastic', shape = 'Block', opts = {}) {
  const M = cf.m ? cf.m : cf;
  const p = { folder, name: opts.name || 'Part', size: { X: size.X, Y: size.Y, Z: size.Z }, m: M.clone(), color, material, shape, canCollide: opts.collide !== false, canQuery: opts.query !== false, attrs: opts.attrs || null };
  parts.push(p);
  const tr = opts.transparency || 0;
  const mode = material === 'Glass' && tr > 0.2 ? 'glass' : tr > 0.05 ? 't' + Math.round(tr * 10) : '';
  const e = M.elements, tx = Math.floor(e[12] / TILE), tz = Math.floor(e[14] / TILE);
  const key = `${material}|${shape}|${mode}|${opts.group || ''}|${opts.shadow ? 1 : 0}|${tx},${tz}`;
  let b = batches.get(key);
  if (!b) batches.set(key, b = { material, shape, mode, group: opts.group || '', shadow: !!opts.shadow, items: [] });
  b.items.push(p);
  return p;
}
export const cfOf = p => new CFrame(p.m);
// turn the batches into meshes (call once the map is built)
export function buildBatches(scene) {
  const col = new THREE.Color();
  for (const b of batches.values()) {
    const mat = material(b.material, b.mode);
    const im = new THREE.InstancedMesh(GEO[b.shape], mat, b.items.length);
    b.items.forEach((p, k) => {
      _m.copy(p.m).scale(_s.set(p.size.X, p.size.Y, p.size.Z));
      im.setMatrixAt(k, _m); im.setColorAt(k, col.setRGB(p.color.R, p.color.G, p.color.B, THREE.SRGBColorSpace));
    });
    im.castShadow = b.shadow; im.receiveShadow = b.material !== 'Neon';
    im.computeBoundingSphere();
    if (b.mode) im.renderOrder = 2;
    im.userData.material = b.material;
    scene.add(im);
    if (b.group) { let g = groups.get(b.group); if (!g) groups.set(b.group, g = []); g.push(im); }
    b.mesh = im;
    // small details (lamps, signs, kerbs, windows, trees) are skipped in tiles far from the camera
    let sum = 0; for (const p of b.items) sum += Math.max(p.size.X, p.size.Y, p.size.Z);
    if (sum / b.items.length < 24 && b.group.indexOf('win') !== 0) {
      let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity;
      for (const p of b.items) { const e = p.m.elements; x0 = Math.min(x0, e[12]); x1 = Math.max(x1, e[12]); z0 = Math.min(z0, e[14]); z1 = Math.max(z1, e[14]); }
      detailBatches.push({ im, x0, x1, z0, z1 });
    }
  }
}
export function setGroupVisible(name, v) { for (const im of groups.get(name) || []) { im.visible = v; im.userData.on = v; } }
// hide far detail batches (called each frame with the camera position)
const detailBatches = [];
export function cullDetail(x, z, dist) {
  for (const d of detailBatches) {
    const dx = Math.max(d.x0 - x, 0, x - d.x1), dz = Math.max(d.z0 - z, 0, z - d.z1);
    d.im.visible = d.im.userData.on !== false && dx * dx + dz * dz < dist * dist;
  }
}
// lamps and lanterns switch between glowing (night) and plain plastic (day)
export function setGroupNeon(name, on) { for (const im of groups.get(name) || []) im.material = on ? material('Neon') : material('Neon', 'plain'); }
export function partColor(c) { return c instanceof Color3 ? c : Color3.fromHex(c); }
