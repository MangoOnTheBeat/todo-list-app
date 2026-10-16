// Kaido Drift shared settings: port of the Roblox game's Config.luau (cars from Cars.luau via tools/luau2json.py).
import { Color3 } from '../rbx/types.js';
import GAME from '../data/game.json';

const Config = {};
Config.VERSION = 4; // the Roblox game's current version: the replica shows the same number
Config.ROAD_HALF = 30;
Config.SEG = 13;
Config.SCALE = 3.5;

const asCar = c => ({ ...c, color: Color3.fromHex(c.color), rim: Color3.fromHex(c.rim), b: { ...c.b } });
Config.Cars = GAME.cars.map(asCar);

// special cars: Robux game passes on Roblox. Same cars and numbers here; the browser has no Robux, so they
// are bought with credits (price shown on the same purple cards).
function special(base, t) {
  const src = Config.Cars.find(c => c.id === base);
  const car = { ...src, b: { ...src.b }, ...t };
  car.mesh = base; car.premium = true;
  return car;
}
Config.Premium = [
  special('fd7', { id: 'fd7x', name: 'Akagi FD-7 Spirit Rotor', tag: 'Special · 1,180 kg triple-rotor · screams to 9,500',
    pass: 2029130262, robux: 149, price: 150000, color: Color3.fromHex('#e8f0ff'), rim: Color3.fromHex('#ff7eb6'),
    mass: 1180, torque: 640, peak: 6800, red: 9500, mu: 1.2, lock: 64 }),
  special('jza', { id: 'jzax', name: 'Kaze JZA-80 Apex Omega', tag: 'Special · 1,000 hp twin-turbo six · fastest on the mountain',
    pass: 2029784268, robux: 249, price: 250000, color: Color3.fromHex('#14141a'), rim: Color3.fromHex('#ffc94d'),
    mass: 1420, torque: 880, peak: 5200, red: 8200, mu: 1.22, lock: 65 }),
  special('r34', { id: 'r34x', name: 'Hoshi R-34 Raijin Z-Tune', tag: 'Special · stroked twin-turbo · 6-speed · ultimate grip',
    pass: 2028884270, robux: 399, price: 400000, color: Color3.fromHex('#9aa3b2'), rim: Color3.fromHex('#59e3ff'),
    mass: 1460, torque: 860, peak: 5000, red: 8600, mu: 1.26, lock: 66 }),
];
for (const c of Config.Premium) Config.Cars.push(c);

Config.Paints = ['e9e6df', '111114', 'c81e2c', 'ff7eb6', '59e3ff', '2a54c8', 'ff6a00', 'ffcc00', '2f6b46', '7c8088', '5a2a8c', '8c1d2a'].map(Color3.fromHex);

Config.Upgrades = [
  { key: 'engine', name: 'Engine', desc: 'Ported head, cams and exhaust: +7% torque a level', cost: [4000, 10000, 22000], apply: (c, l) => { c.torque *= 1 + 0.07 * l; } },
  { key: 'turbo', name: 'Turbo', desc: 'Bigger turbo: more top-end, +6% torque and +250 rpm a level', cost: [5000, 12000, 26000], apply: (c, l) => { c.torque *= 1 + 0.06 * l; c.peak += 250 * l; c.red += 250 * l; } },
  { key: 'grip', name: 'Tyres', desc: 'Stickier compound: +2.5% grip a level', cost: [3000, 8000, 18000], apply: (c, l) => { c.mu *= 1 + 0.025 * l; } },
  { key: 'steer', name: 'Steering angle', desc: 'Angle kit: +3° of lock a level, for deeper drifts', cost: [3000, 7000, 15000], apply: (c, l) => { c.lock += 3 * l; } },
];
Config.UPGRADE_MAX = 3;
Config.Cosmetics = {
  glow: { name: 'Underglow neon', cost: 5000 },
  rims: { name: 'Rim colour', cost: 2000 },
  kit: { name: 'Stance kit (lowered body)', cost: 4000 },
};
Config.GlowColors = ['59e3ff', 'ff7eb6', 'a77bff', '49ff8a', 'ff3b3b', 'ffc94d', 'ffffff'].map(Color3.fromHex);
Config.RimColors = ['c3c6cc', '2a2b30', 'c9a227', 'd8d8d8', 'ff7eb6', '59e3ff', 'c81e2c', 'ffffff'].map(Color3.fromHex);

Config.tuned = function (car, upg) {
  if (!upg || typeof upg !== 'object') return car;
  if (!Config.Upgrades.some(u => (upg[u.key] || 0) > 0)) return car;
  const c = { ...car, b: car.b };
  for (const u of Config.Upgrades) {
    const l = Math.min(Config.UPGRADE_MAX, Math.max(0, Math.floor(Number(upg[u.key]) || 0)));
    if (l > 0) u.apply(c, l);
  }
  return c;
};

