// Kaido Drift car physics: port of the Roblox game's CarPhysics.luau (itself a line-for-line port of the
// browser game's four-tyre simulation). Units are metres, kg, seconds; the client converts to studs.
const G = 9.81, HCG = 0.5, KPK = 0.1, APK = 0.14, ENTRY_YAW = -1, DEG = Math.PI / 180;
export const RW = 0.31; // wheel radius (m)

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); };
const sign = x => (x > 0 ? 1 : x < 0 ? -1 : 0);
const tyreCurve = s => Math.sin(1.35 * Math.atan(2.36 * s));
function tyreXY(kap, alpha, D) {
  const sx = kap / KPK, sy = alpha / APK, s = Math.sqrt(sx * sx + sy * sy);
  if (s < 1e-6) return [0, 0];
  const F = D * tyreCurve(s);
  return [F * sx / s, -F * sy / s];
}
export function torqueAt(c, rpm) {
  if (rpm >= c.red + 150) return 0;
  if (rpm < c.peak) return c.torque * (0.55 + 0.45 * Math.sin(Math.PI / 2 * clamp((rpm - 1000) / (c.peak - 1000), 0, 1)));
  return c.torque * (1 - 0.3 * ((rpm - c.peak) / (c.red - c.peak)) ** 2);
}
const gearRatio = (P, c) => (P.gear < 0 ? -3.4 : c.gears[P.gear - 1]) * c.final;

export const ASSISTS = {
  off: { counter: 0, steerRate: 4.5, speedSteer: false, abs: false, tcs: false, esp: 0, espAngle: 9, damp: 0, entry: 0, thrMod: false },
  low: { counter: 0.35, steerRate: 6, speedSteer: true, abs: true, tcs: false, esp: 0, espAngle: 9, damp: 0.6, entry: 0.35, thrMod: false },
  std: { counter: 0.7, steerRate: 7.5, speedSteer: true, abs: true, tcs: false, esp: 8, espAngle: 1.15, damp: 1.6, entry: 0.5, thrMod: false },
  high: { counter: 0.95, steerRate: 9, speedSteer: true, abs: true, tcs: true, esp: 16, espAngle: 0.95, damp: 2.8, entry: 0.7, thrMod: true },
  touch: { counter: 1, steerRate: 9, speedSteer: true, abs: true, tcs: false, esp: 12, espAngle: 1.0, damp: 2.4, entry: 1, thrMod: true },
};

export function newCar(x, z, h) {
  return {
    x, z, h, vx: 0, vz: 0, r: 0, wr: 0, gear: 1, shiftT: 0, revT: 0, delta: 0, ax: 0, ay: 0,
    boost: 0, eng: 900, rpm: 900, slip: 0, drifting: false, rearSlip: 0, frontLock: false, limiter: false,
    bPrev: null, entryT: 0, entryDir: 0, entryArmed: true, offT: 0, kickT: 0, u: 0, thrEff: 0, brkEff: 0, loads: [1, 1, 1, 1],
  };
}
export function shiftUp(P, c) { if (P.gear > 0 && P.gear < c.gears.length) { P.gear += 1; P.shiftT = 0.12; } }
export function shiftDown(P, c) { if (P.gear > 1) { P.gear -= 1; P.shiftT = 0.1; } }

