/**
 * Versioned JSON message protocol between the Flutter app and the Three.js scene.
 *
 * Keep this file in sync with `app/lib/bridge/web3d_protocol.dart`.
 * Bump `PROTOCOL_VERSION` on every breaking change; the app refuses to talk to a
 * scene whose version it does not know.
 */
export const PROTOCOL_VERSION = 1;

/** Messages the app sends to the scene. */
export type InboundMessage =
  | { type: 'setFloor'; width: number; depth: number }
  | { type: 'addPot'; id: string; x: number; z: number; radius: number; height: number; color?: string }
  | { type: 'removePot'; id: string }
  | { type: 'clearPots' }
  | { type: 'setDebugOverlay'; visible: boolean }
  | { type: 'ping' };

/** Messages the scene sends back to the app. */
export type OutboundMessage =
  | { type: 'ready'; protocol: number; renderer: string }
  | { type: 'selected'; id: string | null }
  | { type: 'pong' }
  | { type: 'fps'; value: number }
  | { type: 'error'; message: string };

/** Envelope shared by both directions. */
export type Envelope<T> = T & { v: number };

export function isEnvelope(value: unknown): value is Envelope<InboundMessage> {
  if (typeof value !== 'object' || value === null) return false;
  const record = value as Record<string, unknown>;
  return typeof record['type'] === 'string' && typeof record['v'] === 'number';
}
