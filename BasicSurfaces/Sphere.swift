//
//  Sphere.swift
//  BasicSurfaces
//
//  Created by Colin Ford on 1/21/20.
//  Copyright © 2020 Colin Ford. All rights reserved.
//

import Foundation
import Metal

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

class Sphere : Node {
    
    init(device: MTLDevice) {
        
        var start, end : UInt64
        
        start = mach_absolute_time()
        
        // This particular algorithm due to Markus Deserno, Associate Professor at CMU (as of 1/28/20)
        // Set up for algorithm of placing vertices on surface of sphere of radius r
        let r = Float(2), vertexCount = Float(10240) * r * r
        let sa = 4 * Float.pi * (r * r) / vertexCount
        let d = sqrtf(sa)
        let m_phi = roundf(Float.pi / d)
        let d_phi = Float.pi / m_phi, d_theta = sa / d_phi
        
        var vertices = Array<Vertex>()
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
                let vertex = Vertex(color: simd_float4(simd_fract(theta), simd_fract(phi), abs(simd_fract(phi - theta)), 1), pos: simd_float4(x, y, z, 0))
                
                vertices.append(vertex)
            }
        }
        
        end = mach_absolute_time()
        print("CPU time: \(Double(end - start) / Double(NSEC_PER_SEC))")
        
        super.init(name: "Sphere", vertices: vertices, device: device)
    }
    
    init(device: MTLDevice, vertices: Array<Vertex>) throws {
        
        super.init(name: "Sphere", vertices: vertices, device: device)
    }
    
    init?(device: MTLDevice, commandQueue: MTLCommandQueue, pipelineState: MTLComputePipelineState, buffer: MTLBuffer) {
        
        var start, end : UInt64
        
        start = mach_absolute_time()
        
        let semaphore = DispatchSemaphore(value: 1)
        
        // Set up for algorithm of placing vertices on surface of sphere of radius r
        let r = Float(2.5), vertexCount = Float(1024000)
        let sa = 4 * Float.pi * r * r / (vertexCount)
        let d = sqrtf(sa)
        let m_phi = round(Float.pi / d)
        let d_phi = Float.pi / m_phi, d_theta = sa / d_phi
        let maxM_theta = round(2 * Float.pi / d_theta)
        
        print("max M_theta = \(maxM_theta), M_phi = \(m_phi), d_phi = \(d_phi), d_theta = \(d_theta)")
        // let avg = (d_theta + d_phi) / 2 // keep this in mind for later
        
        var vertices = Array<Vertex>()
        var sphereData = SphereDataEq(radius: r, m_phi: m_phi, d_theta: d_theta)
        
        // Prepare threadgroup size
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadsPerGrid = MTLSize(width: Int(m_phi), height: Int(maxM_theta), depth: 1) // Not sure what to set for height
        
        let ptr = buffer.contents().assumingMemoryBound(to: Vertex.self)
        let results = UnsafeMutableBufferPointer(start: ptr, count: Int(vertexCount))
        // hol up
        semaphore.wait()
            
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        // Begin encoding
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        computeEncoder.setComputePipelineState(pipelineState)
        
        // Fill buffer with data
        computeEncoder.setBuffer(buffer, offset: 0, index: 0)
        computeEncoder.setBytes(&sphereData, length: MemoryLayout<SphereDataEq>.stride, index: 1)
        computeEncoder.dispatchThreads(threadsPerGrid,
                                            threadsPerThreadgroup: threadsPerThreadgroup)
        
        // Finish encoding
        computeEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }
        
        // Send the encoded command buffer to the GPU.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        //vertices = Array<Vertex>(results)
        vertices.append(contentsOf: results)
        
        end = mach_absolute_time()
        
        let pos = simd_float4(0, 0, 0, 0)
        var i = 0
        for vertex in vertices {
            if (vertex.pos == pos) {
                i += 1
            }
        }
        print("number of vertices equal to 0: \(i)")
        print("GPU time: \(Double(end - start) / Double(NSEC_PER_SEC))")
        
        super.init(name: "Sphere", vertices: vertices, device: device)
    }
}
