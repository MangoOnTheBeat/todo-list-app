import { useEffect, useRef, useState } from 'react';

/**
 * Small SVG charts for live telemetry. One y-axis, thin 2px lines over a soft area,
 * recessive grid, emphasised latest point, and a hover crosshair with a tooltip.
 * Text always uses text tokens; colour only marks identity.
 */

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [w, setW] = useState(300);
  useEffect(() => {
    if (!ref.current) return;
    const ro = new ResizeObserver(([e]) => setW(Math.max(120, e.contentRect.width)));
    ro.observe(ref.current);
    return () => ro.disconnect();
  }, []);
  return [ref, w] as const;
}

export interface Series {
  name: string;
  values: number[];
  color: string;
}

interface AreaProps {
  series: Series[];
  max: number;
  height?: number;
  format: (v: number) => string;
  /** Seconds between samples, for the x-axis caption. */
  step?: number;
  label: string;
}

export function AreaChart({ series, max, height = 120, format, step = 1, label }: AreaProps) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const padL = 36;
  const padB = 16;
  const w = width - padL;
  const h = height - padB;
  const n = series[0].values.length;
  const x = (i: number) => padL + (i / (n - 1)) * w;
  const y = (v: number) => 4 + (1 - Math.min(v, max) / max) * (h - 4);
  const ticks = [0, max / 2, max];

  const path = (vals: number[]) => vals.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join('');
  const last = series.map((s) => s.values[n - 1]);
  const summary = series.map((s, i) => `${s.name} ${format(last[i])}, peak ${format(Math.max(...s.values))}`).join('; ');

  return (
    <div ref={ref} className="relative" onMouseLeave={() => setHover(null)}>
      <svg
        role="img"
        aria-label={`${label}: ${summary} over the last ${n * step} seconds`}
        width={width}
        height={height}
        className="block overflow-visible"
        onMouseMove={(e) => {
          const r = (e.currentTarget as SVGSVGElement).getBoundingClientRect();
          const i = Math.round(((e.clientX - r.left - padL) / w) * (n - 1));
          setHover(i >= 0 && i < n ? i : null);
        }}
      >
        {ticks.map((t) => (
          <g key={t}>
            <line x1={padL} x2={width} y1={y(t)} y2={y(t)} stroke="var(--glass-border)" strokeDasharray={t === 0 ? undefined : '2 4'} />
            <text x={padL - 6} y={y(t) + 3} textAnchor="end" fontSize="9" fill="var(--text-3)" className="tabular-nums">
              {format(t)}
            </text>
          </g>
        ))}
        <text x={padL} y={height - 3} fontSize="9" fill="var(--text-3)">
          {n * step}s ago
        </text>
        <text x={width} y={height - 3} fontSize="9" fill="var(--text-3)" textAnchor="end">
          now
        </text>
        {series.map((s) => (
          <g key={s.name}>
            {series.length === 1 && <path d={`${path(s.values)}L${x(n - 1)},${y(0)}L${x(0)},${y(0)}Z`} fill={s.color} opacity="0.16" />}
            <path d={path(s.values)} fill="none" stroke={s.color} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
            <circle cx={x(n - 1)} cy={y(s.values[n - 1])} r="4" fill={s.color} stroke="var(--glass-tint)" strokeWidth="2" />
          </g>
        ))}
        {hover !== null && (
          <g pointerEvents="none">
            <line x1={x(hover)} x2={x(hover)} y1={4} y2={h} stroke="var(--text-3)" strokeWidth="1" />
            {series.map((s) => (
              <circle key={s.name} cx={x(hover)} cy={y(s.values[hover])} r="4" fill={s.color} stroke="var(--glass-tint)" strokeWidth="2" />
            ))}
          </g>
        )}
      </svg>
      {hover !== null && (
        <div
          className="glass acrylic pointer-events-none absolute top-0 z-10 rounded-lg px-2 py-1.5 text-[11px] shadow-lg"
          style={{ left: Math.min(Math.max(0, x(hover) - 60), width - 130), transform: 'translateY(-105%)' }}
        >
          <p className="text-fg-subtle">{(n - 1 - hover) * step}s ago</p>
          {series.map((s) => (
            <p key={s.name} className="flex items-center gap-1.5 font-medium tabular-nums">
              <span className="size-2 rounded-full" style={{ background: s.color }} />
              <span className="text-fg-muted">{s.name}</span> {format(s.values[hover])}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}

/** Vertical bars from a shared baseline (e.g. per-core load). */
export function BarStrip({ values, max, color, format, label, names }: { values: number[]; max: number; color: string; format: (v: number) => string; label: string; names: (i: number) => string }) {
  const [hover, setHover] = useState<number | null>(null);
  return (
    <div role="img" aria-label={`${label}: ${values.map((v, i) => `${names(i)} ${format(v)}`).join(', ')}`} className="relative flex h-24 items-end gap-[2px]" onMouseLeave={() => setHover(null)}>
      {values.map((v, i) => (
        <div key={i} className="flex h-full flex-1 flex-col justify-end" onMouseEnter={() => setHover(i)}>
          <div className="rounded-t-[4px] transition-[height] duration-700 ease-out" style={{ height: `${Math.max(2, (v / max) * 100)}%`, background: color, opacity: hover === null || hover === i ? 1 : 0.45 }} />
        </div>
      ))}
      {hover !== null && (
        <div className="glass acrylic pointer-events-none absolute -top-2 z-10 -translate-y-full rounded-lg px-2 py-1 text-[11px] font-medium tabular-nums" style={{ left: `${(hover / values.length) * 100}%` }}>
          {names(hover)} · {format(values[hover])}
        </div>
      )}
    </div>
  );
}

/** Tiny inline trend line for table rows and tiles. */
export function Sparkline({ values, max, color, width = 80, height = 22 }: { values: number[]; max: number; color: string; width?: number; height?: number }) {
  const n = values.length;
  const d = values.map((v, i) => `${i ? 'L' : 'M'}${((i / (n - 1)) * width).toFixed(1)},${(height - 2 - (Math.min(v, max) / max) * (height - 4)).toFixed(1)}`).join('');
  return (
    <svg aria-hidden width={width} height={height} className="overflow-visible">
      <path d={d} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" />
    </svg>
  );
}
