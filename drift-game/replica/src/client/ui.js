// Kaido Drift UI kit: port of the Roblox game's Ui.luau. Frosted glass on a blurred world, gradient
// accents, springy motion. Panels are translucent cards with bright glass edges; buttons grow on hover,
// squish when pressed and spring back; screens slide and fade in with an overshoot; chips and knobs bounce.
import { make } from '../rbx/gui.js';
import { TweenService, UserInputService, Lighting, makeEffect } from '../rbx/core.js';
import { Color3, UDim, UDim2, Vector2, Enum, TweenInfo, Font, ColorSequence, NumberSequence, NumberSequenceKeypoint } from '../rbx/types.js';

const Ui = {};
Ui.INK = Color3.fromHex('0c0d16');
Ui.PANEL = Color3.fromHex('141628');
Ui.TEXT = Color3.fromHex('f6f3ee');
Ui.DIM = Color3.fromHex('b3b0c4');
Ui.SAKURA = Color3.fromHex('ff7eb6');
Ui.VIOLET = Color3.fromHex('a77bff');
Ui.NEON = Color3.fromHex('59e3ff');
Ui.GOLD = Color3.fromHex('ffc94d');
Ui.DANGER = Color3.fromHex('ff5a5a');
Ui.LINE = new Color3(1, 1, 1);
// Roblox's TitilliumWeb for text and GothamBlack for display (Montserrat Black is the closest web font)
Ui.BODY = Font.new('Titillium Web', 600);
Ui.BOLD = Font.new('Titillium Web', 700);
Ui.DISPLAY = Font.new('Montserrat', 900);

Ui.make = make;

const SPRING = new TweenInfo(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
const QUICK = new TweenInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
const ELASTIC = new TweenInfo(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out);
Ui.tween = (o, props, info) => { const t = TweenService.Create(o, info || SPRING, props); t.Play(); return t; };
function scaleOf(o) {
  let s = o.FindFirstChildOfClass('UIScale');
  if (!s) s = make('UIScale', { Scale: 1, Parent: o });
  return s;
}
Ui.pop = (o, amount) => { const s = scaleOf(o); s.Scale = amount || 1.18; Ui.tween(s, { Scale: 1 }, ELASTIC); };
Ui.bouncy = b => {
  const s = scaleOf(b);
  b.MouseEnter.Connect(() => Ui.tween(s, { Scale: 1.035 }));
  b.MouseLeave.Connect(() => Ui.tween(s, { Scale: 1 }));
  b.MouseButton1Down.Connect(() => Ui.tween(s, { Scale: 0.94 }, QUICK));
  b.MouseButton1Up.Connect(() => Ui.tween(s, { Scale: 1 }, ELASTIC));
  b.InputBegan.Connect(io => { if (io.UserInputType === Enum.UserInputType.Touch) Ui.tween(s, { Scale: 0.94 }, QUICK); });
  b.InputEnded.Connect(io => { if (io.UserInputType === Enum.UserInputType.Touch) Ui.tween(s, { Scale: 1 }, ELASTIC); });
  return b;
};

Ui.corner = r => make('UICorner', { CornerRadius: new UDim(0, r || 12) });
Ui.pad = (l, t, r, b) => make('UIPadding', { PaddingLeft: new UDim(0, l), PaddingTop: new UDim(0, t ?? l), PaddingRight: new UDim(0, r ?? l), PaddingBottom: new UDim(0, b ?? t ?? l) });
Ui.list = (gap, horizontal, align) => make('UIListLayout', { Padding: new UDim(0, gap || 0), SortOrder: Enum.SortOrder.LayoutOrder, FillDirection: horizontal ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical, VerticalAlignment: align || Enum.VerticalAlignment.Top });
Ui.edge = (t, alpha) => make('UIStroke', { Color: new Color3(1, 1, 1), Thickness: t || 1.2, Transparency: 0, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }, [
  make('UIGradient', { Rotation: 45, Transparency: new NumberSequence([new NumberSequenceKeypoint(0, alpha || 0.45), new NumberSequenceKeypoint(0.5, 0.88), new NumberSequenceKeypoint(1, 0.7)]) }),
]);
Ui.stroke = (color, t, transp) => make('UIStroke', { Color: color || Ui.LINE, Thickness: t || 1, Transparency: transp ?? 0.85, ApplyStrokeMode: Enum.ApplyStrokeMode.Border });
Ui.glass = (f, radius, strength) => {
  f.BackgroundColor3 = Color3.fromHex('1a1d36');
  f.BackgroundTransparency = strength ?? 0.38;
  f.BorderSizePixel = 0;
  make('UICorner', { CornerRadius: new UDim(0, radius || 18), Parent: f });
  make('UIGradient', { Rotation: 100, Color: new ColorSequence(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 210)), Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.25)]), Parent: f });
  Ui.edge(1.2).Parent = f;
  return f;
};
Ui.text = props => {
  props.BackgroundTransparency = 1;
  props.TextColor3 = props.TextColor3 || Ui.TEXT;
  props.FontFace = props.FontFace || Ui.BODY;
  props.TextSize = props.TextSize || 16;
  props.TextWrapped = props.TextWrapped !== false;
  props.TextXAlignment = props.TextXAlignment || Enum.TextXAlignment.Left;
  props.Size = props.Size || new UDim2(1, 0, 0, 0);
  if (props.AutomaticSize === undefined) props.AutomaticSize = Enum.AutomaticSize.Y;
  if (props.RichText === undefined) props.RichText = true;
  // Roblox lays text out from the top of an auto-sized label
  if (props.TextYAlignment === undefined) props.TextYAlignment = Enum.TextYAlignment.Center;
  const { Text, ...rest } = props;
  return make('TextLabel', { ...rest, Text });
};
Ui.eyebrow = (t, order, parent) => Ui.text({ Text: String(t).toUpperCase(), TextSize: 12, TextColor3: Ui.DIM, FontFace: Ui.BOLD, LayoutOrder: order, Parent: parent });
Ui.fine = (t, order, parent) => Ui.text({ Text: t, TextSize: 13, TextColor3: Ui.DIM, LineHeight: 1.25, LayoutOrder: order, Parent: parent });

