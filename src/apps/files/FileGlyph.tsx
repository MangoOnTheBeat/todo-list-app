import { fileIcon } from '@/services/search/providers';
import type { VNode } from '@/services/vfs';

const HUE: Record<string, number> = { folder: 230, document: 255, pdf: 25, image: 330, audio: 350, video: 300, code: 165, archive: 60, spreadsheet: 150, presentation: 40 };

/** File/folder artwork: tinted glass tile; images get a generative "thumbnail". */
export function FileGlyph({ node, size = 56 }: { node: VNode; size?: number }) {
  const Icon = fileIcon[node.kind];
  const hue = HUE[node.kind] ?? 260;
  if (node.kind === 'image') {
    const h = (node.name.length * 47) % 360;
    return (
      <div
        aria-hidden
        className="relative overflow-hidden rounded-[10px] border border-white/30 shadow-md"
        style={{ width: size, height: size * 0.78, background: `radial-gradient(circle at 30% 30%, oklch(0.85 0.12 ${h}), transparent 60%), radial-gradient(circle at 70% 80%, oklch(0.6 0.18 ${(h + 80) % 360}), oklch(0.4 0.1 ${(h + 200) % 360}))` }}
      >
        <div className="absolute inset-x-0 bottom-0 h-1/3" style={{ background: `linear-gradient(transparent, oklch(0.3 0.08 ${h} / 0.6))` }} />
      </div>
    );
  }
  if (node.kind === 'folder') {
    return (
      <svg aria-hidden viewBox="0 0 64 52" width={size} height={size * 0.82}>
        <defs>
          <linearGradient id={`fg-${node.id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="oklch(0.82 0.11 230)" />
            <stop offset="1" stopColor="oklch(0.62 0.15 245)" />
          </linearGradient>
        </defs>
        <path d="M4 8a4 4 0 0 1 4-4h14l6 6h28a4 4 0 0 1 4 4v4H4z" fill="oklch(0.6 0.13 245)" />
        <rect x="2" y="14" width="60" height="36" rx="5" fill={`url(#fg-${node.id})`} />
        <rect x="2" y="14" width="60" height="36" rx="5" fill="none" stroke="oklch(1 0 0 / 0.35)" />
      </svg>
    );
  }
  return (
    <div
      aria-hidden
      className="relative grid place-items-center rounded-[10px] border"
      style={{
        width: size * 0.76,
        height: size,
        borderColor: `oklch(0.7 0.1 ${hue} / 0.4)`,
        background: `linear-gradient(160deg, oklch(0.97 0.02 ${hue}), oklch(0.88 0.06 ${hue}))`,
        boxShadow: `0 6px 14px -6px oklch(0.4 0.1 ${hue} / 0.5)`,
      }}
    >
      <Icon style={{ width: size * 0.36, height: size * 0.36, color: `oklch(0.5 0.15 ${hue})` }} />
      <span className="absolute bottom-1 font-mono text-[8px] font-semibold uppercase" style={{ color: `oklch(0.5 0.12 ${hue})` }}>
        {node.name.split('.').pop()?.slice(0, 5)}
      </span>
    </div>
  );
}
