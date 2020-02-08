//
//  BasicSurfaces.metal
//  BasicSurfaces
//
//  Created by Colin Ford on 2/3/20.
//  Copyright © 2020 Colin Ford. All rights reserved.
//  Some code borrowed from other sources. See README
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

#include "ShaderDefinitions.h"

struct VertexUniforms
{
    simd_float4x4 modelViewMatrix;
    simd_float4x4 projectionMatrix;
};

struct VertexOut
{
    simd_float4 color;
    simd_float4 pos [[position]];
};

struct SphereData {
    float r_i;
    float theta_j;
    int vertexCount;
    int sideLength;
};

struct SphereDataEq {
    float radius;
    float m_phi;
    float d_theta;
};

vertex VertexOut vertexShader(const device Vertex* vertexArray [[buffer(0)]], const device VertexUniforms &uniforms [[buffer(1)]], uint vid [[vertex_id]])
{
    // Get the data for the current vertex.
    Vertex in = vertexArray[vid];
    
    VertexOut out;
    
    // Pass the vertex color directly to the rasterizer
    out.color = in.color;
    // Pass the already normalized screen-space coordinates to the rasterizer
    out.pos = normalize(uniforms.projectionMatrix * uniforms.modelViewMatrix * simd_float4(in.pos.xyz, 1));
    
    return out;
}

fragment float4 fragmentShader(VertexOut interpolated [[stage_in]], const device FragmentUniforms &uniforms [[buffer(0)]])
{
    return float4(uniforms.brightness * interpolated.color.rgb, interpolated.color.a);
}

// For generating points on surface of a sphere
kernel void sphereShader(device Vertex* sphereVertices [[buffer(0)]], const device SphereData &sphereData [[buffer(1)]], uint2 position [[thread_position_in_grid]])
{
    // First compute pair $(r, \theta)$
    // half r_i = sphereData.radius * position.x / sphereData.sideLength;
    // float theta_j = 2 * M_PI_F * position.y / sphereData.sideLength;
    // Compute the index of the new vertex
    int index = position.x + sphereData.sideLength * position.y;
    // Compute position coorindate
    float pos_x = 2 * sphereData.r_i * cos(sphereData.theta_j) / (1 + sphereData.r_i * sphereData.r_i);
    float pos_y = 2 * sphereData.r_i * sin(sphereData.theta_j) / (1 + sphereData.r_i * sphereData.r_i);
    float pos_z = (-1 + sphereData.r_i * sphereData.r_i) / (1 + sphereData.r_i * sphereData.r_i);
    float pos_w = 1;
    sphereVertices[index].pos.xyz = simd_float3(pos_x, pos_y, pos_z);
    sphereVertices[index].pos.w = sphereVertices[sphereData.vertexCount - index].pos.w = pos_w;
    sphereVertices[sphereData.vertexCount - index].pos.xyz = simd_float3(pos_x, -pos_y, -pos_z);
    // Set colors relatively randomly
    simd_float4 color = (fract(sphereData.theta_j), fract(sphereData.r_i * sphereData.theta_j), abs(fract(1 - sphereData.theta_j)), 1);
    sphereVertices[index].color = color;
    sphereVertices[sphereData.vertexCount - index].color = color;
}

// For generating equidistributed points on surface of a sphere
// This particular algorithm due to Markus Deserno, Associate Professor at CMU (as of 1/28/20)
kernel void sphereShaderEq(device Vertex* sphereVertices [[buffer(0)]], const device SphereDataEq &sphereData [[buffer(1)]], uint2 position [[thread_position_in_grid]])
{
    // Compute angle phi, the angle measured from +z-axis (zenith). Longitude
    float phi = M_PI_F * (position.x + 0.5) / sphereData.m_phi;
    // Compute m_theta for checking if index.y is out of bounds. Unfortunately redundant aspect of this implementation
    float m_theta = 2 * M_PI_F * sin(phi) / sphereData.d_theta;
    if (position.y >= round(m_theta))
        return; // out of bounds. Lots of wasted resources :0(
    // Index.y is in bounds, determine the index in which to insert the vertex generated below
    int index = 0;
    float p;
    float m_t;
    for (uint i = 0; i < position.x; i++) {
        p = M_PI_F * (i + 0.5) / sphereData.m_phi;
        m_t = 2 * M_PI_F * sin(p) / sphereData.d_theta;
        index += round(m_t);
    }
    index += position.y;
    // Compute angle theta, as measured from positive x-axis (azimuth). Latitude
    float theta = 2 * M_PI_F * position.y / m_theta;
    // Set positions
    sphereVertices[index].pos.x = sphereData.radius * sin(phi) * cos(theta);
    sphereVertices[index].pos.y = sphereData.radius * sin(phi) * sin(theta);
    sphereVertices[index].pos.z = sphereData.radius * cos(phi);
    sphereVertices[index].pos.w = 1; // don't think too hard about it.
    // Assign colors fairly randomly
    sphereVertices[index].color.r = fract(phi);
    sphereVertices[index].color.g = fract(theta);
    sphereVertices[index].color.b = abs(fract(theta - phi));
    sphereVertices[index].color.a = 1;
    
}

// Blah blah. Make a step function?
kernel void simd_sphereShader(device Vertex* sphereVertices [[buffer(0)]], const device SphereData &sphereData [[buffer(1)]], uint2 index [[thread_position_in_grid]])
{
    
}
