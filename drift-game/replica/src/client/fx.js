// Port of the Roblox game's Fx.luau: skid marks laid by the rear tyres (a pool, oldest reused), exhaust
// backfire flames, and the tyre smoke ParticleEmitters (Rate, Lifetime 1.6–2.8, Speed 2–7, Size 2.2→14,
// Transparency 0.5→1, Drag 1.6, Acceleration up 3, as set up in Main.client's spawnCar).
import * as THREE from 'three';
import { CFrame } from '../rbx/types.js';

let scene = null;
export function initFx(s) { scene = s; makeSkids(); makeSmoke(); makeFlames(); }

// ===================== skid marks =====================
const MAX = 400;
let skidMesh, skidAlpha, poolSize = 400, nextMark = 0;
const trails = {};
function makeSkids() {
  const g = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2);
  skidAlpha = new THREE.InstancedBufferAttribute(new Float32Array(MAX), 1);
  g.setAttribute('aAlpha', skidAlpha);
  const mat = new THREE.MeshBasicMaterial({ color: new THREE.Color().setRGB(16 / 255, 16 / 255, 18 / 255, THREE.SRGBColorSpace), transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -3 });
  mat.onBeforeCompile = sh => {
    sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nattribute float aAlpha; varying float vA;').replace('#include <begin_vertex>', '#include <begin_vertex>\nvA = aAlpha;');
    sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying float vA;').replace('#include <opaque_fragment>', '#include <opaque_fragment>\ngl_FragColor.a *= vA;');
  };
  skidMesh = new THREE.InstancedMesh(g, mat, MAX);
  skidMesh.count = 0; skidMesh.frustumCulled = false; skidMesh.renderOrder = 3;
  scene.add(skidMesh);
}
export function setSkidLimit(n) { poolSize = Math.min(MAX, n); if (nextMark >= poolSize) nextMark = 0; skidMesh.count = Math.min(skidMesh.count, poolSize); }
const _m = new THREE.Matrix4();
// key: wheel name; pos: contact point (Vector3); up: road normal; strength 0..1; width in studs
export function skid(key, pos, up, strength, width) {
  const t = trails[key];
  if (strength <= 0) { delete trails[key]; return; }
  if (!t) { trails[key] = pos; return; }
  const d = pos.sub(t), len = d.Magnitude;
  if (len < 1.6) return;
  if (len > 12) { trails[key] = pos; return; }
  const mid = pos.add(t).div(2).add(up.mul(0.04)), fwd = d.Unit;
  const cf = CFrame.lookAt(mid, mid.add(fwd), up);
  _m.copy(cf.m).scale(new THREE.Vector3(width, 1, len + 0.15));
  const i = nextMark;
  skidMesh.setMatrixAt(i, _m); skidMesh.instanceMatrix.needsUpdate = true;
  skidAlpha.array[i] = 1 - (0.82 - 0.5 * Math.min(1, Math.max(0, strength))); skidAlpha.needsUpdate = true;
  nextMark = (nextMark + 1) % poolSize;
  skidMesh.count = Math.max(skidMesh.count, i + 1);
  trails[key] = pos;
}
export function clearSkids() { for (const k in trails) delete trails[k]; skidMesh.count = 0; nextMark = 0; }

