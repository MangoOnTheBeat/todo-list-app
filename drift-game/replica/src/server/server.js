// The Roblox server's profile logic (Main.server.luau), running in this page: profiles, the garage (buy,
// select, paint, upgrades, cosmetics), banking drifts and laps, daily challenges and the leaderboards.
// Progress is kept in this browser (localStorage) instead of a Roblox DataStore. Remotes behave like
// Roblox's (InvokeServer / FireServer / FireClient), so the client is the same code.
import * as THREE from 'three';
import Config from '../shared/config.js';
import { RemoteEvent, RemoteFunction, ReplicatedStorage, localPlayer, Instance } from '../rbx/core.js';
import { Vector3, CFrame, Color3 } from '../rbx/types.js';
import { addPart } from '../world/parts.js';
import { drawScaled } from '../world/text.js';

const KEY = 'kaido-replica-profile-v1';
const remotes = new Instance('Folder'); remotes.Name = 'KaidoRemotes';
const remote = (cls, name) => { const r = cls === 'RemoteFunction' ? new RemoteFunction() : new RemoteEvent(cls); r.Name = name; r.Parent = remotes; return r; };
const GetProfile = remote('RemoteFunction', 'GetProfile'), Buy = remote('RemoteFunction', 'Buy'), SelectCar = remote('RemoteFunction', 'Select');
const Paint = remote('RemoteFunction', 'Paint'), Erase = remote('RemoteFunction', 'Erase'), SaveSettings = remote('RemoteEvent', 'SaveSettings');
const SetMode = remote('RemoteEvent', 'SetMode'), Bank = remote('RemoteEvent', 'Bank'), Lap = remote('RemoteEvent', 'Lap');
const State = remote('UnreliableRemoteEvent', 'State'), Others = remote('UnreliableRemoteEvent', 'Others'), ProfileChanged = remote('RemoteEvent', 'Profile');
const Tune = remote('RemoteFunction', 'Tune'), BuySpecial = remote('RemoteEvent', 'BuySpecial');
remotes.Parent = ReplicatedStorage;
export const R = Object.fromEntries(remotes.GetChildren().map(r => [r.Name, r]));

const car = id => Config.car(id);
function newProfile() {
  return { credits: 0, owned: { ps13: true }, selected: 'ps13', best: 0, laps: 0, total: 0, paint: {}, upg: {}, cos: {}, daily: null, settings: Config.cleanSettings({}) };
}
function load() {
  const p = newProfile();
  let data = null;
  try { data = JSON.parse(localStorage.getItem(KEY) || 'null'); } catch { data = null; }
  if (data && typeof data === 'object') {
    const n = v => Math.max(0, Math.floor(Number(v) || 0));
    p.credits = n(data.credits); p.best = n(data.best); p.laps = n(data.laps); p.total = n(data.total);
    if (data.owned && typeof data.owned === 'object') for (const id in data.owned) if (data.owned[id] && car(id).id === id) p.owned[id] = true;
    if (typeof data.selected === 'string' && p.owned[data.selected]) p.selected = data.selected;
    if (data.paint && typeof data.paint === 'object') for (const id in data.paint) { const v = data.paint[id]; if (car(id).id === id && typeof v === 'number' && v >= 0 && v <= Config.Paints.length) p.paint[id] = Math.floor(v); }
    p.settings = Config.cleanSettings(data.settings);
    if (data.upg && typeof data.upg === 'object') for (const id in data.upg) {
      const u = data.upg[id]; if (car(id).id !== id || !u || typeof u !== 'object') continue;
      const clean = {}; for (const up of Config.Upgrades) clean[up.key] = Math.min(Config.UPGRADE_MAX, Math.max(0, Math.floor(Number(u[up.key]) || 0)));
      p.upg[id] = clean;
    }
    if (data.cos && typeof data.cos === 'object') for (const id in data.cos) {
      const c = data.cos[id]; if (car(id).id !== id || !c || typeof c !== 'object') continue;
      p.cos[id] = { glowOwned: c.glowOwned === true, rimsOwned: c.rimsOwned === true, kit: c.kit === true,
        glow: Math.min(Config.GlowColors.length, Math.max(0, Math.floor(Number(c.glow) || 0))), rims: Math.min(Config.RimColors.length, Math.max(0, Math.floor(Number(c.rims) || 0))) };
    }
    const d = data.daily;
    if (d && typeof d.day === 'number' && Array.isArray(d.prog) && Array.isArray(d.done)) {
      p.daily = { day: d.day, prog: [], done: [] };
      for (let k = 0; k < 3; k++) { p.daily.prog[k] = Math.max(0, Number(d.prog[k]) || 0); p.daily.done[k] = d.done[k] === true; }
    }
  }
  p.admin = false;
  return p;
}
let profile = load();
function save() { try { localStorage.setItem(KEY, JSON.stringify(profile)); } catch { /* private mode: progress lasts this visit */ } }
let saveT = null;
const dirty = () => { if (!saveT) saveT = setTimeout(() => { saveT = null; save(); }, 1000); };
addEventListener('pagehide', save);

