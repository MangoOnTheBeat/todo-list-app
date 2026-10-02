import { useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { ArrowLeft, ArrowRight, BookOpen, ExternalLink, Globe, Lock, Plus, RotateCw, Search, Star, X } from 'lucide-react';
import clsx from 'clsx';
import { ToolButton } from '@/components/ui/AppKit';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';
import { PAGES, pageTitle } from './pages';

interface Tab {
  id: string;
  history: string[];
  index: number;
}

let tabSeq = 0;
const newTab = (url = 'aurora://newtab'): Tab => ({ id: `t${tabSeq++}`, history: [url], index: 0 });

/** Turn whatever was typed into a URL: known schemes pass, bare domains get https, everything else is a search. */
export function normalize(input: string) {
  const v = input.trim();
  if (!v) return 'aurora://newtab';
  if (/^(aurora|https?):\/\//i.test(v)) return v;
  if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(v)) return `https://${v}`;
  return `aurora://search?q=${encodeURIComponent(v)}`;
}

export default function BrowserApp({ windowId, args }: AppProps) {
  const [tabs, setTabs] = useState<Tab[]>(() => [newTab(typeof args?.url === 'string' ? normalize(args.url) : undefined)]);
  const [activeId, setActiveId] = useState(tabs[0].id);
  const [bookmarks, setBookmarks] = useState<string[]>(['aurora://glass-age', 'aurora://design', 'https://developer.mozilla.org']);
  const [reader, setReader] = useState(false);
  const [loading, setLoading] = useState(0);
  const setTitle = useWindowStore((s) => s.setTitle);

  const tab = tabs.find((t) => t.id === activeId) ?? tabs[0];
  const url = tab.history[tab.index];
  const [address, setAddress] = useState(url);
  const addressRef = useRef<HTMLInputElement>(null);

  useEffect(() => setAddress(url === 'aurora://newtab' ? '' : url), [url, activeId]);
  useEffect(() => setTitle(windowId, pageTitle(url)), [url, windowId, setTitle]);
  useEffect(() => setReader(false), [url]);

  const update = (t: Tab) => setTabs((all) => all.map((x) => (x.id === t.id ? t : x)));
  const navigate = (to: string) => {
    update({ ...tab, history: [...tab.history.slice(0, tab.index + 1), to], index: tab.index + 1 });
    setLoading((n) => n + 1);
  };
  const addTab = (to?: string) => {
    const t = newTab(to);
    setTabs((all) => [...all, t]);
    setActiveId(t.id);
    if (!to) setTimeout(() => addressRef.current?.focus(), 50);
  };
  const closeTab = (id: string) => {
    if (tabs.length === 1) {
      update(newTab());
      return;
    }
    const idx = tabs.findIndex((t) => t.id === id);
    const rest = tabs.filter((t) => t.id !== id);
    setTabs(rest);
    if (id === activeId) setActiveId(rest[Math.min(idx, rest.length - 1)].id);
  };

  const onKey = (e: React.KeyboardEvent) => {
    if (!(e.ctrlKey || e.metaKey)) return;
    if (e.key === 't') addTab();
    else if (e.key === 'l') addressRef.current?.select();
    else if (e.key === 'w' && e.shiftKey) closeTab(activeId);
    else return;
    e.preventDefault();
  };

  const bookmarked = bookmarks.includes(url);
  const isArticle = url === 'aurora://glass-age';
  const secure = url.startsWith('https://') || url.startsWith('aurora://');

  return (
    <div className="@container flex h-full flex-col" onKeyDown={onKey}>
      {/* Tab strip */}
      <div role="tablist" aria-label="Tabs" className="flex h-9 shrink-0 items-end gap-1 overflow-x-auto px-2">
        {tabs.map((t) => {
          const active = t.id === activeId;
          const u = t.history[t.index];
          return (
            <div
              key={t.id}
              role="tab"
              aria-selected={active}
              tabIndex={0}
              onClick={() => setActiveId(t.id)}
              onKeyDown={(e) => e.key === 'Enter' && setActiveId(t.id)}
              onAuxClick={(e) => e.button === 1 && closeTab(t.id)}
              className={clsx('group relative flex h-8 min-w-0 max-w-[200px] flex-1 cursor-default items-center gap-2 rounded-t-xl px-3 text-xs', active ? 'text-fg' : 'text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]')}
            >
              {active && <motion.span layoutId={`btab-${windowId}`} transition={springs.snappy} className="absolute inset-0 rounded-t-xl" style={{ background: 'color-mix(in oklab, var(--glass-tint) 70%, transparent)' }} />}
              <Favicon url={u} />
              <span className="relative min-w-0 flex-1 truncate">{pageTitle(u)}</span>
              <button
                aria-label={`Close ${pageTitle(u)}`}
                onClick={(e) => {
                  e.stopPropagation();
                  closeTab(t.id);
                }}
                className="relative grid size-5 place-items-center rounded-md opacity-0 hover:bg-[color-mix(in_oklab,var(--text-1)_12%,transparent)] focus-visible:opacity-100 group-hover:opacity-100"
              >
                <X className="size-3" />
              </button>
            </div>
          );
        })}
        <ToolButton icon={Plus} label="New tab" onClick={() => addTab()} className="mb-0.5 size-7" />
      </div>

      {/* Navigation bar */}
      <div className="relative flex h-11 shrink-0 items-center gap-1 px-2" style={{ background: 'color-mix(in oklab, var(--glass-tint) 70%, transparent)' }}>
        <ToolButton icon={ArrowLeft} label="Back" disabled={tab.index === 0} onClick={() => update({ ...tab, index: tab.index - 1 })} />
        <ToolButton icon={ArrowRight} label="Forward" disabled={tab.index >= tab.history.length - 1} onClick={() => update({ ...tab, index: tab.index + 1 })} />
        <ToolButton icon={RotateCw} label="Reload" onClick={() => setLoading((n) => n + 1)} />
        <form
          className="glass-well mx-1 flex h-8 min-w-0 flex-1 items-center gap-2 rounded-full px-3 focus-within:ring-2 focus-within:ring-accent"
          onSubmit={(e) => {
            e.preventDefault();
            navigate(normalize(address));
            addressRef.current?.blur();
          }}
        >
          {secure ? <Lock aria-label="Secure connection" className="size-3.5 shrink-0 text-fg-subtle" /> : <Globe className="size-3.5 shrink-0 text-fg-subtle" />}
          <input
            ref={addressRef}
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            onFocus={(e) => e.target.select()}
            aria-label="Address"
            placeholder="Search or enter address"
            className="min-w-0 flex-1 bg-transparent text-[13px] outline-none placeholder:text-fg-subtle"
          />
        </form>
        {isArticle && <ToolButton icon={BookOpen} label="Reader view" active={reader} onClick={() => setReader(!reader)} />}
        <ToolButton icon={Star} label={bookmarked ? 'Remove bookmark' : 'Bookmark this page'} active={bookmarked} onClick={() => setBookmarks(bookmarked ? bookmarks.filter((b) => b !== url) : [...bookmarks, url])} />
        <AnimatePresence>
          {loading > 0 && (
            <motion.div
              key={`${loading}-${url}`}
              className="absolute inset-x-0 bottom-0 h-0.5 origin-left bg-accent shadow-[0_0_8px_var(--color-accent)]"
              initial={{ scaleX: 0, opacity: 1 }}
              animate={{ scaleX: 1, opacity: [1, 1, 0] }}
              transition={{ duration: 0.7, ease: 'easeOut' }}
              onAnimationComplete={() => setLoading(0)}
            />
          )}
        </AnimatePresence>
      </div>

      {/* Bookmarks bar */}
      <div className="flex h-8 shrink-0 items-center gap-1 overflow-x-auto border-b hairline px-3" style={{ background: 'color-mix(in oklab, var(--glass-tint) 70%, transparent)' }}>
        {bookmarks.map((b) => (
          <button key={b} onClick={() => navigate(b)} className="flex shrink-0 items-center gap-1.5 rounded-md px-2 py-0.5 text-[11px] text-fg-muted hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)] hover:text-fg">
            <Favicon url={b} />
            {pageTitle(b)}
          </button>
        ))}
      </div>

      {/* Page */}
      <div className="min-h-0 flex-1 overflow-y-auto" style={{ background: reader ? 'oklch(0.97 0.015 85)' : 'color-mix(in oklab, var(--glass-tint) 82%, transparent)', color: reader ? 'oklch(0.25 0.02 60)' : undefined }}>
        <motion.div key={`${activeId}-${url}`} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={springs.panel} className="min-h-full">
          <Page url={url} navigate={navigate} reader={reader} />
        </motion.div>
      </div>
    </div>
  );
}

function Favicon({ url }: { url: string }) {
  const internal = url.startsWith('aurora://');
  const host = internal ? 'A' : (url.replace(/^https?:\/\//, '')[0] ?? '?').toUpperCase();
  const hue = [...url].reduce((a, c) => a + c.charCodeAt(0), 0) % 360;
  return (
    <span aria-hidden className="relative grid size-4 shrink-0 place-items-center rounded text-[9px] font-bold text-white" style={{ background: internal ? 'linear-gradient(135deg, oklch(0.75 0.14 200), var(--color-accent))' : `oklch(0.6 0.14 ${hue})` }}>
      {host}
    </span>
  );
}

function Page({ url, navigate, reader }: { url: string; navigate: (u: string) => void; reader: boolean }) {
  if (url.startsWith('aurora://search')) {
    const q = decodeURIComponent(url.split('q=')[1] ?? '');
    const hits = Object.entries(PAGES).filter(([, p]) => (p.title + ' ' + p.keywords).toLowerCase().split(/\s+/).some((w) => q.toLowerCase().split(/\s+/).some((t) => t && w.startsWith(t))));
    return (
      <div className="mx-auto max-w-2xl px-6 py-8">
        <p className="text-xs text-fg-subtle">Results for</p>
        <h1 className="text-2xl font-semibold tracking-tight">{q}</h1>
        <ul className="mt-6 space-y-5">
          {hits.map(([u, p]) => (
            <li key={u}>
              <button onClick={() => navigate(u)} className="text-left">
                <span className="text-[11px] text-fg-subtle">{u}</span>
                <span className="block text-base font-medium text-accent hover:underline">{p.title}</span>
                <span className="block text-sm text-fg-muted">{p.blurb}</span>
              </button>
            </li>
          ))}
          <li className="glass-well rounded-xl p-4 text-sm">
            Search the live web for “{q}”:{' '}
            <a className="font-medium text-accent underline" href={`https://duckduckgo.com/?q=${encodeURIComponent(q)}`} target="_blank" rel="noreferrer">
              open in your browser
            </a>
          </li>
        </ul>
      </div>
    );
  }

  const page = PAGES[url];
  if (page) return <page.Component navigate={navigate} reader={reader} />;

  if (/^https?:\/\//.test(url)) {
    const host = url.replace(/^https?:\/\//, '').split('/')[0];
    return (
      <div className="grid min-h-full place-items-center p-8">
        <div className="glass max-w-sm rounded-3xl p-6 text-center">
          <span className="mx-auto grid size-12 place-items-center rounded-2xl bg-accent-soft text-accent">
            <Globe className="size-6" />
          </span>
          <p className="mt-3 text-lg font-semibold tracking-tight">{host}</p>
          <p className="mt-1 text-sm leading-relaxed text-fg-muted">Horizon is a concept browser, so it shows Aurora's own pages rather than loading live websites inside the desktop.</p>
          <a href={url} target="_blank" rel="noreferrer" className="mt-4 inline-flex items-center gap-1.5 rounded-full bg-accent-fill px-4 py-2 text-sm font-medium text-white">
            Open {host} in a new tab <ExternalLink className="size-3.5" />
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="grid min-h-full place-items-center p-8 text-center">
      <div>
        <Search className="mx-auto size-6 text-fg-subtle" />
        <p className="mt-2 text-sm font-medium">This page doesn't exist</p>
        <button onClick={() => navigate('aurora://newtab')} className="mt-2 text-sm text-accent">
          Go to the start page
        </button>
      </div>
    </div>
  );
}
