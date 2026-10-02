import { useEffect, useMemo, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { ArrowLeft, Code2, Compass, Download, Gamepad2, LayoutGrid, Palette, RefreshCw, Star, Wrench } from 'lucide-react';
import clsx from 'clsx';
import { create } from 'zustand';
import { AppIcon } from '@/components/ui/AppIcon';
import { AppLayout, SearchField, SidebarItem, SidebarSection, Toolbar } from '@/components/ui/AppKit';
import { springs } from '@/system/motion';
import { useNotificationStore } from '@/system/store/notificationStore';
import type { AppId, AppProps } from '@/system/types';
import { CATALOG, CATEGORIES, FEATURED, type Category, type StoreApp } from './catalog';

type View = { type: 'discover' } | { type: 'category'; id: Category } | { type: 'updates' } | { type: 'app'; id: string };

/** Install state is shared across Atrium windows. */
const useInstalls = create<{ state: Record<string, 'installing' | 'installed'>; updated: Record<string, boolean>; set: (id: string, v: 'installing' | 'installed') => void; markUpdated: (id: string) => void }>((set) => ({
  state: { moss: 'installed' },
  updated: {},
  set: (id, v) => set((s) => ({ state: { ...s.state, [id]: v } })),
  markUpdated: (id) => set((s) => ({ updated: { ...s.updated, [id]: true } })),
}));

const UPDATES: { appId: AppId; version: string; notes: string }[] = [
  { appId: 'browser', version: '1.1', notes: 'Tab groups remember their colour. Reader view picks up your accent.' },
  { appId: 'music', version: '2.3', notes: 'Smoother visualiser and gapless playback.' },
  { appId: 'notes', version: '1.4', notes: 'Summaries now keep bullet structure.' },
];

const catIcon: Record<Category, typeof Palette> = { productivity: LayoutGrid, creativity: Palette, developer: Code2, games: Gamepad2, utilities: Wrench };

export default function StoreApp({ windowId }: AppProps) {
  const [view, setView] = useState<View>({ type: 'discover' });
  const [query, setQuery] = useState('');
  const pendingUpdates = UPDATES.filter((u) => !useInstalls.getState().updated[u.appId]).length;
  const updated = useInstalls((s) => s.updated);

  const results = useMemo(() => {
    const q = query.toLowerCase().trim();
    return q ? CATALOG.filter((a) => (a.name + a.tagline + a.category + a.developer).toLowerCase().includes(q)) : [];
  }, [query]);

  const sidebar = (
    <div className="pt-2">
      <SidebarSection>
        <SidebarItem layoutGroup={`store-${windowId}`} icon={Compass} label="Discover" active={view.type === 'discover' && !query} onClick={() => (setQuery(''), setView({ type: 'discover' }))} />
        <SidebarItem layoutGroup={`store-${windowId}`} icon={RefreshCw} label="Updates" trailing={UPDATES.filter((u) => !updated[u.appId]).length || undefined} active={view.type === 'updates'} onClick={() => (setQuery(''), setView({ type: 'updates' }))} />
      </SidebarSection>
      <SidebarSection title="Categories">
        {CATEGORIES.map((c) => (
          <SidebarItem key={c.id} layoutGroup={`store-${windowId}`} icon={catIcon[c.id]} label={c.label} active={view.type === 'category' && view.id === c.id} onClick={() => (setQuery(''), setView({ type: 'category', id: c.id }))} />
        ))}
      </SidebarSection>
    </div>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={200}>
      <Toolbar>
        {view.type === 'app' && (
          <button onClick={() => setView({ type: 'discover' })} className="flex h-8 items-center gap-1 rounded-lg px-2 text-xs font-medium text-accent">
            <ArrowLeft className="size-3.5" /> Back
          </button>
        )}
        <SearchField value={query} onChange={setQuery} placeholder="Search apps and games" label="Search Atrium" className="ml-auto w-64" />
      </Toolbar>
      <div className="min-h-0 flex-1 overflow-y-auto p-5">
        <AnimatePresence mode="wait">
          <motion.div key={query ? 'search' : JSON.stringify(view)} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={springs.panel}>
            {query ? (
              <>
                <h1 className="mb-4 text-xl font-semibold">Results for “{query}”</h1>
                {results.length ? <Grid apps={results} open={(id) => (setQuery(''), setView({ type: 'app', id }))} /> : <p className="text-sm text-fg-subtle">No apps match that search.</p>}
              </>
            ) : view.type === 'discover' ? (
              <Discover open={(id) => setView({ type: 'app', id })} />
            ) : view.type === 'category' ? (
              <>
                <h1 className="mb-4 text-xl font-semibold">{CATEGORIES.find((c) => c.id === view.id)?.label}</h1>
                <Grid apps={CATALOG.filter((a) => a.category === view.id)} open={(id) => setView({ type: 'app', id })} />
              </>
            ) : view.type === 'updates' ? (
              <Updates />
            ) : (
              <Detail app={CATALOG.find((a) => a.id === view.id)!} />
            )}
          </motion.div>
        </AnimatePresence>
      </div>
      <span className="sr-only">{pendingUpdates} updates available</span>
    </AppLayout>
  );
}

function Tile({ app, size = 56 }: { app: StoreApp; size?: number }) {
  return (
    <span
      aria-hidden
      className="grid shrink-0 place-items-center font-semibold text-white"
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.26,
        fontSize: size * 0.42,
        background: `linear-gradient(145deg, oklch(0.78 0.13 ${app.hue}), oklch(0.52 0.18 ${app.hue + 25}))`,
        boxShadow: `inset 0 1px 0 oklch(1 0 0 / 0.4), 0 8px 20px -8px oklch(0.52 0.18 ${app.hue})`,
      }}
    >
      {app.glyph}
    </span>
  );
}

