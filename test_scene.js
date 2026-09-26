const fs = require('fs');
const assert = require('assert');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'Resources/index.html'), 'utf-8');

console.log("Verifying Scene & Aesthetic Reset (Monochrome & Lighting)...");

// 1. Check body background color
assert.match(html, /background-color:\s*#000000/, "CSS background-color should be #000000");

// 2. Check fog configuration
assert.match(html, /scene\.fog\s*=\s*new\s+THREE\.FogExp2\(\s*0x000000\s*,\s*0\.015\s*\)/, "scene.fog should be FogExp2(0x000000, 0.015)");

// 3. Check material properties
assert.match(html, /color:\s*0x111111/, "material color should be 0x111111");
assert.match(html, /metalness:\s*0\.9/, "material metalness should be 0.9");
assert.match(html, /roughness:\s*0\.1/, "material roughness should be 0.1");

// 4. Check lights configuration
assert.match(html, /THREE\.AmbientLight\(\s*0xffffff\s*,\s*0\.2\s*\)/, "ambientLight intensity should be 0.2");
assert.match(html, /THREE\.DirectionalLight\(\s*0xffffff\s*,\s*2(?:\.0)?\s*\)/, "dirLight intensity should be 2.0");
assert.match(html, /dirLight\.position\.set\(\s*0\s*,\s*50\s*,\s*50\s*\)/, "dirLight position should be (0, 50, 50)");
assert.match(html, /backLight\.position\.set\(\s*0\s*,\s*10\s*,\s*-50\s*\)/, "backLight position should be (0, 10, -50)");

console.log("All scene & aesthetic checks passed!");
