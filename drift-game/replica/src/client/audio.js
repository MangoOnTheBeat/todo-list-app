// Port of the Roblox game's Audio.luau with its own 7 sound files (roblox/sounds): three on-throttle layers
// (1,800 / 4,200 / 7,000 rpm) crossfaded and pitched to the live rpm, an off-throttle layer, tyre screech,
// wind, a turbo blow-off when you lift at high revs, and a stutter on the rev limiter. Sound objects work like
// Roblox's (Volume, PlaybackSpeed, Looped, Play) on top of Web Audio.
import skid from '../data/sounds/kaido_skid.ogg';
import wind from '../data/sounds/kaido_wind.ogg';

// your Roblox game plays one engine loop from the Toolbox (a Ferrari V8 with a Capristo exhaust), so Audio.luau
// runs in its "simple" mode: that loop pitched with the revs. The loop is made here (see makeV8).
const FILES = { kaido_skid: skid, kaido_wind: wind };
const NAMES = ['kaido_skid', 'kaido_wind'];
const LAYER_RPM = [1800, 4200, 7000];
let ctx = null, master = null;
const buffers = {};
// browsers start audio only after a tap or key press
export function unlockAudio() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext; if (!AC) return;
    ctx = new AC(); master = ctx.createGain(); master.connect(ctx.destination);
    for (const n of NAMES) {
      const bytes = FILES[n];
      ctx.decodeAudioData(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)).then(b => { buffers[n] = b; for (const s of live) if (s.name === n && s.Looped && s.playing) s.Play(); }).catch(() => { });
    }
    buffers.engine = makeV8(ctx);
    for (const s of live) if (s.name === 'engine' && s.playing) s.Play();
  }
  if (ctx.state === 'suspended') ctx.resume();
}
['pointerdown', 'keydown', 'touchend'].forEach(e => addEventListener(e, unlockAudio, { capture: true }));
const live = new Set();

class Sound {
  constructor(name, looped) { this.name = name; this.Looped = looped; this._vol = 0; this._speed = 1; this.src = null; this.gain = null; this.playing = false; live.add(this); }
  get Volume() { return this._vol; } set Volume(v) { this._vol = v; if (this.gain) this.gain.gain.setTargetAtTime(v, ctx.currentTime, 0.02); }
  get PlaybackSpeed() { return this._speed; } set PlaybackSpeed(v) { this._speed = v; if (this.src) this.src.playbackRate.setTargetAtTime(v, ctx.currentTime, 0.02); }
  get IsPlaying() { return this.playing; }
  Play() {
    this.playing = true;
    if (!ctx || !buffers[this.name]) return;
    if (this.src && this.Looped) return;
    if (!this.gain) { this.gain = ctx.createGain(); this.gain.gain.value = this._vol; this.gain.connect(master); }
    const s = ctx.createBufferSource(); s.buffer = buffers[this.name]; s.loop = this.Looped; s.playbackRate.value = this._speed;
    s.connect(this.gain); s.start();
    if (!this.Looped) s.onended = () => { if (this.src === s) { this.src = null; this.playing = false; } };
    this.src = s;
  }
  Destroy() { live.delete(this); try { if (this.src) this.src.stop(); } catch { } if (this.gain) this.gain.disconnect(); this.src = null; this.playing = false; }
}

export const Audio = {
  available: () => true,
  mode: () => 'simple',
  count: () => 0,
};
// own = the player's car (Audio.new in simple mode: one engine loop; tyre screech and wind)
Audio.new = function (car, own) {
  const snd = (name, looped) => { const s = new Sound(name, looped); if (looped) s.Play(); return s; };
  const self = { engine: snd('engine', true), skid: snd('kaido_skid', true), wind: own ? snd('kaido_wind', true) : null, car, load: 0, lastThr: 0, own, t: 0, check: 0 };
  // rpm, throttle (0..1), slide (0..1), speed in km/h, limiter on, master volume (0..1)
  self.update = function (dt, rpm, thr, slide, kmh, limiter, vol0) {
    this.t += dt;
    if (ctx && ctx.state === 'suspended') ctx.resume();
    this.check += dt;
    if (this.check > 1) { this.check = 0; for (const s of [this.engine, this.skid, this.wind]) if (s && !s.src) s.Play(); }
    const car = this.car, pitch = car.pitch || 1;
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    this.load += (thr - this.load) * Math.min(1, dt * 8);
    const norm = rpm * (7000 / car.red);
    const chop = limiter && Math.sin(this.t * 2 * Math.PI * 16) > 0 ? 0.35 : 1;
    const vol = (this.own ? 0.9 : 0.7) * vol0 * chop;
    // one engine loop: pitch follows the revs, volume follows the throttle
    this.engine.PlaybackSpeed = clamp(norm / 3500 * pitch, 0.45, 2.3);
    this.engine.Volume = vol * (0.35 + 0.65 * this.load);
    this.skid.Volume = vol0 * 0.65 * clamp(slide, 0, 1) * clamp(kmh / 30, 0, 1);
    this.skid.PlaybackSpeed = 0.85 + 0.25 * clamp(slide, 0, 1);
    if (this.wind) { this.wind.Volume = vol0 * 0.5 * clamp((kmh - 30) / 170, 0, 1); this.wind.PlaybackSpeed = 0.8 + kmh / 400; }
    this.lastThr = thr;
  };
  self.mute = function () { this.engine.Volume = 0; this.skid.Volume = 0; if (this.wind) this.wind.Volume = 0; };
  self.destroy = function () { for (const s of [this.engine, this.skid, this.wind]) if (s) s.Destroy(); };
  return self;
};

