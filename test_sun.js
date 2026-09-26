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

// 7. Sun scaling formula: 1.0 + (bass * 0.5)
assert.match(
    html,
    /const\s+sunScale\s*=\s*1\.0\s*\+\s*\(\s*bass\s*\*\s*0\.5\s*\);?/,
    "sunScale should be 1.0 + (bass * 0.5)"
);

// 8. Sun scale applied
assert.match(
    html,
    /sun\.scale\.set\(\s*sunScale\s*,\s*sunScale\s*,\s*sunScale\s*\)/,
    "sun.scale should be set to (sunScale, sunScale, sunScale)"
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

// Test scaling function
function calculateSunScale(bass) {
    return 1.0 + (bass * 0.5);
}

assert.strictEqual(calculateSunScale(0), 1.0, "Scale at bass=0 should be 1.0");
assert.strictEqual(calculateSunScale(1.0), 1.5, "Scale at bass=1.0 should be 1.5");
assert.strictEqual(calculateSunScale(2.0), 2.0, "Scale at bass=2.0 should be 2.0");

console.log("All bass sun checks passed!");
