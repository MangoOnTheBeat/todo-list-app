// Roblox engine basics for the replica: signals, instances with attributes, TweenService, RunService,
// UserInputService (keyboard, mouse, touch, gamepad), task, Lighting and the services the scripts use.
import { Vector3, Vector2, Enum, TweenInfo, UDim2, Color3 } from './types.js';

export class Signal {
  constructor() { this.fns = []; }
  Connect(fn) { const c = { fn, Connected: true, Disconnect: () => { c.Connected = false; this.fns = this.fns.filter(x => x !== c); } }; this.fns.push(c); return c; }
  Once(fn) { const c = this.Connect((...a) => { c.Disconnect(); fn(...a); }); return c; }
  Fire(...a) { for (const c of [...this.fns]) if (c.Connected) { try { c.fn(...a); } catch (e) { reportError(e); } } }
}
const errors = new Signal();
export function reportError(e) { console.error(e); errors.Fire(String(e && e.message || e), String(e && e.stack || '')); }

const CLASS_TREE = {
  Instance: null, Folder: 'Instance', Model: 'Instance', ScreenGui: 'LayerCollector', LayerCollector: 'Instance', BillboardGui: 'LayerCollector',
  GuiObject: 'GuiBase2d', GuiBase2d: 'Instance', Frame: 'GuiObject', TextLabel: 'GuiObject', TextButton: 'GuiButton', GuiButton: 'GuiObject',
  TextBox: 'GuiObject', ScrollingFrame: 'GuiObject', CanvasGroup: 'GuiObject', ImageLabel: 'GuiObject',
  UIComponent: 'Instance', UICorner: 'UIComponent', UIPadding: 'UIComponent', UIListLayout: 'UIComponent', UIStroke: 'UIComponent', UIGradient: 'UIComponent', UIScale: 'UIComponent',
  Sound: 'Instance', RemoteEvent: 'Instance', RemoteFunction: 'Instance', UnreliableRemoteEvent: 'Instance', BlurEffect: 'PostEffect', PostEffect: 'Instance',
  BloomEffect: 'PostEffect', ColorCorrectionEffect: 'PostEffect', Atmosphere: 'Instance', Sky: 'Instance', Player: 'Instance', PlayerGui: 'Instance', Lighting: 'Instance',
};
export function isA(cls, want) { for (let c = cls; c; c = CLASS_TREE[c]) if (c === want) return true; return false; }

export class Instance {
  constructor(className) {
    this.ClassName = className; this._name = className; this._parent = null; this._children = []; this._attrs = new Map();
    this._attrSignals = new Map(); this._propSignals = new Map();
    this.ChildAdded = new Signal(); this.ChildRemoved = new Signal(); this.DescendantAdded = new Signal(); this.Destroying = new Signal(); this.Changed = new Signal();
  }
  get Name() { return this._name; } set Name(v) { this._name = String(v); }
  get Parent() { return this._parent; }
  set Parent(p) {
    if (p === this._parent) return;
    const old = this._parent;
    if (old) { old._children = old._children.filter(c => c !== this); old._childRemoved(this); old.ChildRemoved.Fire(this); }
    this._parent = p || null;
    if (p) { p._children.push(this); p._childAdded(this); p.ChildAdded.Fire(this); for (let a = p; a; a = a._parent) a.DescendantAdded.Fire(this); }
    this._parentChanged(old, p);
  }
  _childAdded() { } _childRemoved() { } _parentChanged() { }
  IsA(c) { return isA(this.ClassName, c); }
  GetChildren() { return [...this._children]; }
  GetDescendants() { const out = []; const w = x => { for (const c of x._children) { out.push(c); w(c); } }; w(this); return out; }
  FindFirstChild(n, rec) { for (const c of this._children) if (c._name === n) return c; if (rec) for (const c of this._children) { const r = c.FindFirstChild(n, true); if (r) return r; } return null; }
  WaitForChild(n) { return this.FindFirstChild(n); }
  FindFirstChildOfClass(cls) { return this._children.find(c => c.ClassName === cls) || null; }
  FindFirstChildWhichIsA(cls) { return this._children.find(c => c.IsA(cls)) || null; }
  FindFirstAncestorOfClass(cls) { for (let p = this._parent; p; p = p._parent) if (p.ClassName === cls) return p; return null; }
  ClearAllChildren() { for (const c of [...this._children]) c.Destroy(); }
  Destroy() { this.Destroying.Fire(); for (const c of [...this._children]) c.Destroy(); this.Parent = null; this._destroyed = true; }
  SetAttribute(k, v) { const old = this._attrs.get(k); this._attrs.set(k, v); if (old !== v) { const s = this._attrSignals.get(k); if (s) s.Fire(); } }
  GetAttribute(k) { return this._attrs.get(k); }
  GetAttributeChangedSignal(k) { let s = this._attrSignals.get(k); if (!s) this._attrSignals.set(k, s = new Signal()); return s; }
  GetPropertyChangedSignal(p) { let s = this._propSignals.get(p); if (!s) this._propSignals.set(p, s = new Signal()); return s; }
  _changed(p) { const s = this._propSignals.get(p); if (s) s.Fire(); }
}

