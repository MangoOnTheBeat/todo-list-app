import { memo, useRef, useState } from 'react';
import { AnimatePresence, LayoutGroup, motion } from 'framer-motion';
import { Maximize2, Minimize2, Minus, X } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppId, WindowMode } from '@/system/types';
import { SnapLayoutsFlyout } from './SnapLayoutsFlyout';

interface Props {
  id: string;
  title: string;
  appId: AppId;
  mode: WindowMode;
  focused: boolean;
  groupId?: string;
  onPointerDown: (e: React.PointerEvent) => void;
}

export const TitleBar = memo(function TitleBar({ id, title, appId, mode, focused, groupId, onPointerDown }: Props) {
  const { minimizeWindow, toggleMaximize, closeWindow } = useWindowStore.getState();
  const isDropTarget = useWindowStore((s) => s.groupTarget === id);
  const [flyout, setFlyout] = useState(false);
  const hoverTimer = useRef<ReturnType<typeof setTimeout>>(undefined);

  // Snap layouts appear after a short hover on maximize — intentional, not accidental.
  const openFlyoutSoon = () => {
    clearTimeout(hoverTimer.current);
    hoverTimer.current = setTimeout(() => setFlyout(true), 450);
  };
  const cancelFlyout = () => {
    clearTimeout(hoverTimer.current);
    hoverTimer.current = setTimeout(() => setFlyout(false), 220);
  };

  return (
    <div
      data-titlebar-for={id}
      className="relative z-10 flex h-11 shrink-0 items-center gap-2.5 pl-3.5 pr-2"
      onPointerDown={onPointerDown}
      onDoubleClick={(e) => !(e.target as HTMLElement).closest('[data-no-drag]') && toggleMaximize(id)}
    >
      <AnimatePresence>
        {isDropTarget && (
          <motion.div
            aria-hidden
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="pointer-events-none absolute inset-1 grid place-items-center rounded-xl border border-dashed border-accent bg-accent-soft text-xs font-medium text-accent"
          >
            Drop to add as a tab
          </motion.div>
        )}
      </AnimatePresence>

      {groupId ? (
        <Tabs groupId={groupId} focused={focused} />
      ) : (
        <>
          <AppIcon appId={appId} size={20} />
          <h2 id={`${id}-title`} className={clsx('min-w-0 flex-1 truncate text-[13px] font-medium tracking-tight transition-colors', focused ? 'text-fg' : 'text-fg-subtle')}>
            {title}
          </h2>
        </>
      )}

      <div className="flex shrink-0 items-center gap-1" data-no-drag>
        <ChromeButton label="Minimize" onClick={() => minimizeWindow(id)}>
          <Minus className="size-3.5" />
        </ChromeButton>
        <div className="relative" onMouseEnter={openFlyoutSoon} onMouseLeave={cancelFlyout}>
          <ChromeButton
            label={mode === 'maximized' ? 'Restore' : 'Maximize'}
            aria-haspopup="menu"
            aria-expanded={flyout}
            onClick={() => {
              setFlyout(false);
              toggleMaximize(id);
            }}
            onKeyDown={(e) => {
              if (e.key === 'ArrowDown') {
                e.preventDefault();
                setFlyout(true);
              }
            }}
          >
            {mode === 'maximized' ? <Minimize2 className="size-3.5" /> : <Maximize2 className="size-3.5" />}
          </ChromeButton>
          <AnimatePresence>{flyout && <SnapLayoutsFlyout windowId={id} onClose={() => setFlyout(false)} />}</AnimatePresence>
        </div>
        <ChromeButton label="Close" tone="danger" onClick={() => closeWindow(id)}>
          <X className="size-3.5" />
        </ChromeButton>
      </div>
    </div>
  );
});

/**
 * Tab strip for grouped windows. Click a tab to switch, × to close it,
 * or drag it downward out of the strip to detach it into its own window.
 */
function Tabs({ groupId, focused }: { groupId: string; focused: boolean }) {
  const group = useWindowStore((s) => s.groups[groupId]);
  const windows = useWindowStore((s) => s.windows);
  const tabs = (group?.ids ?? []).map((tid) => ({ tid, title: windows[tid]?.title ?? '', appId: windows[tid]?.appId, active: group.activeId === tid }));
  const { focusWindow, closeWindow, detachFromGroup } = useWindowStore.getState();

  const onTabPointerDown = (tid: string, e: React.PointerEvent) => {
    e.stopPropagation();
    if (e.button !== 0) return;
    const sy = e.clientY;
    const onMove = (ev: PointerEvent) => {
      if (ev.clientY - sy > 34) {
        cleanup();
        detachFromGroup(tid, { x: ev.clientX - 120, y: ev.clientY - 18 });
      }
    };
    const cleanup = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', cleanup);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', cleanup);
  };

  return (
    <div role="tablist" aria-label="Window tabs" className="flex min-w-0 flex-1 items-center gap-1 overflow-hidden">
      <LayoutGroup id={groupId}>
        {tabs.map((t) => (
          <div
            key={t.tid}
            role="tab"
            id={t.active ? `${t.tid}-title` : undefined}
            aria-selected={t.active}
            tabIndex={0}
            data-no-drag
            onPointerDown={(e) => onTabPointerDown(t.tid, e)}
            onClick={() => focusWindow(t.tid)}
            onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && focusWindow(t.tid)}
            className={clsx(
              'group/tab relative flex h-7 min-w-0 max-w-[200px] flex-1 cursor-default items-center gap-2 rounded-lg pl-2 pr-1 text-[12px] font-medium',
              t.active ? (focused ? 'text-fg' : 'text-fg-muted') : 'text-fg-subtle hover:text-fg-muted',
            )}
          >
            {t.active && <motion.span layoutId="tab-pill" transition={springs.snappy} className="glass absolute inset-0 rounded-lg" />}
            <span className="relative">
              {t.appId && <AppIcon appId={t.appId} size={16} />}
            </span>
            <span className="relative min-w-0 flex-1 truncate">{t.title}</span>
            <button
              aria-label={`Close ${t.title}`}
              onPointerDown={(e) => e.stopPropagation()}
              onClick={(e) => {
                e.stopPropagation();
                closeWindow(t.tid);
              }}
              className="relative grid size-5 shrink-0 place-items-center rounded-md opacity-0 hover:bg-[color-mix(in_oklab,var(--text-1)_12%,transparent)] focus-visible:opacity-100 group-hover/tab:opacity-100"
            >
              <X className="size-3" />
            </button>
          </div>
        ))}
      </LayoutGroup>
    </div>
  );
}

function ChromeButton({ label, tone, children, ...rest }: { label: string; tone?: 'danger' } & React.ComponentProps<typeof motion.button>) {
  return (
    <motion.button
      type="button"
      aria-label={label}
      title={label}
      whileHover={{ scale: 1.08 }}
      whileTap={{ scale: 0.88 }}
      transition={springs.snappy}
      className={clsx(
        'grid size-7 place-items-center rounded-full text-fg-muted transition-colors',
        'hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)] hover:text-fg',
        tone === 'danger' && 'hover:!bg-[oklch(0.63_0.21_25)] hover:!text-white',
      )}
      {...rest}
    >
      {children}
    </motion.button>
  );
}
