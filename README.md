# BasicSurfaces

![Rotating Sphere Demo](/rotating-sphere-xcode-preview.gif)

A proof-of-concept for rendering Metal graphics inside a SwiftUI
`View`, including support for Xcode Previews. Built on top of
[`MetalUI`](https://www.github.com/colinrford/MetalUI) (included as a
local package in this repository).

While intended to stay minimal, `BasicSurfaces` also demonstrates:
- Debugging and instrumentation using Apple's tools (`OSLog`, `OSSignposter`)
- DocC documentation (build via **Product > Build Documentation** in Xcode)

If you are interested in seeing what can be built on top of
BasicSurfaces, check out
[my app Surfaces](https://www.colinford.com/surfaces), available
on Apple's App Store.

## Table of Contents

- [Getting Started](#getting-started)
- [What to Expect](#what-to-expect)
- [Configuration](#configuration)
- [Documentation](#documentation)

---

## Getting Started

`BasicSurfaces` should be `git clone`-able and build right out of
the box. It builds for macOS, iOS, and iPadOS. You may need to alter
build settings to enable Mac Catalyst or adjust older OS
compatibility. This should work for any device that can run SwiftUI.

`v0.1` of `BasicSurfaces` is much more bare bones. It has everything
needed to get up and running, but lacks documentation and lacks usage
of e.g. `OSLog`. I added these in `v0.2` of `BasicSurfaces` so that
someone just getting started can have a little more to chew on.

If you find a build bug — or any kind of bug — please let me know via
GitHub issues or email.

## What to Expect

- Opening `Basic3DView.swift` in Xcode shows a multicolored rotating sphere in the Xcode Preview canvas
- Building and running the app displays the same rotating sphere
- The sphere has depth (depth buffering is enabled)
- The resolution is not as good as it could be

## Configuration

### CPU vs. GPU vertex generation

The app includes a toggle button that switches between CPU and GPU
sphere vertex generation at runtime. A small label in the
bottom-right corner shows which method is active.

- **CPU:** Uses `Sphere.init(device:)`, which generates vertices on the
  CPU and should always succeed.
- **GPU:** Uses `Sphere.init?(device:radius:vertexCount:)`, which generates
  vertices via a Metal compute shader. If GPU generation fails, the app
  falls back to CPU automatically.

In both cases, generation time is logged to the console.

### Brightness animation

The app includes a toggle button (bottom-right corner) that enables a
brightness animation, pulsing the sphere's brightness between 0.0 and
1.0 over time using the fragment shader's brightness uniform.

## Documentation

Full API documentation can be built in Xcode via **Product > Build
Documentation**. The DocC catalog covers all public types, the
rendering pipeline, surface geometry, and the linear algebra
utilities.
