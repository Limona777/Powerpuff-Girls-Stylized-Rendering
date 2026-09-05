# Powerpuff Girls Stylized Rendering

> A Unity-based stylized rendering project featuring **Comic-Style Cel Shading** and **Multi-Pass Fur Rendering**, themed around The Powerpuff Girls.

[![Platform](https://img.shields.io/badge/Platform-PC-blue)]()
[![Engine](https://img.shields.io/badge/Engine-Unity%202020.3%2B-orange)]()
[![Language](https://img.shields.io/badge/Language-HLSL%20%2F%20Cg%20%2F%20ShaderLab-green)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)]()

---

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Installation & Setup](#installation--setup)
- [Shader Documentation](#shader-documentation)
  - [Fur Rendering](#fur-rendering)
  - [Comic Style Rendering](#comic-style-rendering)
- [Models & Animation](#models--animation)
- [Dependencies](#dependencies)
- [Controls](#controls)
- [Known Issues & Limitations](#known-issues--limitations)
- [References](#references)
- [License](#license)
- [Author](#author)

---

## 🎯 Overview

This project is an independent research & development endeavor exploring **non-photorealistic rendering (NPR)** techniques in Unity. It consists of two core rendering systems:

1. **Multi-Pass Shell Fur** — Procedurally generates fur layers extruded along vertex normals, with per-shell alpha fading and noise-based perturbation.
2. **Math-Driven Comic Shader** — A texture-free, two-pass cel-shading system using fractal noise to dynamically deform light thresholds, producing halftone dots, cross-hatching, and fine-line details entirely in shader code.

Both systems are demonstrated using **The Powerpuff Girls** as the art-direction reference.

### Tech Stack

| Category | Details |
|---|---|
| **Platform** | PC (Windows / macOS) |
| **Engine** | Unity 2020.3 LTS or higher |
| **Shading Language** | HLSL / Cg (ShaderLab) |
| **Render Pipeline** | Built-in Render Pipeline |
| **Role** | Independent Development |

---

## ✨ Features

### Fur Rendering
- Multi-pass shell technique (configurable shell count)
- Vertex displacement along surface normals
- Noise texture sampling with UV offset to break shell regularity
- Per-layer alpha computation with progressive outer-shell fade-out
- Combined lighting model: Half-Lambert diffuse + Simulated AO + Fresnel rim light
- Anisotropic Kajiya-Kay specular with shifted tangent directions

### Comic Style Rendering
- Fully math-driven — **no pre-authored shading textures required**
- Two-pass setup: Outline Pass + Main Cartoon Pass
- Quantized Lambert lighting into Dark / Mid / Bright bands
- Fractal noise distorts the mid→bright threshold for organic feel
- Procedural shadow hatching: cross-hatch, single-hatch, fine scratch lines
- Halftone dots and masked fine lines in lit areas
- Directional screen-space sampling for pattern orientation

---

## 📁 Project Structure

```
Powerpuff-Girls-Stylized-Rendering/
├── Assets/
│   ├── Shaders/
│   │   ├── Fur/
│   │   │   ├── Fur.shader              # Multi-pass shell fur shader
│   │   │   └── FurNoise.png            # Noise texture for fur perturbation
│   │   ├── Comic/
│   │   │   ├── ComicOutline.shader     # Outline pass (inverted hull)
│   │   │   ├── ComicMain.shader        # Main cel-shading pass
│   │   │   └── ComicNoise.png          # Value noise for threshold distortion
│   │   └── Common/
│   │       └── Lighting.cginc          # Shared lighting functions (Half-Lambert, Fresnel, Kajiya-Kay)
│   ├── Materials/
│   │   ├── PP_Blossom_Fur.mat
│   │   ├── PP_Bubbles_Fur.mat
│   │   ├── PP_Buttercup_Fur.mat
│   │   └── Comic_Demo.mat
│   ├── Models/
│   │   ├── Blossom.fbx
│   │   ├── Bubbles.fbx
│   │   ├── Buttercup.fbx
│   │   └── DemoScene_Model.fbx
│   ├── Animations/
│   │   ├── Idle.anim
│   │   ├── Run.anim
│   │   └── ComicDemo.controller
│   ├── Textures/
│   │   ├── BaseColor_Blossom.png
│   │   ├── BaseColor_Bubbles.png
│   │   ├── BaseColor_Buttercup.png
│   │   └── ProceduralPatterns/          # Generated pattern references
│   ├── Scenes/
│   │   ├── FurDemo.unity
│   │   └── ComicDemo.unity
│   └── Scripts/
│       ├── FurController.cs             # Runtime shell-count & density adjustment
│       └── ComicLightingController.cs   # Runtime light-band parameter adjustment
├── ProjectSettings/
├── Packages/
└── README.md
```

---

## 🚀 Installation & Setup

### Prerequisites

- **Unity** 2020.3 LTS or newer (Built-in Render Pipeline)
- A graphics card with **Shader Model 4.0+** support
- Windows 10+ / macOS 11+

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/Limona777/Powerpuff-Girls-Stylized-Rendering.git
   ```

2. **Open in Unity**
   - Launch Unity Hub → **Open** → Select the cloned folder.

3. **Open a demo scene**
   - `Assets/Scenes/FurDemo.unity` — Multi-pass fur rendering showcase
   - `Assets/Scenes/ComicDemo.unity` — Comic style rendering showcase

4. **Press Play** ▶️

---

## 🔬 Shader Documentation

### Fur Rendering

The fur shader uses a **multi-pass shell technique**: each pass renders a displaced shell layer by offsetting vertices along the normal. The noise texture is sampled with an additional UV offset to break up shell regularity. Alpha is computed per layer, making outer shells progressively fade out.

#### Algorithm Overview

```
For each shell layer i (0 → N-1):
    displacement  = normal * (shellHeight * (i / N))
    alpha         = lerp(opacity, 0, (i / N)) * noise(uv + offset)
    color         = baseColor * lighting(displacement)
```

#### Lighting Model

| Component | Description |
|---|---|
| **Half-Lambert Diffuse** | `dot(N, L) * 0.5 + 0.5` — Soft, wrap-around diffuse |
| **Simulated AO** | Darkens deeper shell layers to fake self-shadowing |
| **Fresnel Rim Light** | `pow(1 - dot(N, V), rimPower)` — Adds a stylized rim glow |
| **Kajiya-Kay Specular** | Anisotropic highlight; shifts the bitangent toward the normal and evaluates two shifted tangent directions |

#### Key Properties (Material Inspector)

| Property | Type | Default | Description |
|---|---|---|---|
| `_ShellCount` | Int | 16 | Number of shell layers |
| `_ShellHeight` | Float | 0.05 | Total fur length |
| `_ShellNoise` | Texture2D | — | Noise texture for irregularity |
| `_NoiseScale` | Float | 10.0 | UV tiling for noise |
| `_Opacity` | Float | 0.8 | Base fur opacity |
| `_RimPower` | Float | 3.0 | Fresnel exponent |
| `_AOStrength` | Float | 0.5 | Simulated AO intensity |

#### ShaderLab Pass Structure

```hlsl
// Pseudocode — actual implementation in Shaders/Fur/Fur.shader
SubShader {
    Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

    // Pass 0: First shell (base mesh)
    // Pass 1..N-1: Subsequent shells with increasing displacement
    // Each pass:
    //   1. Offset vertex along normal
    //   2. Sample noise with UV offset
    //   3. Compute per-layer alpha
    //   4. Apply combined lighting
}
```

---

### Comic Style Rendering

This comic shader uses a **two-pass setup**: an outline pass and a main cartoon pass that quantizes Lambert lighting into dark/mid/bright bands, distorting the mid→bright threshold with fractal noise. Shadow bands are filled with procedural hatching (cross-hatch, single-hatch, and fine scratch lines), whose angle, thickness, and breakage are modulated by value noise. Lit areas receive halftone dots and masked fine lines. Final color is the base texture multiplied by the blended pattern.

#### Pass 1: Outline Pass

- **Technique**: Inverted hull (vertex extrusion along normals)
- **Rendering**: Back-face culling reversed, solid outline color
- **Configurable**: Outline thickness & color per material

```hlsl
// Outline vertex displacement
float4 outlinePos = UnityObjectToClipPos(
    vertex.xyz + normal * _OutlineThickness
);
```

#### Pass 2: Main Cartoon Pass

**Lighting Quantization:**

```
NdotL     = dot(worldNormal, lightDir)
halfLambert = NdotL * 0.5 + 0.5
threshold  = 0.5 + fractalNoise(uv * noiseScale) * 0.15  // distorted threshold

if   halfLambert < 0.33        → DARK band
elif halfLambert < threshold    → MID band  (hatching fills here)
else                            → BRIGHT band (halftone dots)
```

**Procedural Pattern Layer:**

| Pattern | Condition | Modulation |
|---|---|---|
| **Cross-hatch** | Darkest shadows | Angle & thickness via value noise |
| **Single-hatch** | Mid shadows | Line breakage via noise |
| **Fine scratches** | Transition zones | Random displacement |
| **Halftone dots** | Lit areas | Dot size = light intensity |
| **Masked fine lines** | Highlight edges | Screen-space direction |

**Final Composition:**

```
finalColor = baseTexture * lerp(patternColor, float3(1,1,1), litMask)
```

#### Key Properties (Material Inspector)

| Property | Type | Default | Description |
|---|---|---|---|
| `_BaseColor` | Color | White | Albedo tint |
| `_DarkColor` | Color | (0.2, 0.2, 0.3) | Shadow band color |
| `_MidColor` | Color | (0.6, 0.6, 0.7) | Mid-tone color |
| `_BrightColor` | Color | (1.0, 1.0, 1.0) | Highlight color |
| `_OutlineThickness` | Float | 0.02 | Outline width in object space |
| `_NoiseScale` | Float | 5.0 | Fractal noise frequency |
| `_HatchDensity` | Float | 8.0 | Hatching line density |
| `_HalftoneSize` | Float | 4.0 | Halftone dot scale |

---

## 🎬 Models & Animation

The project includes character models inspired by The Powerpuff Girls (Blossom, Bubbles, Buttercup) with idle and locomotion animations.

| Asset | Description |
|---|---|
| `Blossom.fbx` | Main demo character with rigging |
| `Bubbles.fbx` | Secondary character |
| `Buttercup.fbx` | Tertiary character |
| `Idle.anim` | Idle breathing animation |
| `Run.anim` | Running cycle |
| `ComicDemo.controller` | Animator controller for comic scene |

> **Note:** Models are for educational/demo purposes. Please ensure you have the rights to use any copyrighted character assets in your own projects.

---

## 📦 Dependencies

| Package | Version | Purpose |
|---|---|---|
| Unity Built-in Render Pipeline | 2020.3+ | Core rendering |
| No third-party packages required | — | Pure shader-based solution |

---

## 🎮 Controls

| Key | Action |
|---|---|
| `W` / `↑` | Move forward |
| `S` / `↓` | Move backward |
| `A` / `←` | Strafe left |
| `D` / `→` | Strafe right |
| `Mouse` | Orbit camera |
| `Scroll Wheel` | Zoom in/out |
| `1` | Toggle Fur Demo scene |
| `2` | Toggle Comic Demo scene |

---

## ⚠️ Known Issues & Limitations

1. **Shell Count vs Performance** — High shell counts (>32) may impact frame rate on lower-end GPUs.
2. **Built-in Pipeline Only** — Shaders are written for the Built-in Render Pipeline; URP/HDRP compatibility is not guaranteed.
3. **Alpha Sorting** — Transparent fur shells may exhibit sorting artifacts in complex overlapping geometry.
4. **No Shadow Receiving** — The fur shader does not currently receive cast shadows from other objects.

---

## 📚 References

- **Kajiya-Kay Anisotropic Reflection Model** — *Kajiya, J. T., & Kay, T. L. (1989). Rendering fur with three dimensional textures.*
- **Shell Rendering Technique** — *Lengyel, J. (2001). Fur rendering with shell textures.*
- **Cel Shading / Toon Shading** — *Lake, A. et al. (2000). Stylized rendering techniques for scalable real-time 3D animation.*
- **The Powerpuff Girls** — Cartoon Network (character design reference only)

---

## 🔗 GitHub Repository

👉 **https://github.com/Limona777/Powerpuff-Girls-Stylized-Rendering**

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Limona777**
- GitHub: [@Limona777](https://github.com/Limona777)

---

## 📝 Changelog

| Version | Date | Notes |
|---|---|---|
| 1.0.0 | 2025 | Initial release — Fur + Comic rendering systems |

---

> *Made with 💜 for stylized rendering enthusiasts.*
