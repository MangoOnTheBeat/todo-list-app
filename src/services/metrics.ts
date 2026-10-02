import { useEffect } from 'react';
import { create } from 'zustand';
import { getApp } from '@/system/appRegistry';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppId } from '@/system/types';

/**
 * Simulated hardware telemetry. Values follow smoothed random walks with occasional
 * spikes, and open windows contribute load, so the monitor reacts to what you do.
 * The sampler only runs while at least one consumer is mounted.
 */
export const CORES = 8;
const HISTORY = 60;
export const TOTAL_MEM_GB = 32;

export interface Proc {
  pid: number;
  name: string;
  appId?: AppId;
  windowId?: string;
  kind: 'app' | 'background' | 'system';
  cpu: number; // %
  mem: number; // MB
  gpu: number; // %
  energy: 'Low' | 'Moderate' | 'High';
}

interface MetricsState {
  cpu: number[];
  cores: number[];
  mem: number[]; // GB used
  gpu: number[];
  netDown: number[]; // MB/s
  netUp: number[];
  diskRead: number[];
  temp: number;
  uptime: number;
  procs: Proc[];
}

const zeros = () => Array.from({ length: HISTORY }, () => 0);

export const useMetrics = create<MetricsState>()(() => ({
  cpu: zeros(),
  cores: Array.from({ length: CORES }, () => 10),
  mem: zeros().map(() => 11),
  gpu: zeros(),
  netDown: zeros(),
  netUp: zeros(),
  diskRead: zeros(),
  temp: 48,
  uptime: 3 * 3600 + 17 * 60,
  procs: [],
}));

const BACKGROUND: { name: string; kind: Proc['kind']; base: number; mem: number }[] = [
  { name: 'aurora-compositor', kind: 'system', base: 3.5, mem: 420 },
  { name: 'aurora-shell', kind: 'system', base: 1.8, mem: 310 },
  { name: 'Aurora AI runtime', kind: 'background', base: 2.4, mem: 1240 },
  { name: 'indexd (search)', kind: 'background', base: 0.9, mem: 180 },
  { name: 'audiod', kind: 'system', base: 0.6, mem: 64 },
  { name: 'netd', kind: 'system', base: 0.4, mem: 48 },
  { name: 'syncd (cloud)', kind: 'background', base: 0.7, mem: 96 },
  { name: 'kernel_task', kind: 'system', base: 2.2, mem: 1800 },
];

const APP_LOAD: Partial<Record<AppId, { cpu: number; mem: number; gpu: number }>> = {
  browser: { cpu: 6, mem: 1450, gpu: 8 },
  music: { cpu: 2.5, mem: 380, gpu: 4 },
  monitor: { cpu: 1.5, mem: 160, gpu: 6 },
  assistant: { cpu: 4, mem: 900, gpu: 14 },
  files: { cpu: 0.8, mem: 210, gpu: 1 },
  store: { cpu: 1.2, mem: 520, gpu: 3 },
};

const walk = (v: number, target: number, jitter: number, min = 0, max = 100) =>
  Math.min(max, Math.max(min, v + (target - v) * 0.25 + (Math.random() - 0.5) * jitter));

const pidFor = new Map<string, number>();
let nextPid = 4120;
const pid = (key: string) => {
  if (!pidFor.has(key)) pidFor.set(key, nextPid += 7 + Math.floor(Math.random() * 40));
  return pidFor.get(key)!;
};

