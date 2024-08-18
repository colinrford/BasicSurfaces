import MetalKit

public struct Vertex {
    public var pos: simd_float4
    public var color: simd_float4

    public init(pos: simd_float4, color: simd_float4) {
        self.pos = pos
        self.color = color
    }
}
