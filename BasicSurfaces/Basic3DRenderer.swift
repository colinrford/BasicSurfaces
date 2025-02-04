//
//  Basic3DRenderer.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalUI
import MetalKit

final class Basic3DRenderer: NSObject, MetalRendering {
  
  var commandQueue: MTLCommandQueue?
  var renderPipelineState: MTLRenderPipelineState?
  var depthStencilState: MTLDepthStencilState?
  var vertexBuffer: MTLBuffer?
  var vertexUniforms: VertexUniforms?
  var fragmentUniformsBuffer: MTLBuffer?
  
  var vertices: [Vertex] = []
  
  var lastRenderTime: CFTimeInterval? = nil
  var currentTime: Double = 0
  var time: Float = 0
  
  convenience init(mtkView: MTKView, vertices: [Vertex], device: MTLDevice) {
    self.init()
    
    self.vertices = vertices
    
    createCommandQueue(device: device)
    createPipelineState(withLibrary: device.makeDefaultLibrary(), forDevice: device)
    createDepthStencilState(withView: mtkView, forDevice: device)
    createBuffers(device: device)
    let modelViewMatrix = makeModelViewMatrix(scale: Float(1), axis: simd_float4(1, 1, 0, 0), angle: Float.pi, translation: simd_float3(0, 0, 5))
    //let aspect = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
    let projectionMatrix = matrix_perspective_left_hand(fovyRadians: Float.pi / 4,
                                                        aspect: 1.78,
                                                        nearZ: Float(0.1),
                                                        farZ: Float(100.0))
    vertexUniforms = VertexUniforms(modelViewMatrix: modelViewMatrix,
                                    projectionMatrix: projectionMatrix)
  }
  
  func createCommandQueue(device: MTLDevice) {
    commandQueue = device.makeCommandQueue()
  }
  
  func createPipelineState(withLibrary library: MTLLibrary?,
                           forDevice device: MTLDevice) {
    let vertexFunction = library?.makeFunction(name: "basic_3d_vertex_shader")
    let fragmentFunction = library?.makeFunction(name: "basic_3d_fragment_shader")
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
    renderPipelineDescriptor.vertexFunction = vertexFunction
    renderPipelineDescriptor.fragmentFunction = fragmentFunction
    
    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    } catch {
      print(error.localizedDescription)
    }
  }
  
  func createDepthStencilState(withView mtkView: MTKView, forDevice device: MTLDevice) {
    let depthStencilDescriptor = MTLDepthStencilDescriptor()
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
    depthStencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
  }
  
  func createBuffers(device: MTLDevice) {
    vertexBuffer = device.makeBuffer(bytes: vertices,
                                     length: MemoryLayout<Vertex>.stride * vertices.count,
                                     options: [])
    var initialFragmentUniforms = FragmentUniforms(brightness: 1.0)
    fragmentUniformsBuffer = device.makeBuffer(bytes: &initialFragmentUniforms,
                                               length: MemoryLayout<FragmentUniforms>.stride,
                                               options: [])
  }
  
  
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    vertexUniforms?.projectionMatrix = matrix_perspective_left_hand(fovyRadians: Float.pi / 3,
                                                                    aspect: Float(size.width / size.height),
                                                                    nearZ: Float(0.1),
                                                                    farZ: Float(100.0))
  }
  
  func update(t: Float, dt: CFTimeInterval) {
    
    let angle = -t;
    vertexUniforms?.modelViewMatrix = makeModelViewMatrix(scale: Float(1), axis: simd_float4(1, 1, 0, 0), angle: angle, translation: simd_float3(0, 0, 5))
    
    //let ptr = fragmentUniformsBuffer?.contents().bindMemory(to: FragmentUniforms.self, capacity: 1)
    //ptr?.pointee.brightness = Float(0.5 * cos(currentTime) + 0.5)
    
    currentTime += dt
  }
  
  func draw(in view: MTKView) {
    
    guard let drawable = view.currentDrawable,
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let commandQueue = commandQueue,
          let renderPipelineState = renderPipelineState,
          let depthStencilState = depthStencilState else {
            return
          }
    
    let systemTime = CACurrentMediaTime()
    let timeDifference = (lastRenderTime == nil) ? 0 : (systemTime - lastRenderTime!)
    lastRenderTime = systemTime
    time += 1 / Float(view.preferredFramesPerSecond)
    update(t: time, dt: timeDifference)
    
    let commandBuffer = commandQueue.makeCommandBuffer()
    let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    commandEncoder?.setRenderPipelineState(renderPipelineState)
    commandEncoder?.setDepthStencilState(depthStencilState)
    commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder?.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: 1)
    commandEncoder?.setFragmentBuffer(fragmentUniformsBuffer, offset: 0, index: 0)
    commandEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    
    commandEncoder?.endEncoding()
    commandBuffer?.present(drawable)
    commandBuffer?.commit()
  }
}


