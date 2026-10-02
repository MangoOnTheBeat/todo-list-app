export type Edge = 'n' | 's' | 'e' | 'w' | 'ne' | 'nw' | 'se' | 'sw';

const handles: { edge: Edge; className: string; cursor: string }[] = [
  { edge: 'n', className: 'top-0 left-3 right-3 h-1.5', cursor: 'ns-resize' },
  { edge: 's', className: 'bottom-0 left-3 right-3 h-1.5', cursor: 'ns-resize' },
  { edge: 'e', className: 'right-0 top-3 bottom-3 w-1.5', cursor: 'ew-resize' },
  { edge: 'w', className: 'left-0 top-3 bottom-3 w-1.5', cursor: 'ew-resize' },
  { edge: 'nw', className: 'top-0 left-0 h-3.5 w-3.5', cursor: 'nwse-resize' },
  { edge: 'se', className: 'bottom-0 right-0 h-3.5 w-3.5', cursor: 'nwse-resize' },
  { edge: 'ne', className: 'top-0 right-0 h-3.5 w-3.5', cursor: 'nesw-resize' },
  { edge: 'sw', className: 'bottom-0 left-0 h-3.5 w-3.5', cursor: 'nesw-resize' },
];

/** Invisible hit areas on the frame. Pointer-only: keyboard users resize via snap shortcuts. */
export function ResizeHandles({ onStart }: { onStart: (edge: Edge, e: React.PointerEvent) => void }) {
  return (
    <>
      {handles.map((h) => (
        <div
          key={h.edge}
          aria-hidden
          data-resize-handle={h.edge}
          className={`absolute z-20 touch-none ${h.className}`}
          style={{ cursor: h.cursor }}
          onPointerDown={(e) => onStart(h.edge, e)}
        />
      ))}
    </>
  );
}
