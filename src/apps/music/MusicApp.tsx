import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { Heart, Library, Pause, Play, SkipBack, SkipForward, Volume1, VolumeX } from 'lucide-react';
import clsx from 'clsx';
import { AppLayout, SidebarItem, SidebarSection } from '@/components/ui/AppKit';
import { CoverArt, EqBars } from '@/components/ui/CoverArt';
import { Slider } from '@/components/ui/Slider';
import { springs } from '@/system/motion';
import { currentTrack, formatTime, LIBRARY, useMediaStore } from '@/system/store/mediaStore';
import { useSystemStore } from '@/system/store/systemStore';
import type { AppProps } from '@/system/types';

/** Resonance: the media session's full player, with a generative visualiser. */
export default function MusicApp({ windowId }: AppProps) {
  const media = useMediaStore();
  const track = useMediaStore(currentTrack);
  const { volume, set, reduceMotion } = useSystemStore();
  const [view, setView] = useState<'library' | 'liked'>('library');
  const list = view === 'liked' ? LIBRARY.filter((t) => media.liked[t.id]) : LIBRARY;

  const sidebar = (
    <div className="pt-2">
      <SidebarSection title="Library">
        <SidebarItem layoutGroup={`music-${windowId}`} icon={Library} label="All songs" trailing={LIBRARY.length} active={view === 'library'} onClick={() => setView('library')} />
        <SidebarItem layoutGroup={`music-${windowId}`} icon={Heart} label="Liked" trailing={Object.values(media.liked).filter(Boolean).length || undefined} active={view === 'liked'} onClick={() => setView('liked')} />
      </SidebarSection>
      <SidebarSection title="Albums">
        {LIBRARY.map((t) => (
          <li key={t.id} className="flex items-center gap-2 px-2 py-1 text-xs text-fg-muted">
            <CoverArt track={t} size={22} radius={5} />
            <span className="truncate">{t.album}</span>
          </li>
        ))}
      </SidebarSection>
    </div>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={196}>
      <div className="relative shrink-0 overflow-hidden">
        <div aria-hidden className="absolute inset-0 opacity-60" style={{ background: `radial-gradient(70% 140% at 10% 0%, ${track.palette[0]}, transparent 70%), radial-gradient(60% 120% at 90% 100%, ${track.palette[1]}, transparent 70%)` }} />
        <div className="relative flex items-end gap-5 p-5">
          <motion.div key={track.id} initial={{ scale: 0.85, opacity: 0, rotate: -6 }} animate={{ scale: 1, opacity: 1, rotate: 0 }} transition={springs.elastic}>
            <CoverArt track={track} size={128} playing={media.playing} radius={18} />
          </motion.div>
          <div className="min-w-0 flex-1 pb-1">
            <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-fg-muted">{media.playing ? 'Now playing' : 'Paused'}</p>
            <h1 className="truncate text-2xl font-semibold tracking-tight">{track.title}</h1>
            <p className="truncate text-sm text-fg-muted">
              {track.artist} · {track.album}
            </p>
            <Visualizer playing={media.playing && !reduceMotion} palette={track.palette} />
          </div>
        </div>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-3 pb-3">
        <table className="w-full text-[13px]">
          <thead>
            <tr className="text-left text-[11px] uppercase tracking-wider text-fg-subtle">
              <th className="w-10 px-2 py-2 font-medium">#</th>
              <th className="px-2 py-2 font-medium">Title</th>
              <th className="hidden px-2 py-2 font-medium @[560px]:table-cell">Album</th>
              <th className="w-16 px-2 py-2 text-right font-medium">Time</th>
            </tr>
          </thead>
          <tbody>
            {list.map((t) => {
              const idx = LIBRARY.indexOf(t);
              const current = idx === media.index;
              return (
                <tr
                  key={t.id}
                  tabIndex={0}
                  onDoubleClick={() => (useMediaStore.setState({ index: idx, position: 0 }), media.play())}
                  onKeyDown={(e) => e.key === 'Enter' && (useMediaStore.setState({ index: idx, position: 0 }), media.play())}
                  className={clsx('group cursor-default outline-none focus-visible:outline-2 focus-visible:outline-accent', current ? 'bg-accent-soft' : 'hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]')}
                >
                  <td className="rounded-l-lg px-2 py-2 tabular-nums text-fg-subtle">
                    {current && media.playing ? <EqBars playing /> : (
                      <button
                        aria-label={`Play ${t.title}`}
                        onClick={() => (useMediaStore.setState({ index: idx, position: 0 }), media.play())}
                        className="w-4 text-left"
                      >
                        <span className="group-hover:hidden">{idx + 1}</span>
                        <Play className="hidden size-3.5 fill-current group-hover:block" />
                      </button>
                    )}
                  </td>
                  <td className="px-2 py-2">
                    <span className={clsx('block font-medium', current && 'text-accent')}>{t.title}</span>
                    <span className="block text-xs text-fg-subtle">{t.artist}</span>
                  </td>
                  <td className="hidden px-2 py-2 text-fg-muted @[560px]:table-cell">{t.album}</td>
                  <td className="rounded-r-lg px-2 py-2 text-right tabular-nums text-fg-muted">{formatTime(t.duration)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {list.length === 0 && <p className="p-6 text-center text-sm text-fg-subtle">Songs you like appear here. Tap the heart in Quick Settings or below.</p>}
      </div>

      {/* Transport */}
      <div className="flex shrink-0 flex-wrap items-center gap-x-4 gap-y-2 border-t hairline px-4 py-3">
        <div className="flex items-center gap-2">
          <Btn label="Previous" onClick={media.prev}>
            <SkipBack className="size-4 fill-current" />
          </Btn>
          <Btn label={media.playing ? 'Pause' : 'Play'} onClick={media.toggle} big>
            {media.playing ? <Pause className="size-5 fill-current" /> : <Play className="size-5 translate-x-px fill-current" />}
          </Btn>
          <Btn label="Next" onClick={media.next}>
            <SkipForward className="size-4 fill-current" />
          </Btn>
        </div>
        <div className="flex min-w-[160px] flex-1 items-center gap-2 text-[11px] tabular-nums text-fg-subtle">
          <span>{formatTime(media.position)}</span>
          <label className="relative flex-1">
            <span className="sr-only">Seek</span>
            <span className="block h-1 overflow-hidden rounded-full bg-[color-mix(in_oklab,var(--text-1)_14%,transparent)]">
              <span className="block h-full rounded-full bg-accent" style={{ width: `${(media.position / track.duration) * 100}%` }} />
            </span>
            <input type="range" min={0} max={track.duration} value={media.position} onChange={(e) => media.seek(Number(e.target.value))} className="absolute inset-x-0 -top-2 h-5 w-full cursor-pointer opacity-0" />
          </label>
          <span>{formatTime(track.duration)}</span>
        </div>
        <button aria-label={media.liked[track.id] ? 'Unlike' : 'Like'} aria-pressed={!!media.liked[track.id]} onClick={media.toggleLike}>
          <Heart className={clsx('size-4', media.liked[track.id] ? 'fill-[oklch(0.65_0.22_15)] text-[oklch(0.65_0.22_15)]' : 'text-fg-muted')} />
        </button>
        <div className="w-32">
          <Slider label="Volume" icon={volume === 0 ? VolumeX : Volume1} value={volume} onChange={(v) => set('volume', v)} />
        </div>
      </div>
    </AppLayout>
  );
}

function Btn({ label, onClick, big, children }: { label: string; onClick: () => void; big?: boolean; children: React.ReactNode }) {
  return (
    <motion.button aria-label={label} onClick={onClick} whileTap={{ scale: 0.86 }} transition={springs.elastic} className={clsx('grid place-items-center rounded-full', big ? 'size-10 bg-accent text-white shadow-[0_6px_18px_-6px_var(--color-accent)]' : 'size-8 text-fg')}>
      {children}
    </motion.button>
  );
}

/** Canvas spectrum bars driven by layered sine "noise". Stops drawing when paused or hidden. */
function Visualizer({ playing, palette }: { playing: boolean; palette: [string, string, string] }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d')!;
    let raf = 0;
    const levels = new Float32Array(40).fill(0.08);
    const draw = (t: number) => {
      const dpr = window.devicePixelRatio || 1;
      const w = canvas.clientWidth;
      const h = canvas.clientHeight;
      if (canvas.width !== w * dpr) {
        canvas.width = w * dpr;
        canvas.height = h * dpr;
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      const n = levels.length;
      const bw = w / n;
      const grad = ctx.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0, palette[0]);
      grad.addColorStop(1, palette[1]);
      ctx.fillStyle = grad;
      for (let i = 0; i < n; i++) {
        const target = playing ? 0.15 + 0.5 * Math.abs(Math.sin(t / 380 + i * 0.5) * Math.cos(t / 610 - i * 0.23)) + 0.3 * Math.abs(Math.sin(t / 150 + i * 1.7)) * (1 - i / n) : 0.06;
        levels[i] += (target - levels[i]) * 0.18;
        const bh = Math.max(2, levels[i] * h);
        ctx.beginPath();
        ctx.roundRect(i * bw + 1, h - bh, bw - 2, bh, 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    // When paused, let the bars settle then stop the loop.
    const stop = playing ? undefined : setTimeout(() => cancelAnimationFrame(raf), 800);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(stop);
    };
  }, [playing, palette]);
  return <canvas ref={ref} aria-hidden className="mt-3 h-10 w-full max-w-md" />;
}

