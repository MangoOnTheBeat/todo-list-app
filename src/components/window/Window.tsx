import { memo, Suspense, useEffect, useRef, useState } from 'react';
import { animate, motion, useMotionValue, useSpring, useTransform, useVelocity } from 'framer-motion';
import { getApp } from '@/system/appRegistry';
import { dockRegistry } from '@/system/dockRegistry';
import { displayAt, workArea } from '@/system/layout';
import { instant, springs } from '@/system/motion';
import { detectZone, zoneRect } from '@/system/snap';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import { useShellStore } from '@/system/store/shellStore';
import type { OverviewSlot } from '@/system/overview';
import { useSystemStore } from '@/system/store/systemStore';
import type { Rect } from '@/system/types';
import { ResizeHandles, type Edge } from './ResizeHandles';
import { TitleBar } from './TitleBar';

interface Props {
  id: string;
  /** Visual depth in the z-stack of the current desktop (0 = top). */
  depth: number;
  zIndex: number;
  /** Set while Overview is open: where this window's live preview sits. */
  overview?: OverviewSlot;
}

/**
 * A managed window.
 *
 * Geometry lives in motion values, not React state: dragging and resizing write straight to
 * the compositor at pointer rate with zero re-renders, and only the final rect is committed
 * to the store. When the store's rect changes from elsewhere (snap, maximize, display resize)
 * the motion values spring to it — that single path gives every geometry change the same physics.
 */
