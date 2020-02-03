//
//  Cube.swift
//  BasicSurfaces
//
//  Created by Colin Ford on 12/1/19.
//  Copyright © 2020 Colin Ford. All rights reserved.
//  Some code borrowed from other sources. See the README
//

import Foundation
import Metal

class Cube: Node {
    
    init(device: MTLDevice) {
        
        let A = Vertex(color: simd_float4(1.0, 0.0, 0.0, 1.0), pos: simd_float4(-1, 1, 1, 0.0))
        let B = Vertex(color: simd_float4(0.0, 1.0, 0.0, 1.0), pos: simd_float4(-1, -1, 1, 0.0))
        let C = Vertex(color: simd_float4(0.0, 0.0, 1.0, 1.0), pos: simd_float4(1, -1, 1, 0.0))
        let D = Vertex(color: simd_float4(0.1, 0.6, 0.4, 1.0), pos: simd_float4(1, 1, 1, 0.0))
        
        let Q = Vertex(color: simd_float4(1.0, 0.0, 0.0, 1.0), pos: simd_float4(-1, 1, -1, 0.0))
        let R = Vertex(color: simd_float4(0.0, 1.0, 0.0, 1.0), pos: simd_float4(1, 1, -1, 0.0))
        let S = Vertex(color: simd_float4(0.0, 0.0, 1.0, 1.0), pos: simd_float4(-1, -1, -1, 0.0))
        let T = Vertex(color: simd_float4(0.1, 0.6, 0.4, 1.0), pos: simd_float4(1, -1, -1, 0.0))
        
        // triangularize
        let vertices:Array<Vertex> = [
            A, B, C,    A, C, D,    // Front
            R, T, S,    Q, R, S,    // Back
            
            Q, S, B,    Q, B, A,    // Left
            D, C, T,    D, T, R,    // Right
            
            Q, A, D,    Q, D, R,    // Top
            B, S, T,    B, T, C     // Bot
        ]
        
        super.init(name: "Cube", vertices: vertices, device: device)
    }
    
    init(device: MTLDevice, center: Vertex, sidelength: Float) {
        
        super.init(name: "Cube", vertices: [], device: device)
    }
}
