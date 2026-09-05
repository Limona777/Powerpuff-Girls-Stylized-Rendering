# Powerpuff Girls Stylized Rendering

> A Unity-based stylized rendering project featuring **Comic-Style Cel Shading** and **Multi-Pass Fur Rendering**, themed around The Powerpuff Girls.

[![Platform](https://img.shields.io/badge/Platform-PC-blue)]()
[![Engine](https://img.shields.io/badge/Engine-Unity-orange)]()
[![Language](https://img.shields.io/badge/Language-HLSL%20%2F%20Cg%20%2F%20ShaderLab-green)]()

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Dependencies](#dependencies)
- [References](#references)

---

## Overview

This project is an independent research & development endeavor exploring **non-photorealistic rendering (NPR)** techniques in Unity. It consists of two core rendering systems:

1. **Multi-Pass Shell Fur** — Procedurally generates fur layers extruded along vertex normals, with per-shell alpha fading and noise-based perturbation.
2. **Math-Driven Comic Shader** — A texture-free, two-pass cel-shading system using fractal noise to dynamically deform light thresholds, producing halftone dots, cross-hatching, and fine-line details entirely in shader code.

Both systems are demonstrated using **The Powerpuff Girls** as the art-direction reference.

### Tech Stack

| Category | Details |
|---|---|
| **Platform** | PC (Windows / macOS) |
| **Engine** | Unity 2022.3.34 LTS or higher |
| **Shading Language** | HLSL / Cg (ShaderLab) |
| **Render Pipeline** | Built-in Render Pipeline |
| **Role** | Independent Development |

---

## Features

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

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| Unity Built-in Render Pipeline | 2022.3.34+ | Core rendering |
| No third-party packages required | — | Pure shader-based solution |

---

## References

### Academic & Technical Foundations
- **Kajiya-Kay Anisotropic Reflection Model** — Kajiya, J. T., & Kay, T. L. (1989). *Rendering fur with three dimensional textures*. ACM SIGGRAPH Computer Graphics, 23(3), 271–280.

### Implementation Inspiration (Chinese Technical Blogs)
- DeliciousDD. *多pass毛发制作愤怒的小鸡儿 (Multi-Pass Fur Implementation)*. Zhihu. Retrieved from https://zhuanlan.zhihu.com/p/122405983
- bzyzhang. *练习项目(十四)：速度线效果的实现 (Speed Lines Effect Implementation)*. Zhihu. Retrieved from https://zhuanlan.zhihu.com/p/427866097
- Nevrwind. *拆一下漫画风Shader的流程 (Deconstructing Comic-Style Shader Workflow)*. Bilibili. Retrieved from https://www.bilibili.com/opus/748042956511903744

### Art Reference
- **The Powerpuff Girls** — Cartoon Network (character design reference only)

