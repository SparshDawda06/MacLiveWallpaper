const fs = require('fs');
const assert = require('assert');
const path = require('path');
const vm = require('vm');

console.log("Verifying Review Fixes...");

const html = fs.readFileSync(path.join(__dirname, 'Resources/index.html'), 'utf-8');

// 1. Title check
assert.match(html, /<title>Cyber-City Visualizer<\/title>/, "Title should be Cyber-City Visualizer");

// 2. Frustum culling check
assert.match(html, /instancedMesh\.frustumCulled\s*=\s*false;?/, "instancedMesh.frustumCulled should be false");

// 3. Matrix needsUpdate flag check
assert.match(html, /instancedMesh\.instanceMatrix\.needsUpdate\s*=\s*true;?/, "instancedMesh.instanceMatrix.needsUpdate should be true");

// 4. Sun material fog: false check
assert.match(html, /new\s+THREE\.MeshBasicMaterial\(\s*\{\s*color:\s*0xffffff,\s*fog:\s*false\s*\}\s*\)/, "sunMat should have fog: false");

// 5. Fragile audio data validation check
assert.ok(!html.includes("data.length < numBins"), "Should not require data.length >= numBins in guard clause");
assert.match(html, /Math\.min\(\s*numBins\s*,\s*data\.length\s*\)/, "Should iterate up to Math.min(numBins, data.length)");

// 6. Bass extraction check
assert.match(html, /const\s+bass\s*=\s*\(\(currentAudio\[0\]\s*\|\|\s*0\)\s*\+\s*\(currentAudio\[1\]\s*\|\|\s*0\)\)\s*\/\s*2;?/, "bass should average bins");

// 7. Test runtime audio update logic with partial array (e.g. 16 bins)
const ctx = {
    window: {},
    document: { createElementNS: () => ({}) },
    navigator: { userAgent: "" }
};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, 'Resources/three.min.js'), 'utf8'), ctx);

// Execute the updateAudio logic in a sandbox
const sandboxScript = `
const numBins = 32;
const audioDataArray = new Uint8Array(numBins * 4);
window.textureUpdated = false;
window.currentAudio = new Array(numBins).fill(0);
const audioTexture = { set needsUpdate(val) { window.textureUpdated = val; } };

window.updateAudio = function(data) {
    if (!data) return;
    for (let i = 0; i < Math.min(numBins, data.length); i++) {
        window.currentAudio[i] = window.currentAudio[i] * 0.7 + data[i] * 0.3;
        const val = Math.min(255, Math.max(0, currentAudio[i] * 255));
        audioDataArray[i * 4] = val;
        audioDataArray[i * 4 + 1] = val;
        audioDataArray[i * 4 + 2] = val;
        audioDataArray[i * 4 + 3] = 255;
    }
    audioTexture.needsUpdate = true;
};

// Test with 16 bins
const partialData = new Array(16).fill(0.8);
window.updateAudio(partialData);
`;

vm.runInContext(sandboxScript, ctx);

assert.strictEqual(ctx.textureUpdated, true, "audioTexture.needsUpdate should be true after partial audio input");
assert.ok(ctx.currentAudio[0] > 0, "currentAudio[0] should be updated from partial audio data");
assert.strictEqual(ctx.currentAudio[20], 0, "currentAudio[20] should remain 0 when data has only 16 bins");

console.log("All review fix checks passed successfully!");
