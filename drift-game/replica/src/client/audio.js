// Port of the Roblox game's Audio.luau with its own 7 sound files (roblox/sounds): three on-throttle layers
// (1,800 / 4,200 / 7,000 rpm) crossfaded and pitched to the live rpm, an off-throttle layer, tyre screech,
// wind, a turbo blow-off when you lift at high revs, and a stutter on the rev limiter. Sound objects work like
// Roblox's (Volume, PlaybackSpeed, Looped, Play) on top of Web Audio.
import low from '../data/sounds/kaido_engine_low.ogg';
import mid from '../data/sounds/kaido_engine_mid.ogg';
import high from '../data/sounds/kaido_engine_high.ogg';
import off from '../data/sounds/kaido_engine_off.ogg';
import skid from '../data/sounds/kaido_skid.ogg';
import blow from '../data/sounds/kaido_blowoff.ogg';
import wind from '../data/sounds/kaido_wind.ogg';

const FILES = { kaido_engine_low: low, kaido_engine_mid: mid, kaido_engine_high: high, kaido_engine_off: off, kaido_skid: skid, kaido_blowoff: blow, kaido_wind: wind };
const NAMES = ['kaido_engine_low', 'kaido_engine_mid', 'kaido_engine_high', 'kaido_engine_off', 'kaido_skid', 'kaido_blowoff', 'kaido_wind'];
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
  mode: () => 'full',
  count: () => 7,
};
// own = the player's car
Audio.new = function (car, own) {
  const snd = (name, looped) => { const s = new Sound(name, looped); if (looped) s.Play(); return s; };
  const self = {
    layers: [snd(NAMES[0], true), snd(NAMES[1], true), snd(NAMES[2], true)], off: snd('kaido_engine_off', true), skid: snd('kaido_skid', true),
    wind: own ? snd('kaido_wind', true) : null, blow: snd('kaido_blowoff', false), car, load: 0, lastThr: 0, own, t: 0, check: 0,
  };
  // rpm, throttle (0..1), slide (0..1), speed in km/h, limiter on, master volume (0..1)
  self.update = function (dt, rpm, thr, slide, kmh, limiter, vol0) {
    this.t += dt;
    if (ctx && ctx.state === 'suspended') ctx.resume();
    this.check += dt;
    if (this.check > 1) { this.check = 0; for (const s of [...this.layers, this.off, this.skid, this.wind]) if (s && !s.src) s.Play(); }
    const car = this.car, pitch = car.pitch || 1;
    this.load += (thr - this.load) * Math.min(1, dt * 8);
    const norm = rpm * (7000 / car.red);
    const chop = limiter && Math.sin(this.t * 2 * Math.PI * 16) > 0 ? 0.35 : 1;
    const vol = (this.own ? 0.9 : 0.7) * vol0 * chop;
    const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
    this.layers.forEach((s, k) => {
      const c = LAYER_RPM[k];
      let w = clamp(1 - Math.abs(Math.log(norm / c) / Math.log(2.1)), 0, 1);
      if (k === 0 && norm < c) w = 1;
      if (k === 2 && norm > c) w = 1;
      s.PlaybackSpeed = clamp(norm / c * pitch, 0.4, 2.2);
      s.Volume = vol * w * (0.25 + 0.75 * this.load);
    });
    this.off.PlaybackSpeed = clamp(norm / 3500 * pitch, 0.4, 2.2);
    this.off.Volume = vol * 0.8 * (1 - this.load) * clamp((norm - 1100) / 1200, 0.15, 1);
    this.skid.Volume = vol0 * 0.65 * clamp(slide, 0, 1) * clamp(kmh / 30, 0, 1);
    this.skid.PlaybackSpeed = 0.85 + 0.25 * clamp(slide, 0, 1);
    if (this.wind) { this.wind.Volume = vol0 * 0.5 * clamp((kmh - 30) / 170, 0, 1); this.wind.PlaybackSpeed = 0.8 + kmh / 400; }
    if (car.turbo && this.lastThr > 0.7 && thr < 0.2 && rpm > car.red * 0.55) {
      this.blow.Volume = vol0 * 0.55; this.blow.PlaybackSpeed = 0.9 + Math.random() * 0.2; this.blow.Play();
    }
    this.lastThr = thr;
  };
  self.mute = function () { for (const s of this.layers) s.Volume = 0; this.off.Volume = 0; this.skid.Volume = 0; if (this.wind) this.wind.Volume = 0; };
  self.destroy = function () { for (const s of [...this.layers, this.off, this.skid, this.blow, this.wind]) if (s) s.Destroy(); };
  return self;
};

// the combo ping (Roblox's built-in electronicpingshort.wav): a short bright ping, pitched with the combo
export function comboPing(volume, speed) {
  if (!ctx) return;
  const t = ctx.currentTime, o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain();
  o.type = 'sine'; o.frequency.value = 1320 * speed; o2.type = 'sine'; o2.frequency.value = 2640 * speed;
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(volume * 0.5, t + 0.005); g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
  o.connect(g); o2.connect(g); g.connect(master); o.start(t); o2.start(t); o.stop(t + 0.4); o2.stop(t + 0.4);
}
