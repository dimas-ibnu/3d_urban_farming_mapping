import { Bridge } from './bridge';
import { PROTOCOL_VERSION } from './protocol';
import { Scene } from './scene';

const canvas = document.getElementById('scene') as HTMLCanvasElement;
const fpsOverlay = document.getElementById('fps') as HTMLDivElement;

const bridge = new Bridge();

let scene: Scene;
try {
  scene = new Scene(canvas, {
    onSelect: (id) => bridge.send({ type: 'selected', id }),
    onMove: (id, position, mountHeightM) =>
      bridge.send({ type: 'itemMoved', id, position, ...(mountHeightM === undefined ? {} : { mountHeightM }) }),
  });
} catch (error) {
  // Creating the renderer fails where WebGL is unavailable — a headless
  // browser, a WebView with hardware acceleration switched off, a blocklisted
  // driver. Tell the app so it can show its own explanation instead of sitting
  // on "connecting" forever, and hide the canvas so the page is not a blank
  // black rectangle behind Flutter's message.
  canvas.hidden = true;
  bridge.send({ type: 'error', message: `cannot start WebGL: ${error}` });
  throw error;
}

bridge.on('setSpace', ({ space }) => scene.setSpace(space));
bridge.on('upsertItem', ({ item }) => scene.upsertItem(item));
bridge.on('removeItem', ({ id }) => scene.removeItem(id));
bridge.on('clearItems', () => scene.clearItems());
bridge.on('setView', ({ mode }) => scene.setView(mode));
bridge.on('setSelection', ({ id }) => scene.setSelection(id));
bridge.on('setInvalidItems', ({ ids }) => scene.setInvalidItems(ids));
bridge.on('ping', () => bridge.send({ type: 'pong' }));
bridge.on('setDebugOverlay', ({ visible }) => {
  debugOverlay = visible;
  fpsOverlay.hidden = !visible;
  if (!visible) fpsOverlay.textContent = '';
  scene.invalidate();
});

/**
 * The frame loop renders on demand: the scene marks itself dirty on every
 * change and every camera move, and a static plan therefore draws nothing at
 * all. That is the battery fix from `docs/PERF_NOTES.md`.
 *
 * The debug overlay is the opt-in exception. Measuring a frame rate needs
 * frames, so while it is on the scene draws every tick and reports `fps` once a
 * second — which is how the numbers in that document were taken.
 */
let debugOverlay = false;
let frames = 0;
let windowStart = performance.now();

function frame(now: number): void {
  if (debugOverlay) {
    scene.render();
    frames += 1;
    if (now - windowStart >= 1000) {
      const fps = Math.round((frames * 1000) / (now - windowStart));
      frames = 0;
      windowStart = now;
      fpsOverlay.textContent = `${fps} fps`;
      bridge.send({ type: 'fps', value: fps });
    }
  } else {
    scene.renderIfNeeded();
    frames = 0;
    windowStart = now;
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

bridge.send({ type: 'ready', protocol: PROTOCOL_VERSION, renderer: scene.rendererInfo() });
