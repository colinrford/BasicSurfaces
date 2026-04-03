//
//  Sphere.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI
import OSLog

// MARK: - Supporting Types

/// Data for use in generating sphere vertices using Deserno's algorithm.
struct SphereDataEq {
  /// Sphere radius.
  var radius: Float
  /// Number of latitude bands from Deserno's equidistribution algorithm.
  var m_phi: Float
  /// Longitude angular spacing in radians.
  var d_theta: Float
}

/// Whether the sphere was generated on the CPU or GPU.
enum SphereGenerationMethod {
  case cpu
  case gpu
}

/// Specialized error(s) for Sphere.
enum SphereError: Error {
  /// Thrown if sphere generator shader cannot be found.
  case shaderNotFound(String)
}

/// A ``BasicSurface`` subclass that generates sphere vertices using
/// [Deserno's equidistribution algorithm](https://www.cmu.edu/biolphys/deserno/pdf/sphere_equi.pdf).
///
/// Supports both CPU and GPU vertex generation paths.
class Sphere : BasicSurface {
  
  // MARK: - Properties
  
  /// For generating sphere vertices on GPU.
  private var computePipelineStateSphere : MTLComputePipelineState?
  
  // MARK: - CPU Initialization
  
  /// Generates sphere vertices on the CPU using Deserno's algorithm
  /// with a hardcoded radius of 2 and approximately 10,240 vertices.
  ///
  /// - Parameter device: The Metal device.
  init(device: MTLDevice) {
    
    var start, end : UInt64
    
    start = mach_absolute_time()
    
    let sphereGenCPUState = OSSignposter.basicSurfaces.beginInterval("Sphere Generation on CPU")
    
    // This particular algorithm due to Markus Deserno, Associate Professor at CMU (as of 1/28/20)
    // Set up for algorithm of placing vertices on surface of sphere of radius r
    let r = Float(1), vertexCount = Float(10240)
    let sa = 4 * Float.pi / vertexCount
    let d = sqrtf(sa)
    let m_phi = roundf(Float.pi / d)
    let d_phi = Float.pi / m_phi
    let d_theta = sa / d_phi
    
    var vertices = [Vertex]()
    var phi = Float(0);
    var m_theta = Float(0);
    
    for i in 0..<Int(m_phi) {
      phi = Float.pi * (Float(i) + 0.5) / m_phi
      m_theta = roundf(2 * Float.pi * sinf(phi) / d_theta)
      for j in 0..<Int(m_theta) {
        let theta = 2 * Float.pi * Float(j) / m_theta
        let x = r * sinf(phi) * cosf(theta)
        let y = r * sinf(phi) * sinf(theta)
        let z = r * cosf(phi)
        
        let vertex = Vertex(pos: simd_float4(x, y, z, 1), color: simd_float4(simd_fract(phi), simd_fract(theta), abs(simd_fract(theta - phi)), 1.0))
        vertices.append(vertex)
      }
    }
    
    end = mach_absolute_time()
    
    OSSignposter.basicSurfaces.endInterval("Sphere Generation on CPU", sphereGenCPUState)
    Logger.basicSurfaces.info("Sphere CPU init: \(vertices.count) vertices in \(String(format: "%.9f", Double(end - start) / Double(NSEC_PER_SEC)))")
    
    super.init(name: "Sphere", vertices: vertices, device: device)
  }
  
  // MARK: - GPU Initialization
  
  /// Generates sphere vertices on the GPU via a Metal compute shader.
  ///
  /// - Parameters:
  ///   - device: The Metal device.
  ///   - radius: Sphere radius.
  ///   - vertexCount: Approximate target vertex count.
  /// - Returns: `nil` if Metal resource creation or compute shader compilation fails.
  /// - Important: Calls `waitUntilCompleted()` on the command buffer,
  ///   blocking the calling thread until GPU work finishes.
  init?(device: MTLDevice, radius: Float, vertexCount: UInt) {
    var start, end : UInt64
    start = mach_absolute_time()
    
    let sphereGenGPUState = OSSignposter.basicSurfaces.beginInterval("Sphere Generation on GPU")
    
    guard let library = device.makeDefaultLibrary(),
          let commandQueue = device.makeCommandQueue(),
          let buffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * Int(vertexCount), options: []) else {
      Logger.basicSurfaces.fault("Failed to create Metal resources for Sphere GPU init")
      assertionFailure("Failed to create Metal resources for Sphere GPU init")
      return nil
    }
    library.label = "Sphere Generator Library"
    commandQueue.label = "Command Queue for sphere generation on GPU"
    buffer.label = "Sphere vertex generation buffer"
    
    var vertices = [Vertex]()
    
