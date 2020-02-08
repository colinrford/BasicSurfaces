//
//  Renderer.swift
//  BasicSurfaces
//
//  Copyright © 2020 Colin Ford. All rights reserved.
//  Some code borrowed from elsewhere. See README

import Foundation
import Metal
import MetalKit

struct VertexUniforms {
    var modelViewMatrix: simd_float4x4
    var projectionMatrix: simd_float4x4
}

let maxInflightBuffers: Int = 3

class Renderer : NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let computePipelineStateSphere: MTLComputePipelineState
    var vertexUniforms: VertexUniforms
    let fragmentUniformsBuffer: MTLBuffer
    
    let objectToDraw: Sphere
    
    let aspect: Float
    var currentFrameIndex: Int
    let frameBoundarySemaphore = DispatchSemaphore(value: maxInflightBuffers)
    var dynamicDataBuffers: Array<MTLBuffer>
    var dynamicBufferHasInitialized: Array<Bool>
    
    // This keeps track of the system time of the last render
    var lastRenderTime: CFTimeInterval? = nil
    // This is the current time in our app, starting at 0, in units of seconds
    var currentTime: Double = 0
    // Testing rotations with time
    var time: Float = 0
    
    // This is the initializer for the Renderer class.
    // We will need access to the mtkView later, so we add it as a parameter here.
    init?(mtkView: MTKView) {
        device = mtkView.device!
        let library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()!
        
        // Create the Render Pipeline
        do {
            pipelineState = try Renderer.buildRenderPipelineWith(device: device, metalKitView: mtkView, library: library!)
        } catch {
            print("Unable to compile render pipeline state: \(error)")
            return nil
        }
        
        aspect = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
        let fovy = Float.pi / 3
        let projectionMatrix = matrix_perspective_right_hand(fovyRadians: fovy, aspect: aspect, nearZ: Float(0.1), farZ: Float(100))
        vertexUniforms = VertexUniforms(modelViewMatrix: matrix_identity_float4x4, projectionMatrix: projectionMatrix)
        currentFrameIndex = 0
        dynamicDataBuffers = Array<MTLBuffer>()
        dynamicBufferHasInitialized = Array<Bool>()
        
        for index in 0..<maxInflightBuffers {
            // triple buffering
            let dynamicDataBuffer = device.makeBuffer(length: 10240 * MemoryLayout<Vertex>.stride, options: [])
            dynamicDataBuffers.insert(dynamicDataBuffer!, at: index)
            dynamicBufferHasInitialized.insert(false, at: index)
        }
        
        let sphere = Sphere(device: device, commandQueue: commandQueue, pipelineState: computePipelineStateSphere, buffer: dynamicDataBuffers[currentFrameIndex])
        objectToDraw = sphere!
        dynamicBufferHasInitialized[currentFrameIndex] = true
        
        // Create our uniform buffer, and fill it with an initial brightness of 1.0
        var initialFragmentUniforms = FragmentUniforms(brightness: 1.0)
        
        // Note:    Always use a multiple of a type’s stride instead of its size
        //          when allocating memory or accounting for the distance between instances
        //          in memory. (source: Apple Dev documentation/swift/memorylayout)
        let fragmentUniformsBuff = device.makeBuffer(bytes: &initialFragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, options: [])
        fragmentUniformsBuffer = fragmentUniformsBuff!
    }
    
    // Create our custom rendering pipeline, which loads shaders using `device`, and outputs to the format of `metalKitView`
    class func buildRenderPipelineWith(device: MTLDevice, metalKitView: MTKView, library: MTLLibrary) throws -> MTLRenderPipelineState {
        // Create a new pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        
        // Setup the shaders in the pipeline
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        
        // Compile the configured pipeline descriptor to a pipeline state object
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func update(t: Float, dt: CFTimeInterval) {
        // Use modular arithmetic to restrict values to 0, 1, 2
        currentFrameIndex = (currentFrameIndex + 1) % maxInflightBuffers
        
        //if (!dynamicBufferHasInitialized[currentFrameIndex]) {
            dynamicDataBuffers[currentFrameIndex].contents().copyMemory(from: objectToDraw.vertices, byteCount: objectToDraw.vertexCount * MemoryLayout<Vertex>.stride)
            //dynamicBufferHasInitialized[currentFrameIndex] = true
        //}
        
        let angle = -t
        vertexUniforms.modelViewMatrix = makeModelViewMatrix(angle: angle)
        
        //let ptr = fragmentUniformsBuffer.contents().bindMemory(to: FragmentUniforms.self, capacity: 1)
        //ptr.pointee.brightness = Float(0.5 * cos(currentTime) + 0.5)
        
        currentTime += dt
    }
    
    // mtkView will automatically call this function
    // whenever it wants new content to be rendered.
    func draw(in view: MTKView) {
        
        frameBoundarySemaphore.wait()
        
        // Compute dt
        let systemTime = CACurrentMediaTime()
        let timeDifference = (lastRenderTime == nil) ? 0 : (systemTime - lastRenderTime!)
        // Save this system time
        lastRenderTime = systemTime
        
        time += 1 / Float(view.preferredFramesPerSecond)
        
        // Update state
        update(t: time, dt: timeDifference)
        
        // Get an available command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Get the default MTLRenderPassDescriptor from the MTKView argument
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        // Change default settings. For example, we change the clear color from black to red.
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        
        // We compile renderPassDescriptor to a MTLRenderCommandEncoder.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        // Setup render commands to encode
        // We tell it what render pipeline to use
        renderEncoder.setRenderPipelineState(pipelineState)
        // What vertex buffer data to use
        renderEncoder.setVertexBuffer(dynamicDataBuffers[currentFrameIndex], offset: 0, index: 0)
        renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: 1)
        // Bind the fragment uniforms
        renderEncoder.setFragmentBuffer(fragmentUniformsBuffer, offset: 0, index: 0)
        // And what to draw
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: objectToDraw.vertexCount)
        // This finalizes the encoding of drawing commands.
        renderEncoder.endEncoding()
        // Tell Metal to send the rendering result to the MTKView when rendering completes
        commandBuffer.present(view.currentDrawable!)
        
        commandBuffer.addCompletedHandler { _ in
            self.frameBoundarySemaphore.signal()
        }
        
        // Finally, send the encoded command buffer to the GPU.
        commandBuffer.commit()
    }
    
    // mtkView will automatically call this function
    // whenever the size of the view changes (such as resizing the window).
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
