import {
  PROTOCOL_VERSION,
  isEnvelope,
  type Envelope,
  type InboundMessage,
  type OutboundMessage,
} from './protocol';

/** Name of both the JS handler (Android) and the global inbox the app calls into. */
export const CHANNEL_NAME = 'kebunku';

type InAppWebView = { callHandler: (handler: string, ...args: unknown[]) => Promise<unknown> };

declare global {
  interface Window {
    flutter_inappwebview?: InAppWebView;
    kebunku?: { receive: (payload: string) => void };
  }
}

/**
 * One transport for both hosts.
 *
 * - Android: the app evaluates `window.kebunku.receive('<json>')`, and we answer
 *   through the `flutter_inappwebview` JS handler.
 * - Flutter web: the app posts to our `<iframe>`, and we answer `window.parent`.
 */
export class Bridge {
  private readonly handlers = new Map<string, (message: InboundMessage) => void>();
  private readonly pending: Envelope<OutboundMessage>[] = [];

  constructor() {
    window.kebunku = { receive: (payload: string) => this.accept(payload) };
    window.addEventListener('message', (event: MessageEvent) => this.accept(event.data));
  }

  on<T extends InboundMessage['type']>(
    type: T,
    handler: (message: Extract<InboundMessage, { type: T }>) => void,
  ): void {
    this.handlers.set(type, handler as (message: InboundMessage) => void);
  }

  send(message: OutboundMessage): void {
    const envelope: Envelope<OutboundMessage> = { v: PROTOCOL_VERSION, ...message };
    const webView = window.flutter_inappwebview;
    if (webView) {
      // Drain anything queued before the JS handler was injected.
      while (this.pending.length > 0) {
        void webView.callHandler(CHANNEL_NAME, JSON.stringify(this.pending.shift()));
      }
      void webView.callHandler(CHANNEL_NAME, JSON.stringify(envelope));
      return;
    }
    if (window.parent !== window) {
      // `*` because the Android WebView origin is opaque; the app validates the
      // envelope it receives rather than trusting the origin.
      window.parent.postMessage(JSON.stringify(envelope), '*');
      return;
    }
    // Standalone `npm run dev`: no host to talk to.
    this.pending.push(envelope);
  }

  private accept(payload: unknown): void {
    let parsed: unknown = payload;
    if (typeof payload === 'string') {
      try {
        parsed = JSON.parse(payload);
      } catch {
        return; // Not ours — Vite's HMR and browser extensions post here too.
      }
    }
    if (!isEnvelope(parsed)) return;
    if (parsed.v !== PROTOCOL_VERSION) {
      this.send({
        type: 'error',
        message: `unsupported protocol v${parsed.v}, scene speaks v${PROTOCOL_VERSION}`,
      });
      return;
    }
    const handler = this.handlers.get(parsed.type);
    if (!handler) {
      this.send({ type: 'error', message: `unknown message type "${parsed.type}"` });
      return;
    }
    try {
      handler(parsed);
    } catch (error) {
      this.send({ type: 'error', message: String(error) });
    }
  }
}
