// Shin-Hakone: port of the Roblox game's City.luau. A street grid with a downtown of glass towers, mid-rise
// blocks with lit floors, shops and vertical neon signs, low houses and parks at the edges, a lattice tower,
// a scramble crossing with giant screens, an elevated expressway loop with a ramp, and a link road to the
// pass. Folders as on Roblox: City/Ground (drivable), City/Solid (walls), City/Deco, City/Lights, City/Signs.
import { Vector3, CFrame, Color3, Enum } from '../rbx/types.js';
import { addPart } from './parts.js';
import { Terrain } from './terrain.js';
import { addText } from './text.js';

const GRID = 24, BLOCK = 200, STREET = 48, PITCH = BLOCK + STREET, GY = 6.6, CURB = 0.6, RING = 5, RING_Y = 58, DECK = 44;
const rgb = Color3.fromRGB, V = (x, y, z) => new Vector3(x, y, z);
const SIGNS = ['ラーメン', 'カラオケ', '居酒屋', '寿司', 'ホテル', '薬', '焼肉', 'ゲーム', '喫茶', '酒', '書店', '質', 'パチンコ', '駐車場', '整骨院', 'そば', 'うどん', 'コンビニ', '銭湯', '麻雀'];
const SIGN_COLORS = [rgb(255, 70, 110), rgb(80, 220, 255), rgb(255, 200, 60), rgb(150, 255, 120), rgb(255, 120, 40), rgb(200, 120, 255), rgb(255, 255, 255)];
const SHOPS = {
  boba: { col: rgb(255, 214, 226), glow: rgb(255, 236, 214), sign: rgb(120, 230, 214), text: 'BOBA TEA  タピオカ', ink: rgb(70, 30, 60) },
  ramen: { col: rgb(70, 44, 30), glow: rgb(255, 200, 130), sign: rgb(230, 40, 40), text: 'ラーメン  RAMEN', ink: rgb(255, 240, 220) },
  konbini: { col: rgb(244, 244, 240), glow: rgb(235, 250, 255), sign: rgb(40, 160, 90), text: 'コンビニ  24h', ink: rgb(255, 255, 255) },
  cafe: { col: rgb(120, 84, 60), glow: rgb(255, 214, 160), sign: rgb(240, 226, 200), text: '喫茶  CAFÉ', ink: rgb(70, 44, 30) },
  arcade: { col: rgb(26, 22, 40), glow: rgb(190, 120, 255), sign: rgb(255, 70, 160), text: 'ゲーム  GAME', ink: rgb(255, 255, 255) },
  sushi: { col: rgb(226, 214, 190), glow: rgb(255, 230, 190), sign: rgb(30, 50, 110), text: '寿司  SUSHI', ink: rgb(255, 255, 255) },
  karaoke: { col: rgb(46, 30, 70), glow: rgb(255, 120, 220), sign: rgb(160, 80, 255), text: 'カラオケ', ink: rgb(255, 255, 255) },
  drug: { col: rgb(240, 240, 236), glow: rgb(250, 250, 240), sign: rgb(255, 214, 40), text: '薬  DRUG', ink: rgb(30, 30, 30) },
};
const DOWNTOWN_SHOPS = ['boba', 'boba', 'ramen', 'konbini', 'konbini', 'cafe', 'arcade', 'arcade', 'sushi', 'karaoke', 'karaoke', 'drug'];
const SUBURB_SHOPS = ['boba', 'ramen', 'ramen', 'konbini', 'konbini', 'cafe', 'sushi', 'drug'];
const WINDOW = [rgb(255, 214, 150), rgb(255, 236, 200), rgb(190, 220, 255), rgb(150, 200, 255)];

