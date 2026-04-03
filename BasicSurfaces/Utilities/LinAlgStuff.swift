//
//  LinAlgStuff.swift
//  BasicSurfaces
//

import MetalKit

/// Builds a combined model-view matrix by applying scale, then rotation, then translation.
///
/// The result is typically stored in ``VertexUniforms/modelViewMatrix``.
///
/// - Parameters:
///   - scale: Uniform scale factor.
///   - axis: Rotation axis as `simd_float4`; only the xyz components are used.
///   - angle: Rotation angle in radians.
///   - translation: Camera/view offset in world space.
/// - Returns: The composed model-view matrix.
func makeModelViewMatrix(scale: Float, axis: simd_float4, angle: Float, translation: simd_float3) -> float4x4 {
  let modelMatrix = makeScalingMatrixOrigin(scale: scale) * matrix_rotation(angle: angle, axis: axis)
  let viewMatrix = makeTranslationMatrix(by: translation)
  let modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix)
  
  return modelViewMatrix
}

/// Creates a uniform scaling matrix about the origin.
///
/// - Parameter scale: Scale factor applied equally to x, y, and z.
/// - Returns: A 4×4 scaling matrix.
func makeScalingMatrixOrigin(scale: Float) -> float4x4 {
    return simd_float4x4(diagonal: simd_float4(scale, scale, scale, 1))
}

/// Creates a translation matrix.
///
/// - Parameter by: Translation vector.
/// - Returns: A 4×4 translation matrix.
func makeTranslationMatrix(by: simd_float3) -> float4x4 {
  var matrix = matrix_identity_float4x4
  
  matrix[3, 0] = by.x
  matrix[3, 1] = by.y
  matrix[3, 2] = by.z
  
  return matrix
}

/// Builds a rotation matrix using Rodrigues' rotation formula.
///
/// - Parameters:
///   - angle: Rotation angle in radians.
///   - axis: Rotation axis as `simd_float4`; the vector is normalized internally.
/// - Returns: A 4×4 rotation matrix.
/// - Note: The `w` component of `axis` is ignored after normalization.
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

/// Builds a left-handed perspective projection matrix for Metal's clip-space conventions.
///
/// - Parameters:
///   - fovyRadians: Vertical field of view in radians.
///   - aspect: Width-to-height aspect ratio.
///   - nearZ: Distance to the near clipping plane (must be positive).
///   - farZ: Distance to the far clipping plane (must be greater than `nearZ`).
/// - Returns: A 4×4 perspective projection matrix.
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
