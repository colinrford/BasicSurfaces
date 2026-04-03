//
//  Basic3DRenderer.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalUI
import MetalKit
import OSLog
import Synchronization

/// Metal renderer that draws a ``BasicSurface`` as a line strip with per-frame rotation animation.
///
/// Conforms to `MetalRendering` from the MetalUI package.
final class Basic3DRenderer: NSObject, MetalRendering {

  // MARK: - Properties

  /// Metal command queue for submitting render work.
  var commandQueue: MTLCommandQueue?
  /// Compiled vertex/fragment pipeline using `basic_3d_vertex_shader` and `basic_3d_fragment_shader`.
  var renderPipelineState: MTLRenderPipelineState?
  /// Depth testing state (less-equal, write enabled).
  var depthStencilState: MTLDepthStencilState?
  /// GPU buffer containing surface vertex data.
  var vertexBuffer: MTLBuffer?
  /// Per-frame vertex-stage transform matrices.
  var vertexUniforms: VertexUniforms?
  /// GPU buffer for fragment-stage uniforms.
  var fragmentUniformsBuffer: MTLBuffer?

  /// Source vertex data received at init.
  var vertices: [Vertex] = []

  /// Timestamp of the previous frame, used to compute delta time. `nil` before the first frame.
  var lastRenderTime: CFTimeInterval? = nil
  /// Accumulated wall-clock elapsed time in seconds.
  var currentTime: Double = 0
  /// Animation time in seconds, incremented at the preferred frame rate. Used as the rotation angle.
  var time: Float = 0
  /// When `true`, brightness pulses via a cosine wave; when `false`, brightness stays at `1.0`.
  ///
  /// Written from the main thread (UI toggle) and read from the render thread (`CVDisplayLink`),
  /// so access is synchronized via `Atomic` with relaxed ordering.
  private let _isFadeEnabled = Atomic<Bool>(false)
  var isFadeEnabled: Bool {
    get { _isFadeEnabled.load(ordering: .relaxed) }
    set { _isFadeEnabled.store(newValue, ordering: .relaxed) }
  }

  // MARK: - Initialization

  /// Creates the renderer, initializing the full Metal pipeline and initial uniforms.
  ///
  /// - Parameters:
  ///   - mtkView: The view this renderer will draw into.
  ///   - vertices: Vertex data to render.
  ///   - device: The Metal device.
  convenience init(mtkView: MTKView, vertices: [Vertex], device: MTLDevice) {
    self.init()
    
    self.vertices = vertices
    
    createCommandQueue(device: device)
    createPipelineState(withLibrary: device.makeDefaultLibrary(), forDevice: device)
    createDepthStencilState(withView: mtkView, forDevice: device)
    createBuffers(device: device)
    let modelViewMatrix = makeModelViewMatrix(scale: Float(1),
                                              axis: simd_float4(1, 1, 0, 0),
                                              angle: Float.pi,
                                              translation: simd_float3(0, 0, 5))
    let aspect = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
    let projectionMatrix = matrix_perspective_left_hand(fovyRadians: Float.pi / 3,
                                                        aspect: aspect,
                                                        nearZ: Float(0.1),
                                                        farZ: Float(100.0))
    vertexUniforms = VertexUniforms(modelViewMatrix: modelViewMatrix,
                                    projectionMatrix: projectionMatrix)
  }
  
  // MARK: - Metal Setup
  
  /// Creates and assigns the Metal command queue.
  ///
  /// - Parameter device: The Metal device.
  func createCommandQueue(device: MTLDevice) {
    guard let commandQueue = device.makeCommandQueue() else {
      Logger.renderer.fault("device.makeCommandQueue() returned nil")
      assertionFailure("device.makeCommandQueue() returned nil")
      return
    }
    commandQueue.label = "Command Queue"
    self.commandQueue = commandQueue
  }
  