export function buildCity(ctx) {
  const { Track, rng, FLOOR, HALF } = ctx;
  const lights = [];
  const part = (folder, size, cf, color, mat, shape, opts) => addPart('City/' + folder, size, cf, color, (mat && mat.Name) || mat || 'SmoothPlastic', shape ? shape.Name || shape : 'Block', opts);
  const slab = (folder, x0, z0, x1, z1, y, h, color, mat) => {
    const lx = x1 - x0, lz = z1 - z0, nx = Math.ceil(lx / 2000), nz = Math.ceil(lz / 2000);
    for (let i = 0; i < nx; i++) for (let j = 0; j < nz; j++) { const sx = lx / nx, sz = lz / nz; part(folder, V(sx, h, sz), CFrame.new(x0 + sx * (i + 0.5), y - h / 2, z0 + sz * (j + 0.5)), color, mat); }
  };
  let maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (let i = 1; i <= Track.N; i++) { maxX = Math.max(maxX, Track.X[i]); minZ = Math.min(minZ, Track.Z[i]); maxZ = Math.max(maxZ, Track.Z[i]); }
  const SIZE = GRID * PITCH + STREET, X0 = maxX + 900, Z0 = (minZ + maxZ) / 2 - SIZE / 2, cx = X0 + SIZE / 2, cz = Z0 + SIZE / 2;
  const streetX = i => X0 + i * PITCH + STREET / 2, streetZ = j => Z0 + j * PITCH + STREET / 2;

  for (let gx = X0 - 200; gx <= X0 + SIZE + 200; gx += 1024) for (let gz = Z0 - 200; gz <= Z0 + SIZE + 200; gz += 1024) {
    Terrain.FillBlock(CFrame.new(gx + 512, GY - 4 + 8, gz + 512), V(1024, 16, 1024), Enum.Material.Air);
    Terrain.FillBlock(CFrame.new(gx + 512, GY - 4 - 6, gz + 512), V(1024, 12, 1024), Enum.Material.Concrete);
  }
  const asphalt = rgb(40, 41, 46);
  slab('Ground', X0, Z0, X0 + SIZE, Z0 + SIZE, GY, 6, asphalt, Enum.Material.Asphalt);
  const lineCol = rgb(236, 232, 214), yellow = rgb(240, 188, 40);
  const mark = (x, z, sx, sz, col) => part('Deco', V(sx, 0.06, sz), CFrame.new(x, GY + 0.03, z), col, 'SmoothPlastic', null, { collide: false, query: false });
  for (let i = 0; i <= GRID; i++) {
    const avenue = i % 4 === 0;
    for (let j = 0; j < GRID; j++) {
      const a0 = Z0 + j * PITCH + STREET + 8, l = BLOCK - 16, mid = a0 + l / 2, x = streetX(i), z = streetZ(i), b0 = X0 + j * PITCH + STREET + 8, midx = b0 + l / 2;
      if (avenue) {
        mark(x - 0.55, mid, 0.4, l, yellow); mark(x + 0.55, mid, 0.4, l, yellow); mark(x - STREET / 4, mid, 0.35, l, lineCol); mark(x + STREET / 4, mid, 0.35, l, lineCol);
        mark(midx, z - 0.55, l, 0.4, yellow); mark(midx, z + 0.55, l, 0.4, yellow); mark(midx, z - STREET / 4, l, 0.35, lineCol); mark(midx, z + STREET / 4, l, 0.35, lineCol);
      } else { mark(x, mid, 0.45, l, lineCol); mark(midx, z, l, 0.45, lineCol); }
    }
  }
  const district = (x, z) => Math.max(Math.abs(x - cx), Math.abs(z - cz)) / (SIZE / 2);

  let buildingCount = 0;
  const windowBands = (size, cf, faces, color, every, tier, minY) => {
    every = Math.max(every, (size.Y - 4) / (size.Y > 140 ? 16 : 5));
    for (const f of faces) {
      const horiz = f === 'z-' || f === 'z+', w = horiz ? size.X : size.Z;
      for (let y = every; y <= size.Y - 4; y += every) {
        if (y >= (minY || 0) && rng.NextNumber() < 0.78) {
          const len = w * (0.35 + rng.NextNumber() * 0.55), off = (rng.NextNumber() - 0.5) * (w - len);
          const pos = f === 'z-' ? CFrame.new(off, -size.Y / 2 + y, -size.Z / 2 - 0.08) : f === 'z+' ? CFrame.new(off, -size.Y / 2 + y, size.Z / 2 + 0.08) : f === 'x-' ? CFrame.new(-size.X / 2 - 0.08, -size.Y / 2 + y, off) : CFrame.new(size.X / 2 + 0.08, -size.Y / 2 + y, off);
          part('Solid', horiz ? V(len, 1.6, 0.15) : V(0.15, 1.6, len), cf.mul(pos), color, 'Neon', null, { name: 'Window', group: 'win' + tier, collide: false, query: false });
        }
      }
    }
  };
  const sign = (cf, height, text, color) => {
    part('Solid', V(3.2, height, 0.8), cf, rgb(18, 18, 22), 'SmoothPlastic', null, { name: 'Sign', collide: false, query: false });
    const face = cf.mul(CFrame.new(0, 0, -0.45));
    part('Solid', V(2.8, height - 0.6, 0.2), face, color, 'Neon', null, { name: 'SignFace', transparency: 0.15, collide: false, query: false });
    addText(face.mul(CFrame.new(0, 0, -0.11)), 2.8, height - 0.6, [...text].join('\n'), rgb(20, 12, 24), 'signs');
  };
  const faceFrame = (cf, w, l, h, f) => {
    const out = f === 'z-' ? V(0, 0, -1) : f === 'z+' ? V(0, 0, 1) : f === 'x-' ? V(-1, 0, 0) : V(1, 0, 0);
    const half = f === 'z-' || f === 'z+' ? l / 2 : w / 2, width = f === 'z-' || f === 'z+' ? w : l;
    const base = cf.Position.add(out.mul(half)).sub(V(0, h / 2, 0));
    return [CFrame.lookAt(base, base.add(out)), width];
  };
  const shopFront = (F, faceW, kind) => {
    const k = SHOPS[kind], W = Math.min(faceW * 0.86, 46), at = (x, y, z) => F.mul(CFrame.new(x, y, z));
    const deco = (size, cf, color, mat, shape, opts) => part('Solid', size, cf, color, mat, shape, { collide: false, query: false, ...opts });
    deco(V(W, 9, 0.4), at(0, 4.5, -0.25), k.col, kind === 'ramen' || kind === 'cafe' ? 'WoodPlanks' : 'SmoothPlastic');
    deco(V(W * 0.8, 5.4, 0.12), at(0, 3.1, -0.5), k.glow, 'Neon', null, { name: 'Window', group: 'win1', transparency: 0.1 });
    deco(V(W * 0.8, 5.4, 0.1), at(0, 3.1, -0.45), rgb(150, 170, 190), 'Glass', null, { transparency: 0.5 });
    const board = at(0, 7.6, -0.75);
    deco(V(W * 0.74, 2.4, 0.5), board, rgb(20, 20, 24), 'SmoothPlastic');
    const face = board.mul(CFrame.new(0, 0, -0.3));
    deco(V(W * 0.72, 2.1, 0.12), face, k.sign, 'Neon', null, { name: 'SignFace' });
    addText(face.mul(CFrame.new(0, 0, -0.07)), W * 0.72, 2.1, k.text, k.ink, 'signs');
    if (kind === 'boba') {
      const c0 = at(W * 0.3, 12.5, -1.4);
      deco(V(6, 4.6, 4.6), c0.mul(CFrame.Angles(0, 0, Math.PI / 2)), rgb(255, 190, 210), 'Glass', 'Cylinder', { transparency: 0.25 });
      deco(V(0.6, 4.9, 4.9), c0.mul(CFrame.new(0, 3, 0)).mul(CFrame.Angles(0, 0, Math.PI / 2)), rgb(255, 255, 255), 'SmoothPlastic', 'Cylinder');
      for (let p = 1; p <= 3; p++) deco(V(1.2, 1.2, 1.2), c0.mul(CFrame.new((p - 2) * 1.2, -2.2, (p % 2) * 0.6 - 0.3)), rgb(30, 20, 20), 'SmoothPlastic', 'Ball');
      deco(V(0.5, 6, 0.5), c0.mul(CFrame.new(0.6, 4.6, 0)).mul(CFrame.Angles(0, 0, -12 * Math.PI / 180)), rgb(80, 230, 255), 'Neon');
      deco(V(W * 0.8, 0.3, 3), at(0, 6.2, -1.9).mul(CFrame.Angles(-14 * Math.PI / 180, 0, 0)), rgb(150, 230, 220), 'Fabric');
    } else if (kind === 'ramen' || kind === 'sushi') {
      const cloth = kind === 'ramen' ? rgb(150, 24, 30) : rgb(28, 44, 96);
      for (let n = -1; n <= 1; n++) deco(V(2.2, 3.2, 0.1), at(n * 2.4, 4.6, -0.75), cloth, 'Fabric');
      for (const x of [-W * 0.42, W * 0.42]) deco(V(1.8, 2.6, 1.8), at(x, 5.2, -1.3), kind === 'ramen' ? rgb(240, 50, 40) : rgb(255, 244, 220), 'Neon', 'Ball', { name: 'Lantern', group: 'nightNeon' });
    } else if (kind === 'konbini') {
      deco(V(W, 0.7, 0.2), at(0, 6.1, -0.55), rgb(255, 140, 30), 'SmoothPlastic');
      deco(V(W, 0.7, 0.2), at(0, 6.8, -0.55), rgb(40, 160, 90), 'SmoothPlastic');
      for (let n = 0; n <= 1; n++) deco(V(1.4, 2.6, 1.4), at(-W * 0.36 + n * 1.8, 1.3, -1.6), rgb(70, 110, 160), 'SmoothPlastic');
      for (let n = 0; n <= 1; n++) {
        const bx = W * 0.3 + n * 1.6;
        for (const z of [-2.4, -4.8]) deco(V(0.15, 2, 2), at(bx, 1, z).mul(CFrame.Angles(0, Math.PI / 2, 0)), rgb(30, 30, 34), 'SmoothPlastic', 'Cylinder');
        deco(V(0.2, 0.25, 2.6), at(bx, 1.5, -3.6), rgb(200, 40, 50), 'Metal');
      }
    } else if (kind === 'cafe') {
      for (let n = 0; n <= 3; n++) deco(V(W * 0.8 / 4, 0.3, 3), at(-W * 0.3 + n * W * 0.2, 6.2, -1.9).mul(CFrame.Angles(-14 * Math.PI / 180, 0, 0)), n % 2 === 0 ? rgb(30, 90, 60) : rgb(240, 236, 226), 'Fabric');
      for (const x of [-W * 0.44, W * 0.44]) { deco(V(1.6, 1.6, 1.6), at(x, 0.8, -1.4), rgb(120, 70, 50), 'Brick'); deco(V(2.4, 2.4, 2.4), at(x, 2.6, -1.4), rgb(50, 110, 56), 'Grass', 'Ball'); }
    } else if (kind === 'arcade') {
      for (let n = -1; n <= 1; n++) deco(V(0.4, 8, 0.3), at(n * W * 0.45, 4.5, -0.6), SIGN_COLORS[(n + 2) * 2 - 1], 'Neon');
      for (let n = 0; n <= 1; n++) {
        const cm = at(-W * 0.3 + n * 3.4, 0, -2);
        deco(V(3, 5.2, 3), cm.mul(CFrame.new(0, 2.6, 0)), rgb(180, 220, 255), 'Glass', null, { transparency: 0.45 });
        deco(V(3.1, 0.8, 3.1), cm.mul(CFrame.new(0, 5.6, 0)), rgb(255, 80, 180), 'Neon');
      }
    } else if (kind === 'karaoke' || kind === 'drug') deco(V(W, 0.6, 0.2), at(0, 6.4, -0.55), k.sign, 'Neon');
  };

  const building = (x0, z0, x1, z1, d, streetSides) => {
    const w = x1 - x0, l = z1 - z0, tier = rng.NextInteger(1, 3);
    let h, col, mat, every;
    if (d < 0.24) {
      h = 160 + Math.pow(rng.NextNumber(), 1.6) * 380;
      col = [rgb(30, 44, 66), rgb(22, 30, 40), rgb(40, 60, 70), rgb(56, 60, 70)][rng.NextInteger(1, 4) - 1]; mat = 'Glass'; every = 7;
    } else if (d < 0.6) {
      h = 34 + Math.pow(rng.NextNumber(), 1.3) * 120;
      [col, mat] = [[rgb(196, 190, 178), 'CeramicTiles'], [rgb(150, 120, 100), 'CeramicTiles'], [rgb(122, 74, 58), 'Brick'], [rgb(96, 70, 60), 'Brick'],
        [rgb(150, 148, 142), 'Concrete'], [rgb(112, 114, 118), 'Concrete'], [rgb(214, 206, 190), 'Plaster'], [rgb(84, 92, 104), 'Plaster']][rng.NextInteger(1, 8) - 1];
      every = 9;
    } else {
      h = 12 + rng.NextNumber() * 12;
      [col, mat] = [[rgb(224, 216, 200), 'Plaster'], [rgb(200, 188, 166), 'Plaster'], [rgb(176, 186, 190), 'Plaster'], [rgb(92, 64, 46), 'WoodPlanks'], [rgb(70, 54, 42), 'WoodPlanks'], [rgb(140, 86, 64), 'Brick']][rng.NextInteger(1, 6) - 1];
      every = 6;
    }
    const cf = CFrame.new((x0 + x1) / 2, GY + CURB + h / 2, (z0 + z1) / 2), size = V(w, h, l);
    part('Solid', size, cf, col, mat, null, { name: 'Body', shadow: h < 200 });
    if (mat === 'Glass') {
      for (const f of streetSides) {
        const horiz = f === 'z-' || f === 'z+', off = f === 'z-' ? CFrame.new(0, 0, -l / 2 - 0.05) : f === 'z+' ? CFrame.new(0, 0, l / 2 + 0.05) : f === 'x-' ? CFrame.new(-w / 2 - 0.05, 0, 0) : CFrame.new(w / 2 + 0.05, 0, 0);
        part('Solid', horiz ? V(w - 1, h - 6, 0.1) : V(0.1, h - 6, l - 1), cf.mul(off), rgb(40, 70, 110), 'Neon', null, { name: 'Window', group: 'win1', transparency: 0.82, collide: false, query: false });
      }
      part('Solid', V(w + 1.2, 8, l + 1.2), cf.mul(CFrame.new(0, -h / 2 + 4, 0)), rgb(64, 66, 72), 'Granite', null, { query: false });
      part('Solid', V(w + 0.8, 3, l + 0.8), cf.mul(CFrame.new(0, h / 2 - 1.5, 0)), rgb(46, 50, 58), 'Metal', null, { query: false });
    } else if (d < 0.6) {
      part('Solid', V(w + 0.6, 1.4, l + 0.6), cf.mul(CFrame.new(0, h / 2 + 0.7, 0)), new Color3(col.R * 0.75, col.G * 0.75, col.B * 0.75), 'Concrete', null, { query: false });
    }
    if (d < 0.6) {
      part('Solid', V(w * 0.4, 5, l * 0.4), cf.mul(CFrame.new(0, h / 2 + 2.5, 0)), rgb(70, 72, 78), 'Metal', null, { query: false });
      if (h > 140) for (const c of [[-1, -1], [1, 1]]) part('Solid', V(1.2, 1.2, 1.2), cf.mul(CFrame.new(c[0] * (w / 2 - 1), h / 2 + 0.6, c[1] * (l / 2 - 1))), rgb(255, 30, 30), 'Neon', null, { name: 'AirLight', group: 'nightNeon', query: false });
    } else {
      const tile = rng.NextNumber() < 0.75 ? rgb(62, 66, 78) : rgb(146, 70, 48);
      part('Solid', V(w + 0.4, 1.6, l + 0.4), cf.mul(CFrame.new(0, -h / 2 + 0.8, 0)), rgb(96, 94, 90), 'Cobblestone', null, { query: false });
      part('Solid', V(w + 2, 5, l / 2 + 1), cf.mul(CFrame.new(0, h / 2 + 2.5, -(l / 4 + 0.5))), tile, 'ClayRoofTiles', 'Wedge', { shadow: true });
      part('Solid', V(w + 2, 5, l / 2 + 1), cf.mul(CFrame.new(0, h / 2 + 2.5, l / 4 + 0.5)).mul(CFrame.Angles(0, Math.PI, 0)), tile, 'ClayRoofTiles', 'Wedge', { shadow: true });
    }
    let shop = false;
    if (d >= 0.18 && d < 0.6 && streetSides.length > 0) {
      streetSides.forEach((f, n) => { if (n === 0 || rng.NextNumber() < 0.35) { const [F, fw] = faceFrame(cf, w, l, h, f); shopFront(F, fw, DOWNTOWN_SHOPS[rng.NextInteger(1, DOWNTOWN_SHOPS.length) - 1]); } });
    } else if (d >= 0.6 && d < 0.9 && streetSides.length > 0 && rng.NextNumber() < 0.4) {
      const [F, fw] = faceFrame(cf, w, l, h, streetSides[0]); shopFront(F, fw, SUBURB_SHOPS[rng.NextInteger(1, SUBURB_SHOPS.length) - 1]); shop = true;
    }
    if (d < 0.6) windowBands(size, cf, streetSides, WINDOW[rng.NextInteger(1, WINDOW.length) - 1], every, tier, mat === 'Glass' ? 0 : 14);
    else if (streetSides.length > 0 && !shop) {
      const f = streetSides[0], horiz = f === 'z-' || f === 'z+';
      const off = f === 'z-' ? CFrame.new(0, 1, -l / 2 - 0.08) : f === 'z+' ? CFrame.new(0, 1, l / 2 + 0.08) : f === 'x-' ? CFrame.new(-w / 2 - 0.08, 1, 0) : CFrame.new(w / 2 + 0.08, 1, 0);
      const ww = Math.min(6, (horiz ? w : l) * 0.4);
      part('Solid', horiz ? V(ww + 0.8, 3.8, 0.12) : V(0.12, 3.8, ww + 0.8), cf.mul(off), rgb(58, 44, 34), 'Wood', null, { collide: false, query: false });
      part('Solid', horiz ? V(ww, 3, 0.15) : V(0.15, 3, ww), cf.mul(off).mul(horiz ? CFrame.new(0, 0, f === 'z-' ? -0.03 : 0.03) : CFrame.new(f === 'x-' ? -0.03 : 0.03, 0, 0)), WINDOW[0], 'Neon', null, { name: 'Window', group: 'win' + tier, collide: false, query: false });
      const along = (horiz ? w : l) * 0.36;
      part('Solid', horiz ? V(3, 7, 0.2) : V(0.2, 7, 3), cf.mul(off).mul(horiz ? CFrame.new(along, -h / 2 - 1 + 3.5, 0) : CFrame.new(0, -h / 2 - 1 + 3.5, along)), rgb(70, 48, 34), 'WoodPlanks', null, { collide: false, query: false });
    }
    if (d >= 0.18 && d < 0.75 && rng.NextNumber() < 0.42 && streetSides.length > 0) {
      const f = streetSides[0], sh = Math.min(h - 4, 10 + rng.NextNumber() * 14), y = -h / 2 + 6 + sh / 2;
      const pos = f === 'z-' ? CFrame.new(w / 2 - 3, y, -l / 2 - 2.2) : f === 'z+' ? CFrame.new(-w / 2 + 3, y, l / 2 + 2.2).mul(CFrame.Angles(0, Math.PI, 0))
        : f === 'x-' ? CFrame.new(-w / 2 - 2.2, y, -l / 2 + 3).mul(CFrame.Angles(0, -Math.PI / 2, 0)) : CFrame.new(w / 2 + 2.2, y, l / 2 - 3).mul(CFrame.Angles(0, Math.PI / 2, 0));
      sign(cf.mul(pos).mul(CFrame.Angles(0, Math.PI / 2, 0)), sh, SIGNS[rng.NextInteger(1, SIGNS.length) - 1], SIGN_COLORS[rng.NextInteger(1, SIGN_COLORS.length) - 1]);
    }
    buildingCount++;
  };

  const ringLo = GRID / 2 - RING, ringHi = GRID / 2 + RING, centreI = GRID / 2, centreJ = GRID / 2;
  for (let i = 0; i < GRID; i++) for (let j = 0; j < GRID; j++) {
    const bx0 = X0 + STREET + i * PITCH, bz0 = Z0 + STREET + j * PITCH;
    part('Ground', V(BLOCK, CURB + 0.6, BLOCK), CFrame.new(bx0 + BLOCK / 2, GY + CURB / 2 - 0.3, bz0 + BLOCK / 2), rgb(128, 126, 122), 'Pavement', null, { name: 'Block' });
    const kc = rgb(190, 188, 182);
    for (const k of [[0, -1], [0, 1], [-1, 0], [1, 0]]) {
      const kx = bx0 + BLOCK / 2 + k[0] * (BLOCK / 2 - 0.6), kz = bz0 + BLOCK / 2 + k[1] * (BLOCK / 2 - 0.6);
      part('Deco', k[0] === 0 ? V(BLOCK, CURB + 0.66, 1.2) : V(1.2, CURB + 0.66, BLOCK), CFrame.new(kx, GY + CURB / 2 - 0.27, kz), kc, 'Concrete', null, { collide: false, query: false });
    }
    const d = district(bx0 + BLOCK / 2, bz0 + BLOCK / 2);
    if (i === centreI - 1 && j === centreJ - 1) {
      const tx = bx0 + BLOCK / 2, tz = bz0 + BLOCK / 2, red = rgb(214, 52, 30), white = rgb(236, 236, 236), H = 640;
      for (let k = 0; k <= 15; k++) {
        const f0 = k / 16, f1 = (k + 1) / 16, s0 = 70 * Math.pow(1 - f0, 1.7) + 4, s1 = 70 * Math.pow(1 - f1, 1.7) + 4, y0 = GY + CURB + f0 * H, y1 = GY + CURB + f1 * H;
        for (const c of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
          const a = V(tx + c[0] * s0, y0, tz + c[1] * s0), bb = V(tx + c[0] * s1, y1, tz + c[1] * s1);
          part('Solid', V(3, 3, bb.sub(a).Magnitude), CFrame.lookAt(a.add(bb).div(2), bb), k % 2 === 0 ? red : white, 'Metal', null, { query: k < 2, shadow: true });
        }
        if (k === 5 || k === 10) {
          part('Solid', V(s1 * 2 + 14, 10, s1 * 2 + 14), CFrame.new(tx, y1, tz), rgb(240, 240, 240), 'Glass', null, { query: false });
          part('Solid', V(s1 * 2 + 15, 1.5, s1 * 2 + 15), CFrame.new(tx, y1 + 3, tz), rgb(255, 170, 80), 'Neon', null, { query: false });
        }
      }
      part('Solid', V(3, 60, 3), CFrame.new(tx, GY + CURB + H + 30, tz), white, 'Metal', null, { query: false });
      part('Solid', V(4, 4, 4), CFrame.new(tx, GY + CURB + H + 62, tz), rgb(255, 40, 40), 'Neon', null, { name: 'AirLight', group: 'nightNeon', query: false });
    } else if ((i === ringLo || i === ringHi - 1 || j === ringLo || j === ringHi - 1) && i >= ringLo && i < ringHi && j >= ringLo && j < ringHi) {
      part('Solid', V(BLOCK - 30, 14, BLOCK - 30), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 7, bz0 + BLOCK / 2), rgb(96, 98, 104), 'Concrete', null, { name: 'Parking' });
    } else if (d > 0.62 && rng.NextNumber() < 0.12) {
      for (let t = 0; t < 7; t++) {
        const tx = bx0 + 20 + rng.NextNumber() * (BLOCK - 40), tz = bz0 + 20 + rng.NextNumber() * (BLOCK - 40), g = 'tree' + rng.NextInteger(1, 3);
        part('Solid', V(10, 1.4, 1.4), CFrame.new(tx, GY + CURB + 5, tz).mul(CFrame.Angles(0, 0, Math.PI / 2)), rgb(72, 52, 40), 'Wood', 'Cylinder', { group: g, shadow: true });
        part('Solid', V(14, 11, 14), CFrame.new(tx, GY + CURB + 13, tz), rgb(40, 86, 46), 'Grass', 'Ball', { group: g, shadow: true });
      }
      part('Deco', V(BLOCK - 8, 0.2, BLOCK - 8), CFrame.new(bx0 + BLOCK / 2, GY + CURB + 0.05, bz0 + BLOCK / 2), rgb(60, 96, 52), 'Grass', null, { collide: false });
    } else {
      const n = d < 0.6 ? 2 : 3, lot = (BLOCK - 8) / n;
      for (let a = 0; a < n; a++) for (let c = 0; c < n; c++) {
        if (n >= 3 && a > 0 && a < n - 1 && c > 0 && c < n - 1) continue;
        const x0 = bx0 + 4 + a * lot + 2, z0 = bz0 + 4 + c * lot + 2, sides = [];
        if (c === 0) sides.push('z-'); if (c === n - 1) sides.push('z+'); if (a === 0) sides.push('x-'); if (a === n - 1) sides.push('x+');
        const inset = d < 0.24 ? 6 : 2;
        if (d < 0.6 || rng.NextNumber() < 0.72) building(x0 + inset, z0 + inset, x0 + lot - 4 - inset, z0 + lot - 4 - inset, d, sides);
      }
    }
  }

  // street lights on every corner, crosswalks downtown, traffic lights on the avenues
  let nLight = 0;
  for (let i = 0; i <= GRID; i++) for (let j = 0; j <= GRID; j++) {
    const x = streetX(i), z = streetZ(j), px = x + STREET / 2 + 2, pz = z + STREET / 2 + 2;
    part('Solid', V(0.8, 20, 0.8), CFrame.new(px, GY + CURB + 10, pz), rgb(70, 72, 76), 'Metal', null, { name: 'Pole' });
    part('Lights', V(2.6, 0.5, 1.4), CFrame.new(px - 4, GY + CURB + 19.6, pz - 4), rgb(255, 220, 170), 'Neon', null, { name: 'LampHead', group: 'lamp' });
    nLight++;
    lights.push({ x: px - 4, y: GY + CURB + 19.6, z: pz - 4, n: nLight, color: rgb(255, 214, 160), range: 48, brightness: 2.2, city: true });
    if (district(x, z) < 0.48) {
      for (const side of [-1, 1]) {
        for (let k = -3; k <= 3; k++) { mark(x + k * 6.2, z + side * (STREET / 2 + 6), 3, 10, lineCol); mark(x + side * (STREET / 2 + 6), z + k * 6.2, 10, 3, lineCol); }
        mark(x + side * STREET / 4, z + side * (STREET / 2 + 13), STREET / 2 - 2, 0.8, lineCol);
        mark(x - side * (STREET / 2 + 13), z + side * STREET / 4, 0.8, STREET / 2 - 2, lineCol);
      }
    }
    if (i % 4 === 0 && j % 4 === 0) {
      for (const c of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) {
        const px2 = x + c[0] * (STREET / 2 + 3), pz2 = z + c[1] * (STREET / 2 + 3);
        part('Solid', V(0.9, 16, 0.9), CFrame.new(px2, GY + CURB + 8, pz2), rgb(70, 72, 76), 'Metal', null, { name: 'Pole' });
        part('Deco', V(0.6, 0.6, 12), CFrame.new(px2, GY + CURB + 15.4, pz2 - c[1] * 6), rgb(70, 72, 76), 'Metal', null, { collide: false, query: false });
        part('Deco', V(6.5, 2.2, 1.4), CFrame.new(px2, GY + CURB + 14.6, pz2 - c[1] * 11), rgb(30, 32, 36), 'Metal', null, { collide: false, query: false });
        const go = Math.floor((i + j) / 4) % 2 === 0;
        part('Deco', V(1.6, 1.6, 0.3), CFrame.new(px2 + (go ? -2 : 2), GY + CURB + 14.6, pz2 - c[1] * 11 - c[1] * 0.75), go ? rgb(60, 255, 150) : rgb(255, 50, 40), 'Neon', null, { name: 'Signal', collide: false, query: false });
      }
    }
  }
  // street life: utility poles and wires in the suburbs, paper lantern strings across the shopping streets
  const poleCol = rgb(150, 146, 136), wireCol = rgb(26, 26, 28);
  const wire = (a, b2) => part('Deco', V(0.14, 0.14, b2.sub(a).Magnitude), CFrame.lookAt(a.add(b2).div(2), b2), wireCol, 'SmoothPlastic', null, { collide: false, query: false });
  for (let j = 0; j <= GRID; j++) {
    const z = streetZ(j);
    for (let i = 0; i < GRID; i++) {
      const bx0 = X0 + i * PITCH + STREET, d = district(bx0 + BLOCK / 2, z);
      if (d >= 0.55) {
        const pz = z - STREET / 2 - 2.5, tops = [];
        [bx0 + 20, bx0 + 120].forEach((px, n) => {
          part('Solid', V(1.1, 26, 1.1), CFrame.new(px, GY + CURB + 13, pz), poleCol, 'Concrete', null, { name: 'Pole' });
          part('Deco', V(0.4, 0.4, 7), CFrame.new(px, GY + CURB + 24, pz), poleCol, 'Concrete', null, { collide: false, query: false });
          if (n === 1 && rng.NextNumber() < 0.4) part('Deco', V(1.8, 2.6, 1.8), CFrame.new(px, GY + CURB + 20, pz + 1.2).mul(CFrame.Angles(0, 0, Math.PI / 2)), rgb(120, 124, 128), 'Metal', 'Cylinder', { collide: false, query: false });
          tops[n] = px;
        });
        for (const dz of [-2.8, 2.8]) {
          const y = GY + CURB + 24;
          wire(V(tops[0], y, pz + dz), V(tops[1], y, pz + dz));
          if (i < GRID - 1) wire(V(tops[1], y, pz + dz), V(tops[0] + PITCH, y, pz + dz));
        }
      } else if (d >= 0.2 && d < 0.6 && j % 2 === 0 && j < GRID) {
        const lx = bx0 + BLOCK / 2, y = GY + CURB + 17;
        wire(V(lx, y + 0.8, z - STREET / 2 - 2), V(lx, y + 0.8, z + STREET / 2 + 2));
        for (let n = 0; n <= 6; n++) {
          const lz = z - STREET / 2 + 3 + n * (STREET - 6) / 6;
          part('Deco', V(1.6, 2.2, 1.6), CFrame.new(lx, y - Math.sin(n / 6 * Math.PI) * 1.2, lz), n % 2 === 0 ? rgb(240, 50, 40) : rgb(255, 240, 210), 'Neon', 'Ball', { name: 'Lantern', group: 'nightNeon', collide: false, query: false });
        }
      }
    }
  }
  // vending machines: a pair or three on a pavement corner, glowing day and night
  const VEND = [rgb(230, 236, 246), rgb(200, 30, 40), rgb(30, 90, 200), rgb(40, 160, 90)];
  for (let i = 0; i <= GRID; i++) for (let j = 0; j <= GRID; j++) {
    const x = streetX(i), z = streetZ(j), d = district(x, z);
    if (d > 0.22 && d < 0.9 && rng.NextNumber() < 0.35) {
      const n = rng.NextInteger(2, 3);
      for (let k = 0; k < n; k++) {
        const base = V(x - STREET / 2 - 3.2, GY + CURB, z + STREET / 2 + 8 + k * 3.8), face = CFrame.lookAt(base, base.add(V(1, 0, 0)));
        part('Solid', V(3.6, 6.2, 2.4), face.mul(CFrame.new(0, 3.1, 0)), VEND[rng.NextInteger(1, VEND.length) - 1], 'SmoothPlastic', null, { name: 'Vending' });
        part('Deco', V(3, 3.4, 0.12), face.mul(CFrame.new(0, 3.8, -1.22)), rgb(200, 236, 255), 'Neon', null, { name: 'VendingFace', collide: false, query: false });
      }
    }
  }
  // the scramble crossing: giant screens on the corner buildings
  {
    const x = streetX(centreI), z = streetZ(centreJ), texts = ['KAIDO DRIFT', '峠', '新箱根', 'DRIFT KING'];
    [[1, 1], [-1, 1], [1, -1], [-1, -1]].forEach((c, k) => {
      const sx = x + c[0] * (STREET / 2 + 34), sz = z + c[1] * (STREET / 2 + 34);
      const look = CFrame.lookAt(V(sx, GY + 70, sz), V(x, GY + 70, z)), scr = look.mul(CFrame.new(0, 0, 1));
      part('Signs', V(44, 26, 1), scr, SIGN_COLORS[k], 'Neon', null, { name: 'Screen', query: false });
      addText(scr.mul(CFrame.new(0, 0, -0.55)), 44, 26, texts[k], rgb(12, 12, 18), 'screens');
    });
  }
  // the elevated expressway (Shuto-style) loop around downtown, with a ramp up from the west
  const ex0 = streetX(ringLo), ex1 = streetX(ringHi), ez0 = streetZ(ringLo), ez1 = streetZ(ringHi);
  const deckCol = rgb(46, 47, 52), wallCol = rgb(150, 152, 156), rampZ = streetZ(centreJ);
  const deck = (a, b) => {
    const total = b.sub(a).Magnitude, n = Math.max(1, Math.ceil(total / 600));
    for (let s = 0; s < n; s++) {
      const p0 = a.Lerp(b, s / n), p1 = a.Lerp(b, (s + 1) / n), len = p1.sub(p0).Magnitude;
      const ext = s === 0 || s === n - 1 ? DECK / 2 : 0.5;
      const cf = CFrame.lookAt(p0.add(p1).div(2), p1).mul(CFrame.new(0, 0, s === 0 ? ext / 2 - 0.25 : s === n - 1 ? -(ext / 2 - 0.25) : 0));
      part('Ground', V(DECK, 2, len + ext + 0.5), cf.mul(CFrame.new(0, -1, 0)), deckCol, 'Asphalt', null, { name: 'Deck', shadow: true });
      for (const side of [-1, 1]) part('Solid', V(1.4, 4.5, len + ext + 0.5), cf.mul(CFrame.new(side * (DECK / 2 - 0.7), 2.25, 0)), wallCol, 'Concrete', null, { name: 'Barrier' });
      part('Deco', V(0.5, 0.08, len), cf.mul(CFrame.new(0, 0.04, 0)), lineCol, 'SmoothPlastic', null, { collide: false });
      if (s % 2 === 0) {
        const hcf = cf.mul(CFrame.new(DECK / 2 - 3, 14, 0));
        part('Lights', V(2.4, 0.5, 1.2), hcf, rgb(255, 196, 120), 'Neon', null, { name: 'LampHead', group: 'lamp' });
        nLight++;
        lights.push({ x: hcf.X, y: hcf.Y, z: hcf.Z, n: nLight, color: rgb(255, 186, 112), range: 50, brightness: 2.4, city: true });
        part('Solid', V(0.7, 14, 0.7), cf.mul(CFrame.new(DECK / 2 - 0.7, 7, 0)), rgb(70, 72, 76), 'Metal', null, { name: 'Pole' });
      }
    }
  };
  const corners = [V(ex0, RING_Y, ez0), V(ex1, RING_Y, ez0), V(ex1, RING_Y, ez1), V(ex0, RING_Y, ez1)];
  for (let k = 0; k < 4; k++) {
    const a = corners[k], b = corners[(k + 1) % 4];
    if (k === 3) {
      const mid = V(ex0, RING_Y, rampZ);
      deck(a, mid.add(V(0, 0, DECK * 0.6)));
      deck(mid.sub(V(0, 0, DECK * 0.6)), b);
      part('Ground', V(DECK, 2, DECK * 1.4), CFrame.new(mid.sub(V(0, 1, 0))), deckCol, 'Asphalt', null, { name: 'Deck' });
    } else deck(a, b);
    const n = Math.floor(b.sub(a).Magnitude / (PITCH * 2));
    for (let s = 0; s <= n; s++) { const p = a.Lerp(b, s / Math.max(n, 1)); part('Solid', V(10, RING_Y - GY - 2, 10), CFrame.new(p.X, (RING_Y - 2 + GY) / 2, p.Z), rgb(120, 122, 126), 'Concrete', null, { name: 'Pillar', shadow: true }); }
  }
  const rampStart = V(ex0 - 760, GY, rampZ), rampEnd = V(ex0 - DECK / 2, RING_Y, rampZ);
  for (let s = 0; s < 16; s++) {
    const ease = (v, t) => V(v.X, GY + (RING_Y - GY) * (t * t * (3 - 2 * t)), v.Z);
    const a = ease(rampStart.Lerp(rampEnd, s / 16), s / 16), b = ease(rampStart.Lerp(rampEnd, (s + 1) / 16), (s + 1) / 16);
    const len = b.sub(a).Magnitude, cf = CFrame.lookAt(a.add(b).div(2), b);
    part('Ground', V(DECK - 8, 2, len + 1), cf.mul(CFrame.new(0, -1, 0)), deckCol, 'Asphalt', null, { name: 'Ramp', shadow: true });
    for (const side of [-1, 1]) part('Solid', V(1.4, 4.5, len + 1), cf.mul(CFrame.new(side * ((DECK - 8) / 2 - 0.7), 2.25, 0)), wallCol, 'Concrete', null, { name: 'Barrier' });
    if (a.Y > GY + 6) part('Solid', V(8, a.Y - GY, 8), CFrame.new(a.X, (a.Y + GY) / 2 - 1, a.Z), rgb(120, 122, 126), 'Concrete', null, { name: 'Pillar' });
  }

  // the link road from the Hakone pass: leaves the pass at its eastern-most point, drops to street level
  const jIdx = ctx.junction, side = ctx.junctionSide;
  const jx = Track.X[jIdx] + Track.RX[jIdx] * side * HALF, jz = Track.Z[jIdx] + Track.RZ[jIdx] * side * HALF, jy = Track.Y[jIdx];
  const entryZ = streetZ(Math.max(0, Math.min(GRID, Math.floor((jz - Z0) / PITCH + 0.5))));
  const pts = [V(jx, jy, jz), V(jx + 160, jy, jz), V(jx + 160 + (X0 - jx - 160) * 0.5, (jy + GY) / 2, (jz + entryZ) / 2), V(X0 - 40, GY, entryZ), V(X0 + STREET / 2, GY, entryZ)];
  const path = [];
  for (let k = 0; k < pts.length - 1; k++) {
    const p0 = pts[Math.max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[Math.min(pts.length - 1, k + 2)];
    const segs = Math.max(2, Math.floor(p2.sub(p1).Magnitude / 30));
    for (let s = 0; s < segs; s++) {
      const t = s / segs, t2 = t * t, t3 = t2 * t;
      path.push(p1.mul(2).add(p2.sub(p0).mul(t)).add(p0.mul(2).sub(p1.mul(5)).add(p2.mul(4)).sub(p3).mul(t2)).add(p0.neg().add(p1.mul(3)).sub(p2.mul(3)).add(p3).mul(t3)).mul(0.5));
    }
  }
  path.push(pts[pts.length - 1]);
  for (let k = 0; k < path.length - 1; k++) {
    const a = path[k], b = path[k + 1], len = b.sub(a).Magnitude, cf = CFrame.lookAt(a.add(b).div(2), b);
    part('Ground', V(HALF * 2, 4, len + 2), cf.mul(CFrame.new(0, -2, 0)), asphalt, 'Asphalt', null, { name: 'Link' });
    Terrain.FillBlock(cf.mul(CFrame.new(0, -5.5, 0)), V(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground);
    Terrain.FillBlock(cf.mul(CFrame.new(0, 13.5, 0)), V(HALF * 2 + 12, 33, len + 4), Enum.Material.Air);
    if (k > 2) for (const sd of [-1, 1]) part('Solid', V(0.5, 1.2, len + 1), cf.mul(CFrame.new(sd * (HALF + 0.9), 1.6, 0)), rgb(172, 174, 178), 'DiamondPlate', null, { name: 'Rail' });
    const m = a.add(b).div(2);
    if (m.Y > FLOOR + 1) {
      const flat = CFrame.lookAt(V(m.X, (m.Y + FLOOR) / 2 - 1, m.Z), V(b.X, (m.Y + FLOOR) / 2 - 1, b.Z));
      part('Link', V(HALF * 2 + 6, m.Y - FLOOR, len + 2), flat, rgb(96, 88, 78), 'Slate');
    }
  }
  return {
    bounds: [X0, Z0, X0 + SIZE, Z0 + SIZE], junction: jIdx, junctionSide: side,
    spawn: [streetX(6), GY, streetZ(8), 0], grid: { X0, Z0, PITCH, STREET, GRID }, ring: [ex0, ez0, ex1, ez1], buildings: buildingCount, lights,
  };
}
