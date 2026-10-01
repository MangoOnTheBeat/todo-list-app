import { memo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
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
  onPointerDown: (e: React.PointerEvent) => void;
}

export const TitleBar = memo(function TitleBar({ id, title, appId, mode, focused, onPointerDown }: Props) {
  const { minimizeWindow, toggleMaximize, closeWindow } = useWindowStore.getState();
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
      className="relative z-10 flex h-11 shrink-0 items-center gap-2.5 pl-3.5 pr-2"
      onPointerDown={onPointerDown}
      onDoubleClick={(e) => !(e.target as HTMLElement).closest('[data-no-drag]') && toggleMaximize(id)}
    >
      <AppIcon appId={appId} size={20} />
      <h2
        id={`${id}-title`}
        className={clsx('min-w-0 flex-1 truncate text-[13px] font-medium tracking-tight transition-colors', focused ? 'text-fg' : 'text-fg-subtle')}
      >
        {title}
      </h2>

      <div className="flex items-center gap-1" data-no-drag>
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
          <AnimatePresence>
            {flyout && <SnapLayoutsFlyout windowId={id} onClose={() => setFlyout(false)} />}
          </AnimatePresence>
        </div>
        <ChromeButton label="Close" tone="danger" onClick={() => closeWindow(id)}>
          <X className="size-3.5" />
        </ChromeButton>
      </div>
    </div>
  );
});

function ChromeButton({
  label,
  tone,
  children,
  ...rest
}: { label: string; tone?: 'danger' } & React.ComponentProps<typeof motion.button>) {
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
