// Roblox GUI for the replica, drawn with HTML: ScreenGui, Frame, TextLabel, TextButton, TextBox, ScrollingFrame,
// CanvasGroup and the layout objects (UIListLayout, UIPadding, UICorner, UIStroke, UIGradient, UIScale).
// Sizes and positions use UDim2 like Roblox (scale of the parent + pixels), AnchorPoint, AutomaticSize,
// LayoutOrder, ZIndex and rich text, so screens built with the same calls come out the same.
import { Instance, Signal, UserInputService } from './core.js';
import { Vector2, Vector3, UDim2, UDim, Color3, Enum, ColorSequence, NumberSequence } from './types.js';

const css = (s, o) => (s === 0 ? `${o}px` : o === 0 ? `${s * 100}%` : `calc(${s * 100}% + ${o}px)`);
const TEXT_CLASSES = new Set(['TextLabel', 'TextButton', 'TextBox']);
let touchIOFor = null;
export function setTouchLookup(fn) { touchIOFor = fn; }

// Roblox rich text -> HTML
function rich(t) {
  const esc = s => s.replace(/&(?!(lt|gt|amp|quot|apos);)/g, '&amp;');
  let h = esc(String(t));
  h = h.replace(/<font([^>]*)>/g, (_, attrs) => {
    let st = '';
    const col = attrs.match(/color\s*=\s*["']([^"']+)["']/); if (col) st += `color:${col[1].startsWith('#') || col[1].startsWith('rgb') ? col[1] : '#' + col[1]};`;
    const size = attrs.match(/size\s*=\s*["']?(\d+)/); if (size) st += `font-size:${size[1]}px;`;
    const face = attrs.match(/weight\s*=\s*["']?(\w+)/); if (face) st += `font-weight:${face[1] === 'heavy' ? 900 : face[1] === 'bold' ? 700 : 400};`;
    return `<span style="${st}">`;
  }).replace(/<\/font>/g, '</span>').replace(/\n/g, '<br>');
  return h;
}

export class GuiObject extends Instance {
  constructor(cls) {
    super(cls);
    const el = this.el = document.createElement(cls === 'TextBox' ? 'input' : 'div');
    el._rbx = this; el.dataset.rbx = cls;
    el.style.boxSizing = 'border-box'; el.style.position = 'absolute'; el.style.pointerEvents = 'none';
    this._p = { Size: new UDim2(0, 100, 0, 100), Position: new UDim2(), AnchorPoint: new Vector2(), BackgroundColor3: Color3.fromRGB(255, 255, 255), BackgroundTransparency: 0,
      Visible: true, ZIndex: 1, LayoutOrder: 0, AutomaticSize: Enum.AutomaticSize.None, ClipsDescendants: false, Rotation: 0 };
    if (TEXT_CLASSES.has(cls)) {
      Object.assign(this._p, { Text: '', TextColor3: Color3.fromRGB(27, 42, 53), TextTransparency: 0, TextSize: 14, FontFace: null, TextXAlignment: Enum.TextXAlignment.Center,
        TextYAlignment: Enum.TextYAlignment.Center, TextWrapped: false, TextTruncate: Enum.TextTruncate.None, RichText: false, LineHeight: 1 });
      if (cls !== 'TextBox') { this.tx = document.createElement('span'); this.tx.style.display = 'block'; this.tx.style.width = '100%'; el.appendChild(this.tx); el.style.display = 'flex'; }
      else { el.style.border = 'none'; el.style.outline = 'none'; el.style.background = 'transparent'; el.dataset.sink = '1'; el.style.pointerEvents = 'auto'; el.addEventListener('blur', () => { this._p.Text = el.value; this._changed('Text'); this.FocusLost.Fire(false); }); el.addEventListener('input', () => { this._p.Text = el.value; this._changed('Text'); }); el.addEventListener('keydown', e => { if (e.key === 'Enter') el.blur(); }); }
    }
    if (cls === 'TextButton') { el.dataset.sink = '1'; el.style.pointerEvents = 'auto'; el.style.cursor = 'pointer'; el.style.userSelect = 'none'; }
    if (cls === 'ScrollingFrame') { el.dataset.sink = '1'; el.style.pointerEvents = 'auto'; el.style.overflowY = 'auto'; el.style.overflowX = 'hidden'; el.classList.add('rbx-scroll'); }
    this._deco = { list: null, pad: null, corner: null, strokes: [], grad: null, scale: null };
    this._sz(); this._place(); this._bg(); if (this.tx || cls === 'TextBox') this._text();
  }
  // ---- properties ----
  _set(k, v, fn) { this._p[k] = v; fn.call(this); this._changed(k); }
  get Size() { return this._p.Size; } set Size(v) { this._set('Size', v, this._sz); }
  get Position() { return this._p.Position; } set Position(v) { this._set('Position', v, this._place); }
  get AnchorPoint() { return this._p.AnchorPoint; } set AnchorPoint(v) { this._set('AnchorPoint', v, this._place); }
  get AutomaticSize() { return this._p.AutomaticSize; } set AutomaticSize(v) { this._set('AutomaticSize', v, this._sz); }
  get BackgroundColor3() { return this._p.BackgroundColor3; } set BackgroundColor3(v) { this._set('BackgroundColor3', v, this._bg); }
  get BackgroundTransparency() { return this._p.BackgroundTransparency; } set BackgroundTransparency(v) { this._set('BackgroundTransparency', v, this._bg); }
  get Visible() { return this._p.Visible; } set Visible(v) { this._set('Visible', !!v, this._vis); }
  get ZIndex() { return this._p.ZIndex; } set ZIndex(v) { this._set('ZIndex', v, () => { this.el.style.zIndex = v; }); }
  get LayoutOrder() { return this._p.LayoutOrder; } set LayoutOrder(v) { this._set('LayoutOrder', v, () => { this.el.style.order = v; }); }
  get ClipsDescendants() { return this._p.ClipsDescendants; } set ClipsDescendants(v) { this._set('ClipsDescendants', v, () => { if (this.ClassName !== 'ScrollingFrame') this.el.style.overflow = v ? 'hidden' : ''; }); }
  get Rotation() { return this._p.Rotation; } set Rotation(v) { this._set('Rotation', v, this._place); }
  set BorderSizePixel(v) { } get BorderSizePixel() { return 0; }
  set BorderColor3(v) { } set AutoButtonColor(v) { } set Selectable(v) { } set Active(v) { if (v) { this.el.style.pointerEvents = 'auto'; } }
  set ScrollBarThickness(v) { this.el.style.setProperty('--sb', v + 'px'); } set ScrollBarImageColor3(v) { this.el.style.setProperty('--sbc', v.css()); }
  set CanvasSize(v) { } set AutomaticCanvasSize(v) { } set ScrollingDirection(v) { }
  get GroupTransparency() { return this._gt || 0; } set GroupTransparency(v) { this._gt = v; this.el.style.opacity = String(1 - v); }
  // text
  get Text() { return this.ClassName === 'TextBox' ? this.el.value : this._p.Text; } set Text(v) { this._set('Text', v == null ? '' : String(v), this._text); }
  get TextColor3() { return this._p.TextColor3; } set TextColor3(v) { this._set('TextColor3', v, this._tcol); }
  get TextTransparency() { return this._p.TextTransparency; } set TextTransparency(v) { this._set('TextTransparency', v, this._tcol); }
  get TextSize() { return this._p.TextSize; } set TextSize(v) { this._set('TextSize', v, this._font); }
  get FontFace() { return this._p.FontFace; } set FontFace(v) { this._set('FontFace', v, this._font); }
  set Font(v) { } set TextScaled(v) { }
  get TextXAlignment() { return this._p.TextXAlignment; } set TextXAlignment(v) { this._set('TextXAlignment', v, this._align); }
  get TextYAlignment() { return this._p.TextYAlignment; } set TextYAlignment(v) { this._set('TextYAlignment', v, this._align); }
  get TextWrapped() { return this._p.TextWrapped; } set TextWrapped(v) { this._set('TextWrapped', v, this._wrap); }
  get TextTruncate() { return this._p.TextTruncate; } set TextTruncate(v) { this._set('TextTruncate', v, this._wrap); }
  get RichText() { return this._p.RichText; } set RichText(v) { this._set('RichText', v, this._text); }
  get LineHeight() { return this._p.LineHeight; } set LineHeight(v) { this._set('LineHeight', v, this._font); }
  set PlaceholderText(v) { this.el.placeholder = v; } set PlaceholderColor3(v) { this.el.style.setProperty('--ph', v.css()); }
  set ClearTextOnFocus(v) { } set TextEditable(v) { this.el.readOnly = !v; }
  CaptureFocus() { this.el.focus(); } ReleaseFocus() { this.el.blur(); }
  get AbsoluteSize() { const r = this.el.getBoundingClientRect(); return new Vector2(r.width, r.height); }
  get AbsolutePosition() { const r = this.el.getBoundingClientRect(); return new Vector2(r.left, r.top); }

  // ---- layout ----
  get _parentList() { const p = this._parent; return p && p._deco && p._deco.list ? p._deco.list : null; }
  _place() {
    const s = this.el.style, sc = this._deco && this._deco.scale ? this._deco.scale.Scale : 1, rot = this._p.Rotation;
    if (this._parentList) {
      s.position = 'relative'; s.left = ''; s.top = ''; s.flex = 'none';
      s.transform = (sc !== 1 ? `scale(${sc})` : '') + (rot ? ` rotate(${rot}deg)` : '');
    } else {
      const P = this._p.Position, A = this._p.AnchorPoint;
      s.position = 'absolute'; s.left = css(P.X.Scale, P.X.Offset); s.top = css(P.Y.Scale, P.Y.Offset);
      s.transform = (A.X || A.Y ? `translate(${-A.X * 100}%, ${-A.Y * 100}%)` : '') + (sc !== 1 ? ` scale(${sc})` : '') + (rot ? ` rotate(${rot}deg)` : '');
    }
  }
  _sz() {
    const S = this._p.Size, a = this._p.AutomaticSize.Name, s = this.el.style;
    const w = css(S.X.Scale, S.X.Offset), h = css(S.Y.Scale, S.Y.Offset);
    if (a === 'X' || a === 'XY') { s.width = 'max-content'; s.minWidth = w; } else { s.width = w; s.minWidth = ''; }
    if (a === 'Y' || a === 'XY') { s.height = 'auto'; s.minHeight = h; } else { s.height = h; s.minHeight = ''; }
  }
  _vis() { this.el.style.display = this._p.Visible ? (this._deco.list || this.tx ? 'flex' : 'block') : 'none'; }
  _bg() {
    const s = this.el.style, t = this._p.BackgroundTransparency, c = this._p.BackgroundColor3, g = this._deco && this._deco.grad;
    if (g && g.Enabled !== false) {
      const k = g.Color.Keypoints, tk = g.Transparency.Keypoints, stops = [];
      const times = [...new Set([...k.map(x => x.Time), ...tk.map(x => x.Time)])].sort((a, b) => a - b);
      for (const tm of times) {
        let col = k[k.length - 1].Value; for (let i = 0; i < k.length - 1; i++) if (tm <= k[i + 1].Time) { col = k[i].Value.Lerp(k[i + 1].Value, (tm - k[i].Time) / ((k[i + 1].Time - k[i].Time) || 1)); break; }
        const tr = g.Transparency.at(tm);
        stops.push(`${new Color3(c.R * col.R, c.G * col.G, c.B * col.B).css((1 - t) * (1 - tr))} ${(tm * 100).toFixed(1)}%`);
      }
      s.background = `linear-gradient(${90 + (g.Rotation || 0)}deg, ${stops.join(', ')})`;
    } else s.background = t >= 1 ? 'transparent' : c.css(1 - t);
  }
  _text() {
    if (this.ClassName === 'TextBox') { if (this.el.value !== this._p.Text) this.el.value = this._p.Text; this._font(); this._tcol(); return; }
    if (this._p.RichText) this.tx.innerHTML = rich(this._p.Text); else this.tx.textContent = this._p.Text;
    this._font(); this._tcol(); this._align(); this._wrap();
  }
  _tcol() { const s = (this.tx || this.el).style; s.color = this._p.TextColor3.css(1 - this._p.TextTransparency); }
  _font() {
    const s = (this.tx || this.el).style, f = this._p.FontFace;
    s.fontSize = this._p.TextSize + 'px';
    s.fontFamily = f ? `"${f.Family}", "Titillium Web", system-ui, sans-serif` : '"Titillium Web", system-ui, sans-serif';
    s.fontWeight = f ? f.Weight : 600;
    s.lineHeight = String(Math.max(0.8, this._p.LineHeight) * 1.12);
  }
  _align() {
    if (!this.tx) { this.el.style.textAlign = this._p.TextXAlignment.Name.toLowerCase(); return; }
    const x = this._p.TextXAlignment.Name, y = this._p.TextYAlignment.Name;
    this.tx.style.textAlign = x === 'Center' ? 'center' : x === 'Right' ? 'right' : 'left';
    this.el.style.alignItems = y === 'Top' ? 'flex-start' : y === 'Bottom' ? 'flex-end' : 'center';
    // auto-sized labels sit at the top of their own box like Roblox's
    if (this._p.AutomaticSize.Name !== 'None' && y === 'Center') this.el.style.alignItems = 'center';
  }
  _wrap() {
    if (!this.tx) return;
    const s = this.tx.style, trunc = this._p.TextTruncate.Name === 'AtEnd';
    s.whiteSpace = this._p.TextWrapped && !trunc ? 'normal' : 'nowrap';
    s.overflow = trunc ? 'hidden' : ''; s.textOverflow = trunc ? 'ellipsis' : '';
    s.overflowWrap = 'anywhere';
  }
  // decorations from the layout children
  _childAdded(c) {
    if (c instanceof GuiObject) { this._contentEl().appendChild(c.el); c._place(); c._vis(); }
    else if (c._applyTo) c._applyTo(this);
  }
  _childRemoved(c) {
    if (c instanceof GuiObject) { if (c.el.parentNode) c.el.parentNode.removeChild(c.el); }
    else if (c._removeFrom) c._removeFrom(this);
  }
  _contentEl() { return this.el; }
  _relayoutChildren() { for (const c of this._children) if (c instanceof GuiObject) c._place(); this._vis(); }
  // ---- events ----
  _hook(name, type, make) {
    const sig = new Signal(); Object.defineProperty(this, name, { value: sig });
    if (this.ClassName !== 'Frame' || type !== 'click') this.el.style.pointerEvents = 'auto';
    this.el.addEventListener(type, e => make(e, sig));
    return sig;
  }
  get Activated() { return this._hook('Activated', 'click', (e, s) => { e.stopPropagation(); s.Fire(); }); }
  get MouseButton1Click() { return this.Activated; }
  get MouseEnter() { return this._hook('MouseEnter', 'pointerenter', (e, s) => { if (e.pointerType === 'mouse') s.Fire(e.clientX, e.clientY); }); }
  get MouseLeave() { return this._hook('MouseLeave', 'pointerleave', (e, s) => { if (e.pointerType === 'mouse') s.Fire(e.clientX, e.clientY); }); }
  get MouseButton1Down() { return this._hook('MouseButton1Down', 'pointerdown', (e, s) => { if (e.pointerType === 'mouse' && e.button === 0) s.Fire(e.clientX, e.clientY); }); }
  get MouseButton1Up() { return this._hook('MouseButton1Up', 'pointerup', (e, s) => { if (e.pointerType === 'mouse' && e.button === 0) s.Fire(e.clientX, e.clientY); }); }
  _io(e, state) {
    if (e.pointerType === 'touch' && touchIOFor) { const io = touchIOFor(e.pointerId); if (io) return io; }
    return { UserInputType: e.pointerType === 'touch' ? Enum.UserInputType.Touch : Enum.UserInputType.MouseButton1, KeyCode: Enum.KeyCode.Unknown, Position: new Vector3(e.clientX, e.clientY, 0), UserInputState: state };
  }
  get InputBegan() { const s = this._hook('InputBegan', 'pointerdown', (e, s2) => s2.Fire(this._io(e, Enum.UserInputState.Begin))); this.el.style.touchAction = 'none'; return s; }
  get InputEnded() {
    const sig = this._hook('InputEnded', 'pointerup', (e, s) => s.Fire(this._io(e, Enum.UserInputState.End)));
    this.el.addEventListener('pointercancel', e => sig.Fire(this._io(e, Enum.UserInputState.End)));
    this.el.addEventListener('pointerleave', e => { if (e.pointerType === 'touch') sig.Fire(this._io(e, Enum.UserInputState.End)); });
    return sig;
  }
  get InputChanged() { return this._hook('InputChanged', 'pointermove', (e, s) => s.Fire(this._io(e, Enum.UserInputState.Change))); }
  get FocusLost() { const s = new Signal(); Object.defineProperty(this, 'FocusLost', { value: s }); return s; }
  Destroy() { super.Destroy(); if (this.el.parentNode) this.el.parentNode.removeChild(this.el); }
}

export class ScreenGui extends GuiObject {
  constructor() {
    super('ScreenGui');
    Object.assign(this.el.style, { position: 'fixed', left: '0', top: '0', width: '100%', height: '100%', transform: '', background: 'transparent', overflow: 'hidden' });
    this._p.BackgroundTransparency = 1;
  }
  _sz() { } _place() { } _bg() { }
  set Enabled(v) { this.el.style.display = v ? 'block' : 'none'; } get Enabled() { return this.el.style.display !== 'none'; }
  set ResetOnSpawn(v) { } set IgnoreGuiInset(v) { } set ZIndexBehavior(v) { } set DisplayOrder(v) { this.el.style.zIndex = v; }
  _parentChanged(old, p) { if (p && !this.el.parentNode) document.getElementById('gui').appendChild(this.el); }
}

// ---- layout modifiers ----
class Modifier extends Instance {
  constructor(cls, slot) { super(cls); this._slot = slot; this._host = null; }
  _applyTo(host) { this._host = host; if (this._slot === 'strokes') host._deco.strokes.push(this); else host._deco[this._slot] = this; this._apply(); }
  _removeFrom(host) { if (this._slot === 'strokes') host._deco.strokes = host._deco.strokes.filter(s => s !== this); else if (host._deco[this._slot] === this) host._deco[this._slot] = null; this._unapply(host); this._host = null; }
  _apply() { } _unapply() { }
  _upd() { if (this._host) this._apply(); }
}
export class UICorner extends Modifier {
  constructor() { super('UICorner', 'corner'); this._r = new UDim(0, 8); }
  get CornerRadius() { return this._r; } set CornerRadius(v) { this._r = v; this._upd(); }
  _apply() { const r = this._r, e = this._host.el; e.style.borderRadius = r.Scale >= 0.5 ? '9999px' : css(r.Scale, r.Offset); for (const s of this._host._deco.strokes) s._apply(); }
  _unapply(h) { h.el.style.borderRadius = ''; }
}
export class UIPadding extends Modifier {
  constructor() { super('UIPadding', 'pad'); this.v = [new UDim(), new UDim(), new UDim(), new UDim()]; }
  set PaddingLeft(v) { this.v[0] = v; this._upd(); } set PaddingTop(v) { this.v[1] = v; this._upd(); } set PaddingRight(v) { this.v[2] = v; this._upd(); } set PaddingBottom(v) { this.v[3] = v; this._upd(); }
  _apply() { const [l, t, r, b] = this.v, s = this._host.el.style; s.paddingLeft = css(l.Scale, l.Offset); s.paddingTop = css(t.Scale, t.Offset); s.paddingRight = css(r.Scale, r.Offset); s.paddingBottom = css(b.Scale, b.Offset); }
  _unapply(h) { h.el.style.padding = ''; }
}
export class UIListLayout extends Modifier {
  constructor() { super('UIListLayout', 'list'); this.p = { Padding: new UDim(), FillDirection: Enum.FillDirection.Vertical, HorizontalAlignment: Enum.HorizontalAlignment.Left, VerticalAlignment: Enum.VerticalAlignment.Top, Wraps: false }; }
  set Padding(v) { this.p.Padding = v; this._upd(); } set FillDirection(v) { this.p.FillDirection = v; this._upd(); } set HorizontalAlignment(v) { this.p.HorizontalAlignment = v; this._upd(); }
  set VerticalAlignment(v) { this.p.VerticalAlignment = v; this._upd(); } set Wraps(v) { this.p.Wraps = v; this._upd(); } set SortOrder(v) { }
  _apply() {
    const h = this._host, s = (h._contentEl ? h._contentEl() : h.el).style, p = this.p, horiz = p.FillDirection.Name === 'Horizontal';
    const al = n => (n === 'Center' ? 'center' : n === 'Right' || n === 'Bottom' ? 'flex-end' : 'flex-start');
    s.display = h._p.Visible === false ? 'none' : 'flex'; s.flexDirection = horiz ? 'row' : 'column'; s.flexWrap = p.Wraps ? 'wrap' : 'nowrap';
    s.gap = css(p.Padding.Scale, p.Padding.Offset);
    if (horiz) { s.justifyContent = al(p.HorizontalAlignment.Name); s.alignItems = al(p.VerticalAlignment.Name); }
    else { s.justifyContent = al(p.VerticalAlignment.Name); s.alignItems = al(p.HorizontalAlignment.Name); }
    h._relayoutChildren();
  }
  _unapply(h) { const s = h.el.style; s.display = ''; s.flexDirection = ''; s.gap = ''; h._relayoutChildren(); }
}
export class UIScale extends Modifier {
  constructor() { super('UIScale', 'scale'); this._s = 1; }
  get Scale() { return this._s; } set Scale(v) { this._s = v; if (this._host) this._host._place(); }
  _apply() { this._host._place(); } _unapply(h) { h._place(); }
}
export class UIGradient extends Modifier {
  constructor() { super('UIGradient', 'grad'); this._p = { Color: null, Transparency: null, Rotation: 0, Enabled: true }; }
  get Color() { return this._p.Color; } set Color(v) { this._p.Color = v; this._upd(); }
  get Transparency() { return this._p.Transparency; } set Transparency(v) { this._p.Transparency = v; this._upd(); }
  get Rotation() { return this._p.Rotation; } set Rotation(v) { this._p.Rotation = v; this._upd(); }
  get Enabled() { return this._p.Enabled; } set Enabled(v) { this._p.Enabled = v; this._upd(); }
  _defaults() { if (!this._p.Color) this._p.Color = new ColorSequence(new Color3(1, 1, 1)); if (!this._p.Transparency) this._p.Transparency = new NumberSequence(0); }
  _applyTo(host) {
    this._defaults();
    if (host instanceof UIStroke) { host._grad = this; this._host = host; host._apply(); return; }
    super._applyTo(host);
  }
  _removeFrom(host) { if (host instanceof UIStroke) { host._grad = null; host._apply(); return; } super._removeFrom(host); }
  _apply() { if (this._host instanceof UIStroke) this._host._apply(); else this._host._bg(); }
  _unapply(h) { h._bg(); }
}
export class UIStroke extends Modifier {
  constructor() { super('UIStroke', 'strokes'); this.p = { Color: Color3.fromRGB(0, 0, 0), Thickness: 1, Transparency: 0, ApplyStrokeMode: Enum.ApplyStrokeMode.Contextual }; this._grad = null; this._layer = null; }
  get Color() { return this.p.Color; } set Color(v) { this.p.Color = v; this._upd(); }
  get Thickness() { return this.p.Thickness; } set Thickness(v) { this.p.Thickness = v; this._upd(); }
  get Transparency() { return this.p.Transparency; } set Transparency(v) { this.p.Transparency = v; this._upd(); }
  set ApplyStrokeMode(v) { this.p.ApplyStrokeMode = v; this._upd(); } set LineJoinMode(v) { }
  set Enabled(v) { this._off = !v; this._upd(); }
  _childAdded(c) { if (c._applyTo) c._applyTo(this); } _childRemoved(c) { if (c._removeFrom) c._removeFrom(this); }
  _apply() {
    const h = this._host; if (!h) return;
    const p = this.p, textMode = p.ApplyStrokeMode.Name === 'Contextual' && h.tx;
    if (textMode) {
      const c = p.Color.css(this._off ? 0 : 1 - p.Transparency), t = p.Thickness;
      h.tx.style.textShadow = `${t}px 0 ${c}, -${t}px 0 ${c}, 0 ${t}px ${c}, 0 -${t}px ${c}, ${t * 0.7}px ${t * 0.7}px ${c}, -${t * 0.7}px -${t * 0.7}px ${c}, ${t * 0.7}px -${t * 0.7}px ${c}, -${t * 0.7}px ${t * 0.7}px ${c}`;
      return;
    }
    // a border ring drawn on its own layer (so a gradient can fade it round the panel like Roblox's glass edge)
    if (!this._layer) {
      const L = this._layer = document.createElement('div');
      Object.assign(L.style, { position: 'absolute', inset: `-${0}px`, pointerEvents: 'none', borderRadius: 'inherit', boxSizing: 'border-box' });
      h.el.appendChild(L);
    }
    const L = this._layer, t = p.Thickness;
    L.style.inset = `-${t}px`; L.style.borderRadius = h.el.style.borderRadius ? `calc(${h.el.style.borderRadius} + ${t}px)` : '0';
    L.style.display = this._off ? 'none' : 'block';
    const g = this._grad;
    if (g && g.Enabled !== false) {
      const k = g.Transparency.Keypoints, stops = k.map(x => `${p.Color.css((1 - p.Transparency) * (1 - x.Value))} ${(x.Time * 100).toFixed(0)}%`);
      L.style.border = `${t}px solid transparent`;
      L.style.background = `linear-gradient(${90 + (g.Rotation || 0)}deg, ${stops.join(', ')}) border-box`;
      L.style.webkitMask = 'linear-gradient(#000 0 0) padding-box, linear-gradient(#000 0 0)'; L.style.webkitMaskComposite = 'xor'; L.style.maskComposite = 'exclude';
    } else {
      L.style.background = 'none'; L.style.webkitMask = ''; L.style.border = `${t}px solid ${p.Color.css(1 - p.Transparency)}`;
    }
  }
  _unapply(h) { if (this._layer && this._layer.parentNode) this._layer.parentNode.removeChild(this._layer); this._layer = null; if (h.tx) h.tx.style.textShadow = ''; }
}

export class Folder extends Instance { constructor() { super('Folder'); } }

const GUI_CLASSES = { Frame: 1, TextLabel: 1, TextButton: 1, TextBox: 1, ScrollingFrame: 1, CanvasGroup: 1, ImageLabel: 1 };
export function newInstance(cls) {
  if (cls === 'ScreenGui') return new ScreenGui();
  if (GUI_CLASSES[cls]) return new GuiObject(cls);
  if (cls === 'UICorner') return new UICorner();
  if (cls === 'UIPadding') return new UIPadding();
  if (cls === 'UIListLayout') return new UIListLayout();
  if (cls === 'UIScale') return new UIScale();
  if (cls === 'UIGradient') return new UIGradient();
  if (cls === 'UIStroke') return new UIStroke();
  return new Instance(cls);
}
// Ui.make: set properties (Parent last), add children
export function make(cls, props, children) {
  const o = newInstance(cls);
  if (TEXT_CLASSES.has(cls) && cls !== 'TextBox' && !(props && 'Text' in props)) o.Text = cls === 'TextButton' ? '' : '';
  for (const k in props || {}) if (k !== 'Parent') o[k] = props[k];
  for (const c of children || []) c.Parent = o;
  if (props && props.Parent) o.Parent = props.Parent;
  return o;
}
