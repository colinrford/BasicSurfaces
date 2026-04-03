//
//  BasicSurface.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI

/// Base class for GPU-renderable surface geometry, storing vertex data produced by a subclass.
///
/// See ``Sphere`` for the current concrete subclass.
class BasicSurface {
  
  // MARK: - Properties
  
  /// The Metal device used to create GPU resources for this surface.
  let device: MTLDevice
  /// A human-readable label used for debugging.
  let name: String
  /// Number of vertices, initialized from `vertices.count`.
  var vertexCount: Int
  /// The surface's vertex data in object space.
  var vertices: [Vertex]
  /// Per-vertex normals.
  var normals: [simd_float4] = []
  
  // MARK: - Initialization
  
  /// Creates a surface with pre-computed vertex data.
  ///
  /// - Parameters:
  ///   - name: Display name for debugging.
  ///   - vertices: Pre-computed vertex array.
  ///   - device: The Metal device.
  init(name: String, vertices: [Vertex], device: MTLDevice) {
    self.name = name
    self.device = device
    vertexCount = vertices.count
    self.vertices = vertices
  }
}
