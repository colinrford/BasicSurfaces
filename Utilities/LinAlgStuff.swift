//
//  LinAlgStuff.swift
//  BasicSurfaces
//

import MetalKit

func makeModelViewMatrix(scale: Float, axis: simd_float4, angle: Float, translation: simd_float3) -> float4x4 {
  let modelMatrix = makeScalingMatrixOrigin(scale: scale) * matrix_rotation(angle: angle, axis: axis)
  let viewMatrix = makeTranslationMatrix(by: translation)
  let modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix)
  
  return modelViewMatrix
}

func makeScalingMatrixOrigin(scale: Float) -> float4x4 {
    return simd_float4x4(diagonal: simd_float4(scale, scale, scale, 1))
}

func makeTranslationMatrix(by: simd_float3) -> float4x4 {
  var matrix = matrix_identity_float4x4
  
  matrix[3, 0] = by.x
  matrix[3, 1] = by.y
  matrix[3, 2] = by.z
  
  return matrix
}

func matrix_rotation(angle: Float, axis: simd_float4) -> simd_float4x4 {
  let axisNormalized = normalize(axis);
  let ct = cos(angle);
  let st = sin(angle);
  let ci = 1 - ct;
  let x = axisNormalized.x, y = axisNormalized.y, z = axisNormalized.z;
  
  let rows = [
    simd_float4(    ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st, 0),
    simd_float4(y * x * ci + z * st,     ct + y * y * ci, y * z * ci - x * st, 0),
    simd_float4(z * x * ci - y * st, z * y * ci + x * st,     ct + z * z * ci, 0),
    simd_float4(                  0,                   0,                   0, 1)
  ]
  
  return simd_float4x4(rows: rows)
}

func matrix_perspective_left_hand(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> float4x4 {
  let ys = 1 / tan(fovyRadians * 0.5)
  let xs = ys / aspect
  let zs = farZ / (farZ - nearZ)
  
  let rows = [
    simd_float4(xs, 0,  0,           0),
    simd_float4(0, ys,  0,           0),
    simd_float4(0,  0, zs, -nearZ * zs),
    simd_float4(0,  0,  1,           0)
  ]
  
  return float4x4(rows: rows)
}
