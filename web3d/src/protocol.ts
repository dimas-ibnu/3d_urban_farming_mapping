/**
 * Versioned JSON message protocol between the Flutter app and the Three.js scene.
 *
 * Keep this file in sync with `app/lib/bridge/web3d_protocol.dart`, and the table
 * in `README.md` in sync with both. Bump `PROTOCOL_VERSION` on every breaking
 * change; each side drops messages from a version it does not know.
 *
 * v2 mirrors the Dart project model: the app pushes the space and the items, the
 * scene reports what the user touched or dragged. The scene owns no state the app
 * did not give it — an `itemMoved` event is a *request*, and the item only really
 * moves once the app validates it and echoes an `upsertItem` back.
 */
export const PROTOCOL_VERSION = 2;

/** A point on the floor plane, in metres. Matches Dart's `Vec2`. */
export type Vec2 = { x: number; z: number };

export type BarrierKind = 'wall' | 'railing' | 'obstacle';

/** A wall, railing or obstacle: a vertical slab over a floor segment. */
export type Barrier = {
  id: string;
  kind: BarrierKind;
  start: Vec2;
  end: Vec2;
  heightM: number;
};

/** The space being planned. Mirrors Dart's `Space`. */
export type Space = {
  /** Floor outline in metres, ordered around the ring. */
  footprint: Vec2[];
  /** Floor-to-ceiling height. */
  heightM: number;
  /** Compass bearing the open side faces: 0 = north, 90 = east. */
  facingDeg: number;
  barriers: Barrier[];
};

export type ItemType = 'pot' | 'verticalRack' | 'hangingPlanter' | 'wallPlanter';

export type ItemSize = { widthM: number; depthM: number; heightM: number };

/** One pot, rack or planter. Mirrors Dart's `PlacedItem`. */
export type PlacedItem = {
  id: string;
  type: ItemType;
  /** Centre of the footprint, metres. */
  position: Vec2;
  size: ItemSize;
  /** Shelves of growing area; only a rack has more than one. */
  levels: number;
  /** Rotation around the vertical axis, degrees clockwise seen from above. */
  rotationDeg: number;
  /** Height of the base above the floor; 0 for floor items. */
  mountHeightM: number;
  /** The wall a wall planter hangs on, once snapped. */
  barrierId?: string;
};

/** Which camera the scene renders with. */
export type ViewMode = '2d' | '3d';

/** Messages the app sends to the scene. */
export type InboundMessage =
  | { type: 'setSpace'; space: Space }
  | { type: 'upsertItem'; item: PlacedItem }
  | { type: 'removeItem'; id: string }
  | { type: 'clearItems' }
  | { type: 'setView'; mode: ViewMode }
  | { type: 'setSelection'; id: string | null }
  | { type: 'setInvalidItems'; ids: string[] }
  | { type: 'setDebugOverlay'; visible: boolean }
  | { type: 'ping' };

/** Messages the scene sends back to the app. */
export type OutboundMessage =
  | { type: 'ready'; protocol: number; renderer: string }
  | { type: 'selected'; id: string | null }
  | { type: 'itemMoved'; id: string; position: Vec2; mountHeightM?: number }
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

/** The space the scene falls back to before the app has sent a real one. */
export const DEFAULT_SPACE: Space = {
  footprint: [
    { x: -1, z: -0.6 },
    { x: 1, z: -0.6 },
    { x: 1, z: 0.6 },
    { x: -1, z: 0.6 },
  ],
  heightM: 2.6,
  facingDeg: 0,
  barriers: [],
};
