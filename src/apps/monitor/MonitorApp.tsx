import { Activity, Cpu, Gauge, MemoryStick, Network, Thermometer } from 'lucide-react';
import clsx from 'clsx';
import { AreaChart, BarStrip } from '@/components/ui/charts';
import { CORES, TOTAL_MEM_GB, useMetrics, useMetricsFeed } from '@/services/metrics';
import type { AppProps } from '@/system/types';

const pct = (v: number) => `${Math.round(v)}%`;
const gb = (v: number) => `${v.toFixed(1)} GB`;
const mbs = (v: number) => (v >= 10 ? `${Math.round(v)} MB/s` : `${v.toFixed(1)} MB/s`);

/** Live performance dashboard: headline numbers first, then trends, then detail. */
export default function MonitorApp(_: AppProps) {
  useMetricsFeed();
  const m = useMetrics();
  const last = (a: number[]) => a[a.length - 1];
  const cpu = last(m.cpu);
  const mem = last(m.mem);
  const gpu = last(m.gpu);
  const hot = m.temp > 80;
  const top = [...m.procs].sort((a, b) => b.cpu - a.cpu).slice(0, 5);
  const uptime = `${Math.floor(m.uptime / 3600)}h ${Math.floor((m.uptime % 3600) / 60)}m`;

  return (
    <div className="@container h-full overflow-y-auto p-4" style={{ background: 'var(--app-surface)' }}>
      <div className="grid grid-cols-2 gap-2.5 @[640px]:grid-cols-4">
        <Stat icon={Cpu} label="CPU" value={pct(cpu)} detail={`${CORES} cores · up ${uptime}`} level={cpu} />
        <Stat icon={MemoryStick} label="Memory" value={gb(mem)} detail={`of ${TOTAL_MEM_GB} GB · ${pct((mem / TOTAL_MEM_GB) * 100)} used`} level={(mem / TOTAL_MEM_GB) * 100} />
        <Stat icon={Gauge} label="GPU" value={pct(gpu)} detail="16-core integrated" level={gpu} />
        <Stat icon={Thermometer} label="Temperature" value={`${Math.round(m.temp)}°C`} detail={hot ? 'Running hot' : 'Normal'} level={(m.temp - 30) * 1.6} status={hot ? 'warn' : 'ok'} />
      </div>

      <div className="mt-3 grid gap-2.5 @[720px]:grid-cols-2">
        <Panel title="CPU load" icon={Activity} value={pct(cpu)}>
          <AreaChart label="CPU load" series={[{ name: 'CPU', values: m.cpu, color: 'var(--color-accent)' }]} max={100} format={pct} />
        </Panel>
        <Panel title="Memory" icon={MemoryStick} value={gb(mem)}>
          <AreaChart label="Memory used" series={[{ name: 'Used', values: m.mem, color: 'var(--color-accent)' }]} max={TOTAL_MEM_GB} format={(v) => `${Math.round(v)} GB`} />
        </Panel>
        <Panel title="Network" icon={Network} value={`↓ ${mbs(last(m.netDown))}`}>
          <AreaChart
            label="Network throughput"
            series={[
              { name: 'Download', values: m.netDown, color: 'var(--series-1)' },
              { name: 'Upload', values: m.netUp, color: 'var(--series-2)' },
            ]}
            max={Math.max(10, Math.ceil(Math.max(...m.netDown, ...m.netUp) / 10) * 10)}
            format={(v) => `${Math.round(v)}`}
          />
          <Legend items={[{ name: 'Download', color: 'var(--series-1)', value: mbs(last(m.netDown)) }, { name: 'Upload', color: 'var(--series-2)', value: mbs(last(m.netUp)) }]} />
        </Panel>
        <Panel title="Per-core load" icon={Cpu} value={`${CORES} cores`}>
          <BarStrip label="Per-core load" values={m.cores} max={100} color="var(--color-accent)" format={pct} names={(i) => `Core ${i + 1}`} />
          <div className="mt-1.5 flex justify-between text-[10px] text-fg-subtle">
            <span>Core 1</span>
            <span>Core {CORES}</span>
          </div>
        </Panel>
      </div>

      <section className="glass-well mt-3 rounded-2xl p-4" aria-labelledby="top-procs">
        <h2 id="top-procs" className="mb-2 text-xs font-semibold uppercase tracking-[0.1em] text-fg-subtle">
          Top processes
        </h2>
        <table className="w-full text-[13px]">
          <thead className="sr-only">
            <tr>
              <th>Process</th>
              <th>CPU</th>
              <th>Memory</th>
            </tr>
          </thead>
          <tbody>
            {top.map((p) => (
              <tr key={p.pid}>
                <td className="truncate py-1 pr-3">{p.name}</td>
                <td className="w-1/3 py-1">
                  <span className="flex items-center gap-2">
                    <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
                      <span className="block h-full rounded-full bg-accent transition-[width] duration-700" style={{ width: `${Math.min(100, p.cpu * 3)}%` }} />
                    </span>
                    <span className="w-12 text-right tabular-nums text-fg-muted">{p.cpu.toFixed(1)}%</span>
                  </span>
                </td>
                <td className="w-20 py-1 text-right tabular-nums text-fg-muted">{p.mem >= 1024 ? `${(p.mem / 1024).toFixed(1)} GB` : `${Math.round(p.mem)} MB`}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}

function Stat({ icon: Icon, label, value, detail, level, status = 'ok' }: { icon: typeof Cpu; label: string; value: string; detail: string; level: number; status?: 'ok' | 'warn' }) {
  return (
    <div className="glass-well rounded-2xl p-3">
      <p className="flex items-center gap-1.5 text-[11px] font-medium uppercase tracking-wider text-fg-subtle">
        <Icon className="size-3.5" /> {label}
      </p>
      <p className="mt-1 text-2xl font-semibold tabular-nums tracking-tight">{value}</p>
      <div className="mt-2 h-1 overflow-hidden rounded-full bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
        <div className={clsx('h-full rounded-full transition-[width] duration-700', status === 'warn' ? 'bg-[oklch(0.75_0.16_70)]' : 'bg-accent')} style={{ width: `${Math.min(100, Math.max(2, level))}%` }} />
      </div>
      <p className={clsx('mt-1.5 truncate text-[11px]', status === 'warn' ? 'font-medium text-[oklch(0.62_0.16_60)]' : 'text-fg-subtle')}>{status === 'warn' ? `⚠ ${detail}` : detail}</p>
    </div>
  );
}

function Panel({ title, icon: Icon, value, children }: { title: string; icon: typeof Cpu; value: string; children: React.ReactNode }) {
  return (
    <section className="glass-well rounded-2xl p-4 pt-3" aria-label={title}>
      <header className="mb-3 flex items-center gap-1.5">
        <Icon className="size-3.5 text-fg-subtle" />
        <h2 className="text-[13px] font-semibold">{title}</h2>
        <span className="ml-auto text-[13px] font-medium tabular-nums text-fg-muted">{value}</span>
      </header>
      {children}
    </section>
  );
}

function Legend({ items }: { items: { name: string; color: string; value: string }[] }) {
  return (
    <ul className="mt-2 flex gap-4 text-[11px]">
      {items.map((i) => (
        <li key={i.name} className="flex items-center gap-1.5">
          <span className="h-0.5 w-3 rounded-full" style={{ background: i.color }} />
          <span className="text-fg-muted">{i.name}</span>
          <span className="font-medium tabular-nums">{i.value}</span>
        </li>
      ))}
    </ul>
  );
}
