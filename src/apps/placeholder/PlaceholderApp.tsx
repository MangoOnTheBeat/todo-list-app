import { motion } from 'framer-motion';
import { AppIcon } from '@/components/ui/AppIcon';
import { getApp } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';

/** Stand-in for apps whose real implementation lands in a later build phase. */
export default function PlaceholderApp({ windowId }: AppProps) {
  const appId = useWindowStore((s) => s.windows[windowId]?.appId);
  if (!appId) return null;
  const app = getApp(appId);
  return (
    <div className="grid h-full place-items-center p-8">
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ ...springs.panel, delay: 0.08 }}
        className="flex max-w-sm flex-col items-center gap-4 text-center"
      >
        <AppIcon appId={appId} size={84} />
        <div>
          <h3 className="text-xl font-semibold tracking-tight">{app.name}</h3>
          <p className="mt-1 text-sm text-fg-muted">{app.description}</p>
        </div>
        <span className="rounded-full bg-accent-soft px-3 py-1 text-xs font-medium text-accent">Arrives in phase {app.phase}</span>
        <p className="text-xs text-fg-subtle">
          This window is fully managed — drag it, resize it, snap it to an edge, or hover the maximize button for layouts.
        </p>
      </motion.div>
    </div>
  );
}
