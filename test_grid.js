const fs = require('fs');
const assert = require('assert');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'Resources/index.html'), 'utf-8');

console.log("Verifying City Grid InstancedMesh Construction...");

// 1. Box geometry should be configured for skyscrapers: (0.8, 1.0, 0.8)
assert.match(
    html,
    /new\s+THREE\.BoxGeometry\(\s*0\.8\s*,\s*1(?:\.0)?\s*,\s*0\.8\s*\)/,
    "boxGeo should be BoxGeometry(0.8, 1.0, 0.8)"
);

// 2. Grid dimensions and count: 64x64 grid with spacing 1.2
assert.match(
    html,
    /gridCols\s*=\s*64/,
    "gridCols should be 64"
);
assert.match(
    html,
    /gridRows\s*=\s*64/,
    "gridRows should be 64"
);
assert.match(
    html,
    /spacing\s*=\s*1\.2/,
    "spacing should be 1.2"
);

// 3. InstancedMesh creation with boxGeo, material, and count
assert.match(
    html,
    /new\s+THREE\.InstancedMesh\(\s*boxGeo\s*,\s*material\s*,\s*count\s*\)/,
    "instancedMesh should use boxGeo, material, and count"
);

// 4. Grid positioning logic: centered on X, negative Z into distance, posY = 0
assert.match(
    html,
    /posX\s*=\s*\(\s*x\s*-\s*gridCols\s*\/\s*2\s*\)\s*\*\s*spacing/,
    "posX should center around X=0"
);
assert.match(
    html,
    /posZ\s*=\s*-z\s*\*\s*spacing/,
    "posZ should advance into negative Z"
);
assert.match(
    html,
    /dummy\.position\.set\(\s*posX\s*,\s*posY\s*,\s*posZ\s*\)/,
    "dummy.position should be set with (posX, posY, posZ)"
);

// 5. Camera bird's-eye view setup
assert.match(
    html,
    /camera\.position\.set\(\s*0\s*,\s*15\s*,\s*5\s*\)/,
    "camera position should be set to (0, 15, 5)"
);
assert.match(
    html,
    /camera\.lookAt\(\s*0\s*,\s*0\s*,\s*-20\s*\)/,
    "camera should lookAt (0, 0, -20)"
);

// 6. Old sphere placement should be removed
assert.ok(
    !html.includes('new THREE.SphereGeometry(radius'),
    "SphereGeometry for instance placement should be removed"
);

// 7. Slow rotation in animate() should be removed or disabled
assert.ok(
    !html.match(/^[ \t]*instancedMesh\.rotation\.y\s*=\s*time/m),
    "instancedMesh.rotation.y in animate() should be removed or commented out"
);

console.log("All city grid checks passed!");
