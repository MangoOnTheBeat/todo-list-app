import type { AppId } from './types';

/**
 * Dock icons register a measuring function so windows can minimize *into* their icon
 * (genie-style origin) without the window tree depending on dock layout.
 */
const registry = new Map<AppId, () => DOMRect | undefined>();

export const dockRegistry = {
  register(appId: AppId, measure: () => DOMRect | undefined) {
    registry.set(appId, measure);
    return () => {
      if (registry.get(appId) === measure) registry.delete(appId);
    };
  },
  rect(appId: AppId) {
    return registry.get(appId)?.();
  },
};
