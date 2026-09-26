const fs = require('fs');
const assert = require('assert');
const path = require('path');
const vm = require('vm');

const html = fs.readFileSync(path.join(__dirname, 'Resources/index.html'), 'utf-8');

console.log("Verifying Audio-Reactive Vertex Shader & Movement...");

// 1. Check for instanceBasePos extraction from instanceMatrix
assert.match(
    html,
    /vec3\s+instanceBasePos\s*=\s*vec3\(\s*instanceMatrix\[3\]\[0\]\s*,\s*instanceMatrix\[3\]\[1\]\s*,\s*instanceMatrix\[3\]\[2\]\s*\);/,
    "Shader should extract instanceBasePos from instanceMatrix"
);

// 2. Check for X coordinate mapping to audio frequency band
assert.match(
    html,
    /float\s+xMap\s*=\s*clamp\(\s*\(instanceBasePos\.x\s*\+\s*38(?:\.0)?\)\s*\/\s*76(?:\.0)?\s*,\s*0\.0\s*,\s*1\.0\s*\);/,
    "Shader should map instanceBasePos.x to [0.0, 1.0] frequency band"
);

// 3. Each building moves on its own phase instead of the whole grid sliding together
assert.match(
    html,
    /float\s+phase\s*=\s*instanceBasePos\.x\s*\*\s*0\.37\s*\+\s*instanceBasePos\.z\s*\*\s*0\.23;/,
    "Shader should give each building its own phase"
);
assert.match(
    html,
    /transformed\.x\s*\+=\s*sway\s*\*\s*0\.1;/,
    "Shader should sway each building on X"
);
assert.match(
    html,
    /transformed\.z\s*\+=\s*cos\(\s*u_time\s*\*\s*0\.95\s*\+\s*phase\s*\)\s*\*\s*0\.1;/,
    "Shader should sway each building on Z"
);

// 4. Check audio texture sampling using xMap
assert.match(
    html,
    /float\s+band\s*=\s*texture2D\(\s*u_audioTex\s*,\s*vec2\(\s*xMap\s*,\s*0\.5\s*\)\s*\)\.r;/,
    "Shader should sample u_audioTex at vec2(xMap, 0.5)"
);

// 5. Check noise displacement fallback
assert.match(
    html,
    /float\s+noiseDisp\s*=\s*snoise\(\s*vec3\(\s*instanceBasePos\.x\s*\*\s*0\.1\s*,\s*instanceBasePos\.z\s*\*\s*0\.1\s*,\s*u_time\s*\*\s*0\.2\s*\)\s*\)\s*\*\s*0\.5;/,
    "Shader should compute 3D snoise displacement using instanceBasePos and u_time"
);

// 6. Check spike calculation
assert.match(
    html,
    /float\s+spike\s*=\s*clamp\(\s*max\(\s*noiseDisp\s*,\s*band\s*\*\s*0\.55\s*\)\s*,\s*0\.0\s*,\s*0\.6\s*\);/,
    "Shader should cap spike at 0.6 so buildings do not rise too high"
);

// 7. Check Y-axis scaling and base-anchoring
assert.match(
    html,
    /transformed\.y\s*\*=\s*1\.0\s*\+\s*spike;/,
    "Shader should scale transformed.y by 1.0 + spike"
);
assert.match(
    html,
    /transformed\.y\s*\+=\s*\(1\.0\s*\+\s*spike\)\s*\*\s*0\.5\s*-\s*0\.5;/,
    "Shader should offset transformed.y to grow from base"
);

// 8. Shared grid scroll should be gone; motion is per building
assert.ok(
    !html.includes('float zOffset'),
    "Shared zOffset scroll should be removed"
);

// 9. Ensure old sphere transforms are removed
assert.ok(
    !html.includes('vec3 dir = normalize(instanceBasePos);'),
    "Old sphere normal direction calculation should be removed"
);
assert.ok(
    !html.includes('transformed.z *= 1.0 + spike;'),
    "Old Z-scaling spike transform should be removed"
);

// 10. Runtime execution test of onBeforeCompile hook
const ctx = {
    window: {},
    document: { createElementNS: () => ({}) },
    navigator: { userAgent: "" }
};
ctx.window = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, 'Resources/three.min.js'), 'utf8'), ctx);

const fnMatch = html.match(/material\.onBeforeCompile\s*=\s*(\(shader\)\s*=>\s*\{[\s\S]*?\n\s*\});/);
assert.ok(fnMatch, "material.onBeforeCompile function definition should be found");
const onBeforeCompile = eval(fnMatch[1]);

const dummyShader = {
    uniforms: {},
    vertexShader: "#include <begin_vertex>\nvoid main() {}"
};
const uniforms = {
    u_audioTex: { value: {} },
    u_time: { value: 0 }
};

onBeforeCompile(dummyShader);

assert.strictEqual(dummyShader.uniforms.u_audioTex, uniforms.u_audioTex, "u_audioTex uniform should be attached");
assert.strictEqual(dummyShader.uniforms.u_time, uniforms.u_time, "u_time uniform should be attached");
assert.ok(dummyShader.vertexShader.includes("transformed.y *="), "Vertex shader should include transformed.y scaling");
assert.ok(dummyShader.vertexShader.includes("transformed.x += sway * 0.1;"), "Vertex shader should sway each building individually");

console.log("All audio-reactive vertex shader checks passed!");
