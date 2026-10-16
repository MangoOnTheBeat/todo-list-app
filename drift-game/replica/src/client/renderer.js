// The replica's view of the world: draws the scene the way the Roblox game's Lighting is set up (ClockTime,
// Brightness, Ambient / OutdoorAmbient, Atmosphere haze, a sky with stars and the moon at night, BloomEffect,
// ColorCorrection and the menu BlurEffect), with GlobalShadows from the sun or moon and the street lamps'
// PointLights (the nearest ones are real lights; every lamp also lights a pool on the road).
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { Lighting } from '../rbx/core.js';
import { cullDetail } from '../world/parts.js';
import { CFrame, Vector2, Color3 } from '../rbx/types.js';

const lin = c => new THREE.Color().setRGB(c.R, c.G, c.B, THREE.SRGBColorSpace);

// workspace.CurrentCamera
export const camera = {
  _cf: CFrame.new(0, 50, 0), FieldOfView: 70, CameraType: null,
  get CFrame() { return this._cf; }, set CFrame(v) { this._cf = v; },
  get ViewportSize() { return new Vector2(innerWidth, innerHeight); },
};

let renderer, scene, cam, composer, bloomPass, sun, hemi, skyMat, skyMesh, pmrem, envRT, spot;
const lamps = []; let lampPool = [], lightList = [], pools = null;
const state = { hemiN: 5, hemiD: 2.2, quality: null, shadows: true, bloom: true, lights: 1, night: true, envKey: '' };

const SKY_VS = `varying vec3 vDir; void main(){ vDir = normalize((modelMatrix * vec4(position,0.0)).xyz); vec4 p = projectionMatrix * viewMatrix * vec4((modelMatrix*vec4(position,1.0)).xyz,1.0); gl_Position = p.xyww; }`;
const SKY_FS = `
uniform vec3 uZenith, uHorizon, uGround, uSunDir, uSunCol, uMoonDir; uniform float uStars, uSunSize, uMoonSize;
varying vec3 vDir;
float hash(vec3 p){ p = fract(p*0.3183099+.1); p*=17.0; return fract(p.x*p.y*p.z*(p.x+p.y+p.z)); }
void main(){
  vec3 d = normalize(vDir); float h = d.y;
  vec3 col = mix(uHorizon, uZenith, pow(clamp(h,0.0,1.0), 0.45));
  col = mix(col, uGround, smoothstep(0.0, -0.08, h));
  // sun glow and disc
  float s = max(dot(d, uSunDir), 0.0);
  col += uSunCol * (pow(s, 600.0) * 18.0 + pow(s, 12.0) * 0.25);
  // moon
  float m = dot(d, uMoonDir);
  float md = smoothstep(uMoonSize, uMoonSize + 0.0006, m);
  col = mix(col, vec3(0.92,0.93,0.98), md * uStars);
  col += vec3(0.25,0.28,0.4) * pow(max(m,0.0), 60.0) * 0.5 * uStars;
  // stars
  if (uStars > 0.0 && h > 0.0) {
    vec3 q = floor(d * 380.0); float r = hash(q);
    float star = step(0.9965, r) * (0.5 + 0.5 * hash(q + 7.0));
    col += vec3(star) * uStars * smoothstep(0.0, 0.25, h) * (1.0 - md);
  }
  gl_FragColor = vec4(col, 1.0);
  #include <colorspace_fragment>
}`;

export function initRenderer(canvas) {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance', logarithmicDepthBuffer: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
  renderer.setSize(innerWidth, innerHeight, false);
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.15;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  scene = new THREE.Scene();
  cam = new THREE.PerspectiveCamera(70, innerWidth / innerHeight, 0.4, 30000);
  scene.fog = new THREE.FogExp2(0x485278, 0.0004);
  // sky dome
  skyMat = new THREE.ShaderMaterial({
    vertexShader: SKY_VS, fragmentShader: SKY_FS, side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { uZenith: { value: new THREE.Color() }, uHorizon: { value: new THREE.Color() }, uGround: { value: new THREE.Color() }, uSunDir: { value: new THREE.Vector3(0, 1, 0) }, uSunCol: { value: new THREE.Color() }, uMoonDir: { value: new THREE.Vector3(0, 1, 0) }, uStars: { value: 1 }, uSunSize: { value: 0.9998 }, uMoonSize: { value: 0.99955 } },
  });
  skyMesh = new THREE.Mesh(new THREE.SphereGeometry(1000, 32, 16), skyMat);
  skyMesh.frustumCulled = false; skyMesh.renderOrder = -10;
  scene.add(skyMesh);
  // sun / moon light and the ambient
  sun = new THREE.DirectionalLight(0xffffff, 1);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -260, right: 260, top: 260, bottom: -260, near: 1, far: 2000 });
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.6;
  scene.add(sun, sun.target);
  hemi = new THREE.HemisphereLight(0xffffff, 0xffffff, 1);
  scene.add(hemi);
  pmrem = new THREE.PMREMGenerator(renderer);
  // the car's headlight beam (the SpotLight on the car's root)
  spot = new THREE.SpotLight(0xffecc8, 0, 80 * 1.4, THREE.MathUtils.degToRad(35), 0.6, 2);
  scene.add(spot, spot.target);
  // post: bloom (BloomEffect Intensity 0.55, Threshold 1.6 on Roblox: only neon and bright lamps glow)
  composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(1, 1, { type: THREE.HalfFloatType, samples: 4 }));
  composer.addPass(new RenderPass(scene, cam));
  bloomPass = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.55, 0.45, 0.92);
  composer.addPass(bloomPass);
  composer.addPass(new OutputPass());
  const fit = () => {
    renderer.setSize(innerWidth, innerHeight, false); composer.setSize(innerWidth, innerHeight);
    cam.aspect = innerWidth / innerHeight; cam.updateProjectionMatrix();
  };
  addEventListener('resize', fit); fit();
  return { renderer, scene, camera: cam };
}
export const getScene = () => scene;
export const getThreeCamera = () => cam;