function GetButton({ app }: { app: StoreApp }) {
  const status = useInstalls((s) => s.state[app.id]);
  const set = useInstalls((s) => s.set);
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    if (status !== 'installing') return;
    const t0 = Date.now();
    const id = setInterval(() => {
      const p = Math.min(1, (Date.now() - t0) / 2200);
      setProgress(p);
      if (p >= 1) {
        clearInterval(id);
        set(app.id, 'installed');
        useNotificationStore.getState().post({ appId: 'store', title: `${app.name} installed`, body: 'Find it in Atrium under Installed.', priority: 'low' });
      }
    }, 50);
    return () => clearInterval(id);
  }, [status, app, set]);

  if (status === 'installing') {
    const C = 2 * Math.PI * 11;
    return (
      <span role="progressbar" aria-label={`Installing ${app.name}`} aria-valuenow={Math.round(progress * 100)} className="grid size-8 place-items-center">
        <svg viewBox="0 0 28 28" className="size-7 -rotate-90">
          <circle cx="14" cy="14" r="11" fill="none" stroke="color-mix(in oklab, var(--text-1) 15%, transparent)" strokeWidth="3" />
          <circle cx="14" cy="14" r="11" fill="none" stroke="var(--color-accent)" strokeWidth="3" strokeDasharray={C} strokeDashoffset={C * (1 - progress)} strokeLinecap="round" />
        </svg>
      </span>
    );
  }
  return (
    <motion.button
      whileTap={{ scale: 0.92 }}
      onClick={(e) => {
        e.stopPropagation();
        if (!status) set(app.id, 'installing');
      }}
      disabled={status === 'installed'}
      className={clsx('h-7 min-w-16 rounded-full px-3 text-xs font-semibold', status === 'installed' ? 'text-fg-subtle' : 'bg-accent-soft text-accent hover:bg-accent-fill hover:text-white')}
    >
      {status === 'installed' ? 'Installed' : app.price === 'Free' ? 'Get' : app.price}
    </motion.button>
  );
}

function Stars({ rating }: { rating: number }) {
  return (
    <span className="flex items-center gap-0.5" aria-label={`${rating} out of 5 stars`}>
      {Array.from({ length: 5 }, (_, i) => (
        <Star key={i} className={clsx('size-3', i < Math.round(rating) ? 'fill-current text-[oklch(0.78_0.15_80)]' : 'text-fg-subtle')} />
      ))}
    </span>
  );
}

function Grid({ apps, open }: { apps: StoreApp[]; open: (id: string) => void }) {
  return (
    <ul className="grid gap-2 @[620px]:grid-cols-2 @[960px]:grid-cols-3">
      {apps.map((a) => (
        <li key={a.id}>
          <div role="button" tabIndex={0} onClick={() => open(a.id)} onKeyDown={(e) => e.key === 'Enter' && open(a.id)} className="flex cursor-pointer items-center gap-3 rounded-2xl p-2.5 hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]">
            <Tile app={a} />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold">{a.name}</span>
              <span className="block truncate text-xs text-fg-muted">{a.tagline}</span>
              <span className="mt-0.5 flex items-center gap-1.5 text-[11px] text-fg-subtle">
                <Stars rating={a.rating} /> {a.rating}
              </span>
            </span>
            <GetButton app={a} />
          </div>
        </li>
      ))}
    </ul>
  );
}

