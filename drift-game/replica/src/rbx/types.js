// Roblox data types for the replica: Vector3, Vector2, CFrame, Color3, UDim, UDim2, NumberSequence,
// ColorSequence, NumberRange, TweenInfo, Enum. Same names and behaviour as on Roblox, so the ported scripts
// read like the originals (operators become methods: a + b -> a.add(b)).
import * as THREE from 'three';

export class Vector3 {
  constructor(x = 0, y = 0, z = 0) { this.X = x; this.Y = y; this.Z = z; }
  static new(x, y, z) { return new Vector3(x, y, z); }
  get Magnitude() { return Math.sqrt(this.X * this.X + this.Y * this.Y + this.Z * this.Z); }
  get Unit() { const m = this.Magnitude || 1; return new Vector3(this.X / m, this.Y / m, this.Z / m); }
  add(o) { return new Vector3(this.X + o.X, this.Y + o.Y, this.Z + o.Z); }
  sub(o) { return new Vector3(this.X - o.X, this.Y - o.Y, this.Z - o.Z); }
  mul(s) { return typeof s === 'number' ? new Vector3(this.X * s, this.Y * s, this.Z * s) : new Vector3(this.X * s.X, this.Y * s.Y, this.Z * s.Z); }
  div(s) { return new Vector3(this.X / s, this.Y / s, this.Z / s); }
  neg() { return new Vector3(-this.X, -this.Y, -this.Z); }
  Dot(o) { return this.X * o.X + this.Y * o.Y + this.Z * o.Z; }
  Cross(o) { return new Vector3(this.Y * o.Z - this.Z * o.Y, this.Z * o.X - this.X * o.Z, this.X * o.Y - this.Y * o.X); }
  Lerp(o, t) { return new Vector3(this.X + (o.X - this.X) * t, this.Y + (o.Y - this.Y) * t, this.Z + (o.Z - this.Z) * t); }
  toThree(v = new THREE.Vector3()) { return v.set(this.X, this.Y, this.Z); }
}
Vector3.zero = new Vector3(0, 0, 0);
Vector3.one = new Vector3(1, 1, 1);
Vector3.yAxis = new Vector3(0, 1, 0);
Vector3.xAxis = new Vector3(1, 0, 0);
Vector3.zAxis = new Vector3(0, 0, 1);

export class Vector2 {
  constructor(x = 0, y = 0) { this.X = x; this.Y = y; }
  static new(x, y) { return new Vector2(x, y); }
  get Magnitude() { return Math.hypot(this.X, this.Y); }
}
Vector2.zero = new Vector2(0, 0);

// CFrame: rotation (3x3, columns = right, up, back) + position, like Roblox
export class CFrame {
  constructor(m) { this.m = m || new THREE.Matrix4(); }
  static new(x = 0, y = 0, z = 0) {
    if (x instanceof Vector3) return new CFrame(new THREE.Matrix4().makeTranslation(x.X, x.Y, x.Z));
    return new CFrame(new THREE.Matrix4().makeTranslation(x, y, z));
  }
  static Angles(rx, ry, rz) { return new CFrame(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(rx, ry, rz, 'XYZ'))); }
  static fromEulerAnglesXYZ(rx, ry, rz) { return CFrame.Angles(rx, ry, rz); }
  static lookAt(at, target, up = Vector3.yAxis) {
    const a = at.toThree(), b = target.toThree();
    let u = up.toThree();
    const d = b.clone().sub(a);
    if (d.lengthSq() < 1e-12) return CFrame.new(at);
    if (Math.abs(d.clone().normalize().dot(u.clone().normalize())) > 0.9999) u = new THREE.Vector3(0, 0, 1);
    const m = new THREE.Matrix4().lookAt(a, b, u); // -Z looks at the target, as on Roblox
    m.setPosition(a);
    return new CFrame(m);
  }
  get Position() { const e = this.m.elements; return new Vector3(e[12], e[13], e[14]); }
  get X() { return this.m.elements[12]; }
  get Y() { return this.m.elements[13]; }
  get Z() { return this.m.elements[14]; }
  get RightVector() { const e = this.m.elements; return new Vector3(e[0], e[1], e[2]); }
  get UpVector() { const e = this.m.elements; return new Vector3(e[4], e[5], e[6]); }
  get LookVector() { const e = this.m.elements; return new Vector3(-e[8], -e[9], -e[10]); }
  mul(o) {
    if (o instanceof CFrame) return new CFrame(this.m.clone().multiply(o.m));
    const v = new THREE.Vector3(o.X, o.Y, o.Z).applyMatrix4(this.m);
    return new Vector3(v.x, v.y, v.z);
  }
  add(v) { const c = this.m.clone(); const e = c.elements; e[12] += v.X; e[13] += v.Y; e[14] += v.Z; return new CFrame(c); }
  sub(v) { return this.add(v.neg()); }
  Inverse() { return new CFrame(this.m.clone().invert()); }
  PointToWorldSpace(v) { return this.mul(v); }
  PointToObjectSpace(v) { return this.Inverse().mul(v); }
  VectorToWorldSpace(v) { const t = new THREE.Vector3(v.X, v.Y, v.Z).transformDirection(this.m); const l = Math.hypot(v.X, v.Y, v.Z); return new Vector3(t.x * l, t.y * l, t.z * l); }
  ToObjectSpace(cf) { return this.Inverse().mul(cf); }
  Lerp(o, t) {
    const p0 = new THREE.Vector3(), q0 = new THREE.Quaternion(), s0 = new THREE.Vector3();
    const p1 = new THREE.Vector3(), q1 = new THREE.Quaternion(), s1 = new THREE.Vector3();
    this.m.decompose(p0, q0, s0); o.m.decompose(p1, q1, s1);
    return new CFrame(new THREE.Matrix4().compose(p0.lerp(p1, t), q0.slerp(q1, t), new THREE.Vector3(1, 1, 1)));
  }
}
CFrame.identity = new CFrame();