const blur = Lighting.FindFirstChild('KaidoBlur') || makeEffect('BlurEffect', { Name: 'KaidoBlur', Size: 0, Parent: Lighting });
Ui.blur = on => Ui.tween(blur, { Size: on ? 18 : 0 }, new TweenInfo(0.35, Enum.EasingStyle.Quad));

// a floating glass card on the left with a scrolling column (every menu screen)
Ui.sheet = (gui, wide) => {
  const root = make('Frame', { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Visible: false, Parent: gui });
  const w = wide ? 640 : 480;
  const card = make('CanvasGroup', { Size: new UDim2(0, w, 1, -40), Position: new UDim2(0, 20, 0, 20), BackgroundTransparency: 1, Parent: root });
  const glassF = make('Frame', { Size: UDim2.fromScale(1, 1), Parent: card });
  Ui.glass(glassF, 24, 0.3);
  make('Frame', { Size: new UDim2(1, 0, 0, 160), BackgroundColor3: new Color3(1, 1, 1), BackgroundTransparency: 0.9, BorderSizePixel: 0, Parent: glassF }, [
    make('UICorner', { CornerRadius: new UDim(0, 24) }),
    make('UIGradient', { Rotation: 90, Transparency: new NumberSequence(0.2, 1) }),
  ]);
  const scroll = make('ScrollingFrame', {
    Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ScrollBarThickness: 3, ScrollBarImageColor3: Ui.DIM,
    AutomaticCanvasSize: Enum.AutomaticSize.Y, CanvasSize: new UDim2(), Parent: card,
  }, [Ui.pad(28, 30, 28, 30), Ui.list(18)]);
  const fit = () => {
    const vw = innerWidth, ww = Math.min(w, vw - 24);
    card.Size = new UDim2(0, ww, 1, -40);
    card.Position = new UDim2(0, Math.min(20, (vw - ww) / 2), 0, 20);
    card.SetAttribute('Home', card.Position);
  };
  addEventListener('resize', fit);
  fit();
  root.SetAttribute('Card', true);
  return [root, scroll, card];
};
Ui.show = root => {
  root.Visible = true;
  const card = root.FindFirstChildOfClass('CanvasGroup');
  if (card) {
    const x = card.GetAttribute('Home') || card.Position;
    card.GroupTransparency = 1;
    card.Position = x.add(new UDim2(0, -60, 0, 0));
    Ui.tween(card, { GroupTransparency: 0 }, new TweenInfo(0.25, Enum.EasingStyle.Quad));
    Ui.tween(card, { Position: x }, new TweenInfo(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out));
    const s = scaleOf(card);
    s.Scale = 0.96;
    Ui.tween(s, { Scale: 1 }, new TweenInfo(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out));
  }
};
Ui.heading = (t, jp, order, parent) => Ui.text({ Text: t + (jp ? `  <font color="#ff7eb6" size="20">${jp}</font>` : ''), FontFace: Ui.DISPLAY, TextSize: 36, LayoutOrder: order, Parent: parent });

