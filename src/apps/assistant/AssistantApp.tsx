import { AssistantChat } from '@/components/assistant/AssistantChat';
import type { AppProps } from '@/system/types';

/** Aurora AI as a regular window, sharing the conversation with the side panel. */
export default function AssistantApp(_: AppProps) {
  return (
    <div className="h-full" style={{ background: 'var(--app-surface)' }}>
      <AssistantChat />
    </div>
  );
}
