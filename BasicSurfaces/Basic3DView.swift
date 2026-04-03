//
//  Basic3DView.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import MetalUI
import SwiftUI

/// The root SwiftUI view for the app, embedding a Metal-rendered ``Sphere`` via `MetalView`
/// and ``Basic3DPresenter``.
struct Basic3DView: View {
  /// The Metal presenter that owns the renderer and sphere.
  @State private var presenter = Basic3DPresenter()
  /// Tracks whether the brightness cosine animation is active.
  @State private var isFadeEnabled = false
  /// The sphere vertex generation method currently in use.
  @State private var generationMethod: SphereGenerationMethod = .cpu
  
  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      MetalView { presenter }
        .ignoresSafeArea()
      
      HStack(spacing: 12) {
        /// Toggles between CPU and GPU sphere vertex generation.
        Button {
          let desired: SphereGenerationMethod = generationMethod == .cpu ? .gpu : .cpu
          generationMethod = presenter.regenerateSphere(method: desired)
        } label: {
          Text(generationMethod == .cpu ? "CPU" : "GPU")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(12)
            .background(.ultraThinMaterial, in: Capsule())
        }
        
        /// Toggles the brightness fade animation on the fragment shader.
        Button {
          isFadeEnabled.toggle()
          presenter.isFadeEnabled = isFadeEnabled
        } label: {
          Image(systemName: isFadeEnabled ? "sun.max.fill" : "sun.max")
            .font(.title2)
            .foregroundStyle(.white)
            .padding(12)
            .background(.ultraThinMaterial, in: Circle())
        }
      }
      .padding()
    }
  }
}

#Preview {
  Basic3DView()
}
