import { useState } from 'react';
import { ArrowUpRight, Search } from 'lucide-react';
import clsx from 'clsx';
import { useClock } from '@/hooks/useClock';

interface PageProps {
  navigate: (u: string) => void;
  reader: boolean;
}

interface PageDef {
  title: string;
  blurb: string;
  keywords: string;
  Component: (p: PageProps) => React.ReactElement;
}

export function pageTitle(url: string) {
  if (url === 'aurora://newtab') return 'New Tab';
  if (url.startsWith('aurora://search')) return `${decodeURIComponent(url.split('q=')[1] ?? '')} — Search`;
  if (PAGES[url]) return PAGES[url].title;
  return url.replace(/^https?:\/\//, '').replace(/\/$/, '');
}

function NewTab({ navigate }: PageProps) {
  const now = useClock();
  const [q, setQ] = useState('');
  const greeting = now.getHours() < 12 ? 'Good morning' : now.getHours() < 18 ? 'Good afternoon' : 'Good evening';
  const tiles = [
    { url: 'aurora://glass-age', title: 'The Glass Age', hue: 275 },
    { url: 'aurora://design', title: 'Design principles', hue: 200 },
    { url: 'aurora://about', title: 'About Horizon', hue: 160 },
    { url: 'https://developer.mozilla.org', title: 'MDN', hue: 20 },
    { url: 'https://github.com', title: 'GitHub', hue: 250 },
    { url: 'https://en.wikipedia.org', title: 'Wikipedia', hue: 90 },
  ];
  return (
    <div className="mx-auto flex max-w-2xl flex-col items-center px-6 py-14">
      <p className="text-sm text-fg-muted">{now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
      <h1 className="mt-1 text-4xl font-semibold tracking-tight">{greeting}</h1>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (q.trim()) navigate(`aurora://search?q=${encodeURIComponent(q.trim())}`);
        }}
        className="glass mt-8 flex h-12 w-full items-center gap-3 rounded-full px-5"
      >
        <Search className="size-4 text-fg-subtle" />
        <input value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" placeholder="Search Horizon" className="min-w-0 flex-1 bg-transparent outline-none placeholder:text-fg-subtle" />
      </form>
      <div className="mt-10 grid w-full grid-cols-3 gap-4 @[560px]:grid-cols-6">
        {tiles.map((t) => (
          <button key={t.url} onClick={() => navigate(t.url)} className="group flex flex-col items-center gap-2">
            <span
              className="grid size-14 place-items-center rounded-2xl text-lg font-semibold text-white transition-transform group-hover:-translate-y-1"
              style={{ background: `linear-gradient(145deg, oklch(0.75 0.13 ${t.hue}), oklch(0.55 0.17 ${t.hue + 20}))`, boxShadow: `0 10px 24px -10px oklch(0.55 0.17 ${t.hue})` }}
            >
              {t.title[0]}
            </span>
            <span className="w-full truncate text-center text-[11px] text-fg-muted">{t.title}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function GlassAge({ reader }: PageProps) {
  return (
    <article className={clsx('mx-auto px-6 py-10', reader ? 'max-w-[38rem] font-serif text-[18px] leading-[1.75]' : 'max-w-2xl text-[15px] leading-[1.7]')}>
      <p className={clsx('text-xs font-semibold uppercase tracking-[0.18em]', reader ? 'text-[oklch(0.5_0.1_40)]' : 'text-accent')}>Essay · 7 min read</p>
      <h1 className={clsx('mt-2 font-semibold tracking-tight', reader ? 'text-4xl leading-tight' : 'text-3xl')}>The Glass Age of Interfaces</h1>
      <p className="mt-2 text-sm opacity-70">Why the next desktop will feel less like paper and more like light.</p>
      {!reader && <div className="my-6 h-48 rounded-2xl" style={{ background: 'radial-gradient(circle at 30% 30%, oklch(0.8 0.12 200), transparent 60%), radial-gradient(circle at 70% 70%, oklch(0.6 0.2 300), oklch(0.3 0.08 280))' }} />}
      <div className={clsx('space-y-4', reader && 'mt-8')}>
        <p>For forty years the desktop has borrowed its metaphors from the office: folders, files, a trash can, a desk. Those metaphors were useful because they were heavy. A window was a sheet of paper, and paper stays where you put it.</p>
        <p>Glass works differently. It lets context through. A translucent window says that the work behind it still exists, that you have only set it aside. When the glass is tuned well — enough blur to quiet the background, enough tint to keep text readable — it lowers the cost of switching between tasks because nothing ever fully disappears.</p>
        <h2 className="pt-2 text-xl font-semibold">Depth as information</h2>
        <p>In a spatial interface, distance means something. The window you are using sits closest: brightest, sharpest, rimmed in light. Everything else recedes a little, physically and visually. This is not decoration. It is the interface telling you, without words, what has your attention.</p>
        <p>Motion carries the same message. When every surface moves on the same family of springs, the system feels like one physical object rather than a stack of animations. A window that snaps to the edge of the screen should feel caught, not teleported.</p>
        <h2 className="pt-2 text-xl font-semibold">Quiet intelligence</h2>
        <p>The most useful assistant is the one you rarely notice. It holds a notification until your meeting ends, notices that your downloads folder is full of invoices, and offers — once — to sort them. It never moves a file without asking, and every action it takes can be undone.</p>
        <p>That restraint is the real design challenge of the next decade. The technology to make interfaces louder is already here. The craft is in making them calmer.</p>
      </div>
    </article>
  );
}

function Design(_: PageProps) {
  const items = [
    ['Light passes through', 'Surfaces are glass first. Opacity rises only where legibility needs it.'],
    ['Depth is information', 'What has focus is closest: brighter, sharper and rimmed in accent light.'],
    ['One physics', 'Every motion uses a small family of springs, so the whole system feels like one object.'],
    ['Calm by default', 'Colour comes from the wallpaper and one accent. Chrome stays neutral.'],
    ['Assist, never surprise', 'AI suggests and explains. Nothing changes without consent, and everything can be undone.'],
  ];
  return (
    <div className="mx-auto max-w-2xl px-6 py-10">
      <h1 className="text-3xl font-semibold tracking-tight">Aurora design principles</h1>
      <ol className="mt-6 space-y-3">
        {items.map(([t, b], i) => (
          <li key={t} className="glass-well flex gap-4 rounded-2xl p-4">
            <span className="text-2xl font-semibold tabular-nums text-accent">{i + 1}</span>
            <span>
              <span className="block font-semibold">{t}</span>
              <span className="block text-sm text-fg-muted">{b}</span>
            </span>
          </li>
        ))}
      </ol>
    </div>
  );
}

function About({ navigate }: PageProps) {
  return (
    <div className="mx-auto max-w-xl px-6 py-12 text-center">
      <span className="mx-auto grid size-16 place-items-center rounded-2xl text-2xl font-bold text-white" style={{ background: 'linear-gradient(145deg, oklch(0.8 0.14 180), oklch(0.58 0.16 220))' }}>
        H
      </span>
      <h1 className="mt-4 text-2xl font-semibold tracking-tight">Horizon</h1>
      <p className="text-sm text-fg-muted">Version 1.0 · Aurora OS concept</p>
      <p className="mt-6 text-sm leading-relaxed text-fg-muted">Tabs, history, bookmarks and a reader view. Ctrl+T opens a tab, Ctrl+L focuses the address bar, Ctrl+Shift+W closes the current tab.</p>
      <button onClick={() => navigate('aurora://glass-age')} className="mt-6 inline-flex items-center gap-1 text-sm font-medium text-accent">
        Read “The Glass Age of Interfaces” <ArrowUpRight className="size-3.5" />
      </button>
    </div>
  );
}

export const PAGES: Record<string, PageDef> = {
  'aurora://newtab': { title: 'New Tab', blurb: '', keywords: 'start home', Component: NewTab },
  'aurora://glass-age': { title: 'The Glass Age of Interfaces', blurb: 'Why the next desktop will feel less like paper and more like light.', keywords: 'glass interface design essay desktop depth ai', Component: GlassAge },
  'aurora://design': { title: 'Aurora design principles', blurb: 'Five rules behind the look and feel of Aurora OS.', keywords: 'design principles aurora glass motion', Component: Design },
  'aurora://about': { title: 'About Horizon', blurb: 'Version, shortcuts and features of the Horizon browser.', keywords: 'about horizon browser shortcuts version', Component: About },
};
