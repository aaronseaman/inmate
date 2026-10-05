// Rasterizes SVG snapshots with the pre-installed Chromium (development only).
// usage: node tools/svg2png.js in1.svg [in2.svg ...]  -> writes .png next to each
// Uses a local 'playwright' install if present, else PLAYWRIGHT_MODULE, else this container's global path.
let pw;
try { pw = require('playwright'); } catch (e) { pw = require(process.env.PLAYWRIGHT_MODULE || '/opt/node22/lib/node_modules/playwright'); }
const { chromium } = pw;
const fs = require('fs');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2 });
  for (const f of process.argv.slice(2)) {
    const svg = fs.readFileSync(f, 'utf8');
    const m = svg.match(/width="(\d+)" height="(\d+)"/);
    const w = parseInt(m[1]), h = parseInt(m[2]);
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    // Shrink-to-fit, as iOS does: text wider than its box's remaining width gets a smaller font.
    await page.evaluate(() => {
      const ctx = document.createElement('canvas').getContext('2d');
      for (const t of document.querySelectorAll('text[data-maxw]')) {
        const size = parseFloat(t.getAttribute('font-size'));
        ctx.font = `${t.getAttribute('font-weight')} ${size}px ${t.getAttribute('font-family')}`;
        const w = ctx.measureText(t.textContent).width, max = parseFloat(t.dataset.maxw);
        if (w > max) t.setAttribute('font-size', Math.max(6, size * max / w).toFixed(2));
      }
    });
    await page.screenshot({ path: f.replace(/\.svg$/, '.png'), clip: { x: 0, y: 0, width: w, height: h } });
  }
  await browser.close();
})();
