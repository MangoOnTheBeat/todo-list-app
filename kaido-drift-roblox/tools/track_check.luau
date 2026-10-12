local Track = require("../src/shared/Track")
local d = Track.build()
print("N", d.n, "LEN", d.length)
local maxc, maxg = 0, 0
for i = 1, d.n do
  maxc = math.max(maxc, math.abs(d.curv[i]))
  local j = i % d.n + 1
  maxg = math.max(maxg, math.abs(d.y[j]-d.y[i])/d.segment)
  print(string.format("P %.1f %.1f %.1f %.5f", d.x[i], d.y[i], d.z[i], d.curv[i]))
end
print("MAXCURV", maxc, "minR", 1/maxc, "MAXGRADE", maxg)
-- min distance between non-adjacent sections (> 40 points apart along track)
local worst, wi, wj = math.huge, 0, 0
for i = 1, d.n do for j = i + 40, d.n do
  if (i + d.n - j) > 40 then
    local dd = math.sqrt((d.x[i]-d.x[j])^2 + (d.z[i]-d.z[j])^2)
    if dd < worst then worst, wi, wj = dd, i, j end
  end end end
print("MINSEP", worst, wi, wj, d.y[wi], d.y[wj])
