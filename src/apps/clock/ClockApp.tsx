import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Flag, Globe2, Hourglass, Pause, Play, RotateCcw, Target, Timer } from 'lucide-react';
import clsx from 'clsx';
import { Segmented } from '@/components/ui/AppKit';
import { useClock } from '@/hooks/useClock';
import { springs } from '@/system/motion';
import { useNotificationStore } from '@/system/store/notificationStore';
import type { AppProps } from '@/system/types';

type Tab = 'world' | 'timer' | 'stopwatch' | 'focus';

const CITIES = [
  { name: 'San Francisco', tz: 'America/Los_Angeles' },
  { name: 'New York', tz: 'America/New_York' },
  { name: 'London', tz: 'Europe/London' },
  { name: 'Reykjavík', tz: 'Atlantic/Reykjavik' },
  { name: 'Tokyo', tz: 'Asia/Tokyo' },
  { name: 'Sydney', tz: 'Australia/Sydney' },
];

/** Wall-clock parts for a time zone. */
function partsIn(date: Date, tz?: string) {
  const f = new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: 'numeric', minute: 'numeric', second: 'numeric', hour12: false, weekday: 'short' });
  const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]));
  return { h: Number(p.hour) % 24, m: Number(p.minute), s: Number(p.second), weekday: p.weekday };
}

export default function ClockApp(_: AppProps) {
  const [tab, setTab] = useState<Tab>('world');
  return (
    <div className="@container flex h-full flex-col" style={{ background: 'color-mix(in oklab, var(--glass-tint) 35%, transparent)' }}>
      <div className="flex justify-center border-b hairline py-2.5">
        <Segmented
          label="Clock mode"
          value={tab}
          onChange={setTab}
          options={[
            { value: 'world', label: 'World', icon: Globe2 },
            { value: 'timer', label: 'Timer', icon: Hourglass },
            { value: 'stopwatch', label: 'Stopwatch', icon: Timer },
            { value: 'focus', label: 'Focus', icon: Target },
          ]}
        />
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto">
        {/* Keep every tool mounted so a running timer survives switching tabs. */}
        <div hidden={tab !== 'world'} className="h-full">
          <World />
        </div>
        <div hidden={tab !== 'timer'} className="h-full">
          <Countdown kind="timer" />
        </div>
        <div hidden={tab !== 'stopwatch'} className="h-full">
          <Stopwatch />
        </div>
        <div hidden={tab !== 'focus'} className="h-full">
          <Countdown kind="focus" />
        </div>
      </div>
    </div>
  );
}

function AnalogClock({ h, m, s, size, night }: { h: number; m: number; s: number; size: number; night?: boolean }) {
  const hand = (deg: number, len: number, w: number, color: string) => (
    <line x1="50" y1="50" x2={50 + len * Math.sin((deg * Math.PI) / 180)} y2={50 - len * Math.cos((deg * Math.PI) / 180)} stroke={color} strokeWidth={w} strokeLinecap="round" />
  );
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} aria-hidden>
      <defs>
        <radialGradient id={`face-${size}-${night ? 'n' : 'd'}`} cx="35%" cy="25%">
          <stop offset="0" stopColor={night ? 'oklch(0.36 0.05 270)' : 'oklch(1 0 0)'} />
          <stop offset="1" stopColor={night ? 'oklch(0.2 0.04 270)' : 'oklch(0.9 0.02 270)'} />
        </radialGradient>
      </defs>
      <circle cx="50" cy="50" r="48" fill={`url(#face-${size}-${night ? 'n' : 'd'})`} stroke="oklch(1 0 0 / 0.35)" />
      {Array.from({ length: 12 }, (_, i) => {
        const a = (i * 30 * Math.PI) / 180;
        const major = i % 3 === 0;
        return <line key={i} x1={50 + 40 * Math.sin(a)} y1={50 - 40 * Math.cos(a)} x2={50 + (major ? 34 : 37) * Math.sin(a)} y2={50 - (major ? 34 : 37) * Math.cos(a)} stroke={night ? 'oklch(0.8 0 0)' : 'oklch(0.3 0 0)'} strokeWidth={major ? 2.2 : 1.2} strokeLinecap="round" />;
      })}
      {hand((h % 12) * 30 + m * 0.5, 22, 3.6, night ? 'oklch(0.95 0 0)' : 'oklch(0.2 0 0)')}
      {hand(m * 6 + s * 0.1, 32, 2.4, night ? 'oklch(0.95 0 0)' : 'oklch(0.2 0 0)')}
      {size > 60 && hand(s * 6, 36, 1, 'var(--color-accent)')}
      <circle cx="50" cy="50" r="2.4" fill="var(--color-accent)" />
    </svg>
  );
}

