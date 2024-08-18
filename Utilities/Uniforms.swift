//
//  Uniforms.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI

struct VertexUniforms {
  var modelViewMatrix: simd_float4x4
  var projectionMatrix: simd_float4x4
}

struct FragmentUniforms {
  var brightness: Float
}
