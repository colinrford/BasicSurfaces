//
//  Basic3DPresenter.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalUI
import MetalKit
import OSLog

/// An `MTKView` subclass conforming to `MetalPresenting` that configures the Metal view
/// and creates a ``Basic3DRenderer`` to draw a ``Sphere``.
class Basic3DPresenter: MTKView, MetalPresenting {
  
  // MARK: - Properties
  
  /// The renderer responsible for drawing each frame. Set during `configure(device:)`.
  var renderer: MetalRendering!
  /// The surface geometry passed to the renderer.
  var surface: BasicSurface!
  
  /// Forwards the fade toggle to the renderer.
  var isFadeEnabled: Bool {
    get { (renderer as? Basic3DRenderer)?.isFadeEnabled ?? false }
    set { (renderer as? Basic3DRenderer)?.isFadeEnabled = newValue }
  }
  
  // MARK: - Initialization
  
  /// Creates the presenter with the system default Metal device and immediately configures
  /// the rendering pipeline.
  ///
  /// - Important: Compiles the render pipeline synchronously on the calling thread,
  ///   which may cause a brief delay on first launch.
  required init() {
    super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())
    configure(device: device)
  }
  
  /// Storyboard initialization is not supported.
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - MetalPresenting
  
  /// Sets pixel formats, clear color (near-black with a slight blue tint), and depth buffer configuration.
  func configureMTKView() {
    colorPixelFormat = .bgra8Unorm
    clearColor = MTLClearColor(red: 0, green: 0, blue: 0.1, alpha: 1)
    depthStencilPixelFormat = .depth32Float
    clearDepth = 1.0
  }
  
  /// Creates a ``Sphere`` and a ``Basic3DRenderer`` for the given device.
  ///
  /// - Parameter device: The Metal device.
  /// - Returns: A configured ``Basic3DRenderer``.
  func renderer(forDevice device: MTLDevice) -> MetalRendering {
    surface = Sphere(device: device)
    return Basic3DRenderer(mtkView: self, vertices: surface.vertices, device: device)
  }
  
  // MARK: - Sphere Generation
  
  /// Regenerates the sphere using the specified method and swaps in the new vertex data.
  ///
  /// - Parameter method: The desired generation method (CPU or GPU).
  /// - Returns: The method actually used. May differ from `method` if GPU generation fails,
  ///   in which case CPU is used as a fallback.
  @discardableResult
  func regenerateSphere(method: SphereGenerationMethod) -> SphereGenerationMethod {
    guard let device = device else { return .cpu }
    
    switch method {
    case .cpu:
      surface = Sphere(device: device)
    case .gpu:
      if let gpuSphere = Sphere(device: device, radius: 1, vertexCount: 10240) {
        surface = gpuSphere
      } else {
        Logger.basicSurfaces.error("GPU sphere generation failed, falling back to CPU")
        surface = Sphere(device: device)
        (renderer as? Basic3DRenderer)?.replaceVertices(surface.vertices, device: device)
        return .cpu
      }
    }
    
    (renderer as? Basic3DRenderer)?.replaceVertices(surface.vertices, device: device)
    return method
  }
}
