//
//  Node.swift
//  BasicSurfaces
//
//  Created by Colin Ford on 12/1/19.
//  Copyright © 2020 Colin Ford. All rights reserved.
//  Some code borrowed from elsewhere. See README

import Foundation
import Metal
import QuartzCore

class Node {
    
    let device: MTLDevice
    let name: String
    var vertexCount: Int
    var vertices: Array<Vertex>
    
    init(name: String, vertices: Array<Vertex>, device: MTLDevice) {
        
        // Set instance variables
        self.name = name
        self.device = device
        vertexCount = vertices.count
        self.vertices = vertices
    }
}