// a menu button: label left, small note right; primary = pink-violet gradient
Ui.button = (label, note, kind, order, parent) => {
  const primary = kind === 'primary', ghost = kind === 'ghost';
  const b = make('TextButton', {
    Size: new UDim2(1, 0, 0, 58), AutoButtonColor: false, Text: '', LayoutOrder: order, Parent: parent,
    BackgroundColor3: primary ? new Color3(1, 1, 1) : Color3.fromHex('2a2e52'), BackgroundTransparency: primary ? 0 : (ghost ? 1 : 0.45),
  }, [make('UICorner', { CornerRadius: new UDim(0, 16) })]);
  if (primary) {
    make('UIGradient', { Rotation: 0, Color: new ColorSequence(Ui.SAKURA, Ui.VIOLET), Parent: b });
    make('UIStroke', { Color: Color3.fromHex('ffd1e6'), Thickness: 1.5, Transparency: 0.35, ApplyStrokeMode: Enum.ApplyStrokeMode.Border, Parent: b });
  } else Ui.edge(1).Parent = b;
  const lab = Ui.text({ Text: String(label).toUpperCase(), FontFace: Ui.BOLD, TextSize: 16, TextColor3: primary ? new Color3(1, 1, 1) : Ui.TEXT, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0.55, -20, 1, 0), Position: new UDim2(0, 20, 0, 0), TextWrapped: false, Parent: b });
  lab.Name = 'Label';
  if (note) {
    const n = Ui.text({ Text: note, TextSize: 13, TextColor3: primary ? Color3.fromHex('fff0f7') : Ui.DIM, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0.45, -20, 1, 0), Position: new UDim2(0.55, 0, 0, 0), TextXAlignment: Enum.TextXAlignment.Right, TextTruncate: Enum.TextTruncate.AtEnd, TextWrapped: false, Parent: b });
    n.Name = 'Note';
  }
  b.Label = lab;
  return Ui.bouncy(b);
};

// pill chips; returns a setter for the selected value
Ui.chips = (options, current, onPick, order, parent) => {
  const row = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: order, Parent: parent });
  make('UIListLayout', { Padding: new UDim(0, 8), FillDirection: Enum.FillDirection.Horizontal, Wraps: true, SortOrder: Enum.SortOrder.LayoutOrder, Parent: row });
  const btns = new Map();
  const set = (v, animate) => {
    for (const [val, b] of btns) {
      const on = val === v;
      b.BackgroundTransparency = on ? 0 : 0.55;
      b.BackgroundColor3 = on ? new Color3(1, 1, 1) : Color3.fromHex('2a2e52');
      b.TextColor3 = on ? new Color3(1, 1, 1) : Ui.TEXT;
      b.FindFirstChildOfClass('UIGradient').Enabled = on;
      if (on && animate) Ui.pop(b, 1.15);
    }
  };
  options.forEach((opt, k) => {
    const b = make('TextButton', {
      Size: new UDim2(0, 0, 0, 40), AutomaticSize: Enum.AutomaticSize.X, Text: opt[1], FontFace: Ui.BOLD, TextSize: 14, AutoButtonColor: false, LayoutOrder: k + 1, Parent: row,
    }, [make('UICorner', { CornerRadius: new UDim(1, 0) }), Ui.edge(1), Ui.pad(16, 0, 16, 0), make('UIGradient', { Color: new ColorSequence(Ui.SAKURA, Ui.VIOLET), Enabled: false })]);
    btns.set(opt[0], b);
    Ui.bouncy(b);
    b.Activated.Connect(() => { set(opt[0], true); onPick(opt[0]); });
  });
  set(current, false);
  return v => set(v, false);
};