  /// Compiles the render pipeline from `basic_3d_vertex_shader` and `basic_3d_fragment_shader`.
  ///
  /// - Parameters:
  ///   - library: The shader library. If `nil`, the pipeline functions will be `nil`
  ///     and rendering will silently fail.
  ///   - device: The Metal device.
  func createPipelineState(withLibrary library: MTLLibrary?,
                           forDevice device: MTLDevice) {
    let vertexFunction = library?.makeFunction(name: "basic_3d_vertex_shader")
    let fragmentFunction = library?.makeFunction(name: "basic_3d_fragment_shader")
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.label = "Render Pipeline State"
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
    renderPipelineDescriptor.vertexFunction = vertexFunction
    renderPipelineDescriptor.fragmentFunction = fragmentFunction
    
    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    } catch {
      Logger.renderer.error("Pipeline state creation failed: \(error.localizedDescription, privacy: .public)")
    }
  }
  
  /// Creates a depth stencil state with less-equal comparison and depth writes enabled.
  ///
  /// - Parameters:
  ///   - mtkView: The hosting view (currently unused by this method).
  ///   - device: The Metal device.
  func createDepthStencilState(withView mtkView: MTKView, forDevice device: MTLDevice) {
    let depthStencilDescriptor = MTLDepthStencilDescriptor()
    depthStencilDescriptor.label = "Depth Stencil State"
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
    depthStencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
  }
  
  /// Allocates GPU buffers for vertices and fragment uniforms.
  ///
  /// - Parameter device: The Metal device.
  /// - Note: Fragment uniform brightness is initialized to `1.0`.
  func createBuffers(device: MTLDevice) {
    guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                               length: MemoryLayout<Vertex>.stride * vertices.count,
                                               options: []) else {
      Logger.renderer.fault("device.makeBuffer() for vertices returned nil")
      assertionFailure("device.makeBuffer() for vertices returned nil")
      return
    }
    vertexBuffer.label = "BasicSurface Vertex Buffer"
    self.vertexBuffer = vertexBuffer
    
    var initialFragmentUniforms = FragmentUniforms(brightness: 1.0)
    guard let fragmentUniformsBuffer = device.makeBuffer(bytes: &initialFragmentUniforms,
                                                         length: MemoryLayout<FragmentUniforms>.stride,
                                                         options: []) else {
      Logger.renderer.fault("device.makeBuffer() for fragment uniforms returned nil")
      assertionFailure("device.makeBuffer() for fragment uniforms returned nil")
      return
    }
    fragmentUniformsBuffer.label = "BasicSurface Fragment Uniforms Buffer"
    self.fragmentUniformsBuffer = fragmentUniformsBuffer
  }
  
  // MARK: - MTKViewDelegate
  
  /// Recomputes the projection matrix when the drawable size changes.
  ///
  /// - Parameters:
  ///   - view: The `MTKView` whose size changed.
  ///   - size: The new drawable size.
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    vertexUniforms?.projectionMatrix = matrix_perspective_left_hand(fovyRadians: Float.pi / 3,
                                                                    aspect: Float(size.width / size.height),
                                                                    nearZ: Float(0.1),
                                                                    farZ: Float(100.0))
  }
  
  /// Updates per-frame uniforms before encoding draw commands.
  ///
  /// - Parameters:
  ///   - t: Animation time in seconds, used as the rotation angle.
  ///   - dt: Wall-clock delta time since the last frame, in seconds.
  func update(t: Float, dt: CFTimeInterval) {
    let angle = -t;
    vertexUniforms?.modelViewMatrix = makeModelViewMatrix(scale: Float(1), axis: simd_float4(1, 1, 0, 0), angle: angle, translation: simd_float3(0, 0, 5))
    
    let ptr = fragmentUniformsBuffer?.contents().bindMemory(to: FragmentUniforms.self, capacity: 1)
    if isFadeEnabled {
      ptr?.pointee.brightness = Float(0.5 * cos(currentTime) + 0.5)
    } else {
      ptr?.pointee.brightness = 1.0
    }

    currentTime += dt
  }
  
  /// Encodes and submits a single frame's render commands.
  ///
  /// - Parameter view: The `MTKView` to draw into.
  /// - Note: Silently drops the frame if the drawable, render pass descriptor,
  ///   command queue, pipeline state, or depth stencil state is unavailable.
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
    let updateState = OSSignposter.renderer.beginInterval("Update")
    update(t: time, dt: timeDifference)
    OSSignposter.renderer.endInterval("Update", updateState)
    
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      Logger.renderer.fault("commandQueue.makeCommandBuffer() returned nil — dropping frame")
      assertionFailure("commandQueue.makeCommandBuffer() returned nil")
      return
    }
    commandBuffer.label = "Command Buffer"
    commandBuffer.pushDebugGroup("Frame")
    
    guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      Logger.renderer.fault("commandBuffer.makeRenderCommandEncoder() returned nil — dropping frame")
      assertionFailure("commandBuffer.makeRenderCommandEncoder() returned nil")
      commandBuffer.popDebugGroup() // Frame
      commandBuffer.commit() // commit so the buffer isn't leaked
      return
    }
    let commandEncoderState = OSSignposter.renderer.beginInterval("Encode")
    
    commandEncoder.label = "Render Encoder"
    commandEncoder.pushDebugGroup("Draw Surface")
    commandEncoder.setRenderPipelineState(renderPipelineState)
    commandEncoder.setDepthStencilState(depthStencilState)
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: 1)
    commandEncoder.setFragmentBuffer(fragmentUniformsBuffer, offset: 0, index: 0)
    commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertices.count)
    commandEncoder.popDebugGroup() // Draw Surface
    
    commandEncoder.endEncoding()
    commandBuffer.popDebugGroup() // Frame
    commandBuffer.present(drawable)
    commandBuffer.commit()
    
    OSSignposter.renderer.endInterval("Encode", commandEncoderState)
  }
}
