//
//  MatrixOperations.swift
//  MetalIntro1
//
//  Created by Colin Ford on 1/21/20.
//  Copyright © 2020 colinford. All rights reserved.
//  Some logic borrowed from an Apple sample project, will link in README
//  There are a few shortcomings here that will be addressed later

import Foundation
import MetalKit

// When we access elements in a matrix, the order is not the commonplace 'rows first, columns second'
// Instead, it is 'columns first, rows second'
// Thus, if matrix is a 3x3 matrix, then matrix[0, 2] is the element m_{2 0} (bottom-left entry)

// Create 3D translation matrices:
//   Translate the object of interest from its current position (x, y, z) to (x + tx, y + ty, z + tz)
func makeTranslationMatrix(tx: Float, ty: Float, tz: Float) -> float4x4 {
    var matrix = matrix_identity_float4x4
    
    matrix[3, 0] = tx
    matrix[3, 1] = ty
    matrix[3, 2] = tz
    
    return matrix
}

// Create 3D scaling matrices:
//   Scale object of interest by sx in x, sy in y, and sz in z
//   Assume object of interest is centered about the origin
func makeScalingMatrixOrigin(scale: Float) -> float4x4 {
    return simd_float4x4(diagonal: simd_float4(scale, scale, scale, 1))
}

//   Do not assume object of interest is centered about the origin
func makeScalingMatrixGeneral(scale: Float, barycenter: simd_float4) -> float4x4 {
    let translationMatrix = makeTranslationMatrix(tx: barycenter.x, ty: barycenter.y, tz: barycenter.z)
    var scalingMatrix = makeScalingMatrixOrigin(scale: scale)
    let inverseTranslationMatrix = translationMatrix.inverse
    
    scalingMatrix = inverseTranslationMatrix * scalingMatrix * translationMatrix
    
    return scalingMatrix
}

func makeNonUniformScalingMatrixOrigin(sx: Float, sy: Float, sz: Float) -> float4x4 {
    let matrix = simd_float4x4(diagonal: simd_float4(sx, sy, sz, 1))
    
    return matrix
}

//   Do not assume object of interest is centered about the origin
func makeNonUniformScalingMatrixGeneral(sx: Float, sy: Float, sz: Float, barycenter: simd_float4) -> float4x4 {
    let translationMatrix = makeTranslationMatrix(tx: barycenter.x, ty: barycenter.y, tz: barycenter.z)
    var scalingMatrix = makeNonUniformScalingMatrixOrigin(sx: sx, sy: sy, sz: sz)
    let inverseTranslationMatrix = translationMatrix.inverse
    
    scalingMatrix = inverseTranslationMatrix * scalingMatrix * translationMatrix
    
    return scalingMatrix
}

// Create 3D rotation matrices:
//   Rotate object ccw about z-axis by angle
func makeRotationMatrixZ(angle: Float) -> float4x4 {
    let rows = [
        simd_float4( cos(angle), sin(angle), 0, 0),
        simd_float4(-sin(angle), cos(angle), 0, 0),
        simd_float4( 0, 0, 1, 0),
        simd_float4( 0, 0, 0, 1)
    ]
    
    return simd_float4x4(rows: rows)
}

//   Rotate object ccw about z-axis by angle
func makeRotationMatrixY(angle: Float) -> float4x4 {
    let rows = [
        simd_float4( cos(angle), 0, sin(angle), 0),
        simd_float4( 0, 1, 0, 0),
        simd_float4( -sin(angle), 0, cos(angle), 0),
        simd_float4( 0, 0, 0, 1)
    ]
    
    return simd_float4x4(rows: rows)
}

//   Rotate object ccw about x-axis by angle
func makeRotationMatrixX(angle: Float) -> float4x4 {
    let rows = [
        simd_float4( 1, 0, 0, 0),
        simd_float4( 0, cos(angle), -sin(angle), 0),
        simd_float4( 0, sin(angle), cos(angle), 0),
        simd_float4( 0, 0, 0, 1)
    ]
    
    return simd_float4x4(rows: rows)
}

