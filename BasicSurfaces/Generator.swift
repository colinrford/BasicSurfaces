//
//  Generator.swift
//  BasicSurfaces
//
//  Created by Colin Ford on 2/5/20.
//  Copyright © 2020 Colin Ford. All rights reserved.
//

import Foundation
import Metal
import MetalKit

class Generator {
    
    let device: MTLDevice
    let library: MTLLibrary
    
    init?(device: MTLDevice, library: MTLLibrary) {
        
        // Create pipeline for generating nodes on a sphere
        do {
            computePipelineStateSphere = try Renderer.buildComputePipelineSphere(device: device, library: library!)
        } catch {
            print("Unable to compile compute pipeline state (for sphere): \(error)")
            return nil
        }
    }
    
    // Create sphere shader pipeline
    class func buildComputePipelineSphere(device: MTLDevice, library: MTLLibrary) throws -> MTLComputePipelineState {
        //
        let sphereShader = library.makeFunction(name: "sphereShaderEq")
        
        return try device.makeComputePipelineState(function: sphereShader!)
    }
    
    // Create sphere vertices
    func generateSphereVertices(radius: Float, vertexCount: Float) -> Array<Vertex> {
        var start, end : UInt64
        
        start = mach_absolute_time()
        
        // Set up for algorithm of placing vertices on surface of sphere of radius r
        let r = radius
        let sideLength = floor(sqrt(vertexCount / 2))
        let r_i = r / sideLength, theta_j = 2 * Float.pi / sideLength
        
        var vertices = Array<Vertex>()
        var sphereData = SphereData(r_i: r_i, theta_j: theta_j, vertexCount: Int(vertexCount), sideLength: Int(sideLength))
        
        // Prepare threadgroup size
        let w = computePipelineStateSphere.threadExecutionWidth
        let h = computePipelineStateSphere.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        let threadsPerGrid = MTLSize(width: Int(sideLength), height: Int(sideLength), depth: 1) // Not sure what to set for height
        
        let ptr = dynamicDataBuffers[currentFrameIndex].contents().assumingMemoryBound(to: Vertex.self)
        let results = UnsafeMutableBufferPointer(start: ptr, count: Int(vertexCount))
        
        // Use modular arithmetic to restrict values to 0, 1, 2
        currentFrameIndex = (currentFrameIndex + 1) % maxInflightBuffers
        
        // hol up
        frameBoundarySemaphore.wait()
            
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return [] }
        // Begin encoding
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return [] }
        computeEncoder.setComputePipelineState(computePipelineStateSphere)
        
        // Fill buffer with data
        computeEncoder.setBuffer(dynamicDataBuffers[currentFrameIndex], offset: 0, index: 0)
        computeEncoder.setBytes(&sphereData, length: MemoryLayout<SphereDataEq>.stride, index: 1)
        computeEncoder.dispatchThreads(threadsPerGrid,
                                            threadsPerThreadgroup: threadsPerThreadgroup)
        
        // Finish encoding
        computeEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            self.frameBoundarySemaphore.signal()
        }
        
        // Send the encoded command buffer to the GPU.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
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
        
        return vertices
    }
}
