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
  @State private var presenter = Basic3DPresenter()
  @State private var isFadeEnabled = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      MetalView { presenter }
        .ignoresSafeArea()

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
      .padding()
    }
  }
}

#Preview {
  Basic3DView()
}