function Discover({ open }: { open: (id: string) => void }) {
  const featured = FEATURED.map((id) => CATALOG.find((a) => a.id === id)!);
  const [i, setI] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setI((x) => (x + 1) % featured.length), 6000);
    return () => clearInterval(t);
  }, [featured.length]);
  const f = featured[i];
  return (
    <>
      <section aria-roledescription="carousel" aria-label="Featured" className="relative h-56 overflow-hidden rounded-3xl">
        <AnimatePresence mode="popLayout">
          <motion.button
            key={f.id}
            onClick={() => open(f.id)}
            initial={{ opacity: 0, scale: 1.04 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.6 }}
            className="absolute inset-0 flex items-end p-6 text-left text-white"
            style={{ background: `radial-gradient(circle at 80% 20%, oklch(0.8 0.14 ${f.hue}), transparent 55%), linear-gradient(135deg, oklch(0.45 0.16 ${f.hue + 30}), oklch(0.25 0.08 ${f.hue + 60}))` }}
          >
            <span className="flex items-end gap-4">
              <Tile app={f} size={72} />
              <span>
                <span className="block text-[11px] font-semibold uppercase tracking-[0.16em] text-white/75">Editors’ choice</span>
                <span className="block text-2xl font-semibold tracking-tight">{f.name}</span>
                <span className="block text-sm text-white/80">{f.tagline}</span>
              </span>
            </span>
          </motion.button>
        </AnimatePresence>
        <div className="absolute bottom-4 right-5 flex gap-1.5">
          {featured.map((x, k) => (
            <button key={x.id} aria-label={`Show ${x.name}`} aria-current={k === i} onClick={() => setI(k)} className={clsx('h-1.5 rounded-full bg-white transition-all', k === i ? 'w-6' : 'w-1.5 opacity-50')} />
          ))}
        </div>
      </section>
      {CATEGORIES.slice(0, 3).map((c) => (
        <section key={c.id} className="mt-7">
          <h2 className="mb-2 text-base font-semibold">{c.label}</h2>
          <Grid apps={CATALOG.filter((a) => a.category === c.id).slice(0, 3)} open={open} />
        </section>
      ))}
    </>
  );
}

function Updates() {
  const updated = useInstalls((s) => s.updated);
  const mark = useInstalls((s) => s.markUpdated);
  return (
    <>
      <h1 className="mb-4 text-xl font-semibold">Updates</h1>
      <ul className="glass-well divide-y divide-[var(--glass-border)] rounded-2xl">
        {UPDATES.map((u) => (
          <li key={u.appId} className="flex items-start gap-3 p-4">
            <AppIcon appId={u.appId} size={44} />
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold">Version {u.version}</p>
              <p className="text-xs text-fg-muted">{u.notes}</p>
            </div>
            <button onClick={() => mark(u.appId)} disabled={updated[u.appId]} className="flex h-7 items-center gap-1 rounded-full bg-accent-soft px-3 text-xs font-semibold text-accent disabled:bg-transparent disabled:text-fg-subtle">
              {updated[u.appId] ? 'Up to date' : (<><Download className="size-3" /> Update</>)}
            </button>
          </li>
        ))}
      </ul>
    </>
  );
}

function Detail({ app }: { app: StoreApp }) {
  return (
    <div className="max-w-3xl">
      <div className="flex items-start gap-5">
        <Tile app={app} size={96} />
        <div className="min-w-0 flex-1">
          <h1 className="text-2xl font-semibold tracking-tight">{app.name}</h1>
          <p className="text-sm text-fg-muted">{app.tagline}</p>
          <p className="mt-0.5 text-xs text-fg-subtle">{app.developer}</p>
          <div className="mt-3">
            <GetButton app={app} />
          </div>
        </div>
      </div>
      <dl className="mt-6 grid grid-cols-3 divide-x divide-[var(--glass-border)] rounded-2xl text-center glass-well">
        {[
          ['Rating', `${app.rating} ★`, `${(app.reviews / 1000).toFixed(1)}K reviews`],
          ['Size', app.size, 'Download'],
          ['Category', CATEGORIES.find((c) => c.id === app.category)!.label, 'Category'],
        ].map(([k, v, d]) => (
          <div key={k} className="py-3">
            <dt className="text-[10px] uppercase tracking-wider text-fg-subtle">{k}</dt>
            <dd className="text-sm font-semibold">{v}</dd>
            <dd className="text-[10px] text-fg-subtle">{d}</dd>
          </div>
        ))}
      </dl>
      <div className="mt-6 flex gap-3 overflow-x-auto pb-2">
        {[0, 1, 2].map((k) => (
          <div key={k} aria-hidden className="h-40 w-64 shrink-0 rounded-2xl" style={{ background: `radial-gradient(circle at ${30 + k * 20}% 40%, oklch(0.82 0.12 ${app.hue + k * 25}), transparent 60%), linear-gradient(160deg, oklch(0.5 0.14 ${app.hue + 20}), oklch(0.3 0.08 ${app.hue + 50}))` }} />
        ))}
      </div>
      <p className="mt-4 max-w-prose text-sm leading-relaxed">{app.description}</p>
    </div>
  );
}
