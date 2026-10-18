# Three.js performance spike — kickoff measurements

From work item #1 of the breakdown in [APP_GOAL.md](APP_GOAL.md). Measured on the
kickoff bridge prototype (box balcony floor, pots with foliage, one shadow-casting
directional light with a 1024² PCF soft shadow map, device pixel ratio capped at 2,
antialiasing off).

The scene samples its own frame rate once a second and pushes it to the app as an
`fps` message, so every number below is the scene's own reading, not an estimate.

## Results

| Target | Hardware | Pots | FPS |
|---|---|---|---|
| Desktop Chrome | macOS, Apple M5, ANGLE Metal, 900×700 canvas | 8 | 60, steady (first second 38 while warming up) |
| Android WebView (`flutter_inappwebview`) | Pixel 7 emulator, Android API 37, arm64, host GPU | 1 | 51 |
| Android WebView (`flutter_inappwebview`) | Pixel 7 emulator, Android API 37, arm64, host GPU | 8 | 54–59 |
| Flutter web (`<iframe>`) | same as desktop Chrome | 1 | renders correctly; frame rate not sampled (see below) |

60 fps is the `requestAnimationFrame` ceiling, so desktop Chrome is not being
stressed at all by this scene.

## What was not measured

- **A real low-end Android device.** None was available. The emulator runs on the
  host GPU, so its numbers are an optimistic ceiling and say nothing about, say, a
  Helio-class phone with a slow GPU and 3 GB of RAM. Re-run this spike on a cheap
  physical device before the sun-hours heatmap lands (work item #5) — that is the
  first feature heavy enough to matter.
- **Chrome on Android.** Same reason: on the emulator it would run on the host GPU
  and tell us nothing the desktop number does not.
- **Flutter web frame rate.** Verified visually in a headless Chrome screenshot,
  but the capture used Chrome's virtual time, which makes any `fps` reading
  meaningless. The scene code is identical to the one measured at 60 fps directly,
  and the `<iframe>` adds no per-frame cost, so no separate risk is expected here.

## Risks found

- **WebGL may be missing entirely.** In a headless browser, or where hardware
  acceleration is switched off, creating the renderer throws. The scene now catches
  that and sends an `error` message so the app can say something instead of sitting
  on "connecting" forever. Worth a proper UI once the editor exists.
- **Shadows are the expensive part.** The shadow map is the obvious first thing to
  drop on a weak device. The sun-hours heatmap (work item #5) will add considerably
  more per-frame work, so budget for a quality switch then.
- **The scene renders every frame, always.** For a mostly static plan this is
  wasteful on battery. Rendering on demand (only after a change or a camera move)
  is the straightforward fix, deferred because the FPS sampling here needs a
  continuous loop.

## Follow-ups done in the editor ticket

Both of the fixable risks above were addressed when the layout editor landed
(work items #3 and #4):

- **Rendering on demand.** The scene now draws only after a change or a camera
  move; an untouched plan costs nothing per frame. The continuous loop survives
  as the opt-in debug mode behind `setDebugOverlay`, which is what the `fps`
  numbers in this document were measured with — so the measurement path is
  unchanged and this table stays comparable.
- **A real UI when WebGL is missing.** The `error` message now reaches a
  Flutter panel that explains what happened and keeps the plan and the
  growing-area summary usable behind it, instead of a dead canvas.

Still open: the measurement on a cheap physical Android device, and the quality
switch for shadows. Both belong with the sun-hours heatmap (work item #5),
which is the first feature heavy enough to force the question.
