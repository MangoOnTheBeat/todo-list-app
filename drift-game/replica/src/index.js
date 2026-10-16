// Kaido Drift web replica: boots the Roblox game in the browser. Sets up Lighting the way the Roblox
// server does, shows the loading screen, builds the map (same builder, same numbers), then runs the client.
import { installInput, Lighting, makeEffect, RunService, stepTweens, localPlayer, Instance, touchIOFor, reportError } from './rbx/core.js';
import { make, setTouchLookup } from './rbx/gui.js';
import { Color3, UDim2, Enum } from './rbx/types.js';
import Config from './shared/config.js';
import Ui from './client/ui.js';
import { initRenderer, render, setLights, camera } from './client/renderer.js';
import { CFrame, Vector3 } from './rbx/types.js';
import { buildMap } from './world/map.js';
import { buildBatches } from './world/parts.js';
import { buildTerrainMeshes } from './world/terrain.js';
import { buildText } from './world/text.js';
import { buildIndex, World } from './world/query.js';
import { initFx } from './client/fx.js';
import { R, buildBoardParts, buildBoardGui } from './server/server.js';
import { runClient } from './client/main.js';

const canvas = document.getElementById('view');
installInput(canvas);
setTouchLookup(touchIOFor);
const { scene, renderer } = initRenderer(canvas);
renderer.info.autoReset = true;
localPlayer.Name = 'You'; localPlayer.DisplayName = 'You';

// ===================== lighting (as the Roblox server sets it) =====================
Object.assign(Lighting, { ClockTime: 0, Brightness: 1.4, Ambient: Color3.fromRGB(34, 38, 62), OutdoorAmbient: Color3.fromRGB(58, 64, 100), EnvironmentDiffuseScale: 0.45, EnvironmentSpecularScale: 0.7 });
makeEffect('Atmosphere', { Density: 0.3, Offset: 0.12, Haze: 1.1, Glare: 0, Color: Color3.fromRGB(72, 82, 122), Decay: Color3.fromRGB(22, 24, 42), Parent: Lighting });
makeEffect('Sky', { StarCount: 6000, CelestialBodiesShown: true, MoonAngularSize: 13, Parent: Lighting });
makeEffect('BloomEffect', { Name: 'KaidoBloom', Intensity: 0.55, Size: 28, Threshold: 1.6, Parent: Lighting });
makeEffect('ColorCorrectionEffect', { Name: 'KaidoGrade', Contrast: 0.08, Saturation: 0.06, Parent: Lighting });

// ===================== loading =====================
const playerGui = new Instance('PlayerGui'); playerGui.Parent = localPlayer;
const gui = make('ScreenGui', { Name: 'KaidoUI', ResetOnSpawn: false, IgnoreGuiInset: true, ZIndexBehavior: Enum.ZIndexBehavior.Sibling, Parent: playerGui });
const loading = make('Frame', { Size: UDim2.fromScale(1, 1), BackgroundColor3: Ui.INK, ZIndex: 50, Parent: gui });
Ui.text({ Text: 'KAIDO <font color="#ff7eb6">峠</font> DRIFT', FontFace: Ui.DISPLAY, TextSize: 56, TextXAlignment: Enum.TextXAlignment.Center, Position: new UDim2(0, 0, 0.4, -40), ZIndex: 51, Parent: loading });
Ui.text({ Text: 'VERSION ' + Config.VERSION, TextSize: 12, FontFace: Ui.BOLD, TextColor3: Ui.DIM, TextXAlignment: Enum.TextXAlignment.Center, Position: new UDim2(0, 0, 1, -40), ZIndex: 51, Parent: loading });
const loadMsg = Ui.text({ Text: 'Building Japan…', TextSize: 16, TextColor3: Ui.DIM, TextXAlignment: Enum.TextXAlignment.Center, Position: new UDim2(0, 0, 0.4, 30), ZIndex: 51, Parent: loading });
const barBack = make('Frame', { Size: new UDim2(0, 260, 0, 3), Position: new UDim2(0.5, -130, 0.4, 64), BackgroundColor3: new Color3(1, 1, 1), BackgroundTransparency: 0.85, BorderSizePixel: 0, ZIndex: 51, Parent: loading });
const loadBar = make('Frame', { Size: new UDim2(0.1, 0, 1, 0), BackgroundColor3: Ui.SAKURA, BorderSizePixel: 0, ZIndex: 52, Parent: barBack });
const step = (f, msg) => new Promise(r => { loadBar.Size = new UDim2(f, 0, 1, 0); if (msg) loadMsg.Text = msg; requestAnimationFrame(() => setTimeout(r, 0)); });

async function boot() {
  await step(0.1);
  const { attrs, lights } = buildMap();
  await step(0.55);
  const boardFace = buildBoardParts(attrs.CitySpawn);
  const tm = buildTerrainMeshes(scene);
  await step(0.7);
  buildBatches(scene);
  console.log('terrain meshes', tm.length, 'scene objects', scene.children.length);
  await step(0.8);
  await buildText(scene);
  buildIndex();
  setLights(lights, (x, y, z) => World.ground(x, y + 2, z)[0]);
  buildBoardGui(scene, boardFace);
  initFx(scene);
  await step(0.95);
  const mapFolder = new Instance('Folder'); mapFolder.Name = 'KaidoMap';
  for (const k in attrs) mapFolder.SetAttribute(k, attrs[k]);
  runClient({ gui, loading, loadMsg, mapFolder, R });
  let last = performance.now();
  const frame = now => {
    requestAnimationFrame(frame);
    const dt = Math.min(0.1, (now - last) / 1000); last = now;
    if (window.__kaidoPause) return;
    try { RunService.RenderStepped.Fire(dt); stepTweens(); render(dt); RunService.Heartbeat.Fire(dt); } catch (e) { reportError(e); }
  };
  // test hooks: step the game without drawing, draw one frame, read the renderer's counters
  window.__kaidoStep = (n, dt) => { for (let k = 0; k < n; k++) { RunService.RenderStepped.Fire(dt); stepTweens(); RunService.Heartbeat.Fire(dt); } };
  window.__kaidoRbx = { camera, CFrame, Vector3, Lighting, attrs };
  window.__kaidoDraw = () => { render(1 / 60); const i = renderer.info.render; return { calls: i.calls, tris: i.triangles }; };
  requestAnimationFrame(frame);
}
boot().catch(e => { reportError(e); loadMsg.Text = 'Something went wrong (game):\n' + (e && e.message) + '\nSend a screenshot of this to fix it.'; loadMsg.TextColor3 = Ui.DANGER; });
