//
//  vertex.h
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

#ifndef vertex_h
#define vertex_h

#include <simd/simd.h>

struct Vertex 
{
  simd_float4 pos;
  simd_float4 color;
};

struct VertexUniforms
{
  simd_float4x4 modelViewMatrix;
  simd_float4x4 projectionMatrix;
};

struct VertexOut
{
  simd_float4 pos [[position]];
  simd_float4 color;
};

#endif /* vertex_h */
