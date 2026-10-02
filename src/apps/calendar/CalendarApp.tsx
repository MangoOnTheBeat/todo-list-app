import { useEffect, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { ChevronLeft, ChevronRight, MapPin, Sparkles, Trash2, X } from 'lucide-react';
import clsx from 'clsx';
import { AppLayout, Segmented, SidebarSection, Toolbar, ToolButton } from '@/components/ui/AppKit';
import { findFocusSlots } from '@/services/ai/productivity';
import { useClock } from '@/hooks/useClock';
import { springs } from '@/system/motion';
import { CALENDARS, calColor, eventsOnDay, startOfWeek, useCalendarStore, type CalEvent, type CalendarId } from '@/system/store/calendarStore';
import type { AppProps } from '@/system/types';

const HOUR_PX = 48;
const DAY_MS = 86_400_000;
const sameDay = (a: Date, b: Date) => a.toDateString() === b.toDateString();
const fmtTime = (t: number) => new Date(t).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });

type Draft = { start: number; end: number; x: number; y: number };

export default function CalendarApp({ windowId }: AppProps) {
  const events = useCalendarStore((s) => s.events);
  const { add, remove } = useCalendarStore.getState();
  const now = useClock();
  const [view, setView] = useState<'week' | 'month'>('week');
  const [anchor, setAnchor] = useState(() => new Date());
  const [hidden, setHidden] = useState<Set<CalendarId>>(new Set());
  const [draft, setDraft] = useState<Draft | null>(null);
  const [selected, setSelected] = useState<{ ev: CalEvent; x: number; y: number } | null>(null);
  const [focusSuggestions, setFocusSuggestions] = useState<{ start: number; end: number }[] | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);

  // Narrow windows (phones, side-by-side tiling) show three days instead of seven.
  const [compact, setCompact] = useState(false);
  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setCompact(e.contentRect.width < 620));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const weekStart = startOfWeek(anchor);
  const firstDay = compact ? new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate()) : weekStart;
  const days = Array.from({ length: compact ? 3 : 7 }, (_, i) => new Date(firstDay.getTime() + i * DAY_MS));
  const visible = useMemo(() => events.filter((e) => !hidden.has(e.calendar)), [events, hidden]);

  // Open the week view scrolled to 8 AM.
  useEffect(() => {
    if (view === 'week' && scrollRef.current) scrollRef.current.scrollTop = HOUR_PX * 7.5;
  }, [view]);

  const shift = (dir: number) => {
    const d = new Date(anchor);
    if (view === 'week') d.setDate(d.getDate() + dir * (compact ? 3 : 7));
    else d.setMonth(d.getMonth() + dir);
    setAnchor(d);
  };

  const heading =
    view === 'week'
      ? `${days[0].toLocaleDateString(undefined, { month: compact ? 'short' : 'long', day: 'numeric' })} – ${days[days.length - 1].toLocaleDateString(undefined, { month: days[0].getMonth() === days[days.length - 1].getMonth() ? undefined : 'short', day: 'numeric', year: compact ? undefined : 'numeric' })}`
      : anchor.toLocaleDateString(undefined, { month: 'long', year: 'numeric' });

  const relPos = (e: React.MouseEvent) => {
    const r = rootRef.current!.getBoundingClientRect();
    return { x: Math.min(e.clientX - r.left, r.width - 280), y: Math.min(e.clientY - r.top, r.height - 220) };
  };

  const todays = eventsOnDay(visible, now).filter((e) => e.end > now.getTime());

  const sidebar = (
    <div className="pt-2">
      <MiniMonth anchor={anchor} onPick={(d) => setAnchor(d)} now={now} events={visible} />
      <SidebarSection title="Calendars">
        {(Object.keys(CALENDARS) as CalendarId[]).map((id) => (
          <li key={id}>
            <label className="flex h-8 cursor-pointer items-center gap-2.5 rounded-lg px-2 text-[13px] hover:bg-[color-mix(in_oklab,var(--text-1)_5%,transparent)]">
              <input
                type="checkbox"
                checked={!hidden.has(id)}
                onChange={() => {
                  const n = new Set(hidden);
                  n.has(id) ? n.delete(id) : n.add(id);
                  setHidden(n);
                }}
                className="size-3.5"
                style={{ accentColor: calColor(id) }}
              />
              {CALENDARS[id].name}
            </label>
          </li>
        ))}
      </SidebarSection>
      <SidebarSection title="Up next today">
        {todays.length === 0 ? (
          <li className="px-2 text-xs text-fg-subtle">Nothing else today.</li>
        ) : (
          todays.slice(0, 4).map((e) => (
            <li key={e.id} className="flex gap-2 rounded-lg px-2 py-1.5">
              <span className="w-1 shrink-0 rounded-full" style={{ background: calColor(e.calendar) }} />
              <span className="min-w-0">
                <span className="block truncate text-xs font-medium">{e.title}</span>
                <span className="block text-[11px] text-fg-subtle">{fmtTime(e.start)}</span>
              </span>
            </li>
          ))
        )}
      </SidebarSection>
    </div>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={232}>
      <div ref={rootRef} className="relative flex min-h-0 flex-1 flex-col">
        <Toolbar>
          <button onClick={() => setAnchor(new Date())} className="glass-well h-8 rounded-lg px-3 text-xs font-medium">
            Today
          </button>
          <ToolButton icon={ChevronLeft} label={view === 'week' ? 'Previous week' : 'Previous month'} onClick={() => shift(-1)} />
          <ToolButton icon={ChevronRight} label={view === 'week' ? 'Next week' : 'Next month'} onClick={() => shift(1)} />
          <h2 className="min-w-0 flex-1 truncate text-[15px] font-semibold tracking-tight">{heading}</h2>
          <button
            onClick={() => setFocusSuggestions(findFocusSlots(events, weekStart.getTime()))}
            className="hidden h-8 items-center gap-1.5 rounded-lg bg-accent-soft px-2.5 text-xs font-medium text-accent @[620px]:flex"
          >
            <Sparkles className="size-3.5" /> Find focus time
          </button>
          <Segmented
            label="Calendar view"
            value={view}
            onChange={setView}
            options={[
              { value: 'week', label: 'Week' },
              { value: 'month', label: 'Month' },
            ]}
          />
        </Toolbar>

        <AnimatePresence>
          {focusSuggestions && (
            <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="shrink-0 overflow-hidden border-b hairline bg-accent-soft">
              <div className="flex flex-wrap items-center gap-2 px-4 py-2.5 text-xs">
                <Sparkles className="size-3.5 text-accent" />
                <span className="font-medium">
                  {focusSuggestions.length ? `${focusSuggestions.length} open blocks of 90 minutes or more this week:` : 'No 90-minute gaps left this week. Try next week.'}
                </span>
                {focusSuggestions.map((s) => (
                  <button
                    key={s.start}
                    onClick={() => {
                      add({ title: 'Focus time', start: s.start, end: s.end, calendar: 'focus' });
                      setFocusSuggestions(focusSuggestions.filter((x) => x !== s));
                    }}
                    className="rounded-full bg-[var(--glass-tint)] px-2.5 py-1 font-medium hover:bg-accent-fill hover:text-white"
                  >
                    + {new Date(s.start).toLocaleDateString(undefined, { weekday: 'short' })} {fmtTime(s.start)}–{fmtTime(s.end)}
                  </button>
                ))}
                <button aria-label="Dismiss" onClick={() => setFocusSuggestions(null)} className="ml-auto grid size-6 place-items-center rounded-full hover:bg-[var(--glass-tint)]">
                  <X className="size-3.5" />
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {view === 'week' ? (
          <div className="flex min-h-0 flex-1 flex-col">
            <div className="grid shrink-0 border-b hairline" style={{ gridTemplateColumns: `52px repeat(${days.length}, 1fr)` }}>
              <span />
              {days.map((d) => {
                const today = sameDay(d, now);
                return (
                  <div key={d.toISOString()} className="py-2 text-center">
                    <span className="block text-[11px] uppercase tracking-wider text-fg-subtle">{d.toLocaleDateString(undefined, { weekday: 'short' })}</span>
                    <span className={clsx('mx-auto mt-0.5 grid size-7 place-items-center rounded-full text-sm font-semibold tabular-nums', today && 'bg-accent-fill text-white shadow-[0_0_14px_-3px_var(--color-accent)]')}>{d.getDate()}</span>
                  </div>
                );
              })}
            </div>
            <div ref={scrollRef} className="relative min-h-0 flex-1 overflow-y-auto">
              <div className="relative grid" style={{ height: HOUR_PX * 24, gridTemplateColumns: `52px repeat(${days.length}, 1fr)` }}>
                <div className="relative">
                  {Array.from({ length: 23 }, (_, h) => (
                    <span key={h} className="absolute right-2 -translate-y-1/2 text-[10px] tabular-nums text-fg-subtle" style={{ top: (h + 1) * HOUR_PX }}>
                      {new Date(2000, 0, 1, h + 1).toLocaleTimeString(undefined, { hour: 'numeric' })}
                    </span>
                  ))}
                </div>
                {days.map((d) => {
                  const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
                  const dayEvents = eventsOnDay(visible, d);
                  return (
                    <div
                      key={d.toISOString()}
                      className="relative border-l hairline"
                      style={{ backgroundImage: `repeating-linear-gradient(to bottom, transparent 0 ${HOUR_PX - 1}px, var(--glass-border) ${HOUR_PX - 1}px ${HOUR_PX}px)` }}
                      onClick={(e) => {
                        if (e.target !== e.currentTarget) return;
                        const y = e.nativeEvent.offsetY;
                        const start = dayStart + Math.floor((y / HOUR_PX) * 2) * 1_800_000;
                        setSelected(null);
                        setDraft({ start, end: start + 3_600_000, ...relPos(e) });
                      }}
                    >
                      {sameDay(d, now) && (
                        <div className="pointer-events-none absolute inset-x-0 z-10 flex items-center" style={{ top: ((now.getTime() - dayStart) / 3_600_000) * HOUR_PX }}>
                          <span className="-ml-1 size-2 rounded-full bg-[oklch(0.65_0.22_25)]" />
                          <span className="h-px flex-1 bg-[oklch(0.65_0.22_25)]" />
                        </div>
                      )}
                      {dayEvents.map((ev) => {
                        const top = ((Math.max(ev.start, dayStart) - dayStart) / 3_600_000) * HOUR_PX;
                        const h = Math.max(20, ((Math.min(ev.end, dayStart + DAY_MS) - Math.max(ev.start, dayStart)) / 3_600_000) * HOUR_PX - 2);
                        return (
                          <motion.button
                            key={ev.id}
                            layout
                            initial={{ opacity: 0, scale: 0.95 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={springs.snappy}
                            onClick={(e) => {
                              setDraft(null);
                              setSelected({ ev, ...relPos(e) });
                            }}
                            className="absolute inset-x-1 overflow-hidden rounded-lg border-l-[3px] px-1.5 py-1 text-left"
                            style={{
                              top,
                              height: h,
                              borderColor: calColor(ev.calendar),
                              background: ev.calendar === 'focus' ? `repeating-linear-gradient(135deg, ${calColor(ev.calendar, 0.22)} 0 6px, ${calColor(ev.calendar, 0.14)} 6px 12px)` : calColor(ev.calendar, 0.2),
                            }}
                          >
                            <span className="block truncate text-[11px] font-semibold leading-tight">{ev.title}</span>
                            {h > 34 && <span className="block truncate text-[10px] text-fg-muted">{fmtTime(ev.start)}{ev.location ? ` · ${ev.location}` : ''}</span>}
                          </motion.button>
                        );
                      })}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        ) : (
          <MonthGrid anchor={anchor} now={now} events={visible} onPickDay={(d) => (setAnchor(d), setView('week'))} />
        )}

        <AnimatePresence>
          {draft && <QuickCreate key="draft" draft={draft} onClose={() => setDraft(null)} onSave={(title, calendar) => (add({ title, calendar, start: draft.start, end: draft.end }), setDraft(null))} windowId={windowId} />}
          {selected && (
            <Popover key="sel" x={selected.x} y={selected.y} onClose={() => setSelected(null)}>
              <div className="flex items-start gap-2">
                <span className="mt-1 size-2.5 shrink-0 rounded-full" style={{ background: calColor(selected.ev.calendar) }} />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{selected.ev.title}</p>
                  <p className="text-xs text-fg-muted">
                    {new Date(selected.ev.start).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })} · {fmtTime(selected.ev.start)} – {fmtTime(selected.ev.end)}
                  </p>
                  {selected.ev.location && (
                    <p className="mt-1 flex items-center gap-1 text-xs text-fg-muted">
                      <MapPin className="size-3" /> {selected.ev.location}
                    </p>
                  )}
                  <p className="mt-1 text-[11px] text-fg-subtle">{CALENDARS[selected.ev.calendar].name}</p>
                </div>
              </div>
              <button
                onClick={() => {
                  remove(selected.ev.id);
                  setSelected(null);
                }}
                className="mt-3 flex items-center gap-1.5 text-xs font-medium text-[oklch(0.62_0.2_25)]"
              >
                <Trash2 className="size-3.5" /> Delete event
              </button>
            </Popover>
          )}
        </AnimatePresence>
      </div>
    </AppLayout>
  );
}

function Popover({ x, y, onClose, children }: { x: number; y: number; onClose: () => void; children: React.ReactNode }) {
  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, [onClose]);
  return (
    <motion.div
      role="dialog"
      initial={{ opacity: 0, scale: 0.92, y: 6 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={springs.snappy}
      className="glass acrylic absolute z-30 w-[270px] rounded-2xl p-4"
      style={{ left: Math.max(8, x), top: Math.max(8, y), boxShadow: 'inset 0 1px 0 var(--glass-highlight), var(--shadow-window)' }}
    >
      <button aria-label="Close" onClick={onClose} className="absolute right-2 top-2 grid size-6 place-items-center rounded-full hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]">
        <X className="size-3.5" />
      </button>
      {children}
    </motion.div>
  );
}

function QuickCreate({ draft, onClose, onSave, windowId }: { draft: Draft; onClose: () => void; onSave: (title: string, cal: CalendarId) => void; windowId: string }) {
  const [title, setTitle] = useState('');
  const [cal, setCal] = useState<CalendarId>('work');
  return (
    <Popover x={draft.x} y={draft.y} onClose={onClose}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          onSave(title.trim() || 'New event', cal);
        }}
      >
        <label htmlFor={`ev-title-${windowId}`} className="text-xs text-fg-subtle">
          {new Date(draft.start).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })} · {fmtTime(draft.start)} – {fmtTime(draft.end)}
        </label>
        <input id={`ev-title-${windowId}`} autoFocus value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Event title" className="glass-well mt-2 h-9 w-full rounded-lg px-3 text-sm outline-none focus:ring-2 focus:ring-accent" />
        <div className="mt-3 flex gap-1.5" role="radiogroup" aria-label="Calendar">
          {(Object.keys(CALENDARS) as CalendarId[]).map((id) => (
            <button key={id} type="button" role="radio" aria-checked={cal === id} onClick={() => setCal(id)} className={clsx('flex h-7 items-center gap-1 rounded-full px-2 text-[11px] font-medium', cal === id ? 'glass' : 'text-fg-muted')}>
              <span className="size-2 rounded-full" style={{ background: calColor(id) }} />
              {CALENDARS[id].name.split(' ')[0]}
            </button>
          ))}
        </div>
        <button type="submit" className="mt-3 h-8 w-full rounded-lg bg-accent-fill text-xs font-semibold text-white">
          Add event
        </button>
      </form>
    </Popover>
  );
}

function MiniMonth({ anchor, now, onPick, events }: { anchor: Date; now: Date; onPick: (d: Date) => void; events: CalEvent[] }) {
  const [month, setMonth] = useState(new Date(anchor.getFullYear(), anchor.getMonth(), 1));
  useEffect(() => setMonth(new Date(anchor.getFullYear(), anchor.getMonth(), 1)), [anchor]);
  const lead = (month.getDay() + 6) % 7;
  const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const cells = [...Array(lead).fill(null), ...Array.from({ length: count }, (_, i) => new Date(month.getFullYear(), month.getMonth(), i + 1))];
  return (
    <div className="px-1">
      <div className="mb-1 flex items-center">
        <span className="flex-1 px-1 text-[13px] font-semibold">{month.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}</span>
        <ToolButton icon={ChevronLeft} label="Previous month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))} className="size-6" />
        <ToolButton icon={ChevronRight} label="Next month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))} className="size-6" />
      </div>
      <div className="grid grid-cols-7 text-center text-[10px]">
        {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d, i) => (
          <span key={i} className="py-0.5 font-medium text-fg-subtle">
            {d}
          </span>
        ))}
        {cells.map((d, i) =>
          d ? (
            <button
              key={i}
              onClick={() => onPick(d)}
              className={clsx(
                'relative mx-auto grid size-6 place-items-center rounded-full tabular-nums',
                sameDay(d, now) ? 'bg-accent-fill font-semibold text-white' : sameDay(d, anchor) ? 'bg-accent-soft font-semibold' : 'hover:bg-[color-mix(in_oklab,var(--text-1)_8%,transparent)]',
              )}
            >
              {d.getDate()}
              {eventsOnDay(events, d).length > 0 && !sameDay(d, now) && <span className="absolute bottom-0.5 size-0.5 rounded-full bg-fg-subtle" />}
            </button>
          ) : (
            <span key={i} />
          ),
        )}
      </div>
    </div>
  );
}

