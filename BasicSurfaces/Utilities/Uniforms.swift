//
//  Uniforms.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI

// MARK: - Vertex Stage

/// Uniforms passed to the vertex shader stage each frame.
///
/// - Important: The memory layout must exactly match the C `VertexUniforms`
///   struct in `vertex.h`; mismatches will silently corrupt GPU reads.
struct VertexUniforms {
  /// Combined model and view transform, column-major (Metal default).
  var modelViewMatrix: simd_float4x4
  /// Left-handed perspective projection matrix.
  var projectionMatrix: simd_float4x4
}

// MARK: - Fragment Stage

/// Uniforms passed to the fragment shader stage each frame.
///
/// - Important: The memory layout must exactly match the corresponding
///   struct read by `basic_3d_fragment_shader` in `basic_3d_shader.metal`.
struct FragmentUniforms {
  /// Scales RGB output. Effective range is `[0, 1]`.
  var brightness: Float
}
