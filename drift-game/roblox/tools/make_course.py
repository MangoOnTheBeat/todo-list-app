"""Converts the browser game's Hakone course (control points + real DEM heights) into
roblox/src/shared/CourseData.luau: the road line, its real elevation profile, zones,
the hills beside the road and Lake Ashi. Horizontal 3.0 studs per metre (close to the cars' 3.5, so roads and corners fit them); heights 0.6 studs per metre."""
import re, json, base64, math, sys
import numpy as np

SRC = sys.argv[1] if len(sys.argv) > 1 else '../index.html'
OUT = sys.argv[2] if len(sys.argv) > 2 else 'src/shared/CourseData.luau'
H, V = 3.0, 0.6

s = open(SRC).read()
DEM = json.loads(re.search(r'^const DEM = (\{.*?\});$', s, re.M).group(1))
CP = json.loads(re.search(r'^const CP = (\[.*?\]);', s, re.M).group(1))
ZRLE = json.loads(re.search(r'const ZONE_RLE = (\[.*?\]), ZONE_RLE_N = (\d+);', s).group(1))
ZN = int(re.search(r'ZONE_RLE_N = (\d+);', s).group(1))
BASE, LAKE = DEM['base'], DEM['lake']

def grid(g, scale, offset):
    raw = base64.b64decode(g['h'])
    q = np.frombuffer(raw, dtype='<u2').astype(np.float64)
    n = g['n']
    h = (q * scale + offset).reshape(n, n)  # metres above sea level
    bits = np.unpackbits(np.frombuffer(base64.b64decode(g['lake']), dtype=np.uint8), bitorder='little')[: n * n].reshape(n, n)
    return {'size': g['size'], 'n': n, 'h': h, 'lake': bits}
NEAR, FAR = grid(DEM['near'], 0.1, 400), grid(DEM['far'], 1, -200)

def sample(G, x, z):
    n, c = G['n'], (G['n'] - 1) / G['size']
    gx = min(max((x + G['size'] / 2) * c, 0), n - 1.001); gz = min(max((z + G['size'] / 2) * c, 0), n - 1.001)
    ix, iz = int(gx), int(gz); fx, fz = gx - ix, gz - iz; h = G['h']
    return (h[iz, ix] * (1 - fx) + h[iz, ix + 1] * fx) * (1 - fz) + (h[iz + 1, ix] * (1 - fx) + h[iz + 1, ix + 1] * fx) * fz
def lake_at(G, x, z):
    n, c = G['n'], (G['n'] - 1) / G['size']
    ix, iz = round((x + G['size'] / 2) * c), round((z + G['size'] / 2) * c)
    return 0 <= ix < n and 0 <= iz < n and G['lake'][iz, ix] == 1
NH = DEM['near']['size'] / 2
def realH(x, z):
    e = max(abs(x), abs(z))
    if e >= NH - 10: return sample(FAR, x, z)
    nh = sample(NEAR, x, z)
    t = min(max((e - (NH - 300)) / 280, 0), 1); t = t * t * (3 - 2 * t)
    return nh * (1 - t) + sample(FAR, x, z) * t
def inLake(x, z):
    return lake_at(NEAR, x, z) if max(abs(x), abs(z)) < NH - 10 else lake_at(FAR, x, z)

# centripetal Catmull-Rom through the control points (like three.js), closed
P = np.array([[p[0], p[2]] for p in CP])
n = len(P)
dense = []
for i in range(n):
    p0, p1, p2, p3 = P[(i - 1) % n], P[i], P[(i + 1) % n], P[(i + 2) % n]
    def tj(ti, a, b): return ti + max(np.linalg.norm(b - a), 1e-4) ** 0.5
    t0 = 0; t1 = tj(t0, p0, p1); t2 = tj(t1, p1, p2); t3 = tj(t2, p2, p3)
    for k in range(40):
        t = t1 + (t2 - t1) * k / 40
        a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
        a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
        a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
        b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
        b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
        dense.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