// one step. input = { throttle, brake, hand, steer (+ = right) }; settings = { assist, trans, sens }
export function step(P, c, input, settings, dt) {
  const m = c.mass, Lw = c.b.wb, a = Lw * (1 - c.front), b = Lw * c.front, Iz = m * a * b * 1.1;
  const fx = Math.sin(P.h), fz = Math.cos(P.h), lx = fz, lz = -fx;
  const u = P.vx * fx + P.vz * fz, vy = P.vx * lx + P.vz * lz;
  const sp = Math.sqrt(P.vx * P.vx + P.vz * P.vz);
  let thr = input.throttle, brk = input.brake;
  const hand = input.hand, A = ASSISTS[settings.assist] || ASSISTS.std;
  if (A.thrMod && thr > 0.05 && P.gear > 0) { const ab = Math.abs(P.bPrev || 0); if (ab > 0.45) thr *= clamp(1 - (ab - 0.45) / 0.4, 0.3, 1); }
  if (A.entry > 0 && P.gear > 0 && u > 8 && u < 45 && thr > 0.6 && Math.abs(input.steer) > 0.65 && P.entryArmed && Math.abs(P.bPrev || 0) < 0.12) {
    P.entryT = 0.5; P.entryDir = sign(input.steer); P.entryArmed = false;
  }
  if (Math.abs(input.steer) < 0.3 || thr < 0.1) P.entryArmed = true;
  P.entryT = Math.max(0, P.entryT - dt);
  const eK = A.entry * P.entryT / 0.5;
  if (P.gear > 0) {
    if (brk > 0.2 && thr < 0.05 && u < 0.4) { P.revT += dt; if (P.revT > 0.3) { P.gear = -1; P.revT = 0; } } else P.revT = 0;
  } else if (thr > 0.2 && u > -0.4) P.gear = 1;
  if (P.gear < 0) { const t = thr; thr = brk; brk = t; }
  const ratio = gearRatio(P, c), ar = Math.abs(ratio);
  P.shiftT = Math.max(0, P.shiftT - dt);
  if (settings.trans !== 'manual' && P.gear > 0 && P.shiftT === 0) {
    const roadRpm = Math.abs(u) / RW * ar * 9.549;
    if (roadRpm > c.red * 0.97 && P.gear < c.gears.length) { P.gear += 1; P.shiftT = 0.16; }
    else if (P.gear > 1 && roadRpm < c.red * 0.45 && Math.abs(u) / RW * c.gears[P.gear - 2] * c.final * 9.549 < c.red * 0.88) { P.gear -= 1; P.shiftT = 0.1; }
  }
  const wheelRpm = Math.abs(P.wr) * ar * 9.549;
  const clutchSlip = wheelRpm < 1200 || hand;
  const eng = clutchSlip ? Math.max(wheelRpm, 900 + thr * 3400) : wheelRpm;
  if (thr < 0.15) P.offT += dt;
  else { if (P.offT > 0.03 && P.offT < 0.45 && thr > 0.6 && Math.abs(input.steer) > 0.25 && u > 8) P.kickT = 0.35; P.offT = 0; }
  P.kickT = Math.max(0, P.kickT - dt);
  let tq = 0;
  if (P.shiftT > 0 || hand) tq = 0;
  else if (thr > 0.02) tq = eng > c.red ? 0 : torqueAt(c, eng) * thr * (c.turbo ? 0.62 + 0.38 * P.boost : 1) * (P.kickT > 0 ? 1.8 : 1);
  else if (!clutchSlip) tq = -sign(P.wr * ratio) * c.torque * 0.14 * clamp(eng / c.red, 0.2, 1);
  P.limiter = eng > c.red && thr > 0.02;
  if (c.turbo) { const want = smooth(2400, 4300, eng) * (thr > 0.05 && !hand ? thr : 0); P.boost += (want - P.boost) * Math.min(1, dt * (want > P.boost ? 2.2 : 5)); }
  else P.boost = 1;
  const Tdrive = tq * ratio * 0.85;
  const tw = c.b.wid - 0.2, htw = tw / 2;
  const Wf = m * G * b / Lw / 2, Wr = m * G * a / Lw / 2;
  const dLong = m * P.ax * HCG / Lw / 2, dLatF = m * P.ay * HCG / tw * 0.62, dLatR = m * P.ay * HCG / tw * 0.38;
  const minZ = m * G * 0.02;
  const Fz = [Math.max(minZ, Wf - dLong - dLatF), Math.max(minZ, Wf - dLong + dLatF), Math.max(minZ, Wr + dLong - dLatR), Math.max(minZ, Wr + dLong + dLatR)];
  const grip = i => { const front = i < 2; return c.mu * (front ? 1.0 : 1.06 * (1 - 0.6 * eK)) * Fz[i] * (1 - 0.08 * (Fz[i] / (front ? Wf : Wr) - 1)); };
  const WX = [a, a, -b, -b], WY = [htw, -htw, htw, -htw];
  const beta = sp > 1.5 && P.gear > 0 && u > -0.5 * sp ? Math.atan2(vy, Math.max(u, 0.01)) : 0;
  const lock = c.lock * DEG, dIn = -input.steer * settings.sens;
  const betaR = sp > 1.5 && P.gear > 0 && u > 0.5 ? Math.atan2(vy - b * P.r, u) : 0;
  const betaF = sp > 1.5 && P.gear > 0 && u > 0.5 ? Math.atan2(vy + a * P.r, u) : 0;
  const sliding = smooth(0.1, 0.25, Math.abs(betaR));
  const oversteer = sign(betaF) === -sign(P.r) ? 1 : 0;
  const counter = sliding > 0 && sign(dIn) === sign(betaR);
  const inLock = A.speedSteer && !counter ? lerp(lock / (1 + (Math.abs(u) / 14) ** 1.5), lock, sliding) : lock;
  const dT = clamp(dIn * inLock + A.counter * sliding * oversteer * betaF, -lock, lock);
  P.delta += clamp(dT - P.delta, -A.steerRate * dt, A.steerRate * dt);
  const d = P.delta, ack = sign(d) * Math.min(0.06, Math.abs(d) * 0.12);
  const DEL = [d + ack, d - ack, 0, 0];
  const brakeTotal = brk * m * G * 0.95;
  const Fxw = [0, 0, 0, 0], Fyw = [0, 0, 0, 0];
  let lockF = false;
  for (let i = 0; i < 2; i++) {
    const ui = u - P.r * WY[i], vi = vy + P.r * WX[i], cd = Math.cos(DEL[i]), sd = Math.sin(DEL[i]);
    const uw = ui * cd + vi * sd, vw = -ui * sd + vi * cd, D = grip(i), alpha = Math.atan2(vw, Math.max(Math.abs(uw), 1.5));
    let bf = brakeTotal * 0.65 / 2; if (A.abs) bf = Math.min(bf, D * 0.92);
    if (bf > D * 1.02 && Math.abs(uw) > 2) {
      lockF = true; let vv = Math.sqrt(uw * uw + vw * vw); if (vv === 0) vv = 1;
      Fxw[i] = -uw / vv * D * 0.9; Fyw[i] = -vw / vv * D * 0.9;
    } else {
      Fyw[i] = -D * sign(alpha) * tyreCurve(Math.abs(alpha) / APK);
      Fxw[i] = Math.abs(uw) > 0.2 ? -sign(uw) * bf : 0;
      const t = Math.sqrt(Fxw[i] ** 2 + Fyw[i] ** 2); if (t > D) { Fxw[i] *= D / t; Fyw[i] *= D / t; }
    }
  }
  P.frontLock = lockF;
  const Iw = 1.6 + c.engI * ratio * ratio * (clutchSlip ? 0.25 : 1);
  const rr = [2, 3].map(i => { const ui = u - P.r * WY[i], vi = vy + P.r * WX[i]; return { i, ui, vi, den: Math.max(Math.abs(ui), 2), D: grip(i), alpha: Math.atan2(vi, Math.max(Math.abs(ui), 1.5)) }; });
  let Fx0 = 0, slope = 0;
  for (const w of rr) { Fx0 += tyreXY((P.wr * RW - w.ui) / w.den, w.alpha, w.D)[0]; slope += w.D * 1.35 * 2.36 / KPK * RW / w.den; }
  let Tdr = Tdrive;
  if (A.tcs && thr > 0) { const spinS = P.wr * RW - u; if (spinS > 6 + Math.abs(vy)) Tdr *= clamp(1 - (spinS - 6) / 10, 0.35, 1); }
  let wr = P.wr + dt * (Tdr - RW * Fx0) / (Iw + dt * RW * slope);
  const Tb = brakeTotal * 0.35 * RW + (hand ? 4200 : 0);
  if (Tb > 0) { const dw = Tb * dt / Iw; wr = Math.abs(wr) <= dw ? 0 : wr - sign(wr) * dw; }
  P.wr = wr;
  for (const w of rr) { const t = tyreXY((wr * RW - w.ui) / w.den, w.alpha, w.D); Fxw[w.i] = t[0]; Fyw[w.i] = t[1]; }
  let Fxb = 0, Fyb = 0, Mz = 0;
  for (let i = 0; i < 4; i++) {
    const cd = Math.cos(DEL[i]), sd = Math.sin(DEL[i]), fxb = Fxw[i] * cd - Fyw[i] * sd, fyb = Fxw[i] * sd + Fyw[i] * cd;
    Fxb += fxb; Fyb += fyb; Mz += WX[i] * fyb - WY[i] * fxb;
  }
  Fxb -= 0.6 * c.CdA * u * Math.abs(u) + m * G * 0.013 * clamp(u, -1, 1);
  if (A.esp > 0 && Math.abs(beta) > A.espAngle && sp > 5) Mz += A.esp * Iz * (beta - sign(beta) * A.espAngle);
  const bRate = (betaR - (P.bPrev ?? betaR)) / dt; P.bPrev = betaR;
  if (A.damp > 0 && sliding > 0) Mz += A.damp * sliding * Iz * clamp(bRate, -4, 4);
  if (eK > 0) Mz += ENTRY_YAW * P.entryDir * eK * Iz * 3.2;
  const FzSum = Fz[0] + Fz[1] + Fz[2] + Fz[3];
  for (let i = 0; i < 4; i++) P.loads[i] = Fz[i] / FzSum * 4;
  P.vx += (Fxb * fx + Fyb * lx) / m * dt; P.vz += (Fxb * fz + Fyb * lz) / m * dt;
  P.r += Mz / Iz * dt;
  if (sp < 2) P.r *= 1 - Math.min(1, (2 - sp) * 3 * dt);
  if (sp < 0.35 && thr < 0.05 && (brk > 0.05 || hand)) { P.vx = 0; P.vz = 0; P.r = 0; P.wr = 0; }
  P.h += P.r * dt; P.x += P.vx * dt; P.z += P.vz * dt;
  P.ax += (Fxb / m - P.ax) * Math.min(1, dt * 10); P.ay += (Fyb / m - P.ay) * Math.min(1, dt * 10);
  P.eng = eng; P.u = u; P.thrEff = thr; P.brkEff = brk;
  P.slip = sp > 1.5 ? Math.atan2(-vy, Math.abs(u)) : 0;
  P.rearSlip = Math.sqrt((wr * RW - u) ** 2 + (vy - b * P.r) ** 2);
  const sp2 = Math.sqrt(P.vx * P.vx + P.vz * P.vz);
  P.drifting = P.drifting ? (Math.abs(P.slip) > 0.1 && sp2 > 5) : (Math.abs(P.slip) > 0.19 && sp2 > 7);
}

export function wallHit(P, c, nx, nz, depth, rpx, rpz) {
  const m = c.mass, Lw = c.b.wb, a = Lw * (1 - c.front), b = Lw * c.front, Iz = m * a * b * 1.1;
  P.x += nx * depth; P.z += nz * depth;
  const vpx = P.vx + P.r * rpz, vpz = P.vz - P.r * rpx, vn = vpx * nx + vpz * nz;
  if (vn < 0) {
    const k = nx * rpz - nz * rpx, j = -1.25 * vn / (1 / m + k * k / Iz);
    P.vx += j * nx / m; P.vz += j * nz / m; P.r += j * k / Iz;
    const tx = -nz, tz = nx, vt = vpx * tx + vpz * tz, kt = tx * rpz - tz * rpx;
    const jt = clamp(-vt / (1 / m + kt * kt / Iz), -0.3 * j, 0.3 * j);
    P.vx += jt * tx / m; P.vz += jt * tz / m; P.r += jt * kt / Iz;
    return -vn;
  }
  return 0;
}

export function visual(P, c, dt) {
  P.rpm += (P.eng - P.rpm) * Math.min(1, dt * 14);
  if (P.limiter) P.rpm = c.red - Math.random() * 250;
}