const today = () => Math.floor(Date.now() / 86400000);
function daily(p) {
  const d = today();
  if (!p.daily || p.daily.day !== d) p.daily = { day: d, prog: [0, 0, 0], done: [false, false, false] };
  return p.daily;
}
function view(p) {
  const dl = daily(p), list = Config.dailyFor(dl.day);
  const ch = list.map((c, k) => ({ text: c.text, goal: c.goal, reward: c.reward, prog: Math.min(dl.prog[k], c.goal), done: dl.done[k] }));
  return JSON.parse(JSON.stringify({ credits: p.credits, owned: Object.keys(p.owned), selected: p.selected, best: p.best, laps: p.laps, total: p.total, paint: p.paint,
    upg: p.upg, cos: p.cos, daily: ch, settings: p.settings, admin: p.admin === true }));
}

GetProfile.OnServerInvoke = () => view(profile);
Buy.OnServerInvoke = (_, id) => {
  const p = profile; if (typeof id !== 'string') return null;
  const c = car(id);
  if (c.id === id && !c.premium && !p.owned[id] && p.credits >= c.price) { p.credits -= c.price; p.owned[id] = true; p.selected = id; save(); }
  return view(p);
};
// special cars: Robux game passes on Roblox; here they're bought with credits at their listed price
BuySpecial.OnServerEvent.Connect((_, id) => {
  if (typeof id !== 'string') return;
  const c = car(id), p = profile;
  if (c.id === id && c.premium && !p.owned[id] && p.credits >= c.price) {
    p.credits -= c.price; p.owned[id] = true; p.selected = id; save();
    ProfileChanged.FireClient(localPlayer, view(p));
  }
});
SelectCar.OnServerInvoke = (_, id) => { if (typeof id === 'string' && profile.owned[id]) { profile.selected = id; dirty(); } return view(profile); };
Paint.OnServerInvoke = (_, id, idx) => {
  if (typeof id === 'string' && car(id).id === id && typeof idx === 'number' && idx >= 0 && idx <= Config.Paints.length) { profile.paint[id] = Math.floor(idx); dirty(); }
  return view(profile);
};
Tune.OnServerInvoke = (_, id, action, value) => {
  const p = profile;
  if (typeof id !== 'string' || typeof action !== 'string' || car(id).id !== id || !p.owned[id]) return view(p);
  const pay = cost => { if (p.credits < cost) return false; p.credits -= cost; return true; };
  p.upg[id] = p.upg[id] || {};
  p.cos[id] = p.cos[id] || { glowOwned: false, rimsOwned: false, kit: false, glow: 0, rims: 0 };
  const u = p.upg[id], c = p.cos[id];
  for (const up of Config.Upgrades) if (action === 'up_' + up.key) { const l = u[up.key] || 0; if (l < Config.UPGRADE_MAX && pay(up.cost[l])) u[up.key] = l + 1; }
  if (action === 'glowOwn' && !c.glowOwned && pay(Config.Cosmetics.glow.cost)) { c.glowOwned = true; c.glow = 1; }
  if (action === 'rimsOwn' && !c.rimsOwned && pay(Config.Cosmetics.rims.cost)) { c.rimsOwned = true; c.rims = 1; }
  if (action === 'kitOwn' && !c.kit && pay(Config.Cosmetics.kit.cost)) c.kit = true;
  if (action === 'kitOff') c.kit = false;
  if (action === 'glow' && c.glowOwned && typeof value === 'number') c.glow = Math.min(Config.GlowColors.length, Math.max(0, Math.floor(value)));
  if (action === 'rims' && c.rimsOwned && typeof value === 'number') c.rims = Math.min(Config.RimColors.length, Math.max(1, Math.floor(value)));
  save();
  return view(p);
};
SaveSettings.OnServerEvent.Connect((_, s) => { profile.settings = Config.cleanSettings(s); dirty(); });
Erase.OnServerInvoke = () => {
  const keep = profile.settings;
  profile = newProfile(); profile.settings = keep; profile.admin = false;
  save();
  return view(profile);
};

function progress(p, kind, amount) {
  const dl = daily(p), list = Config.dailyFor(dl.day);
  list.forEach((c, k) => {
    if (c.kind === kind && !dl.done[k]) {
      if (kind === 'one' || kind === 'combo') dl.prog[k] = Math.max(dl.prog[k], amount); else dl.prog[k] += amount;
      if (dl.prog[k] >= c.goal) {
        dl.done[k] = true; p.credits += c.reward;
        ProfileChanged.FireClient(localPlayer, view(p), 'Challenge complete  ·  ' + c.text + '  ·  +' + c.reward + ' CR');
      }
    }
  });
  dirty();
}
let lastBank = 0, lastLap = -1e9;
Bank.OnServerEvent.Connect((_, points, zone, tandemPts, combo) => {
  const p = profile;
  if (typeof points !== 'number' || points !== points || points <= 0) return;
  const now = performance.now() / 1000, since = now - lastBank; lastBank = now;
  points = Math.floor(Math.min(points, 600000, since * 30000));
  if (points <= 0) return;
  p.credits += Math.floor(points / 10);
  p.best = Math.max(p.best, points);
  p.total += points;
  dirty(); boardsDirty = true;
  progress(p, 'one', points);
  progress(p, 'total', points);
  if (zone === 'city') progress(p, 'city', points); else if (zone === 'pass') progress(p, 'pass', points);
  if (typeof tandemPts === 'number' && tandemPts === tandemPts && tandemPts > 0) progress(p, 'tandem', Math.min(tandemPts, points));
  if (typeof combo === 'number' && combo === combo) progress(p, 'combo', Math.min(5, Math.max(1, combo)));
});
Lap.OnServerEvent.Connect(() => {
  const now = performance.now() / 1000;
  if (now - lastLap > 180) { lastLap = now; profile.credits += 2000; profile.laps += 1; dirty(); progress(profile, 'lap', 1); }
});
SetMode.OnServerEvent.Connect(() => { });
State.OnServerEvent.Connect(() => { });