dense = np.array(dense)
# resample every 5 m
seg = np.linalg.norm(np.roll(dense, -1, 0) - dense, axis=1); cum = np.concatenate([[0], np.cumsum(seg)])
L = cum[-1]; M = int(round(L / 5)); ts = np.arange(M) * L / M
loop = np.vstack([dense, dense[:1]])
xs = np.interp(ts, cum, loop[:, 0]); zs = np.interp(ts, cum, loop[:, 1])
# road profile: real ground, smoothed like a surveyed road, held to 12 % grade (two-sided envelope, as in the browser)
raw = np.array([realH(x, z) for x, z in zip(xs, zs)])
sig = int(round(110 / 5)); w = np.exp(-0.5 * (np.arange(-3 * sig, 3 * sig + 1) / sig) ** 2); w /= w.sum()
py = np.array([np.sum(raw[(np.arange(i - 3 * sig, i + 3 * sig + 1)) % M] * w) for i in range(M)])
py = np.maximum(py, LAKE + 1.4)
g = 0.12 * 5
Lo, Up = py.copy(), py.copy()
for _ in range(2):
    for k in range(1, M + 1):
        i, h = k % M, (k - 1) % M; Lo[i] = min(Lo[i], Lo[h] + g); Up[i] = max(Up[i], Up[h] - g)
    for k in range(M - 1, -1, -1):
        i, h = k, (k + 1) % M; Lo[i] = min(Lo[i], Lo[h] + g); Up[i] = max(Up[i], Up[h] - g)
py = (Lo + Up) / 2
YB = LAKE - 8  # 0 studs is 8 m below the lake surface
zone = []
for i in range(M):
    zi = int(i * ZN / M); zv = 0
    for s0, v in ZRLE:
        if zi >= s0: zv = v
    zone.append(zv)

# keep every 4th point (20 m) for the Luau spline
step = 4
pts = [(xs[i] * H, (py[i] - YB) * V, zs[i] * H, zone[i]) for i in range(0, M, step)]

# hills beside the road: 40 m cells within 260 m of the road, eased toward the lake level far out,
# always below the road nearby; lake cells
cx0, cx1, cz0, cz1 = xs.min() - 320, xs.max() + 320, zs.min() - 320, zs.max() + 320
road = np.stack([xs, zs], 1)[::2]; ry = py[::2]
cells = []
C = 40
for gx in np.arange(cx0, cx1, C):
    for gz in np.arange(cz0, cz1, C):
        x, z = gx + C / 2, gz + C / 2
        d2 = (road[:, 0] - x) ** 2 + (road[:, 1] - z) ** 2
        k = int(np.argmin(d2)); d = math.sqrt(d2[k])
        if d > 260: continue
        lake = inLake(x, z)
        h = LAKE - 3 if lake else realH(x, z)
        if not lake:
            far = min(max((d - 170) / 90, 0), 1)
            h = h * (1 - far) + (LAKE + 2) * far
            # stay below every stretch of road within 70 m (hairpins stack roads at different heights)
            near = np.nonzero(d2 < 70 * 70)[0]
            for j in near:
                dj = math.sqrt(d2[j])
                h = min(h, ry[j] - 2.5 if dj < 32 else ry[j] - 1.0 + (dj - 32) * 0.3)
        cells.append((round(x * H), round((h - YB) * V, 1), round(z * H), 1 if lake else 0))
# the open lake: 120 m cells over the whole box (outside the hill band too)
lakes = []
for gx in np.arange(-NH, NH, 120):
    for gz in np.arange(-NH, NH, 120):
        if inLake(gx + 60, gz + 60): lakes.append((round((gx + 60) * H), round((gz + 60) * H)))

fx, fz = DEM['fuji']
with open(OUT, 'w') as f:
    f.write('-- Generated by tools/make_course.py from the browser game\'s Hakone course and elevation data. Do not edit.\n')
    f.write('-- POINTS: x, y, z (studs), zone (0 Kojiri village, 1 Hakone hills, 2 Lake Ashi shore) every 20 m of road.\n')
    f.write('-- CELLS: hill columns beside the road: x, top y, z, lake flag (40 m = 88-stud cells). LAKES: open-water cells (120 m).\n')
    f.write('return {\n')
    f.write('\tPOINTS = {' + ','.join(f'{p[0]:.1f},{p[1]:.1f},{p[2]:.1f},{p[3]}' for p in pts) + '},\n')
    f.write('\tCELLS = {' + ','.join(f'{c[0]},{c[1]},{c[2]},{c[3]}' for c in cells) + '},\n')
    f.write(f'\tCELL = {C * H},\n\tLAKECELL = {120 * H},\n')
    f.write('\tLAKES = {' + ','.join(f'{a},{b}' for a, b in lakes) + '},\n')
    f.write(f'\tLAKE_Y = {round((LAKE - YB) * V, 1)},\n')
    f.write(f'\tFUJI = {{ {round(fx / math.hypot(fx, fz) * 15000)}, {round(fz / math.hypot(fx, fz) * 15000)} }},\n')
    f.write('}\n')
print(f'course {L/1000:.2f} km, {len(pts)} points, {len(cells)} hill cells, {len(lakes)} lake cells, road y {min(p[1] for p in pts):.0f}..{max(p[1] for p in pts):.0f} studs')