function sample() {
  const prev = useMetrics.getState();
  const wins = Object.values(useWindowStore.getState().windows);
  const spike = Math.random() < 0.06 ? 25 + Math.random() * 30 : 0;

  const prevByKey = new Map(prev.procs.map((p) => [p.windowId ?? p.name, p]));
  const appProcs: Proc[] = wins.map((w) => {
    const load = APP_LOAD[w.appId] ?? { cpu: 1, mem: 240, gpu: 2 };
    const old = prevByKey.get(w.id);
    const cpu = walk(old?.cpu ?? load.cpu, load.cpu * (w.minimized ? 0.2 : 1), load.cpu * 0.8, 0.1, 60);
    return {
      pid: pid(w.id),
      name: w.title === getApp(w.appId).name ? w.title : `${getApp(w.appId).name} — ${w.title}`,
      appId: w.appId,
      windowId: w.id,
      kind: 'app',
      cpu,
      mem: walk(old?.mem ?? load.mem, load.mem, load.mem * 0.04, 20, 8000),
      gpu: walk(old?.gpu ?? load.gpu, load.gpu * (w.minimized ? 0 : 1), 3, 0, 80),
      energy: cpu > 8 ? 'High' : cpu > 3 ? 'Moderate' : 'Low',
    };
  });
  const bgProcs: Proc[] = BACKGROUND.map((b) => {
    const old = prevByKey.get(b.name);
    const cpu = walk(old?.cpu ?? b.base, b.base, b.base, 0.05, 40);
    return { pid: pid(b.name), name: b.name, kind: b.kind, cpu, mem: walk(old?.mem ?? b.mem, b.mem, b.mem * 0.03, 10, 9000), gpu: b.name.includes('compositor') ? walk(old?.gpu ?? 9, 9, 4) : 0, energy: cpu > 3 ? 'Moderate' : 'Low' };
  });
  const procs = [...appProcs, ...bgProcs];

  const procCpu = procs.reduce((a, p) => a + p.cpu, 0) / 2.2;
  const cpuNow = Math.min(100, walk(prev.cpu[HISTORY - 1], procCpu + 6 + spike, 5));
  const cores = prev.cores.map((c, i) => walk(c, cpuNow * (0.6 + ((i * 37) % 9) / 10) + (i < 2 ? spike : 0), 14));
  const memUsed = Math.min(TOTAL_MEM_GB - 1, 7.5 + procs.reduce((a, p) => a + p.mem, 0) / 1024);
  const gpuNow = walk(prev.gpu[HISTORY - 1], procs.reduce((a, p) => a + p.gpu, 0) * 0.8 + 4, 6);
  const browsing = wins.some((w) => w.appId === 'browser' || w.appId === 'store');
  const down = Math.max(0, walk(prev.netDown[HISTORY - 1], (browsing ? 6 : 0.6) + (Math.random() < 0.08 ? 18 : 0), 3, 0, 120));
  const up = Math.max(0, walk(prev.netUp[HISTORY - 1], 0.4 + (Math.random() < 0.05 ? 4 : 0), 0.8, 0, 50));
  const disk = Math.max(0, walk(prev.diskRead[HISTORY - 1], Math.random() < 0.1 ? 120 : 6, 10, 0, 900));

  const push = (arr: number[], v: number) => [...arr.slice(1), v];
  useMetrics.setState({
    cpu: push(prev.cpu, cpuNow),
    cores,
    mem: push(prev.mem, walk(prev.mem[HISTORY - 1], memUsed, 0.15, 4, TOTAL_MEM_GB)),
    gpu: push(prev.gpu, gpuNow),
    netDown: push(prev.netDown, down),
    netUp: push(prev.netUp, up),
    diskRead: push(prev.diskRead, disk),
    temp: walk(prev.temp, 42 + cpuNow * 0.35, 1, 30, 95),
    uptime: prev.uptime + 1,
    procs,
  });
}

/** One-off reading for callers that aren't subscribed (e.g. the assistant). */
export function snapshot() {
  if (useMetrics.getState().procs.length === 0) for (let i = 0; i < 20; i++) sample();
  else sample();
  return useMetrics.getState();
}

let consumers = 0;
let timer: ReturnType<typeof setInterval> | undefined;

/** Subscribe a component to live telemetry (starts/stops the sampler by ref-count). */
export function useMetricsFeed() {
  useEffect(() => {
    if (consumers++ === 0) {
      // Warm up so charts don't start flat.
      for (let i = 0; i < 40; i++) sample();
      timer = setInterval(sample, 1000);
    }
    return () => {
      if (--consumers === 0) clearInterval(timer);
    };
  }, []);
}
