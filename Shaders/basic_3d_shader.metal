//
//  basic_3d_shader.metal
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "vertex.h"

using namespace metal;

struct FragmentUniforms
{ float brightness; };

vertex VertexOut basic_3d_vertex_shader(const device Vertex* vertexArray [[buffer(0)]],
                                        const device VertexUniforms& uniforms [[buffer(1)]],
                                        uint vid [[vertex_id]])
{
  Vertex in = vertexArray[vid];
  VertexOut out;

  out.pos = float4(normalize((uniforms.projectionMatrix * uniforms.modelViewMatrix * in.pos).xyz), 1); // heh
  out.color = in.color;
  
  return out;
}

fragment float4 basic_3d_fragment_shader(VertexOut interpolated [[stage_in]],
                                         const device FragmentUniforms& uniforms [[buffer(0)]])
{
  return float4(uniforms.brightness * interpolated.color.rgb, interpolated.color.a);
}