//   Rotate object ccw about specified axis by angle. Axis is specified by the initial point of the
//     direction vector
func makeRotationMatrix(axisPoint: simd_float4, axisDirection: simd_float4, angle: Float) -> float4x4 {
    var rotationMatrix = makeRotationMatrixZ(angle: angle)
    let rotateX = makeRotationMatrixX(angle: atan(axisDirection.y / axisDirection.z))
    let inverseRotateX = rotateX.inverse
    let rotateY = makeRotationMatrixY(angle: atan(axisDirection.x / axisDirection.z))
    let inverseRotateY = rotateY.inverse
    let translate = makeTranslationMatrix(tx: axisPoint.x, ty: axisPoint.y, tz: axisPoint.z)
    let inverseTranslate = translate.inverse
    
    rotationMatrix = inverseTranslate * rotateY * rotateX * rotationMatrix * inverseRotateX * inverseRotateY * translate
    
    return rotationMatrix
}

//
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

//
func makeModelViewMatrix() -> float4x4 {
    let modelMatrix = makeScalingMatrixOrigin(scale: 2) * matrix_rotation(angle: -Float.pi / 4, axis: simd_float4(0, 1, 0, 0))
    let viewMatrix = makeTranslationMatrix(tx: 0, ty: 0, tz: 2)
    let modelViewMatrix = viewMatrix * modelMatrix
    
    return modelViewMatrix
}

//
func makeModelViewMatrix(angle: Float) -> float4x4 {
    let modelMatrix = matrix_rotation(angle: -angle, axis: simd_float4(-1, -1, 0, 0)) * makeScalingMatrixOrigin(scale: 2)
    let viewMatrix = makeTranslationMatrix(tx: 0, ty: 0, tz: -9)
    let modelViewMatrix = viewMatrix * modelMatrix
    
    return modelViewMatrix
}

func makeProjectionMatrix(view: MTKView) -> float4x4 {
    let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
    let nearZ = Float(0.1), farZ = Float(100)
    let yy = 1 / tan(Float.pi / 6)
    let xx = yy / aspectRatio
    let zRange = farZ - nearZ
    let zz = -(farZ + nearZ) / zRange
    let wz = -(2 * farZ * nearZ) / zRange
    let zw = Float(-1)
    
    let rows = [
        simd_float4(xx,  0, 0,  0),
        simd_float4(0, yy,  0,  0),
        simd_float4(0,  0, zz, wz),
        simd_float4(0,  0, zw,  0)
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

func matrix_perspective_right_hand(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> float4x4 {
    let ys = 1 / tan(fovyRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)
    
    let rows = [
        simd_float4(xs, 0,  0,          0),
        simd_float4(0, ys,  0,          0),
        simd_float4(0,  0, zs, nearZ * zs),
        simd_float4(0,  0, -1,          0)
    ]
    
    return float4x4(rows: rows)
}

func matrix_ortho_left_hand(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> float4x4 {
    let rows = [
        simd_float4(2 / (right - left), 0,                  0, (left + right) / (left - right)),
        simd_float4(0, 2 / (top - bottom),                  0, (top + bottom) / (bottom - top)),
        simd_float4(0,                  0, 1 / (farZ - nearZ),          nearZ / (nearZ - farZ)),
        simd_float4(0,                  0,                  0,                               1)
    ]
    
    return simd_float4x4(rows: rows)
}

func matrix_ortho_right_hand(left: Float, right: Float, bottom: Float, top: Float, nearZ: Float, farZ: Float) -> float4x4 {
    let rows = [
        simd_float4(2 / (right - left), 0,                   0, (left + right) / (left - right)),
        simd_float4(0, 2 / (top - bottom),                   0, (top + bottom) / (bottom - top)),
        simd_float4(0,                  0, -1 / (farZ - nearZ),          nearZ / (nearZ - farZ)),
        simd_float4(0,                  0,                   0,                               1)
    ]
    
    return float4x4(rows: rows)
}
