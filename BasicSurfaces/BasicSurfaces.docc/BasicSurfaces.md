# ``BasicSurfaces``

Render 3D surfaces in a SwiftUI view using Metal.

## Overview

BasicSurfaces is a proof-of-concept app that renders Metal graphics inside a SwiftUI `View`. It demonstrates how to integrate Metal's rendering pipeline with SwiftUI, including support for Xcode Previews.

The app uses a protocol-based architecture — ``Basic3DPresenter`` conforms to the `MetalPresenting` protocol and manages an ``Basic3DRenderer`` that conforms to `MetalRendering` — to cleanly separate view configuration, rendering logic, and surface geometry.

Currently, the app renders a sphere using [Deserno's algorithm](https://www.cmu.edu/biolphys/deserno/pdf/sphere_equi.pdf) for equidistributed points on a sphere, with support for generating vertices on either the CPU or GPU via a Metal compute shader.

## Topics

### Essentials

- ``BasicSurfacesApp``
- ``Basic3DView``

### Rendering

- ``Basic3DPresenter``
- ``Basic3DRenderer``

### Surfaces

- ``BasicSurface``
- ``Sphere``
- ``SphereDataEq``
- ``SphereError``

### Uniforms

- ``VertexUniforms``
- ``FragmentUniforms``

### Linear Algebra

- ``makeModelViewMatrix(scale:axis:angle:translation:)``
- ``makeScalingMatrixOrigin(scale:)``
- ``makeTranslationMatrix(by:)``
- ``matrix_rotation(angle:axis:)``
- ``matrix_perspective_left_hand(fovyRadians:aspect:nearZ:farZ:)``