// lamps with PointLights: { x, y, z, n, color, range, brightness }; pools drawn under each one at night
export function setLights(list, groundAt) {
  lightList = list;
  const tex = (() => {
    const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.45, 'rgba(255,255,255,0.45)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64); return new THREE.CanvasTexture(c);
  })();
  const mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false, polygonOffset: true, polygonOffsetFactor: -4, fog: true });
  pools = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), mat, list.length);
  const m = new THREE.Matrix4(), col = new THREE.Color();
  list.forEach((l, k) => {
    const gy = groundAt(l.x, l.y, l.z) ?? (l.y - 20);
    const s = l.range * 1.15, k2 = 0.16 * l.brightness;
    m.makeScale(s, 1, s).setPosition(l.x, gy + 0.12, l.z);
    pools.setMatrixAt(k, m); pools.setColorAt(k, col.copy(lin(l.color)).multiplyScalar(k2));
  });
  pools.computeBoundingSphere(); pools.renderOrder = 4;
  scene.add(pools);
}
function poolSize(q) { return q === 'high' ? 12 : q === 'medium' ? 8 : 4; }
function ensureLampPool(n) {
  if (lampPool.length === n) return;
  for (const l of lampPool) scene.remove(l);
  lampPool = [];
  for (let k = 0; k < n; k++) { const l = new THREE.PointLight(0xffffff, 0, 50, 1.3); scene.add(l); lampPool.push(l); }
}
let lampT = 0;
function updateLamps(dt, focus) {
  lampT -= dt;
  if (lampT > 0) return; lampT = 0.25;
  const near = [];
  if (state.night) for (const l of lightList) {
    if (l.n !== undefined && l.n % state.lights !== 0) continue;
    const d = (l.x - focus.x) ** 2 + (l.z - focus.z) ** 2 + (l.y - focus.y) ** 2;
    if (d < 400 * 400) near.push([d, l]);
  }
  near.sort((a, b) => a[0] - b[0]);
  lampPool.forEach((pl, k) => {
    const e = near[k];
    if (!e) { pl.intensity = 0; pl.visible = false; return; }
    const l = e[1];
    pl.visible = true; pl.position.set(l.x, l.y, l.z); pl.color.copy(lin(l.color)); pl.distance = l.range * 1.3; pl.intensity = l.brightness * 260;
  });
}

// Roblox's sun path: rises in the east at 6:00, highest at noon, sets at 18:00 (a little tilted to the south)
function sunDir(t) {
  const a = (t - 6) / 12 * Math.PI;
  return new THREE.Vector3(Math.cos(a), Math.sin(a), -0.35).normalize();
}

