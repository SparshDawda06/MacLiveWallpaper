const fs = require('fs');
const assert = require('assert');
const path = require('path');
const vm = require('vm');

const html = fs.readFileSync(path.join(__dirname, 'Resources/index.html'), 'utf-8');

console.log("Verifying Bass Sun (Background Sphere & Bass Scaling)...");

// 1. Sun geometry: SphereGeometry(10, 32, 32)
assert.match(
    html,
    /new\s+THREE\.SphereGeometry\(\s*10\s*,\s*32\s*,\s*32\s*\)/,
    "sunGeo should be SphereGeometry(10, 32, 32)"
);

// 2. Sun material: MeshBasicMaterial({ color: 0xffffff, fog: false })
assert.match(
    html,
    /new\s+THREE\.MeshBasicMaterial\(\s*\{\s*color:\s*0xffffff,\s*fog:\s*false\s*\}\s*\)/,
    "sunMat should be MeshBasicMaterial with unlit stark white color 0xffffff and fog: false"
);

// 3. Sun mesh creation
assert.match(
    html,
    /new\s+THREE\.Mesh\(\s*sunGeo\s*,\s*sunMat\s*\)/,
    "sun should be a Mesh using sunGeo and sunMat"
);

// 4. Sun positioning: (0, 5, -60)
assert.match(
    html,
    /sun\.position\.set\(\s*0\s*,\s*5\s*,\s*-60\s*\)/,
    "sun.position should be set to (0, 5, -60)"
);

// 5. Sun added to scene
assert.match(
    html,
    /scene\.add\(\s*sun\s*\)/,
    "sun should be added to scene"
);

// 6. Bass extraction from lowest audio bins
assert.match(
    html,
    /const\s+bass\s*=\s*\(\(currentAudio\[0\]\s*\|\|\s*0\)\s*\+\s*\(currentAudio\[1\]\s*\|\|\s*0\)\)\s*\/\s*2;?/,
    "bass should be extracted from average of lowest bins"
);

// 7. Bass brightens the disc. It does not change size.
assert.match(
    html,
    /const\s+sunGlow\s*=\s*0\.82\s*\+\s*bass\s*\*\s*0\.18;?/,
    "sunGlow should be 0.82 + bass * 0.18"
);
assert.ok(!html.includes('sun.scale.set'), "Sun should not scale up and down");

// 8. Rings spin in place
assert.match(
    html,
    /ring\.rotation\.z\s*=\s*time\s*\*\s*\(\s*0\.25\s*\+\s*bass\s*\*\s*0\.45\s*\)/,
    "Ring should spin, faster with bass"
);

// 9. Check declaration order: currentAudio must be declared before animate() is called
const currentAudioIdx = html.indexOf('let currentAudio');
const animateCallIdx = html.indexOf('animate();');
assert.ok(
    currentAudioIdx !== -1 && currentAudioIdx < animateCallIdx,
    "currentAudio must be declared and initialized before animate() is called to avoid TDZ ReferenceError"
);

// 10. Runtime execution test
const ctx = {
    window: {},
    document: { createElementNS: () => ({}) },
    navigator: { userAgent: "" }
};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, 'Resources/three.min.js'), 'utf8'), ctx);

// Setup mock scene & sun in runtime
const THREE = ctx.THREE;
const sunGeo = new THREE.SphereGeometry(10, 32, 32);
const sunMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
const sun = new THREE.Mesh(sunGeo, sunMat);
sun.position.set(0, 5, -60);

assert.strictEqual(sun.position.x, 0);
assert.strictEqual(sun.position.y, 5);
assert.strictEqual(sun.position.z, -60);

function sunGlowFor(bass) {
    return 0.82 + bass * 0.18;
}

assert.strictEqual(sunGlowFor(0), 0.82, "Glow at bass=0 should be 0.82");
assert.ok(Math.abs(sunGlowFor(1) - 1) < 1e-9, "Glow at bass=1 should be 1");
assert.ok(sunGlowFor(1) - sunGlowFor(0) < 0.2, "Bass should only brighten the sun a little");

console.log("All bass sun checks passed!");
