import { useMemo, useState } from 'react';
import { ArrowDown, ArrowUp, Ban, ListChecks, Rocket, X } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { AppLayout, SearchField, SidebarItem, SidebarSection, Toggle, Toolbar } from '@/components/ui/AppKit';
import { Sparkline } from '@/components/ui/charts';
import { useMetrics, useMetricsFeed, type Proc } from '@/services/metrics';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';

type SortKey = 'name' | 'cpu' | 'mem' | 'gpu' | 'pid';

const STARTUP = [
  { name: 'Aurora AI runtime', impact: 'Medium', on: true },
  { name: 'Cloud sync', impact: 'Low', on: true },
  { name: 'Resonance helper', impact: 'Low', on: false },
  { name: 'Horizon updater', impact: 'High', on: true },
  { name: 'Calendar alerts', impact: 'Low', on: true },
];

export default function TasksApp({ windowId }: AppProps) {
  useMetricsFeed();
  const procs = useMetrics((s) => s.procs);
  const cpuHist = useMetrics((s) => s.cpu);
  const memHist = useMetrics((s) => s.mem);
  const [tab, setTab] = useState<'processes' | 'startup'>('processes');
  const [sort, setSort] = useState<{ key: SortKey; dir: 1 | -1 }>({ key: 'cpu', dir: -1 });
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<number | null>(null);
  const [startup, setStartup] = useState(STARTUP);

  const rows = useMemo(() => {
    const q = query.toLowerCase();
    return procs
      .filter((p) => !q || p.name.toLowerCase().includes(q))
      .sort((a, b) => {
        const av = a[sort.key];
        const bv = b[sort.key];
        return (typeof av === 'string' ? av.localeCompare(bv as string) : (av as number) - (bv as number)) * sort.dir;
      });
  }, [procs, sort, query]);

  const groups: { label: string; kind: Proc['kind'] }[] = [
    { label: 'Apps', kind: 'app' },
    { label: 'Background', kind: 'background' },
    { label: 'System', kind: 'system' },
  ];
  const sel = procs.find((p) => p.pid === selected);
  const totals = { cpu: procs.reduce((a, p) => a + p.cpu, 0) / 2.2, mem: procs.reduce((a, p) => a + p.mem, 0) };

  const endTask = () => {
    if (sel?.windowId) useWindowStore.getState().closeWindow(sel.windowId);
    setSelected(null);
  };

  const header = (key: SortKey, label: string, className = '') => (
    <th className={clsx('px-2 pb-2 font-medium', className)} aria-sort={sort.key === key ? (sort.dir === 1 ? 'ascending' : 'descending') : 'none'}>
      <button onClick={() => setSort({ key, dir: sort.key === key ? ((-sort.dir) as 1 | -1) : key === 'name' ? 1 : -1 })} className="inline-flex items-center gap-1 hover:text-fg">
        {label}
        {sort.key === key && (sort.dir === 1 ? <ArrowUp className="size-3" /> : <ArrowDown className="size-3" />)}
      </button>
    </th>
  );

  const sidebar = (
    <div className="pt-2">
      <SidebarSection>
        <SidebarItem layoutGroup={`tasks-${windowId}`} icon={ListChecks} label="Processes" trailing={procs.length} active={tab === 'processes'} onClick={() => setTab('processes')} />
        <SidebarItem layoutGroup={`tasks-${windowId}`} icon={Rocket} label="Startup apps" active={tab === 'startup'} onClick={() => setTab('startup')} />
      </SidebarSection>
      <div className="mt-4 space-y-3 px-2">
        <div>
          <p className="text-[11px] text-fg-subtle">CPU</p>
          <p className="flex items-center justify-between text-sm font-semibold tabular-nums">
            {Math.round(totals.cpu)}% <Sparkline values={cpuHist} max={100} color="var(--color-accent)" />
          </p>
        </div>
        <div>
          <p className="text-[11px] text-fg-subtle">Memory</p>
          <p className="flex items-center justify-between text-sm font-semibold tabular-nums">
            {(totals.mem / 1024).toFixed(1)} GB <Sparkline values={memHist} max={32} color="var(--color-accent)" />
          </p>
        </div>
      </div>
    </div>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={196}>
      {tab === 'processes' ? (
        <>
          <Toolbar>
            <SearchField value={query} onChange={setQuery} placeholder="Filter processes" label="Filter processes" className="w-56" />
            <span className="ml-auto hidden text-xs text-fg-subtle @[560px]:inline">{sel ? `${sel.name} · PID ${sel.pid}` : 'Select a process'}</span>
            <button
              onClick={endTask}
              disabled={!sel || sel.kind !== 'app'}
              title={sel && sel.kind !== 'app' ? 'System processes cannot be ended' : undefined}
              className="flex h-8 items-center gap-1.5 rounded-lg bg-[oklch(0.62_0.2_25)] px-3 text-xs font-semibold text-white disabled:opacity-35"
            >
              {sel && sel.kind !== 'app' ? <Ban className="size-3.5" /> : <X className="size-3.5" />} End task
            </button>
          </Toolbar>
          <div className="min-h-0 flex-1 overflow-y-auto px-3 pb-3">
            <table className="w-full table-fixed text-[13px]">
              <thead className="sticky top-0 z-10 bg-[color-mix(in_oklab,var(--glass-tint)_85%,transparent)] backdrop-blur">
                <tr className="text-left text-[11px] uppercase tracking-wider text-fg-subtle">
                  {header('name', 'Name')}
                  {header('cpu', 'CPU', 'w-20 text-right')}
                  {header('mem', 'Memory', 'w-24 text-right')}
                  {header('gpu', 'GPU', 'hidden w-16 text-right @[640px]:table-cell')}
                  <th className="hidden w-24 px-2 pb-2 font-medium @[720px]:table-cell">Energy</th>
                  {header('pid', 'PID', 'hidden w-16 text-right @[800px]:table-cell')}
                </tr>
              </thead>
              {groups.map((g) => {
                const list = rows.filter((r) => r.kind === g.kind);
                if (!list.length) return null;
                return (
                  <tbody key={g.kind}>
                    <tr>
                      <td colSpan={6} className="px-2 pb-1 pt-3 text-xs font-semibold text-fg-muted">
                        {g.label} ({list.length})
                      </td>
                    </tr>
                    {list.map((p) => (
                      <tr
                        key={p.pid}
                        tabIndex={0}
                        aria-selected={selected === p.pid}
                        onClick={() => setSelected(p.pid)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') setSelected(p.pid);
                          if (e.key === 'Delete' && p.kind === 'app') {
                            setSelected(p.pid);
                            if (p.windowId) useWindowStore.getState().closeWindow(p.windowId);
                          }
                        }}
                        className={clsx('cursor-default outline-none focus-visible:outline-2 focus-visible:outline-accent', selected === p.pid ? 'bg-[color-mix(in_oklab,var(--color-accent)_20%,transparent)]' : 'hover:bg-[color-mix(in_oklab,var(--text-1)_4%,transparent)]')}
                      >
                        <td className="rounded-l-lg px-2 py-1.5">
                          <span className="flex items-center gap-2">
                            {p.appId ? <AppIcon appId={p.appId} size={18} /> : <span className="grid size-[18px] place-items-center rounded-md bg-[color-mix(in_oklab,var(--text-1)_12%,transparent)] text-[9px] font-semibold text-fg-muted">{p.kind === 'system' ? 'S' : 'B'}</span>}
                            <span className="truncate">{p.name}</span>
                          </span>
                        </td>
                        <td className={clsx('px-2 text-right tabular-nums', p.cpu > 10 ? 'font-semibold' : 'text-fg-muted')} style={{ background: `color-mix(in oklab, var(--color-accent) ${Math.min(30, p.cpu * 2)}%, transparent)` }}>
                          {p.cpu.toFixed(1)}%
                        </td>
                        <td className="px-2 text-right tabular-nums text-fg-muted">{p.mem >= 1024 ? `${(p.mem / 1024).toFixed(2)} GB` : `${Math.round(p.mem)} MB`}</td>
                        <td className="hidden px-2 text-right tabular-nums text-fg-muted @[640px]:table-cell">{p.gpu.toFixed(0)}%</td>
                        <td className="hidden px-2 @[720px]:table-cell">
                          <span className={clsx('rounded-full px-2 py-0.5 text-[10px] font-semibold', p.energy === 'High' ? 'bg-[oklch(0.75_0.16_70/0.25)] text-[oklch(0.55_0.14_60)]' : p.energy === 'Moderate' ? 'bg-accent-soft text-accent' : 'text-fg-subtle')}>{p.energy}</span>
                        </td>
                        <td className="hidden rounded-r-lg px-2 text-right tabular-nums text-fg-subtle @[800px]:table-cell">{p.pid}</td>
                      </tr>
                    ))}
                  </tbody>
                );
              })}
            </table>
          </div>
        </>
      ) : (
        <div className="min-h-0 flex-1 overflow-y-auto p-5">
          <p className="mb-3 text-xs text-fg-subtle">These start automatically when you sign in. Turning off high-impact items speeds up login.</p>
          <div className="glass-well divide-y divide-[var(--glass-border)] rounded-2xl">
            {startup.map((s, i) => (
              <div key={s.name} className="flex items-center gap-3 px-4 py-3">
                <span className="min-w-0 flex-1 text-[13px] font-medium">{s.name}</span>
                <span className={clsx('w-16 text-xs', s.impact === 'High' ? 'font-semibold text-[oklch(0.6_0.16_60)]' : 'text-fg-subtle')}>{s.impact} impact</span>
                <Toggle label={`Start ${s.name} at login`} checked={s.on} onChange={(v) => setStartup(startup.map((x, j) => (j === i ? { ...x, on: v } : x)))} />
              </div>
            ))}
          </div>
        </div>
      )}
    </AppLayout>
  );
}
