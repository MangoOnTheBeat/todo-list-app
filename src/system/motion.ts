import type { Transition } from 'framer-motion';

/**
 * Spring vocabulary. Everything in Aurora moves on one of these so motion feels
 * like a single physical system rather than a collection of timings.
 */
export const springs = {
  /** Window geometry: snap, maximize, restore. Critically-damped-ish, slight settle. */
  window: { type: 'spring', stiffness: 420, damping: 36, mass: 0.9 },
  /** Small controls: toggles, hovers, presses. */
  snappy: { type: 'spring', stiffness: 600, damping: 34 },
  /** Panels and overlays sliding in. */
  panel: { type: 'spring', stiffness: 340, damping: 32 },
  /** Large, slow surfaces: desktop switch, wallpaper changes. */
  gentle: { type: 'spring', stiffness: 170, damping: 26 },
  /** Playful elastic overshoot: dock bounce, notifications landing. */
  elastic: { type: 'spring', stiffness: 460, damping: 15 },
} satisfies Record<string, Transition>;

export const instant: Transition = { duration: 0 };
