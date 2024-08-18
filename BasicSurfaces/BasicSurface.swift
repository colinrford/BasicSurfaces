//
//  BasicSurface.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI

class BasicSurface {
    
  let device: MTLDevice
  let name: String
  var vertexCount: Int
  var vertices: [Vertex]
  
  init(name: String, vertices: [Vertex], device: MTLDevice) {
    self.name = name
    self.device = device
    vertexCount = vertices.count
    self.vertices = vertices
  }
}