export class Color3 {
  constructor(r = 0, g = 0, b = 0) { this.R = r; this.G = g; this.B = b; }
  static new(r, g, b) { return new Color3(r, g, b); }
  static fromRGB(r, g, b) { return new Color3(r / 255, g / 255, b / 255); }
  static fromHex(h) { h = String(h).replace('#', ''); return Color3.fromRGB(parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)); }
  Lerp(o, t) { return new Color3(this.R + (o.R - this.R) * t, this.G + (o.G - this.G) * t, this.B + (o.B - this.B) * t); }
  ToHex() { const c = v => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, '0'); return c(this.R) + c(this.G) + c(this.B); }
  css(alpha = 1) { const c = v => Math.round(Math.min(1, Math.max(0, v)) * 255); return alpha >= 1 ? `rgb(${c(this.R)},${c(this.G)},${c(this.B)})` : `rgba(${c(this.R)},${c(this.G)},${c(this.B)},${alpha.toFixed(3)})`; }
  three() { return new THREE.Color(this.R, this.G, this.B); }
}

export class UDim {
  constructor(scale = 0, offset = 0) { this.Scale = scale; this.Offset = offset; }
  static new(s, o) { return new UDim(s, o); }
}
export class UDim2 {
  constructor(xs = 0, xo = 0, ys = 0, yo = 0) { this.X = new UDim(xs, xo); this.Y = new UDim(ys, yo); }
  static new(xs, xo, ys, yo) { return new UDim2(xs, xo, ys, yo); }
  static fromScale(x, y) { return new UDim2(x, 0, y, 0); }
  static fromOffset(x, y) { return new UDim2(0, x, 0, y); }
  add(o) { return new UDim2(this.X.Scale + o.X.Scale, this.X.Offset + o.X.Offset, this.Y.Scale + o.Y.Scale, this.Y.Offset + o.Y.Offset); }
  sub(o) { return new UDim2(this.X.Scale - o.X.Scale, this.X.Offset - o.X.Offset, this.Y.Scale - o.Y.Scale, this.Y.Offset - o.Y.Offset); }
  Lerp(o, t) { const l = (a, b) => a + (b - a) * t; return new UDim2(l(this.X.Scale, o.X.Scale), l(this.X.Offset, o.X.Offset), l(this.Y.Scale, o.Y.Scale), l(this.Y.Offset, o.Y.Offset)); }
}

export class NumberSequenceKeypoint { constructor(t, v) { this.Time = t; this.Value = v; } static new(t, v) { return new NumberSequenceKeypoint(t, v); } }
export class NumberSequence {
  constructor(a, b) {
    if (Array.isArray(a)) this.Keypoints = a;
    else this.Keypoints = [new NumberSequenceKeypoint(0, a), new NumberSequenceKeypoint(1, b === undefined ? a : b)];
  }
  static new(a, b) { return new NumberSequence(a, b); }
  at(t) { const k = this.Keypoints; for (let i = 0; i < k.length - 1; i++) if (t <= k[i + 1].Time) { const f = (t - k[i].Time) / ((k[i + 1].Time - k[i].Time) || 1); return k[i].Value + (k[i + 1].Value - k[i].Value) * f; } return k[k.length - 1].Value; }
}
export class ColorSequenceKeypoint { constructor(t, v) { this.Time = t; this.Value = v; } static new(t, v) { return new ColorSequenceKeypoint(t, v); } }
export class ColorSequence {
  constructor(a, b) {
    if (Array.isArray(a)) this.Keypoints = a;
    else this.Keypoints = [new ColorSequenceKeypoint(0, a), new ColorSequenceKeypoint(1, b || a)];
  }
  static new(a, b) { return new ColorSequence(a, b); }
}
export class NumberRange { constructor(a, b) { this.Min = a; this.Max = b === undefined ? a : b; } static new(a, b) { return new NumberRange(a, b); } }

// Enum: Enum.Material.Grass -> { EnumType: 'Material', Name: 'Grass' } (the same object every time)
const enumCache = new Map();
export const Enum = new Proxy({}, {
  get(_, type) {
    let t = enumCache.get(type);
    if (!t) {
      const items = new Map();
      t = new Proxy({}, { get(_, name) { if (name === 'toString') return () => `Enum.${type}`; let it = items.get(name); if (!it) { it = { EnumType: type, Name: name, toString() { return `Enum.${type}.${name}`; } }; items.set(name, it); } return it; } });
      enumCache.set(type, t);
    }
    return t;
  },
});

export class TweenInfo {
  constructor(time = 1, style = Enum.EasingStyle.Quad, dir = Enum.EasingDirection.Out) { this.Time = time; this.EasingStyle = style; this.EasingDirection = dir; }
  static new(t, s, d) { return new TweenInfo(t, s, d); }
}

export class Font {
  constructor(family, weight) { this.Family = family; this.Weight = weight; }
  static new(f, w) { return new Font(f, w); }
}