    do {
      computePipelineStateSphere = try Sphere.buildComputePipelineSphere(device: device, library: library)
    } catch {
      Logger.basicSurfaces.error("Sphere generation compute pipeline compilation failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
    guard let computePSOSphere = computePipelineStateSphere else {
      Logger.basicSurfaces.fault("computePipelineStateSphere is nil after successful build — this is a bug")
      assertionFailure("computePipelineStateSphere is nil after successful build - this is a bug")
      return nil
    }
    
    var sphereData = Sphere.getSphereDataEq(radius: radius, vertexCount: vertexCount)
    let maxM_theta = round(2 * Float.pi / sphereData.d_theta)
    
    let semaphore = DispatchSemaphore(value: 1)
    
    // Prepare threadgroup size
    let w = computePSOSphere.threadExecutionWidth
    let h = computePSOSphere.maxTotalThreadsPerThreadgroup / w
    let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
    let threadsPerGrid = MTLSize(width: Int(sphereData.m_phi), height: Int(maxM_theta), depth: 1) // Not sure what to set for height
    
    let ptr = buffer.contents().assumingMemoryBound(to: Vertex.self)
    let results = UnsafeMutableBufferPointer(start: ptr, count: Int(vertexCount))
    semaphore.wait() // hol up
    
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      Logger.basicSurfaces.fault("commandQueue.makeCommandBuffer() for generating sphere vertices returned nil")
      assertionFailure("commandQueue.makeCommandBuffer() for generating sphere vertices returned nil")
      return nil
    }
    commandBuffer.pushDebugGroup("Sphere GPU Init")
    commandBuffer.label = "Command Buffer for sphere generation on GPU"
    
    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
      Logger.basicSurfaces.fault("commandBuffer.makeComputeCommandEncoder() for generating sphere vertices returned nil")
      assertionFailure("commandBuffer.makeComputeCommandEncoder() for generating sphere vertices returned nil")
      commandBuffer.popDebugGroup() // Sphere GPU Init
      commandBuffer.commit() // prevent leaking
      return nil
    }
    computeEncoder.pushDebugGroup("Sphere Vertex Generation")
    computeEncoder.label = "Compute Encoder for sphere generation on GPU"
    computeEncoder.setComputePipelineState(computePSOSphere)
    computeEncoder.setBuffer(buffer, offset: 0, index: 0)
    computeEncoder.setBytes(&sphereData, length: MemoryLayout<SphereDataEq>.stride, index: 1)
    computeEncoder.dispatchThreads(threadsPerGrid,
                                   threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder.popDebugGroup() // Sphere Vertex Generation
    computeEncoder.endEncoding()
    
    commandBuffer.addCompletedHandler { _ in
      semaphore.signal()
    }
    
    commandBuffer.popDebugGroup() // Sphere GPU Init
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    OSSignposter.basicSurfaces.endInterval("Sphere Generation on GPU", sphereGenGPUState)
    
    let sphereGenCopyState = OSSignposter.basicSurfaces.beginInterval("Sphere Results Copy")
    vertices.append(contentsOf: results)
    OSSignposter.basicSurfaces.endInterval("Sphere Results Copy", sphereGenCopyState)
    
    end = mach_absolute_time()
    
    Logger.basicSurfaces.info("Sphere GPU init: \(vertices.count) vertices in \(String(format: "%.9f", Double(end - start) / Double(NSEC_PER_SEC)))")
    
    super.init(name: "Sphere", vertices: vertices, device: device)
  }
  
  // MARK: - Private Helpers
  /// Computes the latitude/longitude spacing parameters for Deserno's equidistribution algorithm.
  ///
  /// - Parameters:
  ///   - radius: Sphere radius.
  ///   - vertexCount: Target number of vertices.
  /// - Returns: A ``SphereDataEq`` with the computed spacing values.
  private class func getSphereDataEq(radius: Float, vertexCount: UInt) -> SphereDataEq {
    let sa = 4 * Float.pi * radius * radius / Float(vertexCount)
    let d = sqrtf(sa)
    let m_phi = round(Float.pi / d)
    let d_phi = Float.pi / m_phi
    let d_theta = sa / d_phi
    
    return SphereDataEq(radius: radius, m_phi: m_phi, d_theta: d_theta)
  }
  
  /// Compiles the `sphere_eq_generator` compute shader into a pipeline state.
  ///
  /// - Parameters:
  ///   - device: The Metal device.
  ///   - library: The shader library containing the compute function.
  /// - Throws: ``SphereError/shaderNotFound(_:)`` if the shader function cannot be found,
  ///   or a Metal pipeline compilation error.
  /// - Returns: A compiled compute pipeline state.
  private class func buildComputePipelineSphere(device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
    guard let sphereShader = library.makeFunction(name: "sphere_eq_generator") else {
      throw SphereError.shaderNotFound("sphere_eq_generator")
    }
    return try device.makeComputePipelineState(function: sphereShader)
  }
}