// ===== task =====
export const task = {
  spawn(fn, ...a) { try { fn(...a); } catch (e) { reportError(e); } },
  defer(fn, ...a) { queueMicrotask(() => { try { fn(...a); } catch (e) { reportError(e); } }); },
  delay(t, fn, ...a) { return setTimeout(() => { try { fn(...a); } catch (e) { reportError(e); } }, Math.max(0, t * 1000)); },
  cancel(h) { clearTimeout(h); },
};
export const osClock = () => performance.now() / 1000;

// ===== RunService =====
export const RunService = { RenderStepped: new Signal(), Heartbeat: new Signal(), Stepped: new Signal(), IsStudio: () => false, IsClient: () => true };

// ===== TweenService =====
const EASE = {
  Linear: t => t,
  Quad: t => 1 - (1 - t) * (1 - t),
  Back: t => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); },
  Elastic: t => (t === 0 ? 0 : t === 1 ? 1 : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI) / 3) + 1),
  Sine: t => Math.sin(t * Math.PI / 2),
};
const tweens = new Set();
function lerpValue(a, b, t) {
  if (typeof a === 'number') return a + (b - a) * t;
  if (a && a.Lerp) return a.Lerp(b, t);
  return t < 1 ? a : b;
}
export const TweenService = {
  Create(obj, info, props) {
    info = info || new TweenInfo();
    const tw = {
      Completed: new Signal(),
      Play() {
        for (const o of tweens) if (o.obj === obj) for (const k in props) if (k in o.props) delete o.props[k];
        this.obj = obj; this.props = { ...props }; this.from = {}; for (const k in props) this.from[k] = obj[k];
        this.t0 = performance.now(); tweens.add(this);
      },
      Cancel() { tweens.delete(this); },
      step(now) {
        const dur = Math.max(1e-3, info.Time * 1000), u = Math.min(1, (now - this.t0) / dur);
        const e = (EASE[info.EasingStyle.Name] || EASE.Quad)(u);
        for (const k in this.props) obj[k] = lerpValue(this.from[k], this.props[k], e);
        if (u >= 1) { tweens.delete(this); this.Completed.Fire(Enum.PlaybackState.Completed); }
      },
    };
    return tw;
  },
};
export function stepTweens() { const now = performance.now(); for (const t of [...tweens]) t.step(now); }

// ===== UserInputService =====
const KEYMAP = { KeyW: 'W', KeyA: 'A', KeyS: 'S', KeyD: 'D', KeyC: 'C', KeyV: 'V', KeyR: 'R', KeyP: 'P', KeyQ: 'Q', KeyE: 'E', KeyT: 'T', KeyM: 'M',
  ArrowUp: 'Up', ArrowDown: 'Down', ArrowLeft: 'Left', ArrowRight: 'Right', Space: 'Space', ShiftLeft: 'LeftShift', ShiftRight: 'RightShift',
  Escape: 'Escape', Enter: 'Return', F2: 'F2', Tab: 'Tab' };
