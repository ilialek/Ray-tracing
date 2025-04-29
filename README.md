# Unity Ray Tracer

This project is a GPU ray tracer written in HLSL and integrated into Unity via an unlit shader. It demonstrates ray tracing with support for specular highlights, multiple bounces, and progressive frame accumulation.


## Preview

| Specular Highlights (Marble-like) | Diffuse Only |
|----------------------------------|-----------------------|
| ![Specular](https://github.com/ilialek/Resources/blob/main/Ray%20tracing%20specular%20effect.png) | ![Diffuse](https://github.com/ilialek/Resources/blob/main/Ray%20tracing%20diffuse%20effect.png) |


## Features

- **Multiple Bounces** using a custom loop (`MaxBounceCount`)
- **Specular Reflection** controlled via material `smoothness`
- **Emission** for glowing spheres
- **Sky Gradient + Sun Light**
- **Random Hemisphere Sampling** for diffuse lighting
- **Temporal Accumulation** across frames using a blending shader


## How It Works

### RayTracing Shader

- Shoots rays per-pixel from the camera.
- Calculates intersections with spheres.
- Bounces rays based on surface smoothness:
  - Low smoothness → Diffuse
  - High smoothness → Mirror-like reflection
- Adds emitted light, environment light, and reflected light contributions.

### Blending Shader

- Blends current frame with previous frames using weighted averaging.
- Reduces noise over time by accumulating more samples per pixel.