// A Ferrari flat-plane V8 through a Capristo valved exhaust, recorded at 3,500 rpm (the speed the Roblox
// script treats as normal pitch). Eight evenly spaced firing pulses every two turns of the crank, each one
// ringing the exhaust's resonances, with the small cylinder-to-cylinder differences that give a real engine
// its texture, then the raspy edge of a straight-through exhaust. 58 whole cycles, so the loop is seamless.
function makeV8(ac) {
  const SR = 44100, CYCLE = 1512, N = CYCLE * 58; // 720° at 3,500 rpm is exactly 1,512 samples
  const buf = ac.createBuffer(1, N, SR), out = buf.getChannelData(0);
  let seed = 4411; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  const cyl = Array.from({ length: 8 }, (_, k) => 0.86 + 0.28 * rnd() + (k % 2 ? 0.05 : -0.05)); // bank to bank
  // exhaust resonances: [frequency Hz, decay s, level]
  const modes = [[118, 0.010, 0.55], [236, 0.008, 0.9], [470, 0.006, 0.75], [940, 0.0045, 0.55], [1650, 0.003, 0.42], [2900, 0.0018, 0.3], [4600, 0.0011, 0.18]];
  const len = 900;
  const noise = new Float32Array(len); for (let i = 0; i < len; i++) noise[i] = rnd() * 2 - 1;
  for (let p = 0; p < 58 * 8; p++) {
    const start = Math.round(p * CYCLE / 8), amp = cyl[p % 8] * (0.93 + 0.14 * rnd());
    const ph = modes.map(() => rnd() * 0.6);
    for (let i = 0; i < len; i++) {
      const t = i / SR; let v = 0;
      for (let k = 0; k < modes.length; k++) { const [f, d, a] = modes[k]; v += a * Math.exp(-t / d) * Math.sin(2 * Math.PI * f * t + ph[k]); }
      v += 0.55 * noise[i] * Math.exp(-t / 0.0016) * amp;  // the crack of each exhaust pulse
      out[(start + i) % N] += v * amp;
    }
  }
  // low rumble at half order (the deep note under the scream) and the Capristo rasp (soft clipping)
  let peak = 0;
  for (let i = 0; i < N; i++) {
    const t = i / SR;
    let v = out[i] + 0.18 * Math.sin(2 * Math.PI * 116.67 * t) + 0.08 * Math.sin(2 * Math.PI * 58.33 * t);
    v = Math.tanh(v * 0.7) + 0.06 * Math.tanh(v * 5);
    out[i] = v; peak = Math.max(peak, Math.abs(v));
  }
  // gentle high cut so it's crisp but not fizzy
  let y = 0; for (let i = 0; i < N * 2; i++) { const j = i % N; y += (out[j] - y) * 0.55; if (i >= N) out[j] = y; }
  let mean = 0; for (let i = 0; i < N; i++) mean += out[i] / N;
  peak = 0; for (let i = 0; i < N; i++) { out[i] -= mean; peak = Math.max(peak, Math.abs(out[i])); }
  for (let i = 0; i < N; i++) out[i] *= 0.9 / peak;
  return buf;
}

// the combo ping (Roblox's built-in electronicpingshort.wav): a short bright ping, pitched with the combo
export function comboPing(volume, speed) {
  if (!ctx) return;
  const t = ctx.currentTime, o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain();
  o.type = 'sine'; o.frequency.value = 1320 * speed; o2.type = 'sine'; o2.frequency.value = 2640 * speed;
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(volume * 0.5, t + 0.005); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(g); o2.connect(g); g.connect(master); o.start(t); o2.start(t); o.stop(t + 0.4); o2.stop(t + 0.4);
}