Config.DailyPool = [
  { kind: 'one', text: 'Score %s in one drift', goals: [15000, 25000, 40000], reward: 6000 },
  { kind: 'total', text: 'Bank %s drift points today', goals: [100000, 200000, 350000], reward: 8000 },
  { kind: 'city', text: 'Bank %s points drifting in the city', goals: [40000, 80000], reward: 7000 },
  { kind: 'pass', text: 'Bank %s points drifting on the Hakone pass', goals: [40000, 80000], reward: 7000 },
  { kind: 'tandem', text: 'Bank %s points in tandem drifts', goals: [10000, 25000], reward: 10000 },
  { kind: 'lap', text: 'Complete %s lap(s) of the Hakone pass', goals: [1, 2], reward: 9000 },
  { kind: 'combo', text: 'Reach a ×%s combo', goals: [3, 4, 5], reward: 6000 },
];
// the same picks as the Roblox game for every day (same arithmetic on doubles); capped so it always finishes
Config.dailyFor = function (day) {
  const list = [], used = new Set();
  let seed = day * 7919, tries = 0;
  while (list.length < 3 && tries++ < 1000) {
    seed = (seed * 1103515245 + 12345) % 2147483648;
    const k = seed % Config.DailyPool.length;
    if (!used.has(k)) {
      used.add(k);
      const c = Config.DailyPool[k];
      seed = (seed * 1103515245 + 12345) % 2147483648;
      const goal = c.goals[seed % c.goals.length];
      const g = goal >= 1000 ? `${Math.floor(goal / 1000)},${String(goal % 1000).padStart(3, '0')}` : String(goal);
      list.push({ kind: c.kind, goal, reward: c.reward, text: c.text.replace('%s', g) });
    }
  }
  for (let k = 0; list.length < 3; k++) if (!used.has(k)) { used.add(k); const c = Config.DailyPool[k]; list.push({ kind: c.kind, goal: c.goals[0], reward: c.reward, text: c.text.replace('%s', c.goals[0].toLocaleString('en-US')) }); }
  return list;
};

Config.Admins = [];
Config.Assists = [
  { id: 'touch', name: 'Easy drift', desc: 'Best for touch: auto drift entry, throttle feed, countersteer' },
  { id: 'high', name: 'High', desc: 'Auto countersteer, stability, traction control' },
  { id: 'std', name: 'Medium', desc: 'Auto countersteer, stability' },
  { id: 'low', name: 'Low', desc: 'Light countersteer only' },
  { id: 'off', name: 'Pro', desc: 'No assists, pure simulation' },
];
Config.Quality = {
  low: { trees: 1, lights: 4, shadows: false, bloom: false, smoke: 0.5, windows: 1, signs: false },
  medium: { trees: 2, lights: 2, shadows: true, bloom: false, smoke: 0.8, windows: 2, signs: true },
  high: { trees: 3, lights: 1, shadows: true, bloom: true, smoke: 1, windows: 3, signs: true },
};
Config.DefaultSettings = { quality: 'auto', time: 0, trans: 'auto', assist: '', cam: 0, sens: 1, sound: true, volume: 0.8, start: 'city', v: 2 };
Config.cleanSettings = function (t) {
  const d = Config.DefaultSettings; t = t && typeof t === 'object' ? t : {};
  const num = v => typeof v === 'number' && v === v;
  const out = {};
  out.quality = ['low', 'medium', 'high'].includes(t.quality) ? t.quality : 'auto';
  out.time = num(t.time) ? Math.min(23.75, Math.max(0, t.time)) : d.time;
  out.trans = t.trans === 'manual' ? 'manual' : 'auto';
  out.assist = Config.Assists.some(a => a.id === t.assist) ? t.assist : '';
  out.cam = num(t.cam) ? Math.min(3, Math.max(0, Math.floor(t.cam))) : 0;
  out.sens = num(t.sens) ? Math.min(1.6, Math.max(0.5, t.sens)) : 1;
  out.sound = t.sound !== false;
  out.volume = num(t.volume) ? Math.min(1, Math.max(0, t.volume)) : d.volume;
  out.start = t.v === 2 && t.start === 'pass' ? 'pass' : 'city';
  out.v = 2;
  return out;
};
Config.car = id => Config.Cars.find(c => c.id === id) || Config.Cars[0];
Config.assist = id => Config.Assists.find(a => a.id === id) || Config.Assists[2];

export default Config;
