// Kaido Drift (web replica) client: a line-by-line port of the Roblox game's Main.client.luau. The same
// screens, HUD, controls, drift scoring, camera and physics, the browser car models, free roaming between
// the Hakone pass and Shin-Hakone city, graphics levels, time of day and engine sound.
import Config from '../shared/config.js';
import Track from '../shared/track.js';
import * as CarPhysics from '../shared/carphysics.js';
import Ui from './ui.js';
import { Audio, comboPing } from './audio.js';
import { CarMesh, CarModel, applyStyle as styleCar } from './car.js';
import * as Fx from './fx.js';
import { World } from '../world/query.js';
import { camera, setQuality as rQuality, setBeam, getScene, setFocus } from './renderer.js';
import { setGroupVisible, setGroupNeon } from '../world/parts.js';
import { setTextGroupVisible } from '../world/text.js';
import { RunService, UserInputService, Lighting, ReplicatedStorage, localPlayer, task, osClock, ScriptContext } from '../rbx/core.js';
import { Vector3, Vector2, CFrame, Color3, UDim, UDim2, Enum, ColorSequence, ColorSequenceKeypoint, NumberSequence } from '../rbx/types.js';

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const sgn = x => (x > 0 ? 1 : x < 0 ? -1 : 0);
const pad2 = n => String(n).padStart(2, '0');

