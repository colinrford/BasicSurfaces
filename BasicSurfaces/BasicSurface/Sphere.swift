//
//  Sphere.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalKit
import MetalUI

struct SphereData {
  var r_i: Float
  var theta_j: Float
  var vertexCount: Int
  var sideLength: Int
}

struct SphereDataEq {
  var radius: Float
  var m_phi: Float
  var d_theta: Float
}

class Sphere : BasicSurface {
    
  var computePipelineStateSphere : MTLComputePipelineState?
  
  init(device: MTLDevice) {
      
    var start, end : UInt64
    
    start = mach_absolute_time()
    
    // This particular algorithm due to Markus Deserno, Associate Professor at CMU (as of 1/28/20)
    // Set up for algorithm of placing vertices on surface of sphere of radius r
    let r = Float(2), vertexCount = Float(10240)
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
        //let grayscale = (x + r) / (x + y + Float(3) * r)
        let vertex = Vertex(pos: simd_float4(x, y, z, 1), color: simd_float4(simd_fract(phi), simd_fract(theta), abs(simd_fract(theta - phi)), 1.0))
        //color: simd_float4(cosf(Float(j)), grayscale / Float(j), sinf(Float(i)), 1))
        vertices.append(vertex)
      }
    }
      
    end = mach_absolute_time()
    print("CPU time: \(Double(end - start) / Double(NSEC_PER_SEC))")
    print("vertexCount: \(Double(vertices.count))")
    
    super.init(name: "Sphere", vertices: vertices, device: device)
  }
  
  init?(device: MTLDevice, radius: Float, vertexCount: UInt) {
    var start, end : UInt64
    start = mach_absolute_time()
    let library = device.makeDefaultLibrary()
    let commandQueue = device.makeCommandQueue()
    var vertices = [Vertex]()
    let buffer = device.makeBuffer(bytes: vertices,
                                   length: MemoryLayout<Vertex>.stride * Int(vertexCount),
                                   options: [])

    do {
      computePipelineStateSphere = try Sphere.buildComputePipelineSphere(device: device, library: library!)
    } catch {
      print("Unable to compile compute pipeline state (for sphere): \(error)")
      return nil
    }
      
    var sphereData = Sphere.getSphereDataEq(radius: radius, vertexCount: vertexCount)
    let maxM_theta = round(2 * Float.pi / sphereData.d_theta)
    
    let semaphore = DispatchSemaphore(value: 1)
      
    // Prepare threadgroup size
    let w = computePipelineStateSphere!.threadExecutionWidth
    let h = computePipelineStateSphere!.maxTotalThreadsPerThreadgroup / w
    let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
    let threadsPerGrid = MTLSize(width: Int(sphereData.m_phi), height: Int(maxM_theta), depth: 1) // Not sure what to set for height
    
    let ptr = buffer!.contents().assumingMemoryBound(to: Vertex.self)
    let results = UnsafeMutableBufferPointer(start: ptr, count: Int(vertexCount))
    // hol up
    semaphore.wait()
    
    guard let commandBuffer = commandQueue!.makeCommandBuffer() else { return nil }
    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
    computeEncoder.setComputePipelineState(computePipelineStateSphere!)
    
    computeEncoder.setBuffer(buffer, offset: 0, index: 0)
    computeEncoder.setBytes(&sphereData, length: MemoryLayout<SphereDataEq>.stride, index: 1)
    computeEncoder.dispatchThreads(threadsPerGrid,
                                   threadsPerThreadgroup: threadsPerThreadgroup)
    
    computeEncoder.endEncoding()

    commandBuffer.addCompletedHandler { _ in
      semaphore.signal()
    }
  
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    vertices.append(contentsOf: results)
    
    end = mach_absolute_time()
    print("GPU time: \(Double(end - start) / Double(NSEC_PER_SEC))")
    
    super.init(name: "Sphere", vertices: vertices, device: device)
  }
  
  class func getSphereDataEq(radius: Float, vertexCount: UInt) -> SphereDataEq {
    let sa = 4 * Float.pi * radius * radius / Float(vertexCount)
    let d = sqrtf(sa)
    let m_phi = round(Float.pi / d)
    let d_phi = Float.pi / m_phi
    let d_theta = sa / d_phi
    
    return SphereDataEq(radius: radius, m_phi: m_phi, d_theta: d_theta)
  }
  
  class func buildComputePipelineSphere(device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
    let sphereShader = library.makeFunction(name: "sphere_eq_generator")
    return try device.makeComputePipelineState(function: sphereShader!)
  }
}