function World() {
  const now = useClock('second');
  const local = partsIn(now);
  const localOffset = -now.getTimezoneOffset();
  return (
    <div className="flex flex-col items-center gap-6 p-6 @[620px]:flex-row @[620px]:items-start">
      <div className="flex shrink-0 flex-col items-center">
        <AnalogClock {...local} size={200} />
        <p className="mt-3 text-3xl font-semibold tabular-nums tracking-tight">{now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}</p>
        <p className="text-sm text-fg-muted">{now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
      </div>
      <ul className="grid w-full flex-1 gap-2 @[420px]:grid-cols-2">
        {CITIES.map((c) => {
          const p = partsIn(now, c.tz);
          const night = p.h < 7 || p.h >= 19;
          // Offset relative to local, in hours.
          const cityMinutes = p.h * 60 + p.m;
          const localMinutes = local.h * 60 + local.m;
          let diff = cityMinutes - localMinutes;
          if (diff > 720) diff -= 1440;
          if (diff < -720) diff += 1440;
          const label = diff === 0 ? 'Same time' : `${diff > 0 ? '+' : '−'}${Math.abs(diff / 60)}h`;
          return (
            <li key={c.tz} className="glass-well flex items-center gap-3 rounded-2xl p-3">
              <AnalogClock {...p} size={48} night={night} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{c.name}</p>
                <p className="text-[11px] text-fg-subtle">
                  {p.weekday} · {label}
                </p>
              </div>
              <span className="text-lg font-medium tabular-nums">
                {String(p.h).padStart(2, '0')}:{String(p.m).padStart(2, '0')}
              </span>
            </li>
          );
        })}
      </ul>
      <span className="sr-only">Local offset UTC{localOffset >= 0 ? '+' : '−'}{Math.abs(localOffset / 60)}</span>
    </div>
  );
}

function useTicker(running: boolean, onTick: () => void) {
  const cb = useRef(onTick);
  cb.current = onTick;
  useEffect(() => {
    if (!running) return;
    const t = setInterval(() => cb.current(), 100);
    return () => clearInterval(t);
  }, [running]);
}

const fmt = (ms: number, cs = false) => {
  const t = Math.max(0, ms);
  const m = Math.floor(t / 60000);
  const s = Math.floor((t % 60000) / 1000);
  const c = Math.floor((t % 1000) / 10);
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}${cs ? `.${String(c).padStart(2, '0')}` : ''}`;
};

/** Countdown used for both the timer and Pomodoro-style focus sessions. */
function Countdown({ kind }: { kind: 'timer' | 'focus' }) {
  const presets = kind === 'timer' ? [1, 5, 10, 15, 30] : [25, 50];
  const [total, setTotal] = useState(presets[kind === 'timer' ? 1 : 0] * 60_000);
  const [left, setLeft] = useState(total);
  const [running, setRunning] = useState(false);
  const [phase, setPhase] = useState<'work' | 'break'>('work');
  const [sessions, setSessions] = useState(0);
  const endAt = useRef(0);
  const post = useNotificationStore((s) => s.post);

  useTicker(running, () => {
    const remaining = endAt.current - Date.now();
    if (remaining > 0) return setLeft(remaining);
    setRunning(false);
    setLeft(0);
    if (kind === 'timer') {
      post({ appId: 'clock', title: 'Timer done', body: `Your ${Math.round(total / 60000)}-minute timer has finished.`, priority: 'high' });
    } else if (phase === 'work') {
      setSessions((n) => n + 1);
      setPhase('break');
      setTotal(5 * 60_000);
      setLeft(5 * 60_000);
      useNotificationStore.getState().setDnd(false);
      post({ appId: 'clock', title: 'Focus session complete', body: 'Nice work. Take a 5-minute break.', priority: 'high' });
    } else {
      setPhase('work');
      setTotal(25 * 60_000);
      setLeft(25 * 60_000);
      post({ appId: 'clock', title: 'Break over', body: 'Ready for another focus session?' });
    }
  });

  const start = () => {
    endAt.current = Date.now() + left;
    setRunning(true);
    if (kind === 'focus' && phase === 'work') useNotificationStore.getState().setDnd(true);
  };
  const pause = () => setRunning(false);
  const reset = () => {
    setRunning(false);
    setLeft(total);
    if (kind === 'focus') useNotificationStore.getState().setDnd(false);
  };
  const choose = (min: number) => {
    setRunning(false);
    setTotal(min * 60_000);
    setLeft(min * 60_000);
  };

  const R = 88;
  const C = 2 * Math.PI * R;
  const progress = total ? left / total : 0;

  return (
    <div className="flex h-full flex-col items-center justify-center gap-5 p-6">
      {kind === 'focus' && (
        <p className="text-xs font-medium uppercase tracking-[0.14em] text-accent">
          {phase === 'work' ? 'Focus' : 'Break'} · {sessions} {sessions === 1 ? 'session' : 'sessions'} today
        </p>
      )}
      <div className="relative">
        <svg viewBox="0 0 200 200" width="220" height="220" aria-hidden className="-rotate-90">
          <circle cx="100" cy="100" r={R} fill="none" stroke="color-mix(in oklab, var(--text-1) 10%, transparent)" strokeWidth="8" />
          <motion.circle
            cx="100"
            cy="100"
            r={R}
            fill="none"
            stroke={phase === 'break' ? 'oklch(0.7 0.14 160)' : 'var(--color-accent)'}
            strokeWidth="8"
            strokeLinecap="round"
            strokeDasharray={C}
            animate={{ strokeDashoffset: C * (1 - progress) }}
            transition={{ duration: 0.1 }}
            style={{ filter: 'drop-shadow(0 0 6px var(--color-accent))' }}
          />
        </svg>
        <div className="absolute inset-0 grid place-items-center">
          <span role="timer" aria-live="off" className="text-5xl font-semibold tabular-nums tracking-tight">
            {fmt(left)}
          </span>
        </div>
      </div>
      <div className="flex flex-wrap justify-center gap-1.5">
        {presets.map((m) => (
          <button key={m} onClick={() => choose(m)} className={clsx('rounded-full px-3 py-1 text-xs font-medium', total === m * 60_000 ? 'bg-accent text-white' : 'glass-well text-fg-muted')}>
            {m} min
          </button>
        ))}
      </div>
      <div className="flex gap-3">
        <RoundButton label="Reset" onClick={reset}>
          <RotateCcw className="size-5" />
        </RoundButton>
        <RoundButton label={running ? 'Pause' : 'Start'} onClick={running ? pause : start} primary>
          {running ? <Pause className="size-6 fill-current" /> : <Play className="size-6 translate-x-0.5 fill-current" />}
        </RoundButton>
      </div>
      {kind === 'focus' && <p className="max-w-xs text-center text-xs text-fg-subtle">Starting a focus session turns on Do Not Disturb until the break.</p>}
    </div>
  );
}

function Stopwatch() {
  const [elapsed, setElapsed] = useState(0);
  const [running, setRunning] = useState(false);
  const [laps, setLaps] = useState<number[]>([]);
  const base = useRef(0);
  useTicker(running, () => setElapsed(Date.now() - base.current));
  const lapTimes = laps.map((t, i) => t - (laps[i - 1] ?? 0));
  const best = Math.min(...lapTimes);
  const worst = Math.max(...lapTimes);
  return (
    <div className="flex h-full flex-col items-center gap-5 p-6 pt-10">
      <span role="timer" className="text-6xl font-semibold tabular-nums tracking-tight">
        {fmt(elapsed, true)}
      </span>
      <div className="flex gap-3">
        <RoundButton label={running ? 'Lap' : 'Reset'} onClick={() => (running ? setLaps([...laps, elapsed]) : (setElapsed(0), setLaps([])))}>
          {running ? <Flag className="size-5" /> : <RotateCcw className="size-5" />}
        </RoundButton>
        <RoundButton
          label={running ? 'Stop' : 'Start'}
          primary
          onClick={() => {
            if (running) setRunning(false);
            else {
              base.current = Date.now() - elapsed;
              setRunning(true);
            }
          }}
        >
          {running ? <Pause className="size-6 fill-current" /> : <Play className="size-6 translate-x-0.5 fill-current" />}
        </RoundButton>
      </div>
      <ol className="w-full max-w-sm divide-y divide-[var(--glass-border)] text-sm">
        {lapTimes
          .map((t, i) => ({ t, i }))
          .reverse()
          .map(({ t, i }) => (
            <li key={i} className={clsx('flex justify-between py-2 tabular-nums', laps.length > 2 && t === best && 'text-[oklch(0.65_0.16_155)]', laps.length > 2 && t === worst && 'text-[oklch(0.65_0.2_25)]')}>
              <span>Lap {i + 1}</span>
              <span>{fmt(t, true)}</span>
            </li>
          ))}
      </ol>
    </div>
  );
}

function RoundButton({ label, onClick, primary, children }: { label: string; onClick: () => void; primary?: boolean; children: React.ReactNode }) {
  return (
    <motion.button
      aria-label={label}
      title={label}
      onClick={onClick}
      whileTap={{ scale: 0.9 }}
      whileHover={{ scale: 1.05 }}
      transition={springs.elastic}
      className={clsx('grid size-16 place-items-center rounded-full', primary ? 'bg-accent text-white shadow-[0_8px_24px_-8px_var(--color-accent)]' : 'glass-well text-fg')}
    >
      {children}
    </motion.button>
  );
}
