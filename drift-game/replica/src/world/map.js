// Kaido Drift world: port of the Roblox server's map builder (Main.server.luau): ground, hills and Lake Ashi
// (terrain), the road with rails, edge lines, kerbs and centre lines, chevron boards, street lamps, Kojiri
// village, trees, the torii and Mt. Fuji, then Shin-Hakone city (city.js). Same numbers and order as the
// Roblox game; Roblox's Random is swapped for a seeded generator with the same calls.
import { Vector3, CFrame, Color3, Enum } from '../rbx/types.js';
import Config from '../shared/config.js';
import Track from '../shared/track.js';
import { addPart } from './parts.js';
import { Terrain } from './terrain.js';
import { buildCity } from './city.js';

export function makeRandom(seed) {
  let a = seed >>> 0;
  const next = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  return { NextNumber: (lo, hi) => (lo === undefined ? next() : lo + next() * (hi - lo)), NextInteger: (lo, hi) => lo + Math.floor(next() * (hi - lo + 1)) };
}
const V = (x, y, z) => new Vector3(x, y, z);
const rgb = Color3.fromRGB;

export function buildMap() {
  const attrs = {};
  const rng = makeRandom(1989);
  const N = Track.N, X = Track.X, Y = Track.Y, Z = Track.Z;
  const HALF = Config.ROAD_HALF, FLOOR = 6;
  const block = (folder, size, cf, color, material, shape, opts) => addPart(folder, size, cf, color, material.Name || material, shape ? shape.Name || shape : 'Block', opts);

  // ground, hills and Lake Ashi (terrain)
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (let i = 1; i <= N; i++) { minX = Math.min(minX, X[i]); maxX = Math.max(maxX, X[i]); minZ = Math.min(minZ, Z[i]); maxZ = Math.max(maxZ, Z[i]); }
  const margin = 2400;
  for (let gx = minX - margin; gx <= maxX + margin; gx += 2048) for (let gz = minZ - margin; gz <= maxZ + margin; gz += 2048)
    Terrain.FillBlock(CFrame.new(gx + 1024, FLOOR - 6, gz + 1024), V(2048, 12, 2048), Enum.Material.Grass);
  const LAKE_Y = Track.Course.LAKE_Y;
  const lakeCell = (x, z, size) => {
    Terrain.FillBlock(CFrame.new(x, LAKE_Y + 6, z), V(size, 12, size), Enum.Material.Air);
    Terrain.FillBlock(CFrame.new(x, LAKE_Y - 6, z), V(size, 12, size), Enum.Material.Water);
    Terrain.FillBlock(CFrame.new(x, LAKE_Y - 16, z), V(size, 8, size), Enum.Material.Sand);
  };
  const L = Track.Course.LAKES;
  for (let k = 0; k < L.length; k += 2) lakeCell(L[k], L[k + 1], Track.Course.LAKECELL);
  const Cc = Track.Course.CELLS, CS = Track.Course.CELL, hillTops = [];
  for (let k = 0; k < Cc.length; k += 4) {
    const x = Cc[k], top = Cc[k + 1], z = Cc[k + 2], lake = Cc[k + 3];
    if (lake === 1) lakeCell(x, z, CS);
    else if (top > FLOOR + 0.5) {
      const mat = top > 60 ? Enum.Material.LeafyGrass : Enum.Material.Grass;
      Terrain.FillBlock(CFrame.new(x, (top + FLOOR - 4) / 2, z), V(CS, top - FLOOR + 4, CS), mat);
      hillTops.push([x, top, z]);
    } else hillTops.push([x, FLOOR, z]);
  }

  // where the link road to the city leaves the pass: its eastern-most point (no guardrail on that side there)
  let junction = 1, junctionSide = 1;
  { let best = -Infinity; for (let k = 1; k <= N; k++) if (X[k] > best) { best = X[k]; junction = k; } junctionSide = Track.RX[junction] > 0 ? 1 : -1; }
  const nearJunction = k => { const d = Math.abs(k - junction); return Math.min(d, N - d) <= 5; };

  // road: straight runs are merged into long parts, curves use short ones
  const asphalt = rgb(44, 45, 50), rail = rgb(172, 174, 178), rock = rgb(96, 88, 78), EDGE = rgb(89, 227, 255);
  const turnBetween = (i, j) => Math.abs(Math.atan2(Track.TX[i] * Track.TZ[j] - Track.TZ[i] * Track.TX[j], Track.TX[i] * Track.TX[j] + Track.TZ[i] * Track.TZ[j]));
  const wrap = k => ((k - 1) % N + N) % N + 1;
  let i = 1;
  while (i <= N) {
    let j = i + 1;
    while (j - i < 8 && j <= N && turnBetween(i, wrap(j)) < 1.5 * Math.PI / 180 && Math.abs(Track.slope(i) - Track.slope(wrap(j))) < 0.01) j++;
    const jj = wrap(j);
    const a = V(X[i], Y[i], Z[i]), b = V(X[jj], Y[jj], Z[jj]), mid = a.add(b).div(2);
    const len = b.sub(a).Magnitude + 1.2 + HALF * 2 * turnBetween(wrap(j - 1), jj);
    const cf = CFrame.lookAt(mid, b);
    block('Road', V(HALF * 2, 4, len), cf.mul(CFrame.new(0, -2, 0)), asphalt, Enum.Material.Asphalt, null, { name: 'Road' });
    Terrain.FillBlock(cf.mul(CFrame.new(0, -5.5, 0)), V(HALF * 2 + 4, 4, len + 2), Enum.Material.Ground);
    Terrain.FillBlock(cf.mul(CFrame.new(0, 13.5, 0)), V(HALF * 2 + 12, 33, len + 4), Enum.Material.Air);
    for (const side of [-1, 1]) {
      if (side === junctionSide && (nearJunction(i) || nearJunction(jj))) continue;
      const ra = a.add(V(Track.RX[i], 0, Track.RZ[i]).mul(side * (HALF + 0.9))), rb = b.add(V(Track.RX[jj], 0, Track.RZ[jj]).mul(side * (HALF + 0.9)));
      const rcf = CFrame.lookAt(ra.add(rb).div(2), rb);
      block('Rails', V(0.5, 1.2, rb.sub(ra).Magnitude + 0.8), rcf.mul(CFrame.new(0, 1.6, 0)), rail, Enum.Material.DiamondPlate, null, { name: 'Rail' });
      block('Rails', V(0.4, 2.2, 0.4), CFrame.new(ra.add(V(0, 1.1, 0))), rgb(120, 122, 126), Enum.Material.Metal, null, { name: 'Post' });
      const ea = a.add(V(Track.RX[i], 0, Track.RZ[i]).mul(side * (HALF + 0.3))), eb = b.add(V(Track.RX[jj], 0, Track.RZ[jj]).mul(side * (HALF + 0.3)));
      block('Rails', V(0.5, 0.3, eb.sub(ea).Magnitude + 0.6), CFrame.lookAt(ea.add(eb).div(2), eb).mul(CFrame.new(0, -0.1, 0)), EDGE, Enum.Material.Neon, null, { name: 'Edge', collide: false, query: false });
    }
    if (mid.Y > FLOOR + 1) {
      const flat = CFrame.lookAt(V(mid.X, (mid.Y + FLOOR) / 2 - 1, mid.Z), V(b.X, (mid.Y + FLOOR) / 2 - 1, b.Z));
      block('Road', V(HALF * 2 + 6, mid.Y - FLOOR, len), flat, rock, Enum.Material.Slate, null, { name: 'Bank' });
    }
    i = j;
  }
  // kerbs on the bends, dashed centre line on the straights
  for (let k = 1; k <= N; k++) {
    const nx = k % N + 1, a = V(X[k], Y[k], Z[k]), b = V(X[nx], Y[nx], Z[nx]);
    const cf = CFrame.lookAt(a.add(b).div(2), b), len = b.sub(a).Magnitude + 0.4;
    if (turnBetween(k, ((k + 1) % N) + 1) > 2.2 * Math.PI / 180) {
      for (const side of [-1, 1]) block('RoadDeco', V(1.6, 0.22, len), cf.mul(CFrame.new(side * (HALF - 0.8), 0.06, 0)), k % 2 === 0 ? rgb(205, 36, 40) : rgb(236, 236, 236), Enum.Material.SmoothPlastic, null, { collide: false });
    } else if (k % 4 === 0) block('RoadDeco', V(0.45, 0.08, len * 1.6), cf.mul(CFrame.new(0, 0.02, 0)), rgb(240, 236, 220), Enum.Material.SmoothPlastic, null, { collide: false });
  }
  // chevron boards on the outside of the tight corners, pointing the way the road turns
  {
    const turnAt = k => { const a = wrap(k - 3), b = wrap(k + 3); return Math.asin(Math.max(-1, Math.min(1, Track.TX[a] * Track.TZ[b] - Track.TZ[a] * Track.TX[b]))); };
    let k = 1, placed = 0;
    while (k <= N) {
      const t = turnAt(k);
      if (6 * Config.SEG / Math.max(Math.abs(t), 1e-6) < 68 && !nearJunction(k)) {
        const a = wrap(k - 3), b = wrap(k + 3);
        const inward = (Track.TX[b] - Track.TX[a]) * Track.RX[k] + (Track.TZ[b] - Track.TZ[a]) * Track.RZ[k];
        const s = inward > 0 ? 1 : -1;
        for (let n = 0; n <= 4; n++) {
          const q = wrap(k - 3 + n * 2);
          const T = V(Track.TX[q], 0, Track.TZ[q]), Rv = V(Track.RX[q], 0, Track.RZ[q]);
          const base = V(X[q], Y[q], Z[q]).sub(Rv.mul(s * (HALF + 4.5)));
          const board = CFrame.lookAt(base.add(V(0, 3.2, 0)), base.add(V(0, 3.2, 0)).sub(T));
          block('Chevrons', V(0.4, 3, 0.4), CFrame.new(base.add(V(0, 1.5, 0))), rgb(62, 64, 68), Enum.Material.Metal);
          block('Chevrons', V(3.6, 2.6, 0.3), board, rgb(18, 18, 22), Enum.Material.SmoothPlastic);
          const dir = Rv.mul(s).Dot(board.RightVector) > 0 ? 1 : -1;
          for (const up of [1, -1]) block('Chevrons', V(1.7, 0.42, 0.12), board.mul(CFrame.new(0, up * 0.42, -0.2)).mul(CFrame.Angles(0, 0, -up * dir * 38 * Math.PI / 180)), rgb(255, 200, 40), Enum.Material.Neon, null, { collide: false, query: false });
          placed++;
        }
        k += 14;
      } else k++;
    }
    attrs.ChevronCount = placed;
  }
  // street lamps (warm sodium light)
  const lampLights = [];
  let lampCount = 0;
  for (let k = 1; k <= N; k += 18) {
    const side = Math.floor(k / 18) % 2 === 0 ? 1 : -1;
    const base = V(X[k] + Track.RX[k] * side * (HALF + 3), Y[k], Z[k] + Track.RZ[k] * side * (HALF + 3));
    const inward = V(-Track.RX[k] * side, 0, -Track.RZ[k] * side), pole = rgb(62, 64, 68);
    block('Lamps', V(0.8, 18, 0.8), CFrame.new(base.add(V(0, 9, 0))), pole, Enum.Material.Metal);
    block('Lamps', V(0.5, 0.5, 6), CFrame.lookAt(base.add(V(0, 18, 0)).add(inward.mul(3)), base.add(V(0, 18, 0)).add(inward.mul(6))), pole, Enum.Material.Metal);
    const hp = base.add(V(0, 17.6, 0)).add(inward.mul(5.5));
    block('Lamps', V(2.2, 0.5, 1.2), CFrame.new(hp), rgb(255, 196, 120), Enum.Material.Neon, null, { name: 'LampHead', group: 'lamp' });
    lampCount++;
    lampLights.push({ x: hp.X, y: hp.Y, z: hp.Z, n: lampCount, color: rgb(255, 186, 112), range: 44, brightness: 2.4 });
  }
  // Kojiri village: wooden houses with lit windows and lanterns, and glowing vending machines
  const wood = rgb(98, 68, 48), roofC = rgb(58, 62, 74);
  let houses = 0;
  const lanternLights = [];
  for (let k = 1; k <= N; k += 9) {
    if (Track.ZONE[k] !== 0) continue;
    const side = Math.floor(k / 9) % 2 === 0 ? 1 : -1;
    const dist = HALF + 24 + rng.NextNumber() * 10;
    const c = V(X[k] + Track.RX[k] * side * dist, Y[k], Z[k] + Track.RZ[k] * side * dist);
    if (Track.near(c.X, c.Z, HALF + 18).length !== 0) continue;
    houses++;
    const face = CFrame.lookAt(c, c.sub(V(Track.RX[k] * side, 0, Track.RZ[k] * side)));
    block('Village', V(30, c.Y - FLOOR + 2, 26), CFrame.new(c.sub(V(0, (c.Y - FLOOR + 2) / 2, 0))), rgb(82, 76, 68), Enum.Material.Cobblestone);
    const w = 20 + rng.NextInteger(0, 6), d = 14 + rng.NextInteger(0, 4), h = 11 + rng.NextInteger(0, 5);
    block('Village', V(w, h * 0.55, d), face.mul(CFrame.new(0, h * 0.275, 0)), wood, Enum.Material.WoodPlanks, null, { shadow: true });
    block('Village', V(w - 0.4, h * 0.45, d - 0.4), face.mul(CFrame.new(0, h * 0.775, 0)), rgb(226, 220, 206), Enum.Material.Plaster, null, { shadow: true });
    block('Village', V(w + 0.6, 1.4, d + 0.6), face.mul(CFrame.new(0, 0.7, 0)), rgb(104, 100, 94), Enum.Material.Cobblestone);
    block('Village', V(w + 1.2, 0.5, d + 1.2), face.mul(CFrame.new(0, h * 0.55, 0)), rgb(58, 62, 74), Enum.Material.ClayRoofTiles);
    block('Village', V(4, 7, 0.3), face.mul(CFrame.new(0, 3.5, -d / 2 - 0.1)), rgb(64, 44, 32), Enum.Material.WoodPlanks);
    block('Village', V(w + 2, 5, d / 2 + 1), face.mul(CFrame.new(0, h + 2.5, -(d / 4 + 0.5))), roofC, Enum.Material.ClayRoofTiles, 'Wedge', { shadow: true });
    block('Village', V(w + 2, 5, d / 2 + 1), face.mul(CFrame.new(0, h + 2.5, d / 4 + 0.5)).mul(CFrame.Angles(0, Math.PI, 0)), roofC, Enum.Material.ClayRoofTiles, 'Wedge', { shadow: true });
    for (const wx of [-1, 1]) block('Village', V(3.2, 3, 0.3), face.mul(CFrame.new(wx * w / 4, h * 0.3, -d / 2 - 0.05)), rgb(255, 202, 128), Enum.Material.Neon, null, { name: 'Window', group: 'win1' });
    const lcf = face.mul(CFrame.new(0, h * 0.7, -d / 2 - 1.2));
    block('Village', V(1.6, 2.2, 1.6), lcf, rgb(236, 56, 40), Enum.Material.Neon, 'Ball', { name: 'Lantern', group: 'nightNeon' });
    lanternLights.push({ x: lcf.X, y: lcf.Y, z: lcf.Z, color: rgb(255, 140, 90), range: 22, brightness: 2 });
    if (houses % 3 === 0) {
      block('Village', V(3.6, 6, 2.4), face.mul(CFrame.new(w / 2 + 3, 3, -d / 2 + 1)), rgb(230, 236, 246), Enum.Material.SmoothPlastic, null, { name: 'Vending' });
      block('Village', V(3, 3.4, 0.2), face.mul(CFrame.new(w / 2 + 3, 3.6, -d / 2 - 0.25)), rgb(150, 220, 255), Enum.Material.Neon, null, { name: 'VendingFace' });
    }
  }
  // trees on the hillsides: cedars and autumn maples; Tier lets each player's graphics level thin them out
  let placed = 0;
  for (const cell of hillTops) {
    if (placed >= 1800) break;
    for (let q = 0; q < 2; q++) {
      const x = cell[0] + rng.NextNumber(-40, 40), z = cell[2] + rng.NextNumber(-40, 40);
      if (Track.near(x, z, HALF + 14).length === 0 && rng.NextNumber() < 0.75) {
        const s = 0.8 + rng.NextNumber() * 0.8, ground = V(x, cell[1] - 0.5, z);
        const tier = rng.NextInteger(1, 3), g = 'tree' + tier;
        const maple = rng.NextNumber() < 0.22;
        block('Trees', V(14 * s, 1.6 * s, 1.6 * s), CFrame.new(ground.add(V(0, 7 * s, 0))).mul(CFrame.Angles(0, 0, Math.PI / 2)), rgb(72, 52, 40), Enum.Material.Wood, 'Cylinder', { group: g, shadow: true });
        if (maple) {
          const leaf = rng.NextNumber() < 0.5 ? rgb(180, 54, 32) : rgb(216, 142, 44);
          block('Trees', V(15 * s, 11 * s, 15 * s), CFrame.new(ground.add(V(0, 14 * s, 0))), leaf, Enum.Material.Grass, 'Ball', { group: g, shadow: true });
          block('Trees', V(10 * s, 8 * s, 10 * s), CFrame.new(ground.add(V(2 * s, 19 * s, -1 * s))), leaf, Enum.Material.Grass, 'Ball', { group: g, shadow: true });
        } else {
          const leaf = rgb(26 + rng.NextInteger(0, 14), 64 + rng.NextInteger(0, 18), 38);
          for (let t = 0; t <= 2; t++) { const r = (8.5 - t * 2.4) * s; block('Trees', V(r * 2, r * 1.7, r * 2), CFrame.new(ground.add(V(0, (11 + t * 6.5) * s, 0))), leaf, Enum.Material.Grass, 'Ball', { group: g, shadow: true }); }
        }
        placed++;
      }
    }
  }
  // the start gate (torii) and Mt. Fuji on the horizon
  {
    const k = 1, c = V(X[k], Y[k], Z[k]), face = CFrame.lookAt(c, c.add(V(Track.TX[k], 0, Track.TZ[k]))), red = rgb(196, 30, 34);
    for (const s of [-1, 1]) block('Map', V(1.8, 24, 1.8), face.mul(CFrame.new(s * (HALF + 3), 12, 0)), red, Enum.Material.Wood, null, { shadow: true });
    block('Map', V(HALF * 2 + 16, 1.8, 2.6), face.mul(CFrame.new(0, 23, 0)), red, Enum.Material.Wood, null, { shadow: true });
    block('Map', V(HALF * 2 + 11, 1.2, 1.8), face.mul(CFrame.new(0, 20, 0)), rgb(28, 28, 30), Enum.Material.Wood);
    const [fx, fz] = Track.Course.FUJI;
    for (let t = 0; t <= 11; t++) {
      const r = 1024 * Math.pow(1 - t / 12, 1.15), hgt = 95;
      const col = t >= 8 ? rgb(236, 240, 246) : rgb(64 + t * 3, 72 + t * 3, 96 + t * 2);
      block('Fuji', V(hgt, r * 2, r * 2), CFrame.new(fx, FLOOR + hgt / 2 + t * hgt, fz).mul(CFrame.Angles(0, 0, Math.PI / 2)), col, t >= 8 ? Enum.Material.Snow : Enum.Material.Rock, 'Cylinder', { collide: false });
    }
  }
  // Shin-Hakone city and the link road
  const city = buildCity({ Track, rng, FLOOR, HALF, junction, junctionSide });
  Object.assign(attrs, {
    CitySpawn: V(city.spawn[0], city.spawn[1], city.spawn[2]), CityMin: { X: city.bounds[0], Y: city.bounds[1] }, CityMax: { X: city.bounds[2], Y: city.bounds[3] },
    CityRing: V(city.ring[0], city.ring[1], city.ring[2]), CityRing2: city.ring[3], CityPitch: city.grid.PITCH, CityStreet: city.grid.STREET, CityGrid: city.grid.GRID,
    Junction: junction, Ready: true,
  });
  console.log(`Kaido Drift map ready: pass ${N} samples, city ${city.buildings} buildings`);
  return { attrs, lights: [...lampLights, ...lanternLights, ...city.lights] };
}
