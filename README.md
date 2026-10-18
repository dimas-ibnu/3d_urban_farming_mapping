# 3D Urban Farming Mapping

A small-space urban farming planner: model your balcony, terrace or small yard in 3D, see how much sun each spot gets, and get a planting plan that makes the most of the space. Indonesia first.

Built with Flutter (web + Android) and Three.js.

- Product goal, tech stack and release plan: [docs/APP_GOAL.md](docs/APP_GOAL.md)

## Layout

```
app/     Flutter app (web + Android), Bahasa Indonesia default, English second
web3d/   Three.js scene (TypeScript, Vite); builds into app/assets/web3d/
docs/    Product and technical docs
.github/ CI workflows
```

## Requirements

- Flutter 3.44.1 (Dart 3.12) — the version CI pins
- Node.js 22+
- Android SDK and a JDK 21 for the Android build

## Build and run

The 3D scene is a **build input for the Flutter app**, so build `web3d/` first. Its
output is a single self-contained `app/assets/web3d/index.html`, which Flutter
bundles as an asset — that is what makes the scene work offline, and why the
Vite build inlines the JS and CSS instead of emitting separate files (an Android
WebView loading `file://` has an opaque origin and cannot fetch a module script).

```bash
# 1. Build the 3D scene into app/assets/web3d/
cd web3d
npm install
npm run build

# 2. Run the app
cd ../app
flutter pub get          # also generates lib/l10n/gen from the ARB files
flutter run -d chrome    # web
flutter run              # Android device or emulator
```

Re-run `npm run build` in `web3d/` after any change there; Flutter does not pick
up scene changes on hot reload because the scene is an asset, not Dart code.

To iterate on the scene alone, `npm run dev` in `web3d/` serves it at
`http://localhost:5173`. It renders standalone — with no host to talk to it just
queues its outgoing messages.

### Checks

```bash
cd web3d && npm run lint && npm run typecheck && npm run build
cd ../app && dart format . && flutter analyze && flutter test
```

CI (`.github/workflows/ci.yml`) runs exactly these, plus `flutter build web
--release` and `flutter build apk --debug`.

## The Flutter ↔ Three.js bridge

The app owns all state; the scene only renders what it is told and reports back
what the user touched. They speak a versioned JSON protocol, defined twice and
kept in sync by hand:

- `web3d/src/protocol.ts`
- `app/lib/bridge/web3d_protocol.dart`

Every envelope carries `v` (currently `1`). Either side drops messages from a
version it does not know rather than guessing at their shape.

| Direction | Messages |
|---|---|
| App → scene | `setFloor`, `addPot`, `removePot`, `clearPots`, `setDebugOverlay`, `ping` |
| Scene → app | `ready`, `selected`, `pong`, `fps`, `error` |

One Dart interface, `Web3dBridge`, hides the two transports:

| Target | Embedding | App → scene | Scene → app |
|---|---|---|---|
| Android | `flutter_inappwebview`, asset loaded from `file://` | `evaluateJavascript` into `window.kebunku.receive` | `flutter_inappwebview` JS handler |
| Web | `<iframe>` in an `HtmlElementView` | `postMessage` to the iframe | `postMessage` to `window.parent` |

Commands sent before the scene is up are queued and replayed in order, so
callers never have to wait for the handshake.

## Current state

`app/lib/scene_page.dart` is the bridge prototype from the kickoff ticket: a
box-shaped balcony floor with pots you can add, clear and tap. Drag orbits the
camera; a tap picks a pot and the scene answers with `selected`. The real editor,
the sun engine, the crop database and storage are later tickets — see the work
breakdown in [docs/APP_GOAL.md](docs/APP_GOAL.md).

## Localisation

Strings live in `app/lib/l10n/*.arb`; `app_id.arb` (Bahasa Indonesia) is the
template and the default locale, `app_en.arb` is the English translation.
`flutter pub get` regenerates `app/lib/l10n/gen/`, which is not checked in. Add
new strings to both files and never hard-code user-visible text.

## Deploying the web app

The web app is hosted on [Netlify](https://www.netlify.com/). GitHub Actions builds and deploys it (`.github/workflows/deploy.yml`). Netlify does not build it.

Both workflows (`ci.yml` and `deploy.yml`) run **only on pushes to `main`**, i.e. when a PR is merged. Pull requests and feature branches don't trigger them. Each merge to `main` runs CI and a production deploy.

Branch workflow: branch out from the latest `main`, push the branch, open a PR against `main`, and merge it.

The workflow:

1. Builds `web3d/` (`npm ci && npm run build`). Vite writes one self-contained `index.html` into `app/assets/web3d/`.
2. Builds the Flutter web app (`flutter build web --release`). The scene ends up at `app/build/web/assets/assets/web3d/index.html`.
3. Deploys `app/build/web` with the Netlify CLI (`netlify deploy --no-build`), run from the repo root so `netlify.toml` is applied.

`netlify.toml` sets the SPA fallback (`/* /index.html 200`), the MIME types for `.wasm` and `.js`, and caching. Flutter's entry files (`index.html`, `main.dart.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`) and the web3d scene are served with `no-cache`, so users get the new version after each deploy.

### Required secrets

Add these under **Settings → Secrets and variables → Actions** in the GitHub repo. Never commit them.

| Secret | Where to get it |
|---|---|
| `NETLIFY_AUTH_TOKEN` | Netlify → User settings → Applications → Personal access tokens |
| `NETLIFY_SITE_ID` | Netlify → Site configuration → General → Site details → Site ID |

If either secret is missing, the build still runs and the deploy steps are skipped with a notice.

### One-time Netlify setup

1. Create the site in Netlify (**Add new site → Deploy manually** is enough; it doesn't need to be linked to the repo).
2. Turn off Netlify's own builds: **Site configuration → Build & deploy → Continuous deployment → Build settings → Stop builds**. GitHub Actions builds every commit, so Netlify must not build it again. As a backstop, `netlify.toml` also sets `ignore = "exit 0"`, which cancels any Netlify build that does start.
3. Add the two secrets above.
