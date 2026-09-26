# Cyber-City Visualizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the existing audio-reactive sphere into a monochrome, bird's-eye view cyber-city visualizer that reacts to system audio.

**Architecture:** Modifies the existing Three.js setup in `Resources/index.html`. Uses `THREE.InstancedMesh` on a flat XZ grid for buildings, a custom vertex shader for audio-reactive heights, and a scaling sphere for the background sun.

**Tech Stack:** HTML, JavaScript, Three.js (WebGL)

## Global Constraints

- Must run smoothly on standard Mac hardware (60fps).
- High-contrast monochrome aesthetic (black and white).
- Audio reactivity relies on the existing Swift `AudioAnalyzer` injecting data into `window.updateAudio`.

---

### Task 1: Scene & Aesthetic Reset (Monochrome & Lighting)

**Files:**
- Modify: `Resources/index.html`

**Interfaces:**
- Consumes: Existing Three.js scene setup.
- Produces: A black/white high-contrast scene with a dark reflective material for the instanced mesh.

- [ ] **Step 1: Write verification script**

Create `test_scene.js` (can be run via node with a dom parser or just visually verified, we'll write a visual check log):
```javascript
// Verification: Open index.html in a browser and check console for errors.
// Also verify fog color is 0x000000 and material color is 0x111111 (dark grey).
console.log("Visual verification step");
```

- [ ] **Step 2: Run verification**

Run: `open Resources/index.html` (or serve locally)
Expected: Scene is currently a sphere with white/gray colors.

- [ ] **Step 3: Write minimal implementation**

Modify `index.html`:
1. Change `scene.fog = new THREE.FogExp2(0x050505, 0.02);` to `scene.fog = new THREE.FogExp2(0x000000, 0.015);`
2. Change the background color in CSS body to `#000000`.
3. Update `material`:
```javascript
    const material = new THREE.MeshStandardMaterial({
        color: 0x111111, // Dark grey/black for high contrast reflections
        metalness: 0.9,
        roughness: 0.1,
    });
```
4. Update Lights:
```javascript
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.2);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 2.0);
    dirLight.position.set(0, 50, 50); // Overhead/Front stark white light
    scene.add(dirLight);
    
    // Remove backLight or set it to stark white as well
    const backLight = new THREE.DirectionalLight(0xffffff, 1.0);
    backLight.position.set(0, 10, -50);
    scene.add(backLight);
```

- [ ] **Step 4: Run verification**

Run: `open Resources/index.html`
Expected: Scene is much darker with stark white highlights on the existing sphere.

- [ ] **Step 5: Commit**

```bash
git add Resources/index.html
git commit -m "feat(visualizer): apply monochrome lighting and materials"
```

---

### Task 2: City Grid InstancedMesh Construction

**Files:**
- Modify: `Resources/index.html`

**Interfaces:**
- Consumes: The `material` from Task 1.
- Produces: A flat grid of boxes on the XZ plane instead of a sphere.

- [ ] **Step 1: Write verification script**

```javascript
// Verification: Ensure the InstancedMesh is arranged in a grid, not a sphere.
```

- [ ] **Step 2: Run verification**

Run: visually check `index.html`.
Expected: Still a sphere.

- [ ] **Step 3: Write minimal implementation**

Modify `index.html`. Replace the `SphereGeometry` instance placement code with a grid:

```javascript
    // The single voxel geometry (a skyscraper box)
    // Make it taller so it looks like a building
    const boxGeo = new THREE.BoxGeometry(0.8, 1.0, 0.8);
    
    // Create grid layout
    const gridCols = 64;
    const gridRows = 64;
    const count = gridCols * gridRows;
    const spacing = 1.2;
    
    const instancedMesh = new THREE.InstancedMesh(boxGeo, material, count);
    
    const dummy = new THREE.Object3D();
    let index = 0;
    for (let x = 0; x < gridCols; x++) {
        for (let z = 0; z < gridRows; z++) {
            // Center the grid around X=0, start Z from close to camera pushing back
            const posX = (x - gridCols / 2) * spacing;
            const posZ = -z * spacing; // Negative Z goes into the screen
            const posY = 0;
            
            dummy.position.set(posX, posY, posZ);
            dummy.updateMatrix();
            instancedMesh.setMatrixAt(index, dummy.matrix);
            index++;
        }
    }
    
    scene.add(instancedMesh);
    
    // Adjust camera for bird's-eye view
    camera.position.set(0, 15, 5);
    camera.lookAt(0, 0, -20);
    
    // Remove the slow rotation from animate()
    // instancedMesh.rotation.y = time * 0.05;
    // instancedMesh.rotation.z = time * 0.02;
```

- [ ] **Step 4: Run verification**

Run: `open Resources/index.html`
Expected: A vast grid of flat, dark boxes stretching into the darkness, viewed from above.

- [ ] **Step 5: Commit**

```bash
git add Resources/index.html
git commit -m "feat(visualizer): construct city grid instances and adjust camera"
```

---

### Task 3: Audio-Reactive Vertex Shader & Movement

**Files:**
- Modify: `Resources/index.html`

**Interfaces:**
- Consumes: The `instancedMesh` grid and `audioTexture`.
- Produces: Buildings that scale on the Y-axis based on audio, plus infinite forward scrolling.

- [ ] **Step 1: Write verification script**

```javascript
// Verification: The buildings should spike up based on the injected audio data.
```

- [ ] **Step 2: Run verification**

Run: visually check `index.html`.
Expected: Buildings are flat or doing weird sphere-based transforms.

- [ ] **Step 3: Write minimal implementation**

Modify the shader injection in `material.onBeforeCompile`:

```javascript
        shader.vertexShader = shader.vertexShader.replace(
            `#include <begin_vertex>`,
            `
            vec3 transformed = vec3(position);
            
            // Get base position of the instance on the grid
            vec3 instanceBasePos = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
            
            // Map X position to an audio frequency band (0.0 to 1.0)
            // Grid width is roughly 64 * 1.2 = 76.8, so from -38.4 to +38.4
            float xMap = clamp((instanceBasePos.x + 38.0) / 76.0, 0.0, 1.0);
            
            // Animate the Z position to simulate moving forward
            // The grid loops every 1.2 units (the spacing)
            float zOffset = mod(u_time * 5.0, 1.2);
            instanceBasePos.z += zOffset;
            
            // Audio data based on X position (creates a spectrum analyzer effect across the city)
            float band = texture2D(u_audioTex, vec2(xMap, 0.5)).r;
            
            // Noise fallback for silence
            float noiseDisp = snoise(vec3(instanceBasePos.x * 0.1, instanceBasePos.z * 0.1, u_time * 0.2)) * 0.5;
            
            // Calculate height spike (ensure it goes mostly up)
            // If band is 0, use noise. If band > 0, spike massively.
            float spike = max(noiseDisp, band * 15.0);
            
            // Scale the Y axis of the building
            transformed.y *= 1.0 + spike;
            // Shift up so it grows from the base instead of the center
            transformed.y += (1.0 + spike) * 0.5 - 0.5;
            
            // Apply the scrolling Z offset to the vertex
            transformed.z += zOffset;
            `
        );
