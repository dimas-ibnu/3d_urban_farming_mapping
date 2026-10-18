import { defineConfig, type Plugin } from 'vite';

/**
 * Inlines the JS bundle and CSS into `index.html` so the build is a single file.
 *
 * The Android WebView loads the scene straight off `file:///android_asset/...`,
 * where the document origin is opaque: a `<script type="module" src="...">` would
 * be blocked by CORS. One self-contained HTML file with a classic `<script>` has
 * no subresources to fetch, so the same artifact works from `file://` (Android)
 * and from an `<iframe>` served by Flutter web.
 */
function inlineBundle(): Plugin {
  return {
    name: 'kebunku-inline-bundle',
    enforce: 'post',
    generateBundle(_options, bundle) {
      const html = Object.values(bundle).find(
        (f) => f.type === 'asset' && f.fileName.endsWith('.html'),
      );
      if (!html || html.type !== 'asset') return;

      let source = String(html.source);

      for (const [fileName, chunk] of Object.entries(bundle)) {
        if (chunk.type === 'chunk' && chunk.isEntry) {
          const tag = new RegExp(
            `<script[^>]*src="[^"]*${escapeRegExp(fileName)}"[^>]*></script>`,
          );
          // Vite emits the entry tag in <head>, which is fine for a deferred
          // module but not for the classic script we inline: it would run
          // before <canvas> exists. Drop the tag and re-add the code at the end
          // of <body>. The replacements use a *function*, not a string, because
          // minified code contains `$&` and friends that `String.replace` would
          // expand into the match.
          source = source.replace(tag, '');
          source = source.replace(
            '</body>',
            () => `  <script>\n${chunk.code}\n</script>\n  </body>`,
          );
          delete bundle[fileName];
        } else if (chunk.type === 'asset' && fileName.endsWith('.css')) {
          const tag = new RegExp(`<link[^>]*href="[^"]*${escapeRegExp(fileName)}"[^>]*>`);
          source = source.replace(tag, () => `<style>\n${String(chunk.source)}\n</style>`);
          delete bundle[fileName];
        }
      }

      // Nothing is fetched at runtime, so the preload hints are dead weight.
      source = source.replace(/<link[^>]*rel="modulepreload"[^>]*>/g, '');

      html.source = source;
    },
  };
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export default defineConfig({
  base: './',
  plugins: [inlineBundle()],
  build: {
    // Bundled into the Flutter app's assets so the scene works offline.
    outDir: '../app/assets/web3d',
    // The build is a single `index.html` that is overwritten every time, and the
    // directory also holds a checked-in `.gitkeep` that Flutter needs in order
    // to resolve the declared asset directory before the first build.
    emptyOutDir: false,
    target: 'es2020',
    assetsInlineLimit: Number.MAX_SAFE_INTEGER,
    cssCodeSplit: false,
    modulePreload: { polyfill: false },
    rollupOptions: {
      output: {
        format: 'iife',
        inlineDynamicImports: true,
        entryFileNames: 'main.js',
        assetFileNames: '[name][extname]',
      },
    },
  },
});