// ===================== tyre smoke (ParticleEmitter) =====================
const PMAX = 900;
let pts, pPos, pSize, pAlpha, alive = 0;
const parts = []; // { x,y,z, vx,vy,vz, age, life }
function makeSmoke() {
  const g = new THREE.BufferGeometry();
  pPos = new THREE.BufferAttribute(new Float32Array(PMAX * 3), 3); pSize = new THREE.BufferAttribute(new Float32Array(PMAX), 1); pAlpha = new THREE.BufferAttribute(new Float32Array(PMAX), 1);
  g.setAttribute('position', pPos); g.setAttribute('size', pSize); g.setAttribute('alpha', pAlpha);
  const c = document.createElement('canvas'); c.width = c.height = 64; const gg = c.getContext('2d');
  const gr = gg.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.5, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  gg.fillStyle = gr; gg.fillRect(0, 0, 64, 64);
  const mat = new THREE.ShaderMaterial({
    uniforms: { uTex: { value: new THREE.CanvasTexture(c) }, uColor: { value: new THREE.Color() }, uScale: { value: 500 } },
    vertexShader: `attribute float size; attribute float alpha; varying float vA; uniform float uScale;
      #include <common>
      #include <logdepthbuf_pars_vertex>
      void main(){ vA = alpha; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = size * uScale / -mv.z; gl_Position = projectionMatrix * mv;
      #include <logdepthbuf_vertex>
      }`,
    fragmentShader: `uniform sampler2D uTex; uniform vec3 uColor; varying float vA;
      #include <logdepthbuf_pars_fragment>
      void main(){
      #include <logdepthbuf_fragment>
      vec4 t = texture2D(uTex, gl_PointCoord); gl_FragColor = vec4(uColor, t.a * vA); }`,
    transparent: true, depthWrite: false,
  });
  pts = new THREE.Points(g, mat); pts.frustumCulled = false; pts.renderOrder = 5;
  scene.add(pts);
}
// emit from world point at `rate` particles per second (call every frame for each emitter)
const acc = {};
export function smoke(key, pos, rate, dt) {
  acc[key] = (acc[key] || 0) + rate * dt;
  while (acc[key] >= 1) {
    acc[key] -= 1;
    if (parts.length >= PMAX) parts.shift();
    // SpreadAngle 45: a random direction within 45° of the emitter's up (Attachment faces +Y)
    const a = Math.random() * Math.PI * 2, s = Math.random() * Math.PI / 4, sp = 2 + Math.random() * 5;
    parts.push({ x: pos.X, y: pos.Y, z: pos.Z, vx: Math.cos(a) * Math.sin(s) * sp, vy: Math.cos(s) * sp, vz: Math.sin(a) * Math.sin(s) * sp, age: 0, life: 1.6 + Math.random() * 1.2 });
  }
}
// LightInfluence 1: smoke is lit like the world (pale at noon, dim blue at night)
export function updateSmoke(dt, camH, light) {
  pts.material.uniforms.uScale.value = camH;
  pts.material.uniforms.uColor.value.setRGB(222 / 255, 224 / 255, 232 / 255, THREE.SRGBColorSpace).multiplyScalar(light);
  let n = 0;
  for (let i = parts.length - 1; i >= 0; i--) { const p = parts[i]; p.age += dt; if (p.age >= p.life) parts.splice(i, 1); }
  const drag = Math.exp(-1.6 * dt);
  for (const p of parts) {
    p.vx *= drag; p.vy = p.vy * drag + 3 * dt; p.vz *= drag;
    p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
    const f = p.age / p.life;
    pPos.array[n * 3] = p.x; pPos.array[n * 3 + 1] = p.y; pPos.array[n * 3 + 2] = p.z;
    pSize.array[n] = 2.2 + (14 - 2.2) * f; pAlpha.array[n] = (1 - (0.5 + 0.5 * f)) * 0.9;
    n++;
  }
  pts.geometry.setDrawRange(0, n);
  pPos.needsUpdate = pSize.needsUpdate = pAlpha.needsUpdate = true;
}
export function clearSmoke() { parts.length = 0; }

// ===================== backfire =====================
const FLAME = [[255, 140, 40], [255, 200, 80], [120, 170, 255]];
let flames = [], flameLight;
function makeFlames() {
  const geo = new THREE.SphereGeometry(0.5, 10, 8);
  for (let k = 0; k < 12; k++) {
    const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ transparent: true, opacity: 0.85, toneMapped: false }));
    m.visible = false; m.userData.t = 0; scene.add(m); flames.push(m);
  }
  flameLight = new THREE.PointLight(0xff9640, 0, 14 * 1.3, 1.3); scene.add(flameLight);
}
let fk = 0;
// tips: CFrames pointing backwards out of the exhaust tips
export function backfire(tips, big) {
  for (const tip of tips) {
    const n = big ? 3 : 2;
    for (let k = 0; k < n; k++) setTimeout(() => {
      const s = (big ? 1.3 : 0.9) * (0.7 + Math.random() * 0.6), f = flames[fk = (fk + 1) % flames.length];
      const c = FLAME[Math.floor(Math.random() * (big ? 3 : 2))];
      f.material.color.setRGB(c[0] / 255, c[1] / 255, c[2] / 255, THREE.SRGBColorSpace).multiplyScalar(1.4);
      const p = tip.mul(CFrame.new(0, 0, -s * 0.4)).Position;
      f.position.set(p.X, p.Y, p.Z); f.scale.setScalar(s); f.visible = true; f.userData.t = 0.07;
      flameLight.position.copy(f.position); flameLight.intensity = 3 * 260; flameLight.userData.t = 0.07;
    }, k * 45);
  }
}
export function updateFlames(dt) {
  for (const f of flames) if (f.visible) { f.userData.t -= dt; if (f.userData.t <= 0) f.visible = false; }
  if (flameLight.intensity > 0) { flameLight.userData.t -= dt; if (flameLight.userData.t <= 0) flameLight.intensity = 0; }
}
// tandem link: needs another driver; the web copy has no other players, so it never shows
export function tandem() { }