// a slider with a glowing knob that bounces when grabbed
Ui.slider = (min, max, step, value, onChange, order, parent) => {
  const holder = make('Frame', { Size: new UDim2(1, 0, 0, 32), BackgroundTransparency: 1, LayoutOrder: order, Parent: parent });
  const track = make('Frame', { Size: new UDim2(1, 0, 0, 8), Position: new UDim2(0, 0, 0.5, -4), BackgroundColor3: Color3.fromHex('2a2e52'), BackgroundTransparency: 0.3, Parent: holder }, [make('UICorner', { CornerRadius: new UDim(1, 0) })]);
  const fill = make('Frame', { Size: new UDim2(0, 0, 1, 0), BackgroundColor3: new Color3(1, 1, 1), Parent: track }, [make('UICorner', { CornerRadius: new UDim(1, 0) }), make('UIGradient', { Color: new ColorSequence(Ui.SAKURA, Ui.VIOLET) })]);
  const knob = make('Frame', { Size: new UDim2(0, 24, 0, 24), AnchorPoint: new Vector2(0.5, 0.5), Position: new UDim2(0, 0, 0.5, 0), BackgroundColor3: new Color3(1, 1, 1), ZIndex: 2, Parent: track }, [
    make('UICorner', { CornerRadius: new UDim(1, 0) }), make('UIStroke', { Color: Ui.SAKURA, Thickness: 3, Transparency: 0.2, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
  ]);
  const show = v => { const f = (v - min) / (max - min); fill.Size = new UDim2(f, 0, 1, 0); knob.Position = new UDim2(f, 0, 0.5, 0); };
  let dragging = null;
  const at = x => {
    const r = track.el.getBoundingClientRect();
    const f = Math.min(1, Math.max(0, (x - r.left) / r.width));
    const v = Math.min(max, Math.max(min, min + Math.floor((f * (max - min)) / step + 0.5) * step));
    show(v); onChange(v);
  };
  holder.el.dataset.sink = '1';
  holder.InputBegan.Connect(io => { dragging = io; at(io.Position.X); Ui.tween(scaleOf(knob), { Scale: 1.35 }); });
  UserInputService.InputChanged.Connect(io => { if (dragging && (io.UserInputType === Enum.UserInputType.MouseMovement || io === dragging)) at(io.Position.X); });
  UserInputService.InputEnded.Connect(io => { if (dragging && (io === dragging || io.UserInputType === Enum.UserInputType.MouseButton1)) { dragging = null; Ui.tween(scaleOf(knob), { Scale: 1 }, ELASTIC); } });
  show(value);
  return show;
};

// glass stat tiles ("12,400 CREDITS")
Ui.stats = (items, order, parent) => {
  const row = make('Frame', { Size: new UDim2(1, 0, 0, 64), BackgroundTransparency: 1, LayoutOrder: order, Parent: parent }, [Ui.list(10, true)]);
  const vals = [];
  items.forEach((it, k) => {
    const tile = make('Frame', { Size: new UDim2(1 / items.length, -10 * (items.length - 1) / items.length, 1, 0), LayoutOrder: k + 1, Parent: row }, [Ui.pad(14, 8, 14, 8), Ui.list(0)]);
    Ui.glass(tile, 14, 0.55);
    vals[k] = Ui.text({ Text: '0', FontFace: Ui.DISPLAY, TextSize: 22, TextColor3: it[1] || Ui.TEXT, TextWrapped: false, LayoutOrder: 1, Parent: tile });
    Ui.text({ Text: String(it[0]).toUpperCase(), TextSize: 11, TextColor3: Ui.DIM, FontFace: Ui.BOLD, TextWrapped: false, LayoutOrder: 2, Parent: tile });
  });
  return vals;
};
Ui.field = (label, order, parent) => {
  const f = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: order, Parent: parent }, [Ui.list(8)]);
  const l = Ui.eyebrow(label, 0, f);
  return [f, l];
};
Ui.fmt = n => Math.floor(n).toLocaleString('en-US');

export default Ui;