export const Window = memo(function Window({ id, depth, zIndex, overview }: Props) {
  const win = useWindowStore((s) => s.windows[id]);
  const focused = useWindowStore((s) => s.focusedId === id);
  const hiddenTab = useWindowStore((s) => isHiddenTab(s, s.windows[id]));
  const { focusWindow, commitRect, snapWindow, setSnapPreview, setGroupTarget, groupWindows } = useWindowStore.getState();
  const reduceMotion = useSystemStore((s) => s.reduceMotion);
  const app = getApp(win.appId);
  const AppComponent = app.component;

  const x = useMotionValue(win.rect.x);
  const y = useMotionValue(win.rect.y);
  const w = useMotionValue(win.rect.w);
  const h = useMotionValue(win.rect.h);

  // Elastic tilt from horizontal velocity: the window "leans" into fast drags and settles back.
  const vx = useVelocity(x);
  // Only pointer drags lean; programmatic moves (snap, maximize) stay upright.
  const interacting = useRef(false);
  const leaning = useRef(false);
  const lean = useTransform(vx, (v) => (leaning.current ? Math.max(-2.2, Math.min(2.2, v / 1400)) : 0));
  const tilt = useSpring(lean, {
    stiffness: 300,
    damping: 24,
  });

  const [dragging, setDragging] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  // Store → motion values. Skipped mid-gesture so the pointer stays authoritative.
  useEffect(() => {
    if (interacting.current) return;
    const t = reduceMotion ? instant : springs.window;
    const anims = [
      animate(x, win.rect.x, t),
      animate(y, win.rect.y, t),
      animate(w, win.rect.w, t),
      animate(h, win.rect.h, t),
    ];
    return () => anims.forEach((a) => a.stop());
  }, [win.rect, reduceMotion, x, y, w, h]);

  // Move keyboard focus into the window when it becomes active via shortcut / dock.
  useEffect(() => {
    if (focused && !win.minimized && rootRef.current && !rootRef.current.contains(document.activeElement)) {
      rootRef.current.focus({ preventScroll: true });
    }
  }, [focused, win.minimized]);

  const current = (): Rect => ({ x: x.get(), y: y.get(), w: w.get(), h: h.get() });

  /* ─────────── Move ─────────── */
  const onTitlePointerDown = (e: React.PointerEvent) => {
    if (e.button !== 0 || (e.target as HTMLElement).closest('[data-no-drag]')) return;
    const start = { px: e.clientX, py: e.clientY, ...current() };
    const wasTiled = win.mode !== 'normal';
    let moved = false;
    let zone: ReturnType<typeof detectZone> = null;
    let zoneDisplay = win.displayId;

    const onMove = (ev: PointerEvent) => {
      const dx = ev.clientX - start.px;
      const dy = ev.clientY - start.py;
      if (!moved) {
        if (Math.hypot(dx, dy) < 4) return;
        moved = true;
        interacting.current = true;
        leaning.current = true;
        setDragging(true);
        // Tearing a tiled window off: morph back to its free size, keeping the grab point
        // at the same relative position under the cursor.
        if (wasTiled && win.restoreRect) {
          const ratio = (start.px - start.x) / start.w;
          start.x = start.px - win.restoreRect.w * ratio;
          start.w = win.restoreRect.w;
          start.h = win.restoreRect.h;
          animate(w, start.w, springs.window);
          animate(h, start.h, springs.window);
        }
      }
      const display = displayAt(useWindowStore.getState().displays, ev.clientX, ev.clientY);
      const wa = workArea(display);
      x.set(start.x + dx);
      y.set(Math.max(wa.y - 6, start.y + dy));

      const next = detectZone(ev.clientX, ev.clientY, display);
      if (next !== zone || display.id !== zoneDisplay) {
        zone = next;
        zoneDisplay = display.id;
        setSnapPreview(next ? { zone: next, rect: zoneRect(next, display) } : null);
      }

      // Hovering another window's title bar offers to merge into it as a tab. Only the
      // top-most window under the pointer counts, so obscured title bars can't be targeted.
      const under = next
        ? undefined
        : document.elementsFromPoint(ev.clientX, ev.clientY).find((el) => {
            const owner = el.closest<HTMLElement>('[data-window-id]');
            return owner && owner.dataset.windowId !== id;
          });
      const hit = under?.closest<HTMLElement>('[data-titlebar-for]') ?? undefined;
      setGroupTarget(hit?.dataset.titlebarFor ?? null);
    };

    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      window.removeEventListener('pointercancel', onUp);
      if (!moved) return;
      interacting.current = false;
      leaning.current = false;
      setDragging(false);
      setSnapPreview(null);
      const target = useWindowStore.getState().groupTarget;
      if (target) groupWindows(id, target);
      else if (zone) snapWindow(id, zone, zoneDisplay);
      else commitRect(id, { x: x.get(), y: y.get(), w: start.w, h: start.h });
      setGroupTarget(null);
    };

    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    window.addEventListener('pointercancel', onUp);
  };

  /* ─────────── Resize ─────────── */
  const onResizeStart = (edge: Edge, e: React.PointerEvent) => {
    e.stopPropagation();
    e.preventDefault();
    const start = { px: e.clientX, py: e.clientY, ...current() };
    const { minSize } = app;
    interacting.current = true;
    setDragging(true);

    const onMove = (ev: PointerEvent) => {
      const dx = ev.clientX - start.px;
      const dy = ev.clientY - start.py;
      if (edge.includes('e')) w.set(Math.max(minSize.w, start.w + dx));
      if (edge.includes('s')) h.set(Math.max(minSize.h, start.h + dy));
      if (edge.includes('w')) {
        const nw = Math.max(minSize.w, start.w - dx);
        w.set(nw);
        x.set(start.x + start.w - nw);
      }
      if (edge.includes('n')) {
        const nh = Math.max(minSize.h, start.h - dy);
        h.set(nh);
        y.set(start.y + start.h - nh);
      }
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      interacting.current = false;
      setDragging(false);
      commitRect(id, current());
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
  };

  /* ─────────── Minimize target ─────────── */
  // Genie-ish minimize: scale toward the app's dock icon by moving the transform origin there.
  const [origin, setOrigin] = useState('50% 100%');
  useEffect(() => {
    if (!win.minimized) return;
    const icon = dockRegistry.rect(win.appId);
    if (!icon) return;
    const r = current();
    const ox = ((icon.x + icon.width / 2 - r.x) / r.w) * 100;
    const oy = ((icon.y + icon.height / 2 - r.y) / r.h) * 100;
    setOrigin(`${ox}% ${oy}%`);
  }, [win.minimized, win.appId]);

  const tiled = win.mode !== 'normal';
  const radius = win.mode === 'maximized' ? 14 : 'var(--radius-window)';

  return (
    <motion.div
      ref={rootRef}
      role="dialog"
      aria-modal={false}
      aria-labelledby={`${id}-title`}
      aria-hidden={win.minimized || hiddenTab}
      inert={win.minimized || hiddenTab}
      tabIndex={-1}
      data-window-id={id}
      data-focused={focused}
      data-dragging={dragging}
      onPointerDownCapture={() => !focused && focusWindow(id)}
      className="absolute left-0 top-0 outline-none focus-visible:outline-none"
      style={{
        x,
        y,
        width: w,
        height: h,
        zIndex,
        rotate: tilt,
        pointerEvents: win.minimized || hiddenTab ? 'none' : 'auto',
        visibility: hiddenTab ? 'hidden' : undefined,
      }}
    >
      <motion.div
        className="h-full w-full"
        style={{ transformOrigin: overview ? '0% 0%' : origin }}
        initial={{ opacity: 0, scale: 0.9, filter: 'blur(10px)' }}
        animate={
          overview
            ? { opacity: 1, x: overview.dx, y: overview.dy, scale: overview.scale, filter: 'blur(0px)', transition: springs.window, transitionEnd: { filter: 'none' } }
            : win.minimized
            ? { opacity: 0, scale: 0.08, filter: 'blur(6px)', transition: { ...springs.panel, opacity: { duration: 0.25, delay: 0.08 } } }
            : {
                opacity: 1,
                x: 0,
                y: 0,
                // Depth stacking: windows further back sit very slightly smaller.
                scale: focused ? 1 : Math.max(0.985, 1 - depth * 0.004),
                filter: 'blur(0px)',
                transition: springs.window,
                transitionEnd: { filter: 'none' },
              }
        }
        exit={{ opacity: 0, scale: 0.94, filter: 'blur(8px)', transition: { duration: 0.18, ease: [0.4, 0, 1, 1] } }}
      >
        <div
          className="window-surface glass glass-sheen relative flex h-full w-full flex-col overflow-hidden"
          style={{
            borderRadius: radius,
            boxShadow: focused
              ? `inset 0 1px 0 var(--glass-highlight), 0 0 0 1px color-mix(in oklab, var(--color-accent) 35%, transparent), 0 0 48px -12px color-mix(in oklab, var(--color-accent) 45%, transparent), var(--shadow-window)`
              : `inset 0 1px 0 var(--glass-highlight), var(--shadow-window-idle)`,
          }}
        >
          <TitleBar
            id={id}
            title={win.title}
            appId={win.appId}
            mode={win.mode}
            focused={focused}
            groupId={win.groupId}
            onPointerDown={onTitlePointerDown}
          />
          <div className="relative min-h-0 flex-1">
            <Suspense fallback={<div className="grid h-full place-items-center text-sm text-fg-subtle">Loading…</div>}>
              <AppComponent windowId={id} args={win.args} />
            </Suspense>
          </div>
          {!tiled && !overview && <ResizeHandles onStart={onResizeStart} />}
          {overview && (
            // In Overview the window is a live preview: one click target that picks it.
            <button
              aria-label={`Show ${win.title}`}
              className="absolute inset-0 z-40 cursor-pointer rounded-[inherit] outline-none ring-accent transition-shadow hover:ring-[6px] focus-visible:ring-[6px]"
              onClick={() => {
                focusWindow(id);
                useShellStore.getState().setOverview(false);
              }}
            />
          )}
        </div>
      </motion.div>
    </motion.div>
  );
});
