//
//  Basic3DPresenter.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalUI
import MetalKit

class Basic3DPresenter: MTKView, MetalPresenting {
  var renderer: MetalRendering!
  var surface: BasicSurface!
  
  required init() {
    super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
    configure(device: device)
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configureMTKView() {
    colorPixelFormat = .bgra8Unorm
    clearColor = MTLClearColor(red: 0, green: 0, blue: 0.1, alpha: 1)
  }
  
  func renderer(forDevice device: MTLDevice) -> MetalRendering {
    surface = Sphere(device: device)//, radius: 2, vertexCount: 10240)
    return Basic3DRenderer(mtkView: self, vertices: surface.vertices, device: device)
  }
}

