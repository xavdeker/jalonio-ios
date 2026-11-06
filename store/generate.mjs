// SPDX-License-Identifier: EUPL-1.2
// Icône et logo de l'application iOS, exportés par Chrome sans interface (comme la fiche Android).
// node store/generate.mjs  (Playwright du dépôt jalonio)
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const require = createRequire("/var/www/jalonio/frontend/package.json");
const { chromium } = require("@playwright/test");
const dir = dirname(fileURLToPath(import.meta.url));
const assets = join(dir, "../Jalonio/Resources/Assets.xcassets");
// Symbole Jalonio (vitrine/build.mjs du dépôt jalonio) ; trait clair en mode sombre
const mark = (size, ink = "#111315") => `<svg width="${size}" height="${size}" viewBox="0 0 48 48"><defs><clipPath id="h"><rect x="27" y="3" width="9" height="30" rx="4.5"/></clipPath></defs><path d="M31.5 28 V33 A8 8 0 0 1 15.5 33" fill="none" stroke="${ink}" stroke-width="9" stroke-linecap="round"/><g clip-path="url(#h)"><rect x="27" y="3" width="9" height="8" fill="#ff4f8b"/><rect x="27" y="11" width="9" height="7" fill="${ink}"/><rect x="27" y="18" width="9" height="7" fill="#ff4f8b"/><rect x="27" y="25" width="9" height="8" fill="${ink}"/></g></svg>`;
const centered = (size, background, content) => `<body style="margin:0;width:${size}px;height:${size}px;background:${background};display:grid;place-items:center">${content}</body>`;
// L'App Store exige une icône carrée de 1024 px, opaque (iOS arrondit les angles lui-même)
const pages = {
  "AppIcon.appiconset/AppIcon-1024.png": [1024, centered(1024, "#fff", mark(760)), false],
};
for (const scale of [1, 2, 3]) {
  pages[`Logo.imageset/logo@${scale}x.png`] = [72 * scale, centered(72 * scale, "transparent", mark(72 * scale)), true];
  pages[`Logo.imageset/logo-dark@${scale}x.png`] = [72 * scale, centered(72 * scale, "transparent", mark(72 * scale, "#f5f9fa")), true];
}
const browser = await chromium.launch();
for (const [file, [size, body, transparent]] of Object.entries(pages)) {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  await page.setContent(`<!doctype html><html><head><meta charset="utf-8"></head>${body}</html>`);
  mkdirSync(dirname(join(assets, file)), { recursive: true });
  await page.screenshot({ path: join(assets, file), omitBackground: transparent });
  console.log(file);
}
await browser.close();