// ===== leaderboards: on the web there's one driver per browser, so the boards show your own records =====
let boardsDirty = true, updateNeonBoard = null;
function refreshBoards() {
  if (!boardsDirty) return; boardsDirty = false;
  const name = localPlayer.Name;
  const boards = { best: profile.best > 0 ? [[name, profile.best]] : [], total: profile.total > 0 ? [[name, profile.total]] : [] };
  ReplicatedStorage.SetAttribute('Boards', JSON.stringify(boards));
  if (updateNeonBoard) updateNeonBoard(boards);
}
setTimeout(refreshBoards, 5000);
setInterval(refreshBoards, 60000);

// the neon leaderboard gantry over the street just ahead of the city spawn (parts go in before the batches)
export function buildBoardParts(spawn) {
  const sx = spawn.X, sy = spawn.Y, sz = spawn.Z, gx = sx + 70, steel = Color3.fromRGB(44, 46, 52);
  const block = (size, cf, color, mat, opts) => addPart('Leaderboard', size, cf, color, mat, 'Block', opts);
  for (const side of [-1, 1]) block(new Vector3(2.4, 40, 2.4), CFrame.new(gx, sy + 20, sz + side * 27), steel, 'Metal', { name: 'Pillar' });
  block(new Vector3(2.4, 2, 58), CFrame.new(gx, sy + 39, sz), steel, 'Metal');
  const centre = new Vector3(gx, sy + 27, sz), face = CFrame.lookAt(centre, centre.sub(new Vector3(10, 0, 0)));
  block(new Vector3(50, 22, 0.8), face, Color3.fromRGB(10, 10, 18), 'SmoothPlastic', { name: 'BoardFace', collide: false });
  for (const e of [[0, 11.2, 50.6, 0.5], [0, -11.2, 50.6, 0.5], [25.2, 0, 0.5, 22.8], [-25.2, 0, 0.5, 22.8]])
    block(new Vector3(e[2], e[3], 1), face.mul(CFrame.new(e[0], e[1], 0)), Color3.fromRGB(255, 126, 182), 'Neon', { collide: false });
  return face;
}
// its SurfaceGui (Front face, 1000×440 canvas, GothamBlack, Brightness 2)
export function buildBoardGui(scene, face) {
  const c = document.createElement('canvas'); c.width = 1000; c.height = 440;
  const g = c.getContext('2d'), tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  const mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, toneMapped: false, polygonOffset: true, polygonOffsetFactor: -2 });
  mat.color.setScalar(1.6);
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(50, 22), mat);
  const m = face.mul(CFrame.new(0, 0, -0.41)).m.clone().multiply(new THREE.Matrix4().makeRotationY(Math.PI));
  m.decompose(mesh.position, mesh.quaternion, mesh.scale);
  scene.add(mesh);
  const label = (text, x, y, w, h, size, color, align = 'left') => {
    if (!text) return;
    g.font = `900 ${size}px "Montserrat", "Arial Black", sans-serif`; g.fillStyle = color; g.textBaseline = 'middle';
    g.textAlign = align; g.fillText(text, align === 'center' ? x + w / 2 : align === 'right' ? x + w : x, y + h / 2);
  };
  const commas = v => Math.floor(v).toLocaleString('en-US');
  updateNeonBoard = boards => {
    g.clearRect(0, 0, 1000, 440);
    label('KAIDO LEADERBOARD', 0, 8, 1000, 50, 40, '#ff7eb6', 'center');
    label('BEST DRIFT', 40, 64, 440, 36, 26, '#ffc94d');
    label('TOTAL POINTS', 530, 64, 440, 36, 26, '#59e3ff');
    for (let k = 1; k <= 8; k++) ['best', 'total'].forEach((key, col) => {
      const x = col === 0 ? 40 : 530, e = boards[key][k - 1];
      if (e) { label(k + '  ' + e[0], x, 64 + k * 40, 330, 36, 24, '#f0eee8'); label(commas(e[1]), x + 300, 64 + k * 40, 130, 36, 24, '#f0eee8', 'right'); }
    });
    tex.needsUpdate = true;
  };
  document.fonts.ready.then(() => { boardsDirty = true; refreshBoards(); });
  updateNeonBoard({ best: [], total: [] });
}
export { drawScaled };