// boot: world = { mapFolder, gui, loading UI } built by index.js before this runs
export function runClient({ gui, loading, loadMsg, mapFolder, R }) {
  const U = {};
  const make = Ui.make, text = Ui.text, fmt = Ui.fmt;
  const K = Config.SCALE, HALF = Config.ROAD_HALF;
  const touch = UserInputService.TouchEnabled && !UserInputService.KeyboardEnabled;
  const player = localPlayer;

  const showLoadError = (where, message) => {
    if (loading.Parent) { loadMsg.Text = 'Something went wrong (' + where + '):\n' + message + '\nSend a screenshot of this to fix it.'; loadMsg.TextColor3 = Ui.DANGER; }
  };
  ScriptContext.Error.Connect((message, trace) => showLoadError('game', message + '\n' + trace));
  loadMsg.Text = 'Loading your garage…';
  let profile = R.GetProfile.InvokeServer();
  const S = profile.settings;
  if (S.assist === '') S.assist = touch ? 'touch' : 'std';

  const owned = id => profile.owned.includes(id);
  const paintOf = id => { const idx = profile.paint[id] || 0; return [idx > 0 ? Config.Paints[idx - 1] : Config.car(id).color, idx]; };
  let saveQueued = false;
  const saveSettings = () => { if (saveQueued) return; saveQueued = true; task.delay(1, () => { saveQueued = false; R.SaveSettings.FireServer(S); }); };

  // ===================== graphics level and time of day (this device only) =====================
  let qAuto = touch ? 'low' : 'high';
  const qName = () => (S.quality === 'auto' ? qAuto : S.quality);
  const curTime = () => ReplicatedStorage.GetAttribute('KaidoTime') ?? S.time;
  const night = () => { const t = curTime(); return t < 6.2 || t > 17.8; };
  const applyWorld = () => {
    const Q = Config.Quality[qName()], n = night();
    setGroupNeon('lamp', n); setGroupNeon('nightNeon', n);
    for (let k = 1; k <= 3; k++) { setGroupVisible('win' + k, n && k <= Q.windows); setGroupVisible('tree' + k, k <= Q.trees); }
    setTextGroupVisible('signs', Q.signs); setTextGroupVisible('screens', true);
  };
  const applyQuality = () => {
    const Q = Config.Quality[qName()];
    Lighting.GlobalShadows = Q.shadows;
    const bloom = Lighting.FindFirstChild('KaidoBloom');
    if (bloom) bloom.Enabled = Q.bloom;
    rQuality(qName(), Q);
    Fx.setSkidLimit(qName() === 'low' ? 200 : 400);
    applyWorld();
  };
  let carModel = null;
  let beamOn = false;
  const setCarLights = (m, on) => { beamOn = on; };
  const applyTime = () => {
    Lighting.ClockTime = curTime();
    const n = night();
    const dusk = clamp(1 - Math.min(Math.abs(curTime() - 6), Math.abs(curTime() - 18)) / 1.5, 0, 1);
    Lighting.Ambient = n ? Color3.fromRGB(34, 38, 62) : Color3.fromRGB(110, 110, 118);
    Lighting.OutdoorAmbient = n ? Color3.fromRGB(58, 64, 100) : Color3.fromRGB(130, 134, 146).Lerp(Color3.fromRGB(150, 110, 100), dusk);
    Lighting.Brightness = n ? 1.4 : 2.6;
    const atmo = Lighting.FindFirstChildOfClass('Atmosphere');
    if (atmo) {
      atmo.Density = n ? 0.3 : 0.26;
      atmo.Color = n ? Color3.fromRGB(72, 82, 122) : Color3.fromRGB(199, 214, 232).Lerp(Color3.fromRGB(240, 160, 120), dusk);
      atmo.Decay = n ? Color3.fromRGB(22, 24, 42) : Color3.fromRGB(106, 122, 150).Lerp(Color3.fromRGB(160, 90, 80), dusk);
    }
    applyWorld();
    if (carModel) setCarLights(carModel, n);
  };
  applyQuality();
  applyTime();

  // ===================== the car =====================
  let camMode = S.cam;
  let carDef = Config.car(profile.selected);
  const START = 8;
  let P = CarPhysics.newCar(Track.X[START] / K, Track.Z[START] / K, Track.heading(START));
  let idx = START, posY = Track.Y[START], vy = 0;
  let groundN = Vector3.yAxis, onGround = true;
  let onPass = true;
  let roll = 0, rollV = 0, pitch = 0, pitchV = 0, fspin = 0;
  let garageSel = profile.selected;
  let sound = null;
  const usingMesh = true;
  const input = { throttle: 0, brake: 0, hand: false, steer: 0 };
  const physSet = { assist: S.assist, trans: S.trans, sens: S.sens };
  const junction = mapFolder.GetAttribute('Junction') || 1;
  const nearJunction = k => { const d = Math.abs(k - junction); return Math.min(d, Track.N - d) <= 7; };
  const scene = getScene();
  const buildCar = (def, name, paint) => CarMesh.build(def, name, paint);
  const placeCar = (m, mesh, cf, steer, rf, rr) => CarMesh.place(m, cf, steer, rf, rr);
  const applyStyle = (m, def) => styleCar(m, def, profile.cos && profile.cos[def.id], Config);

  const spawnCar = id => {
    if (carModel) CarMesh.destroy(carModel);
    if (sound) { sound.destroy(); sound = null; }
    const base = Config.car(id || profile.selected);
    carDef = Config.tuned(base, profile.upg && profile.upg[base.id]);
    const [col] = paintOf(carDef.id);
    carModel = buildCar(carDef, 'MyCar', col);
    scene.add(carModel.group);
    placeCar(carModel, true, CFrame.new(P.x * K, posY, P.z * K).mul(CFrame.Angles(0, P.h + Math.PI, 0)), 0, 0, 0);
    setCarLights(carModel, night());
    applyStyle(carModel, carDef);
    if (Audio.available()) sound = Audio.new(carDef, true);
  };

  const drift = { active: false, score: 0, mult: 1, time: 0, idle: 0, tags: {}, combo: 1, comboT: 0, sign: 1, tandemPts: 0 };
  const placeAt = (x, y, z, h) => {
    P = CarPhysics.newCar(x / K, z / K, h);
    posY = y; vy = 0;
    idx = Track.nearest(x, z, null);
    Object.assign(drift, { active: false, score: 0, mult: 1, combo: 1, comboT: 0, tandemPts: 0 });
    Fx.clearSkids();
  };
  const resetCar = i => {
    if (!onPass && !i) {
      const min = mapFolder.GetAttribute('CityMin'), cpitch = mapFolder.GetAttribute('CityPitch'), street = mapFolder.GetAttribute('CityStreet');
      if (min) {
        const x = P.x * K, z = P.z * K;
        const gx = min.X + Math.floor((x - min.X) / cpitch + 0.5) * cpitch + street / 2;
        const gz = min.Y + Math.floor((z - min.Y) / cpitch + 0.5) * cpitch + street / 2;
        if (Math.abs(x - gx) < Math.abs(z - gz)) placeAt(gx, World.ground(gx, 200, z)[0] ?? 7, z, 0); else placeAt(x, World.ground(x, 200, gz)[0] ?? 7, gz, Math.PI / 2);
        return;
      }
    }
    i = i || Track.nearest(P.x * K, P.z * K, idx);
    placeAt(Track.X[i], Track.Y[i], Track.Z[i], Track.heading(i));
  };
  const goCity = () => {
    const sp = mapFolder.GetAttribute('CitySpawn');
    if (sp) { placeAt(sp.X, sp.Y + 0.5, sp.Z, Math.PI / 2); onPass = false; }
  };

  let shake = 0, wallT = 0, lastZone = -1;
  let showToast;
  // ===================== screens =====================
  // title
  const [title, tCol] = Ui.sheet(gui);
  text({ Text: 'KAIDO DRIFT\n<font color="#ff7eb6" size="40">街道 · 峠</font>', FontFace: Ui.DISPLAY, TextSize: 62, LineHeight: 0.95, LayoutOrder: 1, Parent: tCol });
  text({ Text: 'Midnight at Lake Ashi. Slide a 1989 coupe through Kojiri village, up the Hakone hairpins and along the shore, then down into the neon streets and elevated expressway of Shin-Hakone city. Earn credits for every drift and unlock the garage.', TextColor3: Ui.DIM, TextSize: 16, LineHeight: 1.3, LayoutOrder: 2, Parent: tCol });
  const tStats = Ui.stats([['Credits', Ui.GOLD], ['Best drift'], ['Cars']], 3, tCol);
  const tMenu = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 4, Parent: tCol }, [Ui.list(10)]);
  U.bSolo = Ui.button('Play solo', 'Just you on the mountain', 'primary', 1, tMenu);
  U.bPublic = Ui.button('Play with others', 'Public map · drift together · chat', null, 2, tMenu);
  U.bGarage = Ui.button('Garage', 'Unlock & paint', null, 3, tMenu);
  U.bSettings = Ui.button('Settings', 'Graphics, gearbox, assists, sound', null, 4, tMenu);
  U.bBoards = Ui.button('Leaderboards', 'Best drift and total points, worldwide', null, 5, tMenu);
  U.bAdmin = Ui.button('Admin panel', 'Only you can see this', 'ghost', 7, tMenu);
  U.bAdmin.Visible = profile.admin === true;
  {
    const [f] = Ui.field('Start at', 6, tMenu);
    Ui.chips([['city', 'Shin-Hakone city'], ['pass', 'Hakone pass']], S.start, v => { S.start = v; saveSettings(); }, 1, f);
  }
  Ui.fine(touch ? 'Drag on the left to steer. GAS, BRAKE and HAND BRAKE are on the right; hold BRAKE when stopped to reverse. To start a drift: steer hard with GAS, tap HAND BRAKE, or lift and re-press GAS (clutch kick). CAM switches to the cockpit view.'
    : 'W/↑ gas · S/↓ brake (hold to reverse) · A D / ← → steer · Space hand brake · drift: steer + gas, tap Space, or lift and re-press W (clutch kick) · C camera · Q/E shift (manual) · R reset · Esc pause. Controllers work too.', 5, tCol);
  [U.dailyF] = Ui.field('Daily challenges', 4, tCol);
  U.dailyF.LayoutOrder = 5;
  U.dailyRows = [];
  for (let k = 1; k <= 3; k++) {
    const row = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: k, Parent: U.dailyF }, [Ui.list(4)]);
    const label = text({ Text: '', TextSize: 14, RichText: true, LayoutOrder: 1, Parent: row });
    const back = make('Frame', { Size: new UDim2(1, 0, 0, 5), BackgroundColor3: new Color3(1, 1, 1), BackgroundTransparency: 0.88, BorderSizePixel: 0, LayoutOrder: 2, Parent: row }, [Ui.corner(3)]);
    const bar = make('Frame', { Size: new UDim2(0, 0, 1, 0), BackgroundColor3: Ui.NEON, BorderSizePixel: 0, Parent: back }, [Ui.corner(3)]);
    U.dailyRows.push({ label, bar });
  }
  const refreshDaily = () => {
    U.dailyRows.forEach((r, k) => {
      const c = profile.daily && profile.daily[k];
      r.label.Parent.Visible = !!c;
      if (c) {
        r.label.Text = (c.done ? '<font color="#59e3ff">✓ </font>' : '') + c.text + '  <font color="#ffc94d">+' + fmt(c.reward) + ' CR</font>';
        r.bar.Size = new UDim2(clamp(c.prog / c.goal, 0, 1), 0, 1, 0);
        r.bar.BackgroundColor3 = c.done ? Ui.NEON : Ui.SAKURA;
      }
    });
  };
  const refreshTitle = () => {
    refreshDaily();
    tStats[0].Text = fmt(profile.credits);
    tStats[1].Text = fmt(profile.best);
    tStats[2].Text = profile.owned.length + '/' + Config.Cars.length;
  };

  // garage
  const [garage, gCol] = Ui.sheet(gui, true);
  Ui.heading('Garage', 'ガレージ', 1, gCol);
  const gStats = Ui.stats([['Credits', Ui.GOLD]], 2, gCol);
  const gList = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 3, Parent: gCol }, [Ui.list(8)]);
  const gDetail = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 4, Parent: gCol }, [Ui.list(10)]);
  [U.gPaintF] = Ui.field('Paint (free)', 5, gCol);
  const gSwatches = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 1, Parent: U.gPaintF }, [
    make('UIListLayout', { Padding: new UDim(0, 8), FillDirection: Enum.FillDirection.Horizontal, Wraps: true, SortOrder: Enum.SortOrder.LayoutOrder }),
  ]);
  [U.gUpF] = Ui.field('Upgrades', 6, gCol);
  const gUpList = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 1, Parent: U.gUpF }, [Ui.list(8)]);
  [U.gStyleF] = Ui.field('Style', 7, gCol);
  const gStyle = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 1, Parent: U.gStyleF }, [Ui.list(10)]);
  Ui.fine('Drag on the car to turn it around.', 8, gCol);
  U.gBack = Ui.button('Back', null, null, 9, gCol);
  let renderGarage;
  const statBar = (label, v, parent, order) => {
    const row = make('Frame', { Size: new UDim2(1, 0, 0, 18), BackgroundTransparency: 1, LayoutOrder: order, Parent: parent });
    text({ Text: label.toUpperCase(), TextSize: 12, FontFace: Ui.BOLD, TextColor3: Ui.DIM, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0, 110, 1, 0), Parent: row });
    const back = make('Frame', { Size: new UDim2(1, -120, 0, 6), Position: new UDim2(0, 120, 0.5, -3), BackgroundColor3: new Color3(1, 1, 1), BackgroundTransparency: 0.88, BorderSizePixel: 0, Parent: row }, [Ui.corner(3)]);
    make('Frame', { Size: new UDim2(clamp(v, 0.05, 1), 0, 1, 0), BackgroundColor3: Ui.NEON, BorderSizePixel: 0, Parent: back }, [Ui.corner(3)]);
  };
  const tune = (id, action, value) => {
    task.spawn(() => {
      const res = R.Tune.InvokeServer(id, action, value);
      if (res) { profile = res; profile.settings = S; spawnCar(garageSel); renderGarage(); refreshTitle(); }
    });
  };
  const swatchRow = (parent, order, colors, cur, withOff, onPick) => {
    const row = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: order, Parent: parent }, [
      make('UIListLayout', { Padding: new UDim(0, 8), FillDirection: Enum.FillDirection.Horizontal, Wraps: true, SortOrder: Enum.SortOrder.LayoutOrder }),
    ]);
    for (let k = withOff ? 0 : 1; k <= colors.length; k++) {
      const sel = k === cur;
      const sw = make('TextButton', { Size: new UDim2(0, 34, 0, 34), Text: k === 0 ? 'OFF' : '', TextSize: 9, FontFace: Ui.BOLD, TextColor3: Ui.DIM,
        AutoButtonColor: false, BackgroundColor3: k === 0 ? Ui.INK : colors[k - 1], LayoutOrder: k, Parent: row }, [
        make('UICorner', { CornerRadius: new UDim(0, 17) }), Ui.stroke(sel ? Ui.SAKURA : Ui.LINE, sel ? 3 : 1, sel ? 0 : 0.6),
      ]);
      Ui.bouncy(sw);
      sw.Activated.Connect(() => onPick(k));
    }
  };
  const clearGui = f => { for (const c of f.GetChildren()) if (c.IsA('GuiObject')) c.Destroy(); };
  const renderTuning = (car, have) => {
    clearGui(gUpList); clearGui(gStyle);
    if (!have) {
      Ui.fine('Own this car to upgrade and style it.', 1, gUpList);
      Ui.fine('Own this car to upgrade and style it.', 1, gStyle);
      return;
    }
    const u = (profile.upg && profile.upg[car.id]) || {};
    Config.Upgrades.forEach((up, k0) => {
      const k = k0 + 1, l = u[up.key] || 0;
      const pips = '●'.repeat(l) + '○'.repeat(Config.UPGRADE_MAX - l);
      if (l >= Config.UPGRADE_MAX) Ui.button(up.name + '   ' + pips, up.desc + ' · fully upgraded', null, k, gUpList);
      else {
        const cost = up.cost[l];
        const b = Ui.button(up.name + '   ' + pips, up.desc + ' · ' + fmt(cost) + ' CR', profile.credits >= cost ? 'primary' : null, k, gUpList);
        b.Activated.Connect(() => { if (profile.credits >= cost) tune(car.id, 'up_' + up.key); else showToast('Need ' + fmt(cost - profile.credits) + ' more CR', Ui.DANGER); });
      }
    });
    const cs = (profile.cos && profile.cos[car.id]) || {};
    const [f1] = Ui.field(Config.Cosmetics.glow.name, 1, gStyle);
    if (cs.glowOwned) swatchRow(f1, 1, Config.GlowColors, cs.glow || 0, true, k => tune(car.id, 'glow', k));
    else {
      const c = Config.Cosmetics.glow.cost;
      Ui.button('Fit underglow', fmt(c) + ' CR · then any colour, free', profile.credits >= c ? 'primary' : null, 1, f1).Activated.Connect(() => tune(car.id, 'glowOwn'));
    }
    const [f2] = Ui.field(Config.Cosmetics.rims.name, 2, gStyle);
    if (cs.rimsOwned) swatchRow(f2, 1, Config.RimColors, cs.rims || 1, false, k => tune(car.id, 'rims', k));
    else {
      const c = Config.Cosmetics.rims.cost;
      Ui.button('Custom rims', fmt(c) + ' CR · then any colour, free', profile.credits >= c ? 'primary' : null, 1, f2).Activated.Connect(() => tune(car.id, 'rimsOwn'));
    }
    const [f3] = Ui.field(Config.Cosmetics.kit.name, 3, gStyle);
    if (cs.kit) Ui.button('Remove stance kit', 'Back to stock height (refitting costs ' + fmt(Config.Cosmetics.kit.cost) + ' CR)', 'ghost', 1, f3).Activated.Connect(() => tune(car.id, 'kitOff'));
    else {
      const c = Config.Cosmetics.kit.cost;
      Ui.button('Fit stance kit', 'Lowered body · ' + fmt(c) + ' CR', profile.credits >= c ? 'primary' : null, 1, f3).Activated.Connect(() => tune(car.id, 'kitOwn'));
    }
  };
  renderGarage = () => {
    gStats[0].Text = fmt(profile.credits);
    clearGui(gList);
    let order = 0;
    Config.Cars.forEach((car, k) => {
      order += 1;
      if (car.premium && !Config.Cars[k - 1].premium) {
        // the special cars section (Robux on Roblox; credits on the web)
        const h = text({ Text: 'SPECIAL CARS  <font color="#b3b0c4">·  faster than anything in the garage  ·  big credit prizes</font>', TextSize: 12, FontFace: Ui.BOLD, TextColor3: Ui.VIOLET, LayoutOrder: order, Parent: gList });
        h.RichText = true;
        order += 1;
      }
      const sel = car.id === garageSel, have = owned(car.id);
      const card = make('TextButton', { Size: new UDim2(1, 0, 0, 58), AutoButtonColor: false, Text: '', LayoutOrder: order, BackgroundColor3: car.premium ? Ui.VIOLET : new Color3(1, 1, 1), BackgroundTransparency: sel ? 0.82 : (car.premium ? 0.9 : 0.97), Parent: gList },
        [Ui.corner(14), Ui.stroke(sel ? Ui.SAKURA : (car.premium ? Ui.VIOLET : Ui.LINE), sel ? 1.5 : 1, sel ? 0 : (car.premium ? 0.5 : 0.87))]);
      Ui.bouncy(card);
      text({ Text: car.name, FontFace: Ui.BOLD, TextSize: 16, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(1, -150, 0, 22), Position: new UDim2(0, 14, 0, 8), TextWrapped: false, Parent: card });
      text({ Text: car.tag, TextSize: 13, TextColor3: Ui.DIM, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(1, -150, 0, 18), Position: new UDim2(0, 14, 0, 31), TextWrapped: false, TextTruncate: Enum.TextTruncate.AtEnd, Parent: card });
      const pr = car.id === profile.selected ? 'DRIVING' : have ? 'OWNED' : fmt(car.price) + ' CR';
      text({ Text: pr, FontFace: Ui.BOLD, TextSize: 15, TextColor3: have ? Ui.NEON : car.premium ? Ui.VIOLET : (profile.credits >= car.price ? Ui.GOLD : Ui.DIM), AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0, 130, 1, 0), Position: new UDim2(1, -144, 0, 0), TextXAlignment: Enum.TextXAlignment.Right, TextWrapped: false, Parent: card });
      card.Activated.Connect(() => { garageSel = car.id; spawnCar(car.id); renderGarage(); });
    });
    clearGui(gDetail);
    const car = Config.tuned(Config.car(garageSel), profile.upg && profile.upg[garageSel]);
    const kwPerT = car.torque * Math.min(car.red * 0.9, car.peak + 1600) / 9549 / (car.mass / 1000);
    statBar('Power', kwPerT / 260, gDetail, 1);
    statBar('Grip', (car.mu - 0.98) / 0.22, gDetail, 2);
    statBar('Weight', 1 - (car.mass - 900) / 700, gDetail, 3);
    statBar('Steering lock', (car.lock - 46) / 17, gDetail, 4);
    statBar('Agility', 1 - (car.b.wb - 2.2) / 0.6, gDetail, 5);
    text({ Text: car.tag + '  ·  ' + (car.turbo ? 'turbo' : 'naturally aspirated') + '  ·  ' + car.gears.length + '-speed', TextSize: 13, TextColor3: Ui.DIM, LayoutOrder: 0, Parent: gDetail });
    const have = owned(car.id);
    let label, note, kind;
    if (car.id === profile.selected) [label, note, kind] = ['Driving this car', null, null];
    else if (have) [label, note, kind] = ['Drive this car', null, 'primary'];
    else if (profile.credits >= car.price) [label, note, kind] = ['Buy', fmt(car.price) + ' CR', 'primary'];
    else [label, note, kind] = ['Locked', 'Need ' + fmt(car.price - profile.credits) + ' more CR', null];
    const act = Ui.button(label, note, kind, 6, gDetail);
    act.Activated.Connect(() => {
      let res;
      if (have && car.id !== profile.selected) res = R.Select.InvokeServer(car.id);
      else if (!have && car.premium) { if (profile.credits >= car.price) R.BuySpecial.FireServer(car.id); return; }
      else if (!have && profile.credits >= car.price) res = R.Buy.InvokeServer(car.id);
      if (res) { profile = res; profile.settings = S; spawnCar(garageSel); renderGarage(); refreshTitle(); }
    });
    clearGui(gSwatches);
    const [, cur] = paintOf(car.id);
    for (let k = 0; k <= Config.Paints.length; k++) {
      const col = k === 0 ? car.color : Config.Paints[k - 1];
      const sw = make('TextButton', { Size: new UDim2(0, 36, 0, 36), Text: '', AutoButtonColor: true, BackgroundColor3: col, LayoutOrder: k, Parent: gSwatches }, [
        make('UICorner', { CornerRadius: new UDim(0, 18) }), Ui.stroke(k === cur ? Ui.SAKURA : Ui.LINE, k === cur ? 3 : 1, k === cur ? 0 : 0.6),
      ]);
      sw.Activated.Connect(() => {
        profile.paint[car.id] = k;
        if (carModel) CarModel.paint(carModel, col);
        task.spawn(() => { const res = R.Paint.InvokeServer(car.id, k); if (res) profile.paint = res.paint; });
        renderGarage();
      });
    }
    renderTuning(car, have);
  };

  // leaderboards
  const [boards, bCol] = Ui.sheet(gui, true);
  Ui.heading('Leaderboards', 'ランキング', 1, bCol);
  U.boardCols = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 2, Parent: bCol }, [Ui.list(16)]);
  U.boardsBack = Ui.button('Back', null, null, 4, bCol);
  Ui.fine('Updated every minute. Your scores count once you bank a drift. The same board glows over the street at the city start.', 3, bCol);
  const renderBoards = () => {
    clearGui(U.boardCols);
    let data = {};
    try { data = JSON.parse(ReplicatedStorage.GetAttribute('Boards') || '{}'); } catch { data = {}; }
    [['best', 'Best single drift', Ui.GOLD], ['total', 'Total drift points', Ui.NEON]].forEach((col, o) => {
      const [f] = Ui.field(col[1], o + 1, U.boardCols);
      const list = data[col[0]] || [];
      if (list.length === 0) Ui.fine('No scores yet. Bank a drift to be first.', 1, f);
      list.forEach((e, k0) => {
        const k = k0 + 1, me = e[0] === player.Name;
        const row = Ui.glass(make('Frame', { Size: new UDim2(1, 0, 0, 36), LayoutOrder: k, Parent: f }), 12, me ? 0.2 : 0.5);
        text({ Text: k + '   ' + e[0], TextSize: 15, FontFace: Ui.BOLD, TextColor3: me ? Ui.SAKURA : Ui.TEXT, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(1, -150, 1, 0), Position: new UDim2(0, 14, 0, 0), TextWrapped: false, TextYAlignment: Enum.TextYAlignment.Center, Parent: row });
        text({ Text: fmt(e[1]), TextSize: 15, FontFace: Ui.BOLD, TextColor3: col[2], AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0, 130, 1, 0), Position: new UDim2(1, -144, 0, 0), TextXAlignment: Enum.TextXAlignment.Right, TextYAlignment: Enum.TextYAlignment.Center, TextWrapped: false, Parent: row });
      });
    });
  };
  // admin panel: only for the Roblox game's owner (never shown on the web)
  U.adminRoot = make('Frame', { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Visible: false, Parent: gui });
  U.adminPanel = { refresh() { } };

  // settings
  const [settings, sCol] = Ui.sheet(gui);
  Ui.heading('Settings', '設定', 1, sCol);
  {
    const [f] = Ui.field('Graphics quality', 2, sCol);
    Ui.chips([['auto', 'Auto'], ['low', 'Low'], ['medium', 'Medium'], ['high', 'High']], S.quality, v => { S.quality = v; applyQuality(); saveSettings(); }, 1, f);
    Ui.fine('Low: phones and older computers. Medium adds shadows. High adds bloom and every tree.', 2, f);
  }
  let setTimeSlider, setTimeChips;
  {
    const [f, l] = Ui.field('Time of day', 3, sCol);
    U.timeLabel = l;
    const show = () => { U.timeLabel.Text = `TIME OF DAY · ${pad2(Math.floor(S.time))}:${pad2(Math.floor((S.time % 1) * 60 + 0.5))}`; };
    setTimeSlider = Ui.slider(0, 23.75, 0.25, S.time, v => { S.time = v; show(); applyTime(); saveSettings(); if (setTimeChips) setTimeChips(v); }, 1, f);
    setTimeChips = Ui.chips([[5.75, 'Dawn'], [12.5, 'Noon'], [17.25, 'Sunset'], [0, 'Midnight']], S.time, v => { S.time = v; setTimeSlider(v); show(); applyTime(); saveSettings(); }, 2, f);
    show();
  }
  {
    const [f] = Ui.field('Gearbox', 4, sCol);
    Ui.chips([['auto', 'Automatic'], ['manual', 'Manual']], S.trans, v => { S.trans = v; saveSettings(); }, 1, f);
    Ui.fine(touch ? 'Manual: ▲ ▼ buttons appear above the pedals.' : 'Manual: Q / E or LB / RB to shift. Hold brake when stopped to reverse in either mode.', 2, f);
  }
  {
    const [f] = Ui.field('Drift assists', 5, sCol);
    const opts = Config.Assists.map(a => [a.id, a.name]);
    const assistDesc = Ui.fine(Config.assist(S.assist).desc, 2, f);
    Ui.chips(opts, S.assist, v => { S.assist = v; assistDesc.Text = Config.assist(v).desc; saveSettings(); }, 1, f);
    Ui.fine('Every level uses the same tyre physics. Assists only help with steering and catching slides, like in sim drift games.', 3, f);
  }
  let setCamChips;
  {
    const [f] = Ui.field('Camera', 6, sCol);
    setCamChips = Ui.chips([[0, 'Chase'], [1, 'Far chase'], [2, 'Cockpit'], [3, 'Hood']], S.cam, v => { S.cam = v; camMode = v; saveSettings(); }, 1, f);
  }
  {
    const [f] = Ui.field('Steering sensitivity', 7, sCol);
    Ui.slider(0.5, 1.6, 0.05, S.sens, v => { S.sens = v; saveSettings(); }, 1, f);
  }
  {
    const [f] = Ui.field('Sound', 8, sCol);
    Ui.chips([[true, 'On'], [false, 'Off']], S.sound, v => { S.sound = v; saveSettings(); }, 1, f);
    Ui.slider(0, 1, 0.05, S.volume, v => { S.volume = v; saveSettings(); }, 2, f);
    Ui.fine("Engine sound: the game's own engine sounds are installed.", 3, f);
  }
  {
    const [f] = Ui.field('Your progress', 9, sCol);
    Ui.fine('Credits, cars, paint and these settings are saved in this browser automatically.', 1, f);
    const erase = Ui.button('Erase progress', null, 'ghost', 2, f);
    let sure = false;
    erase.Activated.Connect(() => {
      if (!sure) {
        sure = true;
        erase.Label.Text = 'TAP AGAIN TO ERASE EVERYTHING';
        erase.Label.TextColor3 = Ui.DANGER;
        task.delay(4, () => { sure = false; erase.Label.Text = 'ERASE PROGRESS'; erase.Label.TextColor3 = Ui.TEXT; });
      } else {
        sure = false;
        const res = R.Erase.InvokeServer();
        if (res) { profile = res; profile.settings = S; garageSel = profile.selected; spawnCar(); refreshTitle(); }
        erase.Label.Text = 'PROGRESS ERASED';
      }
    });
  }
  U.sBack = Ui.button('Back', null, null, 10, sCol);

  // pause
  const [pause, pCol] = Ui.sheet(gui);
  Ui.heading('Paused', '一時停止', 1, pCol);
  const pMenu = make('Frame', { Size: new UDim2(1, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, BackgroundTransparency: 1, LayoutOrder: 2, Parent: pCol }, [Ui.list(10)]);
  U.pResume = Ui.button('Resume', null, 'primary', 1, pMenu);
  U.pGarage = Ui.button('Garage', 'Unlock & paint', null, 2, pMenu);
  U.pSettings = Ui.button('Settings', 'Graphics, gearbox, assists', null, 3, pMenu);
  U.pPass = Ui.button('Go to Hakone pass', 'Start line at Kojiri', null, 4, pMenu);
  U.pCity = Ui.button('Go to Shin-Hakone city', 'Neon streets & expressway', null, 5, pMenu);
  U.pPhoto = Ui.button('Photo mode', 'Freeze the moment · drag to frame your shot', null, 6, pMenu);
  U.pQuit = Ui.button('Main menu', null, 'ghost', 7, pMenu);
  U.pAdmin = Ui.button('Admin panel', 'Only you can see this', 'ghost', 8, pMenu);
  U.pAdmin.Visible = profile.admin === true;

  // ===================== HUD =====================
  const hud = make('Frame', { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Visible: false, Parent: gui });
  U.photoBar = Ui.glass(make('Frame', { Size: new UDim2(0, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.XY, AnchorPoint: new Vector2(0.5, 1), Position: new UDim2(0.5, 0, 1, -18), Visible: false, Parent: gui }, [Ui.list(12, true, Enum.VerticalAlignment.Center), Ui.pad(16, 8, 8, 8)]), 18, 0.4);
  text({ Text: touch ? 'Drag to orbit · pinch to zoom' : 'Drag to orbit · scroll to zoom · Esc to leave', TextSize: 13, TextColor3: Ui.DIM, AutomaticSize: Enum.AutomaticSize.XY, Size: new UDim2(), TextWrapped: false, LayoutOrder: 1, Parent: U.photoBar });
  U.photoExit = Ui.bouncy(make('TextButton', { Size: new UDim2(0, 120, 0, 34), Text: 'Done', TextColor3: Ui.INK, FontFace: Ui.BOLD, TextSize: 14, BackgroundColor3: Ui.SAKURA, AutoButtonColor: false, LayoutOrder: 2, Parent: U.photoBar }, [Ui.corner(17)]));
  U.photo = { yaw: 0, pitch: 0.25, dist: 9 };
  const shadowT = o => { make('UIStroke', { Color: new Color3(0, 0, 0), Thickness: 1, Transparency: 0.55, ApplyStrokeMode: Enum.ApplyStrokeMode.Contextual, Parent: o }); return o; };
  const tl = Ui.glass(make('Frame', { Size: new UDim2(0, 0, 0, 0), AutomaticSize: Enum.AutomaticSize.XY, Position: new UDim2(0, 16, 0, 62), Parent: hud }, [Ui.list(2), Ui.pad(14, 8, 18, 10)]), 16, 0.45);
  U.credRow = make('Frame', { Size: new UDim2(1, 0, 0, 26), BackgroundTransparency: 1, LayoutOrder: 1, Parent: tl }, [Ui.list(8, true, Enum.VerticalAlignment.Bottom)]);
  text({ Text: 'CR', TextSize: 11, FontFace: Ui.BOLD, TextColor3: Ui.DIM, AutomaticSize: Enum.AutomaticSize.XY, Size: new UDim2(), TextWrapped: false, LayoutOrder: 1, Parent: U.credRow });
  const hCredits = shadowT(text({ Text: '0', TextSize: 22, FontFace: Ui.BOLD, TextColor3: Ui.GOLD, AutomaticSize: Enum.AutomaticSize.XY, Size: new UDim2(), TextWrapped: false, LayoutOrder: 2, Parent: U.credRow }));
  const hZone = shadowT(text({ Text: '', TextSize: touch ? 12 : 15, FontFace: Ui.DISPLAY, LayoutOrder: 2, Parent: tl }));
  const dW = touch ? 200 : 360;
  const dBox = make('Frame', { Size: new UDim2(0, dW, 0, 0), AutomaticSize: Enum.AutomaticSize.Y, Position: new UDim2(0.5, -dW / 2, 0, touch ? 6 : 12), BackgroundTransparency: 1, Visible: false, Parent: hud }, [
    make('UIListLayout', { Padding: new UDim(0, touch ? 0 : 2), HorizontalAlignment: Enum.HorizontalAlignment.Center, SortOrder: Enum.SortOrder.LayoutOrder }),
  ]);
  const dTier = shadowT(text({ Text: 'DRIFT', TextSize: touch ? 10 : 13, FontFace: Ui.BOLD, TextColor3: Ui.GOLD, TextXAlignment: Enum.TextXAlignment.Center, LayoutOrder: 1, Parent: dBox }));
  const dScore = shadowT(text({ Text: '0', TextSize: touch ? 30 : 52, FontFace: Ui.DISPLAY, TextXAlignment: Enum.TextXAlignment.Center, LayoutOrder: 2, Parent: dBox }));
  const dMult = shadowT(text({ Text: '×1.0', TextSize: touch ? 12 : 18, FontFace: Ui.BOLD, TextColor3: Ui.SAKURA, TextXAlignment: Enum.TextXAlignment.Center, LayoutOrder: 3, Parent: dBox }));
  const dTags = make('Frame', { Size: new UDim2(1, 0, 0, touch ? 16 : 22), BackgroundTransparency: 1, LayoutOrder: 4, Parent: dBox }, [
    make('UIListLayout', { Padding: new UDim(0, 6), FillDirection: Enum.FillDirection.Horizontal, HorizontalAlignment: Enum.HorizontalAlignment.Center, SortOrder: Enum.SortOrder.LayoutOrder }),
  ]);
  const toast = shadowT(text({ Text: '', TextSize: touch ? 16 : 24, FontFace: Ui.DISPLAY, TextColor3: Ui.GOLD, TextXAlignment: Enum.TextXAlignment.Center, Size: new UDim2(0, 520, 0, 0), Position: new UDim2(0.5, -260, 0, touch ? 82 : 130), TextTransparency: 1, Parent: hud }));
  let toastT = 0;
  showToast = (t, c) => { toast.Text = t; toast.TextColor3 = c || Ui.GOLD; toast.TextTransparency = 0; toastT = 2.4; Ui.pop(toast, 1.25); };
  const hint = make('TextLabel', { Size: new UDim2(0, 0, 0, 34), AutomaticSize: Enum.AutomaticSize.X, AnchorPoint: new Vector2(0.5, 0), Position: new UDim2(0.5, 0, 0.42, 0), BackgroundColor3: Color3.fromHex('0a0b14'), BackgroundTransparency: 0.3, Text: '', FontFace: Ui.BOLD, TextSize: 14, TextColor3: Ui.TEXT, Visible: false, Parent: hud }, [Ui.corner(4), Ui.pad(14, 0, 14, 0)]);
  // speed
  const spBox = Ui.glass(make('Frame', { Size: new UDim2(0, 210, 0, 96), Position: new UDim2(0.5, -105, 1, touch ? -112 : -108), Parent: hud }, [Ui.pad(10, 6, 10, 6)]), 20, 0.45);
  const hSpeed = shadowT(text({ Text: '0', TextSize: touch ? 42 : 56, FontFace: Ui.DISPLAY, TextXAlignment: Enum.TextXAlignment.Right, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0.6, 0, 0, 56), Parent: spBox }));
  text({ Text: 'KM/H', TextSize: 11, FontFace: Ui.BOLD, TextColor3: Ui.DIM, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0.38, 0, 0, 14), Position: new UDim2(0.64, 0, 0, 12), Parent: spBox });
  const hGear = shadowT(text({ Text: '1', TextSize: 22, FontFace: Ui.BOLD, TextColor3: Ui.NEON, AutomaticSize: Enum.AutomaticSize.None, Size: new UDim2(0.38, 0, 0, 26), Position: new UDim2(0.64, 0, 0, 26), Parent: spBox }));
  U.rpmBack = make('Frame', { Size: new UDim2(1, 0, 0, 4), Position: new UDim2(0, 0, 0, 62), BackgroundColor3: new Color3(1, 1, 1), BackgroundTransparency: 0.87, BorderSizePixel: 0, Parent: spBox }, [Ui.corner(2)]);
  const rpmBar = make('Frame', { Size: new UDim2(0.2, 0, 1, 0), BackgroundColor3: new Color3(1, 1, 1), BorderSizePixel: 0, Parent: U.rpmBack }, [
    Ui.corner(2), make('UIGradient', { Color: new ColorSequence([new ColorSequenceKeypoint(0, Ui.NEON), new ColorSequenceKeypoint(0.85, Ui.SAKURA), new ColorSequenceKeypoint(1, Ui.DANGER)]) }),
  ]);
  const hAngle = text({ Text: '', TextSize: 11, FontFace: Ui.BOLD, TextColor3: Ui.DIM, TextXAlignment: Enum.TextXAlignment.Center, Position: new UDim2(0, 0, 0, 70), Parent: spBox });
  // minimap
  const mmSize = touch ? 100 : 150;
  const mm = make('Frame', { Size: new UDim2(0, mmSize, 0, mmSize), Position: new UDim2(1, -mmSize - 14, 0, 14), BackgroundColor3: Color3.fromHex('1a1d36'), BackgroundTransparency: 0.45, ClipsDescendants: true, Parent: hud }, [make('UICorner', { CornerRadius: new UDim(0.5, 0) }), Ui.stroke(Ui.LINE, 1.5, 0.7)]);
  const cityMin = mapFolder.GetAttribute('CityMin'), cityMax = mapFolder.GetAttribute('CityMax');
  let mmMinX = Infinity, mmMaxX = -Infinity, mmMinZ = Infinity, mmMaxZ = -Infinity;
  for (let i = 1; i <= Track.N; i++) { mmMinX = Math.min(mmMinX, Track.X[i]); mmMaxX = Math.max(mmMaxX, Track.X[i]); mmMinZ = Math.min(mmMinZ, Track.Z[i]); mmMaxZ = Math.max(mmMaxZ, Track.Z[i]); }
  if (cityMin) { mmMinX = Math.min(mmMinX, cityMin.X); mmMaxX = Math.max(mmMaxX, cityMax.X); mmMinZ = Math.min(mmMinZ, cityMin.Y); mmMaxZ = Math.max(mmMaxZ, cityMax.Y); }
  const mmSpan = Math.max(mmMaxX - mmMinX, mmMaxZ - mmMinZ) * 1.08;
  const mmPos = (x, z) => new UDim2(0.5 + (x - (mmMinX + mmMaxX) / 2) / mmSpan, 0, 0.5 + (z - (mmMinZ + mmMaxZ) / 2) / mmSpan, 0);
  U.zoneCol = { 0: Ui.NEON, 1: Ui.SAKURA, 2: Ui.GOLD };
  for (let i = 1; i <= Track.N; i += Math.max(1, Math.floor(Track.N / 260)))
    make('Frame', { Size: new UDim2(0, 3, 0, 3), AnchorPoint: new Vector2(0.5, 0.5), Position: mmPos(Track.X[i], Track.Z[i]), BackgroundColor3: U.zoneCol[Track.ZONE[i]], BorderSizePixel: 0, Parent: mm });
  if (cityMin) {
    const grid = mapFolder.GetAttribute('CityGrid'), pitch2 = mapFolder.GetAttribute('CityPitch'), street = mapFolder.GetAttribute('CityStreet');
    const span = (cityMax.X - cityMin.X) / mmSpan;
    for (let k = 0; k <= grid; k += 2) {
      const x = cityMin.X + k * pitch2 + street / 2;
      make('Frame', { Size: new UDim2(0, 1, span, 0), AnchorPoint: new Vector2(0.5, 0), Position: new UDim2(mmPos(x, 0).X.Scale, 0, mmPos(0, cityMin.Y).Y.Scale, 0), BackgroundColor3: Color3.fromRGB(200, 200, 210), BackgroundTransparency: 0.6, BorderSizePixel: 0, Parent: mm });
      const z = cityMin.Y + k * pitch2 + street / 2;
      make('Frame', { Size: new UDim2(span, 0, 0, 1), AnchorPoint: new Vector2(0, 0.5), Position: new UDim2(mmPos(cityMin.X, 0).X.Scale, 0, mmPos(0, z).Y.Scale, 0), BackgroundColor3: Color3.fromRGB(200, 200, 210), BackgroundTransparency: 0.6, BorderSizePixel: 0, Parent: mm });
    }
    const r1 = mapFolder.GetAttribute('CityRing'), r2 = mapFolder.GetAttribute('CityRing2');
    const p0 = mmPos(r1.X, r1.Y), p1 = mmPos(r1.Z, r2);
    make('Frame', { Size: new UDim2(p1.X.Scale - p0.X.Scale, 0, p1.Y.Scale - p0.Y.Scale, 0), Position: p0, BackgroundTransparency: 1, Parent: mm }, [make('UIStroke', { Color: Ui.SAKURA, Thickness: 1.5, ApplyStrokeMode: Enum.ApplyStrokeMode.Border })]);
  }
  const mmMe = make('Frame', { Size: new UDim2(0, 10, 0, 10), AnchorPoint: new Vector2(0.5, 0.5), BackgroundColor3: Ui.SAKURA, BorderSizePixel: 0, ZIndex: 3, Parent: mm }, [make('UICorner', { CornerRadius: new UDim(0.5, 0) }), make('UIStroke', { Color: Ui.INK, Thickness: 2, ApplyStrokeMode: Enum.ApplyStrokeMode.Border })]);
  // buttons
  const hb = make('Frame', { Size: new UDim2(0, 4 * 60, 0, 44), BackgroundTransparency: 1, Parent: hud }, [
    make('UIListLayout', { FillDirection: Enum.FillDirection.Horizontal, Padding: new UDim(0, 6), HorizontalAlignment: Enum.HorizontalAlignment.Right, SortOrder: Enum.SortOrder.LayoutOrder }),
  ]);
  hb.Position = touch ? new UDim2(1, -mmSize - 14 - 4 * 60 - 8, 0, 14) : new UDim2(1, -4 * 60 - 14, 1, -58);
  const hudBtn = (t, order) => Ui.bouncy(Ui.glass(make('TextButton', { Size: new UDim2(0, 54, 0, 44), Text: t, TextColor3: Ui.TEXT, FontFace: Ui.BOLD, TextSize: 13, AutoButtonColor: false, LayoutOrder: order, Parent: hb }), 14, 0.45));
  const bCam = hudBtn('CAM', 1), bSnd = hudBtn('SND', 2), bPause = hudBtn('II', 3);

  // touch controls
  const touchState = { gas: false, brake: false, hand: false, steer: 0 };
  let shiftRow = null;
  if (touch) {
    const steerZone = make('Frame', { Size: new UDim2(0.45, 0, 0.6, 0), Position: new UDim2(0, 0, 0.4, 0), BackgroundTransparency: 1, Parent: hud });
    const knobBase = make('Frame', { Size: new UDim2(0, 170, 0, 56), Position: new UDim2(0, 24, 1, -84), BackgroundColor3: Color3.fromHex('0a0b14'), BackgroundTransparency: 0.45, Parent: hud }, [make('UICorner', { CornerRadius: new UDim(0.5, 0) }), Ui.stroke(Ui.LINE, 1, 0.8)]);
    const knob = make('Frame', { Size: new UDim2(0, 48, 0, 48), Position: new UDim2(0.5, -24, 0, 4), BackgroundColor3: Ui.NEON, BackgroundTransparency: 0.25, Parent: knobBase }, [make('UICorner', { CornerRadius: new UDim(0.5, 0) })]);
    let steerInput = null, startX = 0;
    steerZone.InputBegan.Connect(io => { if (io.UserInputType === Enum.UserInputType.Touch && !steerInput) { steerInput = io; startX = io.Position.X; } });
    UserInputService.InputChanged.Connect(io => { if (io === steerInput) touchState.steer = clamp((io.Position.X - startX) / 70, -1, 1); });
    UserInputService.InputEnded.Connect(io => { if (io === steerInput) { steerInput = null; touchState.steer = 0; } });
    RunService.RenderStepped.Connect(() => { knob.Position = new UDim2(0.5, -24 + touchState.steer * 58, 0, 4); });
    const pedal = (t, size, pos, color, key) => {
      const b = make('TextButton', { Size: size, Position: pos, BackgroundColor3: color, BackgroundTransparency: 0.3, Text: t, TextColor3: Ui.INK, FontFace: Ui.BOLD, TextSize: 15, AutoButtonColor: false, Parent: hud }, [Ui.corner(18), Ui.stroke(Ui.LINE, 1.5, 0.5), make('UIGradient', { Rotation: 90, Transparency: new NumberSequence(0, 0.3) })]);
      Ui.bouncy(b);
      const held = new Set();
      b.InputBegan.Connect(io => { if (io.UserInputType === Enum.UserInputType.Touch) { held.add(io); touchState[key] = true; b.BackgroundTransparency = 0.05; } });
      b.InputEnded.Connect(io => { held.delete(io); if (held.size === 0) { touchState[key] = false; b.BackgroundTransparency = 0.3; } });
      return b;
    };
    pedal('GAS', new UDim2(0, 88, 0, 150), new UDim2(1, -102, 1, -164), Ui.SAKURA, 'gas');
    pedal('BRAKE', new UDim2(0, 84, 0, 70), new UDim2(1, -194, 1, -84), Color3.fromRGB(214, 216, 226), 'brake');
    pedal('HAND', new UDim2(0, 84, 0, 70), new UDim2(1, -194, 1, -164), Ui.NEON, 'hand');
    const reset = Ui.bouncy(Ui.glass(make('TextButton', { Size: new UDim2(0, 44, 0, 40), Position: new UDim2(1, -58, 1, -214), Text: '↺', TextColor3: Ui.TEXT, TextSize: 20, FontFace: Ui.BOLD, AutoButtonColor: false, Parent: hud }), 14, 0.45));
    reset.Activated.Connect(() => resetCar());
    shiftRow = make('Frame', { Size: new UDim2(0, 100, 0, 40), Position: new UDim2(1, -164, 1, -214), BackgroundTransparency: 1, Parent: hud }, [Ui.list(8, true)]);
    [['▼', -1], ['▲', 1]].forEach((d, k) => {
      const sb = Ui.bouncy(Ui.glass(make('TextButton', { Size: new UDim2(0, 46, 0, 40), Text: d[0], TextColor3: Ui.TEXT, TextSize: 18, FontFace: Ui.BOLD, AutoButtonColor: false, LayoutOrder: k + 1, Parent: shiftRow }), 14, 0.45));
      sb.Activated.Connect(() => { if (d[1] > 0) CarPhysics.shiftUp(P, carDef); else CarPhysics.shiftDown(P, carDef); });
    });
  }

  // ===================== screen switching =====================
  let mode = 'title';
  let returnTo = 'title';
  U.version = Ui.glass(make('TextLabel', { Size: new UDim2(0, 0, 0, 28), AutomaticSize: Enum.AutomaticSize.X, AnchorPoint: new Vector2(1, 1),
    Position: new UDim2(1, -16, 1, -16), Text: 'Version ' + Config.VERSION, TextSize: 13, FontFace: Ui.BOLD, TextColor3: Ui.TEXT, ZIndex: 20, Parent: gui },
  [Ui.pad(12, 0, 12, 0)]), 14, 0.45);
  const setMode = m => {
    if ((m === 'garage' || m === 'settings') && (mode === 'pause' || mode === 'play')) returnTo = 'pause';
    else if (m === 'garage' || m === 'settings') returnTo = 'title';
    if (mode === 'garage' && m !== 'garage' && garageSel !== profile.selected) { garageSel = profile.selected; spawnCar(); }
    mode = m;
    if (m === 'boards') renderBoards();
    if (m === 'admin') U.adminPanel.refresh();
    for (const [name, root] of Object.entries({ title, garage, settings, pause, boards, admin: U.adminRoot })) {
      if (name === m) { if (!root.Visible) Ui.show(root); } else root.Visible = false;
    }
    Ui.blur(m !== 'play' && m !== 'photo');
    U.version.Visible = m !== 'play' && m !== 'photo';
    U.photoBar.Visible = m === 'photo';
    if (m !== 'play') Fx.tandem(null, null, 0);
    if (m === 'photo') { U.photo.yaw = P.h + Math.PI * 0.75; U.photo.pitch = 0.22; U.photo.dist = 8; }
    hud.Visible = m === 'play';
    if (m === 'title') refreshTitle();
    if (m === 'garage') { garageSel = profile.selected; renderGarage(); }
    if (m === 'play' && shiftRow) shiftRow.Visible = S.trans === 'manual';
    if (m !== 'play' && sound) sound.mute();
  };
  U.setMode = setMode;
  const start = pub => {
    R.SetMode.FireServer(pub ? 'public' : 'solo');
    setMode('play');
    if (S.start === 'city') goCity(); else { resetCar(START); onPass = true; }
    lastZone = -1;
    showToast(pub ? 'Public map · everyone here drives together' : 'Solo · just you', pub ? Ui.NEON : Ui.TEXT);
  };
  U.bSolo.Activated.Connect(() => start(false));
  U.bPublic.Activated.Connect(() => start(true));
  U.bGarage.Activated.Connect(() => setMode('garage'));
  U.bSettings.Activated.Connect(() => setMode('settings'));
  U.bBoards.Activated.Connect(() => setMode('boards'));
  U.boardsBack.Activated.Connect(() => setMode('title'));
  ReplicatedStorage.GetAttributeChangedSignal('Boards').Connect(() => { if (mode === 'boards') renderBoards(); });
  U.gBack.Activated.Connect(() => setMode(returnTo));
  U.sBack.Activated.Connect(() => { physSet.assist = S.assist; physSet.trans = S.trans; physSet.sens = S.sens; setMode(returnTo); });
  U.pResume.Activated.Connect(() => setMode('play'));
  U.pGarage.Activated.Connect(() => setMode('garage'));
  U.pSettings.Activated.Connect(() => setMode('settings'));
  U.pPass.Activated.Connect(() => { resetCar(START); onPass = true; setMode('play'); });
  U.pCity.Activated.Connect(() => { goCity(); setMode('play'); });
  U.pQuit.Activated.Connect(() => { R.SetMode.FireServer('solo'); setMode('title'); });
  U.pPhoto.Activated.Connect(() => setMode('photo'));
  U.photoExit.Activated.Connect(() => setMode('pause'));
  UserInputService.InputChanged.Connect((io, processed) => {
    if (mode !== 'garage' && mode !== 'photo') return;
    const t = io.UserInputType;
    if (t === Enum.UserInputType.MouseWheel && mode === 'photo') { U.photo.dist = clamp(U.photo.dist - io.Position.Z * 0.8, 3, 30); return; }
    if (processed) return;
    const dragging = t === Enum.UserInputType.Touch || (t === Enum.UserInputType.MouseMovement && UserInputService.IsMouseButtonPressed(Enum.UserInputType.MouseButton1));
    if (!dragging) return;
    const d = io.Delta;
    if (mode === 'garage') { U.orbitNudge = (U.orbitNudge || 0) - d.X * 0.008; U.dragT = osClock(); }
    else { U.photo.yaw -= d.X * 0.008; U.photo.pitch = clamp(U.photo.pitch + d.Y * 0.006, -0.1, 1.3); }
  });
  UserInputService.TouchPinch.Connect((_, scale, __, state) => {
    if (mode === 'photo' && state === Enum.UserInputState.Change) U.photo.dist = clamp(U.photo.dist / Math.pow(Math.max(scale, 0.5), 0.05), 3, 30);
  });
  // a special car bought (or a daily challenge finished): the server sends the new profile
  R.Profile.OnClientEvent.Connect((res, message) => {
    const carChanged = res.selected !== profile.selected;
    profile = res; profile.settings = S;
    if (message) { showToast(message, Ui.GOLD); if (U.showCallout) U.showCallout('CHALLENGE COMPLETE!', Ui.NEON); }
    else { garageSel = profile.selected; if (carChanged) spawnCar(profile.selected); showToast('Unlocked · ' + Config.car(profile.selected).name, Ui.VIOLET); }
    if (mode === 'garage') renderGarage();
    refreshTitle();
  });
  U.CAM_NAMES = { 0: 'Chase', 1: 'Far chase', 2: 'Cockpit · first person', 3: 'Hood' };
  const cycleCam = () => { camMode = (camMode + 1) % 4; S.cam = camMode; setCamChips(camMode); saveSettings(); showToast(U.CAM_NAMES[camMode], Ui.TEXT); };
  bCam.Activated.Connect(cycleCam);
  bSnd.Activated.Connect(() => { S.sound = !S.sound; saveSettings(); showToast(S.sound ? 'Sound on' : 'Sound off', Ui.TEXT); });
  bPause.Activated.Connect(() => setMode('pause'));
  UserInputService.InputBegan.Connect((io, processed) => {
    if (processed) return;
    const k = io.KeyCode, KC = Enum.KeyCode;
    if (mode === 'play') {
      if (k === KC.C || k === KC.V || k === KC.ButtonY) cycleCam();
      if (k === KC.R || k === KC.ButtonSelect) resetCar();
      if (k === KC.Escape || k === KC.P || k === KC.ButtonStart) setMode('pause');
      if (S.trans === 'manual') {
        if (k === KC.E || k === KC.ButtonR1 || k === KC.DPadUp) CarPhysics.shiftUp(P, carDef);
        if (k === KC.Q || k === KC.ButtonL1 || k === KC.DPadDown) CarPhysics.shiftDown(P, carDef);
      }
    } else if (mode === 'pause' && (k === KC.Escape || k === KC.P || k === KC.ButtonStart)) setMode('play');
    else if (mode === 'photo' && (k === KC.Escape || k === KC.ButtonB || k === KC.ButtonStart)) setMode('pause');
  });

  // ===================== input (keys ramp, gas rolls on) =====================
  let kbSteer = 0, kbThr = 0;
  const readInput = dt => {
    const k = UserInputService, KC = Enum.KeyCode;
    const typing = k.GetFocusedTextBox() != null;
    const left = !typing && (k.IsKeyDown(KC.A) || k.IsKeyDown(KC.Left));
    const right = !typing && (k.IsKeyDown(KC.D) || k.IsKeyDown(KC.Right));
    const target = (right ? 1 : 0) - (left ? 1 : 0);
    const rate = target === 0 ? 7 : (kbSteer !== 0 && sgn(target) !== sgn(kbSteer)) ? 9 : 4.2;
    kbSteer += clamp(target - kbSteer, -rate * dt, rate * dt);
    const thrT = (!typing && (k.IsKeyDown(KC.W) || k.IsKeyDown(KC.Up))) || (touch && touchState.gas);
    kbThr += clamp((thrT ? 1 : 0) - kbThr, -dt * 9, dt * (kbThr < 0.5 ? 6 : 3));
    let thr = kbThr, steer = kbSteer;
    let brk = (!typing && (k.IsKeyDown(KC.S) || k.IsKeyDown(KC.Down))) ? 1 : 0;
    let hand = !typing && (k.IsKeyDown(KC.Space) || k.IsKeyDown(KC.LeftShift));
    if (touch) {
      if (touchState.brake) brk = 1;
      if (touchState.hand) hand = true;
      if (Math.abs(touchState.steer) > Math.abs(steer)) steer = touchState.steer;
    }
    for (const io of UserInputService.GetGamepadState(Enum.UserInputType.Gamepad1)) {
      if (io.KeyCode === KC.Thumbstick1 && Math.abs(io.Position.X) > 0.12 && Math.abs(io.Position.X) > Math.abs(steer)) steer = sgn(io.Position.X) * Math.pow(Math.abs(io.Position.X), 1.4);
      if (io.KeyCode === KC.ButtonR2) thr = Math.max(thr, io.Position.Z);
      if (io.KeyCode === KC.ButtonL2) brk = Math.max(brk, io.Position.Z);
    }
    for (const b of [KC.ButtonA, KC.ButtonB, KC.ButtonX]) if (UserInputService.IsGamepadButtonDown(Enum.UserInputType.Gamepad1, b)) hand = true;
    input.throttle = thr; input.brake = brk; input.hand = hand; input.steer = steer;
  };

  // ===================== drift scoring =====================
  U.TIERS = [[0, 'DRIFT'], [3000, 'GREAT DRIFT'], [8000, 'AWESOME DRIFT'], [15000, 'INSANE DRIFT'], [30000, 'UNBELIEVABLE DRIFT']];
  const tierOf = pts => { let t = 'DRIFT'; for (const x of U.TIERS) if (pts >= x[0]) t = x[1]; return t; };
  let nearWall = false, tandem = 0;
  U.CALLOUTS = [[0, 'NICE DRIFT!', Ui.TEXT], [5000, 'GREAT DRIFT!', Ui.NEON], [15000, 'AWESOME!', Ui.GOLD], [30000, 'INSANE!', Ui.SAKURA], [60000, 'LEGENDARY!', Ui.VIOLET]];
  U.callout = shadowT(text({ Text: '', TextSize: touch ? 34 : 58, FontFace: Ui.DISPLAY, TextXAlignment: Enum.TextXAlignment.Center, Size: new UDim2(1, 0, 0, 0), Position: new UDim2(0, 0, 0.3, 0), TextTransparency: 1, Parent: hud }));
  U.calloutT = 0;
  const callout = (t, color) => { U.callout.Text = t; U.callout.TextColor3 = color; U.callout.TextTransparency = 0; U.calloutT = 1.6; Ui.pop(U.callout, 1.5); };
  U.showCallout = callout;
  const comboUp = () => {
    drift.combo = Math.min(6, drift.combo + 0.5);
    Ui.pop(dMult, 1.4);
    if (S.sound) comboPing(0.45 * S.volume, 0.9 + drift.combo * 0.1);
  };
  const endDrift = bank => {
    if (!drift.active) return;
    const total = Math.floor(drift.score * drift.mult);
    const combo = drift.mult, tandemPts = Math.floor(drift.tandemPts * drift.mult);
    drift.active = false; drift.tags = {};
    drift.combo = 1; drift.mult = 1; drift.comboT = 0;
    if (!bank || total < 50) { drift.score = 0; drift.tandemPts = 0; return; }
    const cr = Math.floor(total / 10);
    R.Bank.FireServer(total, onPass ? 'pass' : lastZone === 3 ? 'city' : 'link', tandemPts, combo);
    profile.credits += cr;
    profile.total = (profile.total || 0) + total;
    const best = total > profile.best;
    if (best) profile.best = total;
    let c = U.CALLOUTS[0];
    for (const x of U.CALLOUTS) if (total >= x[0]) c = x;
    callout(best ? 'NEW BEST!' : c[1], best ? Ui.GOLD : c[2]);
    showToast(`+${fmt(total)}  ·  ×${combo.toFixed(1)} combo  ·  ${fmt(cr)} CR`, Ui.GOLD);
    drift.score = 0; drift.tandemPts = 0;
  };
  let lastCrash = 0;
  const crash = force => {
    const now = osClock();
    if (now - lastCrash < 0.6) return;
    lastCrash = now;
    shake = Math.min(1, force / 14);
    if (drift.active && drift.score * drift.mult > 200) { callout('CRASH!', Ui.DANGER); showToast(fmt(drift.score * drift.mult) + ' lost  ·  combo reset', Ui.DANGER); }
    drift.active = false; drift.score = 0; drift.tandemPts = 0;
    drift.combo = 1; drift.mult = 1; drift.comboT = 0; drift.tags = {};
  };
  const updateScoring = (dt, sp) => {
    const vdot = onPass && sp > 1 ? (P.vx * Track.TX[idx] + P.vz * Track.TZ[idx]) / sp : 1;
    if (P.drifting && sp > 8 && vdot > 0.2) {
      const sign = P.slip > 0 ? 1 : -1;
      if (!drift.active) { drift.active = true; drift.score = 0; drift.time = 0; drift.tandemPts = 0; drift.combo = 1; drift.comboT = 0; drift.sign = sign; }
      else if (drift.idle > 0.15) comboUp();
      else if (sign !== drift.sign && Math.abs(P.slip) > 0.17) comboUp();
      if (Math.abs(P.slip) > 0.17) drift.sign = sign;
      drift.idle = 0;
      drift.time += dt;
      drift.comboT += dt;
      if (drift.comboT >= 2.5) { drift.comboT -= 2.5; comboUp(); }
      const ang = Math.min(Math.abs(P.slip) * 57.3, 90);
      let bonus = 1;
      drift.tags = {};
      if (tandem > 0) { bonus *= 1 + tandem; drift.tags.TANDEM = `TANDEM ×${(1 + tandem).toFixed(1)}`; }
      if (nearWall) { bonus *= 1.35; drift.tags['NEAR WALL'] = true; }
      if (ang > 45) { drift.tags.ANGLE = true; bonus *= 1.15; }
      if (sp * 3.6 > 110) { drift.tags.SPEED = true; bonus *= 1.15; }
      drift.mult = drift.combo;
      const gain = sp * 3.6 * ang * 0.5 * dt * bonus;
      drift.score += gain;
      if (tandem > 0) drift.tandemPts += gain;
    } else if (drift.active) {
      drift.idle += dt;
      if (drift.idle > 1.4) endDrift(true);
    }
  };
  let tagCache = '';
  const renderTags = () => {
    const names = [];
    for (const n of ['TANDEM', 'NEAR WALL', 'ANGLE', 'SPEED']) { const v = drift.tags[n]; if (v) names.push(typeof v === 'string' ? v : n); }
    const key = names.join('|');
    if (key === tagCache) return;
    tagCache = key;
    clearGui(dTags);
    names.forEach((n, k) => make('TextLabel', { Size: new UDim2(0, 0, 1, 0), AutomaticSize: Enum.AutomaticSize.X, BackgroundColor3: Ui.NEON, Text: n, TextColor3: Color3.fromHex('04222b'), FontFace: Ui.BOLD, TextSize: touch ? 9 : 11, LayoutOrder: k + 1, Parent: dTags }, [Ui.corner(2), Ui.pad(6, 0, 6, 0)]));
  };

  // ===================== main loop =====================
  let camPos = camera.CFrame.Position;
  let orbit = 0, lookYaw = 0;
  let perfT = 0, perfN = 0, perfDone = false;
  let lapCP = 0, prevIdx = START;
  const WALL = HALF + 0.65;
  RunService.RenderStepped.Connect(dt0 => {
    const dt = Math.min(dt0, 0.05);
    if (!carModel) { spawnCar(); return; }
    const m = carModel, c = carDef;
    physSet.assist = S.assist; physSet.trans = S.trans; physSet.sens = S.sens;

    if (mode === 'play') {
      readInput(dt);
      const prev = new Vector3(P.x * K, posY, P.z * K);
      const steps = Math.max(1, Math.ceil(dt * 240));
      for (let s = 0; s < steps; s++) CarPhysics.step(P, c, input, physSet, dt / steps);
      CarPhysics.visual(P, c, dt);
      let X = P.x * K, Z = P.z * K;

      idx = Track.nearest(X, Z, idx);
      const [, roadY] = Track.at(X, Z, idx);
      const dd = Math.sqrt((Track.X[idx] - X) ** 2 + (Track.Z[idx] - Z) ** 2);
      onPass = dd < HALF + 10 && Math.abs(posY - roadY) < 14;
      nearWall = false; tandem = 0;
      if (onPass && !nearJunction(idx)) {
        const hl = c.b.len / 2 - 0.05, hw = c.b.wid / 2;
        const fx2 = Math.sin(P.h), fz2 = Math.cos(P.h), lx2 = fz2, lz2 = -fx2;
        let worst = 0, wc = null, maxLat = 0;
        for (let k = 0; k <= 3; k++) {
          const cx = (k & 1) ? hw : -hw, cz = (k & 2) ? hl : -hl;
          const px = P.x + lx2 * cx + fx2 * cz, pz = P.z + lz2 * cx + fz2 * cz;
          const l = (px * K - Track.X[idx]) * Track.RX[idx] + (pz * K - Track.Z[idx]) * Track.RZ[idx];
          maxLat = Math.max(maxLat, Math.abs(l));
          const pen = Math.abs(l) - WALL;
          if (pen > worst) { worst = pen; wc = [px - P.x, pz - P.z, sgn(l)]; }
        }
        nearWall = P.drifting && maxLat > WALL - 1.3 * K;
        if (wc) {
          const v = CarPhysics.wallHit(P, c, -Track.RX[idx] * wc[2], -Track.RZ[idx] * wc[2], worst / K, wc[0], wc[1]);
          if (v > 6.5) crash(v);
        }
      } else if (!onPass) {
        const size = new Vector3(c.b.wid * K, 2.6, c.b.len * K), up = new Vector3(0, 2.6, 0);
        const now = new Vector3(P.x * K, posY, P.z * K);
        const hit = World.sweep(prev.add(up), now.add(up), P.h, size);
        if (hit) {
          const dir = now.sub(prev).Unit;
          const back = prev.add(dir.mul(Math.max(0, hit.Distance - 0.05)));
          P.x = back.X / K; P.z = back.Z / K;
          let n = new Vector3(hit.Normal.X, 0, hit.Normal.Z);
          if (n.Magnitude > 0.1) {
            n = n.Unit;
            const v = CarPhysics.wallHit(P, c, n.X, n.Z, 0, (hit.Position.X - back.X) / K, (hit.Position.Z - back.Z) / K);
            if (v > 6.5) crash(v);
          }
        }
        for (let it = 0; it < 3; it++) {
          const here = new Vector3(P.x * K, posY, P.z * K).add(up);
          const [push, n] = World.pushOut(here, P.h, size);
          if (!push) break;
          P.x += push.X / K; P.z += push.Z / K;
          const v = CarPhysics.wallHit(P, c, n.X, n.Z, 0, -n.X * c.b.wid / 2, -n.Z * c.b.wid / 2);
          if (v > 6.5) crash(v);
        }
      }

      // ground
      X = P.x * K; Z = P.z * K;
      const sp = Math.sqrt(P.vx * P.vx + P.vz * P.vz);
      const [gy, gn] = World.ground(X, posY, Z);
      if (gy != null) {
        const snap = 0.6 + sp * K * dt * 0.7;
        if (onGround && posY - gy <= snap) {
          vy = (gy - posY) / dt;
          posY = gy;
          groundN = groundN.Lerp(gn, Math.min(1, dt * 12));
        } else {
          if (onGround) onGround = false;
          vy -= 34.3 * dt;
          posY += vy * dt;
          if (posY <= gy) { if (vy < -30) shake = Math.min(1, -vy / 80); posY = gy; vy = 0; onGround = true; }
        }
        if (posY >= gy - 0.01 && Math.abs(posY - gy) < 0.05) onGround = true;
      } else resetCar();

      updateScoring(dt, sp);

      // laps on the pass
      if (onPass) {
        lapCP |= 1 << Math.min(3, Math.floor((idx - 1) / (Track.N / 4)));
        if (prevIdx > Track.N * 0.9 && idx < Track.N * 0.1 && lapCP === 15) {
          lapCP = 1;
          R.Lap.FireServer();
          profile.credits += 2000;
          showToast('Lap complete  ·  +2,000 CR', Ui.GOLD);
        }
        prevIdx = idx;
      }

      // HUD
      const kmh = sp * 3.6;
      hSpeed.Text = String(Math.floor(kmh));
      hGear.Text = (S.trans === 'manual' ? 'M' : '') + (P.gear < 0 ? 'R' : sp < 0.5 && input.throttle === 0 ? 'N' : String(P.gear));
      rpmBar.Size = new UDim2(clamp((P.rpm - 800) / (c.red - 800), 0, 1), 0, 1, 0);
      hAngle.Text = P.drifting ? Math.floor(Math.abs(P.slip) * 57.3) + '° ANGLE' : '';
      const credText = fmt(profile.credits);
      if (credText !== hCredits.Text) { hCredits.Text = credText; Ui.pop(tl, 1.12); }
      const cmin = mapFolder.GetAttribute('CityMin'), cmax = mapFolder.GetAttribute('CityMax');
      const z = onPass ? Track.ZONE[idx] : (cmin && X > cmin.X && X < cmax.X && Z > cmin.Y && Z < cmax.Y) ? 3 : 4;
      if (z !== lastZone) {
        lastZone = z;
        const name = Track.ZONE_NAMES[z] || (z === 3 ? '新箱根 · Shin-Hakone city' : '連絡道路 · Link road');
        hZone.Text = name;
        showToast(name, Ui.TEXT);
      }
      dBox.Visible = drift.active;
      if (drift.active) {
        const pts = drift.score * drift.mult;
        dScore.Text = fmt(pts);
        dMult.Text = '×' + drift.mult.toFixed(1);
        const tier = tierOf(pts);
        if (tier !== dTier.Text) { dTier.Text = tier; Ui.pop(dBox, 1.15); }
        renderTags();
      }
      mmMe.Position = mmPos(X, Z);
      if (toastT > 0) { toastT -= dt; if (toastT < 0.5) toast.TextTransparency = 1 - toastT * 2; }
      if (U.calloutT > 0) { U.calloutT -= dt; if (U.calloutT < 0.5) U.callout.TextTransparency = 1 - U.calloutT * 2; }
      const vdot = onPass && sp > 3 ? (P.vx * Track.TX[idx] + P.vz * Track.TZ[idx]) / sp : 1;
      const h = vdot < -0.5 && P.gear > 0 ? (touch ? 'Wrong way · tap ↺ to reset' : 'Wrong way · press R to reset') : '';
      hint.Text = h; hint.Visible = h !== '';

      if (S.quality === 'auto' && !perfDone) {
        perfT += dt0; perfN += 1;
        if (perfT > 6) {
          const fps = perfN / perfT;
          perfT = 0; perfN = 0;
          if (fps < 38 && qAuto !== 'low') { qAuto = qAuto === 'high' ? 'medium' : 'low'; applyQuality(); showToast('Graphics lowered for smoother driving', Ui.TEXT); }
          else perfDone = true;
        }
      }
    }

    // suspension
    rollV += ((clamp(P.ay * 0.0065, -0.1, 0.1) - roll) * 90 - rollV * 11) * dt; roll += rollV * dt;
    pitchV += ((clamp(-P.ax * 0.0045, -0.05, 0.06) - pitch) * 110 - pitchV * 13) * dt; pitch += pitchV * dt;
    fspin += (P.u || 0) / CarPhysics.RW * dt;
    P.rspin = (P.rspin || 0) + P.wr * dt;
    const X = P.x * K, Z = P.z * K;
    const pos = new Vector3(X, posY, Z);
    const f = new Vector3(Math.sin(P.h), 0, Math.cos(P.h));
    const up = groundN.Magnitude > 0.5 ? groundN.Unit : Vector3.yAxis;
    let fwd = f.sub(up.mul(f.Dot(up)));
    fwd = fwd.Magnitude > 1e-3 ? fwd.Unit : f;
    const cf = CFrame.lookAt(pos, pos.add(fwd), up).mul(CFrame.Angles(-pitch, 0, -roll));
    placeCar(m, usingMesh, cf, -P.delta, fspin, P.rspin);
    setFocus(pos);
    setBeam(cf, beamOn && night());

    // tyre smoke, skid marks, sound
    const skidV = clamp((P.rearSlip - 2.5) / 9, 0, 1);
    const angF = clamp(Math.abs(P.slip) * 57.3 / 45, 0, 1);
    const smoking = mode === 'play' && skidV > 0.12;
    const rate = smoking ? Math.floor(50 * Config.Quality[qName()].smoke * skidV * (0.5 + angF)) : 0;
    ['SmokeL', 'SmokeR'].forEach((a, k) => {
      const att = m.smoke[k];
      const on = mode === 'play' && onGround && skidV > 0.15;
      Fx.skid(a, cf.PointToWorldSpace(att.sub(new Vector3(0, att.Y, 0))), up, on ? skidV : 0, 0.9);
      if (rate > 0) Fx.smoke(a, cf.PointToWorldSpace(att), rate, dt);
    });
    Fx.updateSmoke(dt, innerHeight / (2 * Math.tan(camera.FieldOfView * Math.PI / 360)), night() ? 0.32 : 1);
    Fx.updateFlames(dt);
    if (mode === 'play') {
      const lift = U.lastThr && U.lastThr > 0.8 && input.throttle < 0.1 && P.rpm > c.red * 0.7;
      const upshift = U.lastGear && P.gear > U.lastGear && U.lastGear >= 1 && P.rpm > c.red * 0.45;
      if (upshift || (lift && Math.random() < 0.6)) {
        const tips = [], back = cf.LookVector.neg(), ex = c.b.exhaust || 1;
        for (let k = 1; k <= ex; k++) {
          const x = ex === 1 ? -c.b.wid * K * 0.3 : (k === 1 ? -1 : 1) * c.b.wid * K * 0.3;
          const tipPos = cf.PointToWorldSpace(new Vector3(x, 0.32 * K, c.b.len * K / 2 + 0.2));
          tips.push(CFrame.lookAt(tipPos, tipPos.add(back)));
        }
        Fx.backfire(tips, upshift === true);
      }
      U.lastThr = input.throttle; U.lastGear = P.gear;
    }
    if (sound && mode === 'play') sound.update(dt, P.rpm, P.thrEff, skidV, Math.sqrt(P.vx * P.vx + P.vz * P.vz) * 3.6, P.limiter, S.sound ? S.volume : 0);

    // camera (in studs)
    const sp = Math.sqrt(P.vx * P.vx + P.vz * P.vz);
    if (mode === 'photo') {
      const ph = U.photo, r = ph.dist * K;
      let eye = pos.add(new Vector3(Math.sin(ph.yaw) * Math.cos(ph.pitch) * r, Math.sin(ph.pitch) * r + 0.6 * K, Math.cos(ph.yaw) * Math.cos(ph.pitch) * r));
      const [gy] = World.ground(eye.X, eye.Y, eye.Z);
      if (gy != null && eye.Y < gy + 0.6 * K) eye = new Vector3(eye.X, gy + 0.6 * K, eye.Z);
      camera.CFrame = CFrame.lookAt(eye, pos.add(new Vector3(0, 0.6 * K, 0)));
      camera.FieldOfView += (45 - camera.FieldOfView) * Math.min(1, dt * 4);
      CarModel.setCabinVisible(m, true);
    } else if (mode !== 'play') {
      if (osClock() - (U.dragT || 0) > 3) orbit += dt * 0.18;
      orbit += U.orbitNudge || 0;
      U.orbitNudge = 0;
      const r = (mode === 'garage' ? 6.2 : 8.5) * K;
      const eye = pos.add(new Vector3(Math.sin(P.h + orbit) * r, (mode === 'garage' ? 1.5 : 2.4) * K, Math.cos(P.h + orbit) * r));
      const side = (mode === 'title' || mode === 'garage') && camera.ViewportSize.X > 800;
      const right = new Vector3(-Math.cos(P.h + orbit), 0, Math.sin(P.h + orbit));
      camera.CFrame = CFrame.lookAt(eye, pos.add(new Vector3(0, 0.7 * K, 0)).add(side ? right.mul(2.2 * K) : Vector3.zero));
      camera.FieldOfView = 50;
      CarModel.setCabinVisible(m, true);
    } else if (camMode === 2 || camMode === 3) {
      lookYaw += (clamp(-P.slip * (camMode === 2 ? 0.6 : 0.3), -0.7, 0.7) - lookYaw) * Math.min(1, dt * 4);
      const eye = camMode === 2 ? cf.mul(CFrame.new(c.b.wid * 0.21 * K, c.b.h * 0.8 * K, c.b.wb * 0.08 * K)) : cf.mul(CFrame.new(0, c.b.h * 0.86 * K, -c.b.wb * 0.18 * K));
      let cam = eye.mul(CFrame.Angles((camMode === 2 ? -4 : -2) * Math.PI / 180, lookYaw, 0));
      if (shake > 0) { cam = cam.mul(CFrame.Angles(0, 0, (Math.random() - 0.5) * shake * 0.03)); shake = Math.max(0, shake - dt * 2.5); }
      camera.CFrame = cam;
      const fov = clamp((camMode === 2 ? 70 : 66) + sp * 0.18, 60, 84);
      camera.FieldOfView += (fov - camera.FieldOfView) * Math.min(1, dt * 3);
    } else {
      let dx = f.X, dz = f.Z;
      if (sp > 4) {
        const vx = P.vx / sp, vz = P.vz / sp;
        dx += (vx - dx) * 0.55; dz += (vz - dz) * 0.55;
        const l = Math.sqrt(dx * dx + dz * dz); dx /= l; dz /= l;
      }
      let dist = (6.4 + sp * 0.035) * K, height = 2.25 * K, look = 1.0 * K;
      if (camMode === 1) { dist = (10.5 + sp * 0.04) * K; height = 3.9 * K; look = 0.8 * K; }
      const tx = X - dx * dist, tz = Z - dz * dist;
      let ty = posY + height;
      const [gy] = World.ground(tx, ty, tz);
      if (gy != null) ty = Math.max(ty, gy + 1.2 * K);
      if (camPos.sub(new Vector3(tx, ty, tz)).Magnitude > 20 * K) camPos = new Vector3(tx, ty, tz);
      const kx = 1 - Math.exp(-6 * dt);
      camPos = new Vector3(camPos.X + (tx - camPos.X) * kx, camPos.Y + (ty - camPos.Y) * (1 - Math.exp(-4 * dt)), camPos.Z + (tz - camPos.Z) * kx);
      let eye = camPos;
      if (shake > 0) { eye = eye.add(new Vector3((Math.random() - 0.5) * shake * 0.5 * K, (Math.random() - 0.5) * shake * 0.4 * K, 0)); shake = Math.max(0, shake - dt * 2.5); }
      const hs = clamp((sp * 3.6 - 150) / 150, 0, 1);
      if (hs > 0) eye = eye.add(new Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).mul(hs * 0.07 * K));
      camera.CFrame = CFrame.lookAt(eye, new Vector3(X + f.X * 2.5 * K, posY + look, Z + f.Z * 2.5 * K));
      const fov = clamp(60 + sp * 0.32, 60, 82);
      camera.FieldOfView += (fov - camera.FieldOfView) * Math.min(1, dt * 3);
    }
    CarModel.setCabinVisible(m, !(mode === 'play' && camMode === 2));
  });

  spawnCar();
  refreshTitle();
  loading.Destroy();
  setMode('title');
  // for tests
  window.__kaido = { get P() { return P; }, get mode() { return mode; }, setMode, start, get profile() { return profile; }, input, get posY() { return posY; }, get onPass() { return onPass; }, resetCar, goCity };
}