function MonthGrid({ anchor, now, events, onPickDay }: { anchor: Date; now: Date; events: CalEvent[]; onPickDay: (d: Date) => void }) {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  const start = startOfWeek(first);
  const cells = Array.from({ length: 42 }, (_, i) => new Date(start.getTime() + i * DAY_MS));
  return (
    <div className="grid min-h-0 flex-1 grid-cols-7 grid-rows-[auto_repeat(6,1fr)]">
      {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => (
        <span key={d} className="border-b hairline py-1.5 text-center text-[11px] uppercase tracking-wider text-fg-subtle">
          {d}
        </span>
      ))}
      {cells.map((d) => {
        const evs = eventsOnDay(events, d);
        const inMonth = d.getMonth() === anchor.getMonth();
        return (
          <button key={d.toISOString()} onClick={() => onPickDay(d)} className={clsx('min-h-0 overflow-hidden border-b border-r hairline p-1 text-left hover:bg-[color-mix(in_oklab,var(--text-1)_4%,transparent)]', !inMonth && 'opacity-45')}>
            <span className={clsx('grid size-6 place-items-center rounded-full text-xs font-medium tabular-nums', sameDay(d, now) && 'bg-accent-fill text-white')}>{d.getDate()}</span>
            <span className="mt-0.5 block space-y-0.5">
              {evs.slice(0, 3).map((e) => (
                <span key={e.id} className="flex items-center gap-1 truncate text-[10px]">
                  <span className="size-1.5 shrink-0 rounded-full" style={{ background: calColor(e.calendar) }} />
                  <span className="truncate">{e.title}</span>
                </span>
              ))}
              {evs.length > 3 && <span className="block text-[10px] text-fg-subtle">+{evs.length - 3} more</span>}
            </span>
          </button>
        );
      })}
    </div>
  );
}