```

- [ ] **Step 4: Run verification**

Run: `open Resources/index.html` (You can simulate audio by opening dev tools and running `window.updateAudio(new Array(32).fill(0.8))`).
Expected: Buildings rise up in a wave pattern based on noise, and spike heavily when audio data is provided. The city slowly scrolls forward.

- [ ] **Step 5: Commit**

```bash
git add Resources/index.html
git commit -m "feat(visualizer): inject audio-reactive shader for building heights"
```

---

### Task 4: The Bass Sun

**Files:**
- Modify: `Resources/index.html`

**Interfaces:**
- Consumes: The `currentAudio` array in Javascript.
- Produces: A large stark white sphere in the background that scales with the bass.

- [ ] **Step 1: Write verification script**

```javascript
// Verification: A white sphere exists far away and pulses.
```

- [ ] **Step 2: Run verification**

Run: visually check.
Expected: No sun exists.

- [ ] **Step 3: Write minimal implementation**

Modify `index.html`. Add the sun object:

```javascript
    // Add this after the instancedMesh creation
    const sunGeo = new THREE.SphereGeometry(10, 32, 32);
    const sunMat = new THREE.MeshBasicMaterial({ color: 0xffffff }); // Unlit stark white
    const sun = new THREE.Mesh(sunGeo, sunMat);
    sun.position.set(0, 5, -60); // Far back
    scene.add(sun);
```

Update the `animate()` function to scale the sun:

```javascript
    function animate() {
        requestAnimationFrame(animate);
        
        const time = clock.getElapsedTime();
        uniforms.u_time.value = time;
        
        // Extract bass from the lowest bin
        const bass = currentAudio[0] || 0; 
        
        // Scale sun based on bass, minimum scale 1.0
        const sunScale = 1.0 + (bass * 0.5);
        sun.scale.set(sunScale, sunScale, sunScale);

        renderer.render(scene, camera);
    }
```

- [ ] **Step 4: Run verification**

Run: `open Resources/index.html`
Expected: A massive white sphere in the distance that pulses when `currentAudio[0]` changes.

- [ ] **Step 5: Commit**

```bash
git add Resources/index.html
git commit -m "feat(visualizer): add pulsing background bass sun"
```