class InputObject {
  constructor(type, keyCode) { this.UserInputType = type; this.KeyCode = keyCode || Enum.KeyCode.Unknown; this.Position = new Vector3(); this.Delta = new Vector3(); this.UserInputState = Enum.UserInputState.Begin; }
}
const keysDown = new Set();
let mouseDown = false;
const touchIO = new Map(); // pointerId -> InputObject
export const UserInputService = {
  InputBegan: new Signal(), InputEnded: new Signal(), InputChanged: new Signal(), TouchPinch: new Signal(),
  TouchEnabled: matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 0,
  KeyboardEnabled: !matchMedia('(pointer: coarse)').matches,
  MouseEnabled: !matchMedia('(pointer: coarse)').matches,
  GamepadEnabled: false,
  IsKeyDown(k) { return keysDown.has(k.Name); },
  IsMouseButtonPressed(b) { return b.Name === 'MouseButton1' && mouseDown; },
  GetFocusedTextBox() { const a = document.activeElement; return a && a.dataset && a.dataset.rbx === 'TextBox' ? a._rbx : null; },
  GetGamepadState() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [], p = pads && pads[0]; if (!p) return [];
    const io = (code, x, y, z) => { const o = new InputObject(Enum.UserInputType.Gamepad1, Enum.KeyCode[code]); o.Position = new Vector3(x, y, z); return o; };
    return [io('Thumbstick1', p.axes[0] || 0, -(p.axes[1] || 0), 0), io('ButtonR2', 0, 0, p.buttons[7] ? p.buttons[7].value : 0), io('ButtonL2', 0, 0, p.buttons[6] ? p.buttons[6].value : 0)];
  },
  IsGamepadButtonDown(_, b) {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [], p = pads && pads[0]; if (!p) return false;
    const idx = { ButtonA: 0, ButtonB: 1, ButtonX: 2, ButtonY: 3, ButtonL1: 4, ButtonR1: 5, ButtonSelect: 8, ButtonStart: 9, DPadUp: 12, DPadDown: 13 }[b.Name];
    return idx !== undefined && p.buttons[idx] && p.buttons[idx].pressed;
  },
};
// an event over the 3D view is "not processed"; over a GUI button, text box or scrolling list it is
const processedBy = t => !!(t && t.closest && t.closest('[data-sink="1"]'));
export function installInput(canvas) {
  const typing = () => !!UserInputService.GetFocusedTextBox();
  addEventListener('keydown', e => {
    const name = KEYMAP[e.code]; if (!name) return;
    if (['Up', 'Down', 'Left', 'Right', 'Space'].includes(name) && !typing()) e.preventDefault();
    if (e.repeat) return;
    keysDown.add(name);
    const io = new InputObject(Enum.UserInputType.Keyboard, Enum.KeyCode[name]);
    UserInputService.InputBegan.Fire(io, typing());
  });
  addEventListener('keyup', e => {
    const name = KEYMAP[e.code]; if (!name) return; keysDown.delete(name);
    const io = new InputObject(Enum.UserInputType.Keyboard, Enum.KeyCode[name]); io.UserInputState = Enum.UserInputState.End;
    UserInputService.InputEnded.Fire(io, typing());
  });
  addEventListener('blur', () => keysDown.clear());
  let lastX = 0, lastY = 0, pinch0 = 0;
  addEventListener('pointerdown', e => {
    const proc = processedBy(e.target);
    if (e.pointerType === 'touch') {
      const io = new InputObject(Enum.UserInputType.Touch); io.Position = new Vector3(e.clientX, e.clientY, 0); touchIO.set(e.pointerId, io);
      UserInputService.InputBegan.Fire(io, proc);
      if (touchIO.size === 2) { const [a, b] = [...touchIO.values()]; pinch0 = Math.hypot(a.Position.X - b.Position.X, a.Position.Y - b.Position.Y); }
    } else {
      if (e.button === 0) mouseDown = true;
      lastX = e.clientX; lastY = e.clientY;
      const io = new InputObject(e.button === 2 ? Enum.UserInputType.MouseButton2 : Enum.UserInputType.MouseButton1); io.Position = new Vector3(e.clientX, e.clientY, 0);
      UserInputService.InputBegan.Fire(io, proc);
    }
  }, true);
  addEventListener('pointermove', e => {
    const proc = processedBy(e.target);
    if (e.pointerType === 'touch') {
      const io = touchIO.get(e.pointerId); if (!io) return;
      io.Delta = new Vector3(e.clientX - io.Position.X, e.clientY - io.Position.Y, 0); io.Position = new Vector3(e.clientX, e.clientY, 0); io.UserInputState = Enum.UserInputState.Change;
      UserInputService.InputChanged.Fire(io, proc);
      if (touchIO.size === 2 && pinch0 > 0) { const [a, b] = [...touchIO.values()]; const d = Math.hypot(a.Position.X - b.Position.X, a.Position.Y - b.Position.Y); UserInputService.TouchPinch.Fire([], d / pinch0, 0, Enum.UserInputState.Change, proc); }
    } else {
      const io = new InputObject(Enum.UserInputType.MouseMovement); io.Position = new Vector3(e.clientX, e.clientY, 0); io.Delta = new Vector3(e.clientX - lastX, e.clientY - lastY, 0);
      lastX = e.clientX; lastY = e.clientY; io.UserInputState = Enum.UserInputState.Change;
      UserInputService.InputChanged.Fire(io, proc);
    }
  }, true);
  const up = e => {
    const proc = processedBy(e.target);
    if (e.pointerType === 'touch') {
      const io = touchIO.get(e.pointerId); if (!io) return; touchIO.delete(e.pointerId); io.UserInputState = Enum.UserInputState.End;
      UserInputService.InputEnded.Fire(io, proc); if (touchIO.size < 2) pinch0 = 0;
    } else {
      if (e.button === 0) mouseDown = false;
      const io = new InputObject(Enum.UserInputType.MouseButton1); io.Position = new Vector3(e.clientX, e.clientY, 0); io.UserInputState = Enum.UserInputState.End;
      UserInputService.InputEnded.Fire(io, proc);
    }
  };
  addEventListener('pointerup', up, true); addEventListener('pointercancel', up, true);
  canvas.addEventListener('wheel', e => { e.preventDefault(); const io = new InputObject(Enum.UserInputType.MouseWheel); io.Position = new Vector3(0, 0, -Math.sign(e.deltaY)); UserInputService.InputChanged.Fire(io, false); }, { passive: false });
  addEventListener('gamepadconnected', () => { UserInputService.GamepadEnabled = true; });
  // gamepad buttons as key presses (Start, Y, Select, shoulder buttons…)
  const prev = {};
  RunService.Heartbeat.Connect(() => {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [], p = pads && pads[0]; if (!p) return;
    const names = { 3: 'ButtonY', 4: 'ButtonL1', 5: 'ButtonR1', 8: 'ButtonSelect', 9: 'ButtonStart', 1: 'ButtonB', 12: 'DPadUp', 13: 'DPadDown' };
    for (const i in names) { const down = p.buttons[i] && p.buttons[i].pressed; if (down && !prev[i]) UserInputService.InputBegan.Fire(new InputObject(Enum.UserInputType.Gamepad1, Enum.KeyCode[names[i]]), false); prev[i] = down; }
  });
}

