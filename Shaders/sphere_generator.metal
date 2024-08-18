//
//  sphere_generator.metal
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

#include <metal_stdlib>
#include "vertex.h"

using namespace metal;

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

// For generating equidistributed points on surface of a sphere
// This particular algorithm due to Markus Deserno, Associate Professor at CMU (as of 1/28/20)
kernel void sphere_eq_generator(device Vertex* sphereVertices [[buffer(0)]],
                                const device SphereDataEq& sphereData [[buffer(1)]],
                                uint2 position [[thread_position_in_grid]])
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
  for (uint i = 0; i < position.x; i++) 
  {
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
