import { useSystemStore } from '@/system/store/systemStore';

/**
 * Software display controls: brightness dims the whole scene, Night Light warms it.
 * Pointer-transparent overlays at the very top of the stack.
 */
export function DisplayFilters() {
  const brightness = useSystemStore((s) => s.brightness);
  const nightLight = useSystemStore((s) => s.nightLight);
  return (
    <>
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 z-[3000] transition-opacity duration-700"
        style={{ background: 'oklch(0.75 0.15 60)', mixBlendMode: 'multiply', opacity: nightLight ? 0.32 : 0 }}
      />
      <div aria-hidden className="pointer-events-none absolute inset-0 z-[3001] bg-black transition-opacity duration-150" style={{ opacity: (1 - brightness) * 0.75 }} />
    </>
  );
}