// ===== Lighting and effects (read by the renderer) =====
export const Lighting = new Instance('Lighting');
Object.assign(Lighting, { ClockTime: 0, Brightness: 1.4, Ambient: Color3.fromRGB(34, 38, 62), OutdoorAmbient: Color3.fromRGB(58, 64, 100), EnvironmentDiffuseScale: 0.45, EnvironmentSpecularScale: 0.7, GlobalShadows: true });
Lighting.Name = 'Lighting';
export function makeEffect(cls, props) {
  const o = new Instance(cls); const { Parent, ...rest } = props || {};
  Object.assign(o, { Enabled: true }, rest); if (Parent) o.Parent = Parent; return o;
}

// ===== remotes: client and server both run in this page, so calls go straight through =====
export class RemoteEvent extends Instance {
  constructor(cls = 'RemoteEvent') { super(cls); this.OnServerEvent = new Signal(); this.OnClientEvent = new Signal(); }
  FireServer(...a) { this.OnServerEvent.Fire(localPlayer, ...a); }
  FireClient(p, ...a) { if (p === localPlayer) this.OnClientEvent.Fire(...a); }
  FireAllClients(...a) { this.OnClientEvent.Fire(...a); }
}
export class RemoteFunction extends Instance {
  constructor() { super('RemoteFunction'); this.OnServerInvoke = null; }
  InvokeServer(...a) { return this.OnServerInvoke ? this.OnServerInvoke(localPlayer, ...a) : null; }
}

// ===== players =====
export const localPlayer = new Instance('Player');
localPlayer.Name = 'Player'; localPlayer.DisplayName = 'Player'; localPlayer.UserId = 1;
export const Players = { LocalPlayer: localPlayer, PlayerAdded: new Signal(), PlayerRemoving: new Signal(), GetPlayers: () => [localPlayer], GetPlayerByUserId: id => (id === localPlayer.UserId ? localPlayer : null) };
export const ReplicatedStorage = new Instance('Folder'); ReplicatedStorage.Name = 'ReplicatedStorage';
export const ScriptContext = { Error: errors };
export { Vector2 };
// the InputObject of a touch, so GUI events and UserInputService hand out the same object (Roblox does)
export const touchIOFor = id => touchIO.get(id);
