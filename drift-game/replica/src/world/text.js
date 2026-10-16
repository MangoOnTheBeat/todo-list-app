// SurfaceGui text for the replica (shop signs, vertical banners, the scramble screens, the leaderboard):
// GothamBlack, TextScaled, LightInfluence 0 like the Roblox game's signs. Each distinct text is drawn once
// to a canvas and every sign that shows it is one instance of a flat quad facing the part's front (-Z).
import * as THREE from 'three';

const items = new Map(); // key -> { text, ink, aspect, group, mats: [Matrix4] }
const FONT = '"Montserrat", "Arial Black", system-ui, sans-serif';
export const textGroups = new Map(); // group -> [Mesh]

// cf: CFrame on the face (text faces its -Z); w, h in studs; ink: Color3
export function addText(cf, w, h, text, ink, group = 'signs') {
  const key = `${text}|${ink.css()}|${(w / h).toFixed(2)}|${group}`;
  let it = items.get(key);
  if (!it) items.set(key, it = { text, ink, aspect: w / h, group, mats: [] });
  const m = (cf.m || cf).clone().multiply(new THREE.Matrix4().makeRotationY(Math.PI)).scale(new THREE.Vector3(w, h, 1));
  it.mats.push(m);
}

// Roblox TextScaled: the largest size at which the text fits the box (lines kept as written)
export function drawScaled(g, text, W, H, color, pad = 0.04) {
  const lines = String(text).split('\n');
  let size = H / lines.length;
  g.font = `900 ${size}px ${FONT}`;
  const widest = () => Math.max(...lines.map(l => g.measureText(l).width));
  const maxW = W * (1 - pad * 2);
  if (widest() > maxW) size *= maxW / widest();
  size = Math.floor(size * 0.98);
  g.font = `900 ${size}px ${FONT}`;
  g.fillStyle = color; g.textAlign = 'center'; g.textBaseline = 'middle';
  const lh = size * 1.0, y0 = H / 2 - (lh * (lines.length - 1)) / 2;
  lines.forEach((l, k) => g.fillText(l, W / 2, y0 + k * lh + size * 0.04));
}

export function makeTextTexture(text, ink, aspect) {
  const H = aspect >= 1 ? 128 : Math.min(1024, Math.round(128 / aspect)), W = Math.max(16, Math.round(H * aspect));
  const c = document.createElement('canvas'); c.width = Math.min(2048, W); c.height = H;
  const g = c.getContext('2d');
  drawScaled(g, text, c.width, c.height, ink.css());
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return t;
}

const quad = new THREE.PlaneGeometry(1, 1);
export async function buildText(scene) {
  try { await Promise.race([document.fonts.load(`900 64px "Montserrat"`, '新箱根 KAIDO'), new Promise(r => setTimeout(r, 2500))]); } catch { /* offline: fallback font */ }
  for (const it of items.values()) {
    const mat = new THREE.MeshBasicMaterial({ map: makeTextTexture(it.text, it.ink, it.aspect), transparent: true, depthWrite: false, toneMapped: false, polygonOffset: true, polygonOffsetFactor: -2 });
    const im = new THREE.InstancedMesh(quad, mat, it.mats.length);
    it.mats.forEach((m, k) => im.setMatrixAt(k, m));
    im.computeBoundingSphere(); im.renderOrder = 3;
    scene.add(im);
    let g = textGroups.get(it.group); if (!g) textGroups.set(it.group, g = []); g.push(im);
  }
}
export function setTextGroupVisible(name, v) { for (const m of textGroups.get(name) || []) m.visible = v; }
