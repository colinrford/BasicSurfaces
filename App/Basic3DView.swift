//
//  Basic3DView.swift
//  BasicSurfaces
//
//  Copyright © 2024 Colin Ford. All rights reserved.
//

import MetalUI
import SwiftUI

struct Basic3DView: View {
  var body: some View {
    MetalView {
      Basic3DPresenter()
    }
  }
}

#Preview {
  Basic3DView()
}
