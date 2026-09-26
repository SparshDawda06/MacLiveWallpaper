# Cyber-City Audio Visualizer Design

## 1. Overview
The goal is to replace the existing audio-reactive sphere wallpaper with a "Cyber-City" audio visualizer. The new visualizer will feature a high-contrast monochrome aesthetic (black and white) from a bird's-eye perspective, providing a sleek, modern, and highly reactive desktop experience.

## 2. Visual Architecture & Three.js Components
*   **The Cityscape (InstancedMesh):** Thousands of box geometries (`THREE.BoxGeometry`) will be arranged on a flat XZ grid extending into the distance, representing skyscrapers. `THREE.InstancedMesh` will be used for high performance.
*   **Building Aesthetics:** The buildings will use a dark, highly metallic `THREE.MeshStandardMaterial`. They will be solid and reflective, catching the stark white lighting.
*   **The Bass Sun:** A massive, stark white glowing sphere will sit far in the background (`Z = -far`), pulsing in scale and brightness based on the heaviest bass frequencies.
*   **Camera & Lighting:** 
    *   **Perspective:** Bird's-eye view, looking down and slightly forward over the massive city grid.
    *   **Lighting:** Strong white directional lighting and ambient light to create high-contrast reflections on the dark metallic buildings. 
    *   **Atmosphere:** Dense black fog (`THREE.FogExp2`) will fade the distant buildings into complete darkness.
    *   **Movement:** The city grid (or camera) will continuously translate along the Z-axis, simulating endless forward motion over the city.

## 3. Data Flow & Audio-Reactivity
*   **Audio Pipeline:** The existing Swift `AudioAnalyzer` (32 bins) and `audioTexture` will remain unchanged.
*   **Building Heights:** A custom vertex shader will be injected into the building material using `onBeforeCompile`. Each building's world position will be mapped to a specific frequency band from the `audioTexture`. The building's Y-scale (height) will spike dynamically based on that frequency.
*   **Sun Pulsing:** The main JavaScript `animate()` loop will sample the lowest frequency bin (bass) and scale the background sun uniformly.

## 4. Performance & Error Handling
*   **GPU Offloading:** By utilizing `THREE.InstancedMesh` and custom vertex shaders, the CPU only updates the audio texture and time uniform once per frame. All position and scale transformations happen on the GPU.
*   **Shadows:** Cast-shadows will be disabled to ensure a smooth 60fps framerate on standard Mac hardware.
*   **Silence Fallback:** If no audio is detected, the vertex shader will use a slow, sweeping Simplex noise function to gently roll the building heights. This ensures the city remains visually interesting and alive even in complete silence.
