import { Bridge } from './bridge';
import { PROTOCOL_VERSION } from './protocol';
import { Scene } from './scene';

const canvas = document.getElementById('scene') as HTMLCanvasElement;
const fpsOverlay = document.getElementById('fps') as HTMLDivElement;

const bridge = new Bridge();

let scene: Scene;
try {
  scene = new Scene(canvas, (id) => bridge.send({ type: 'selected', id }));
} catch (error) {
  // Creating the renderer fails where WebGL is unavailable — a headless browser,
  // a WebView with hardware acceleration switched off, a blocklisted driver.
  // Tell the app instead of dying quietly and leaving it on "connecting".
  bridge.send({ type: 'error', message: `cannot start WebGL: ${error}` });
  throw error;
}

bridge.on('setFloor', ({ width, depth }) => scene.setFloor(width, depth));
bridge.on('addPot', (message) => scene.addPot(message));
bridge.on('removePot', ({ id }) => scene.removePot(id));
bridge.on('clearPots', () => scene.clearPots());
bridge.on('ping', () => bridge.send({ type: 'pong' }));
bridge.on('setDebugOverlay', ({ visible }) => {
  fpsOverlay.hidden = !visible;
});

// FPS is sampled once a second and pushed to the app, which is how the
// WebView-vs-browser performance numbers in the README were measured.
let frames = 0;
let windowStart = performance.now();

function frame(now: number): void {
  scene.render();
  frames += 1;
  if (now - windowStart >= 1000) {
    const fps = Math.round((frames * 1000) / (now - windowStart));
    frames = 0;
    windowStart = now;
    fpsOverlay.textContent = `${fps} fps`;
    bridge.send({ type: 'fps', value: fps });
  }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

bridge.send({ type: 'ready', protocol: PROTOCOL_VERSION, renderer: scene.rendererInfo() });