// apply Lighting (called each frame; cheap when nothing changed)
function applyLighting(focus) {
  const t = Lighting.ClockTime, night = t < 6.2 || t > 17.8;
  const atmo = Lighting.FindFirstChildOfClass('Atmosphere');
  const s = sunDir(t), moon = s.clone().negate();
  const up = night ? moon : s;
  const dusk = Math.max(0, 1 - Math.min(Math.abs(t - 6), Math.abs(t - 18)) / 1.5);
  const above = Math.max(0, up.y);
  // light from the sun (day) or moon (night)
  sun.position.copy(focus).addScaledVector(up.y > 0.05 ? up : new THREE.Vector3(up.x, 0.05, up.z).normalize(), 900);
  sun.target.position.copy(focus);
  if (night) { sun.color.setRGB(0.55, 0.62, 0.85); sun.intensity = Lighting.Brightness * 0.32 * Math.min(1, above * 3 + 0.3); }
  else { sun.color.copy(new THREE.Color(1, 0.97, 0.9).lerp(new THREE.Color(1, 0.62, 0.38), dusk)); sun.intensity = Lighting.Brightness * 1.25 * Math.min(1, above * 4 + 0.08); }
  sun.castShadow = state.shadows && Lighting.GlobalShadows !== false;
  hemi.color.copy(lin(Lighting.OutdoorAmbient)).add(lin(Lighting.Ambient)); hemi.groundColor.copy(lin(Lighting.Ambient));
  hemi.intensity = night ? state.hemiN : state.hemiD;
  // sky and haze from the Atmosphere
  const aCol = atmo ? atmo.Color : Color3.fromRGB(72, 82, 122), aDec = atmo ? atmo.Decay : Color3.fromRGB(22, 24, 42), dens = atmo ? atmo.Density : 0.3;
  const horizon = lin(aCol), zen = night ? lin(aDec).multiplyScalar(0.7) : new THREE.Color().setRGB(0.24, 0.45, 0.85, THREE.SRGBColorSpace).lerp(lin(aDec), 0.35 + dusk * 0.4);
  skyMat.uniforms.uZenith.value.copy(zen); skyMat.uniforms.uHorizon.value.copy(horizon);
  skyMat.uniforms.uGround.value.copy(horizon).multiplyScalar(0.8);
  skyMat.uniforms.uSunDir.value.copy(s); skyMat.uniforms.uMoonDir.value.copy(moon);
  skyMat.uniforms.uSunCol.value.set(1, 0.9, 0.7).multiplyScalar(night ? 0 : 1);
  skyMat.uniforms.uStars.value = night ? 1 : 0;
  scene.fog.color.copy(horizon);
  scene.fog.density = dens * 0.0012;
  state.night = night;
  // reflections: rebuild the environment from the sky when the time changes
  const key = t.toFixed(2) + '|' + aCol.ToHex();
  if (key !== state.envKey) {
    state.envKey = key;
    const envScene = new THREE.Scene(); const dome = new THREE.Mesh(skyMesh.geometry, skyMat); dome.scale.setScalar(0.5); envScene.add(dome);
    const rt = pmrem.fromScene(envScene, 0, 0.1, 2000);
    if (envRT) envRT.dispose(); envRT = rt;
    scene.environment = rt.texture;
  }
}

// graphics level (Config.Quality): shadows, bloom, how many lamps cast light
export function setQuality(name, Q) {
  state.quality = name; state.shadows = Q.shadows; state.bloom = Q.bloom; state.lights = Q.lights;
  renderer.setPixelRatio(Math.min(devicePixelRatio, name === 'low' ? 1 : name === 'medium' ? 1.25 : 1.5));
  sun.shadow.mapSize.set(name === 'high' ? 2048 : 1024, name === 'high' ? 2048 : 1024);
  if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
  ensureLampPool(poolSize(name));
  lampT = 0;
  addEventListener('resize', () => {}, { once: true });
  composer.setSize(innerWidth, innerHeight);
}

// the car's SpotLight beam (Range 80, Angle 70, Brightness 4) following the car's root CFrame
export function setBeam(cf, on) {
  if (!cf || !on) { spot.intensity = 0; spot.visible = false; return; }
  const e = cf.m.elements;
  spot.visible = true;
  spot.position.set(e[12] - e[8] * 4 + e[4] * 2.2, e[13] - e[9] * 4 + e[5] * 2.2, e[14] - e[10] * 4 + e[6] * 2.2);
  spot.target.position.set(e[12] - e[8] * 60, e[13] - e[9] * 60 - 4, e[14] - e[10] * 60);
  spot.intensity = 4 * 120;
}

const _p = new THREE.Vector3(), _q = new THREE.Quaternion(), _s = new THREE.Vector3();
let blurNow = -1;
export function render(dt) {
  // camera from workspace.CurrentCamera
  camera._cf.m.decompose(_p, _q, _s);
  cam.position.copy(_p); cam.quaternion.copy(_q);
  if (Math.abs(cam.fov - camera.FieldOfView) > 1e-3) { cam.fov = camera.FieldOfView; cam.updateProjectionMatrix(); }
  skyMesh.position.copy(_p);
  const focus = state.focus || _p;
  applyLighting(focus);
  updateLamps(dt, focus);
  cullDetail(_p.x, _p.z, state.quality === 'low' ? 1400 : state.quality === 'medium' ? 2200 : 3600);
  if (pools) pools.visible = state.night;
  // BlurEffect "KaidoBlur" and the ColorCorrection grade, as a CSS filter on the canvas
  const blur = Lighting.FindFirstChild('KaidoBlur'), b = blur && blur.Enabled !== false ? blur.Size : 0;
  if (Math.abs(b - blurNow) > 0.05) { blurNow = b; renderer.domElement.style.filter = `contrast(1.08) saturate(1.06)${b > 0.3 ? ` blur(${(b * 0.45).toFixed(1)}px)` : ''}`; }
  if (state.bloom) composer.render(dt); else renderer.render(scene, cam);
}
export function setFocus(v) { state.focus = new THREE.Vector3(v.X, v.Y, v.Z); }
export const isNight = () => state.night;
export const tuning = state;
