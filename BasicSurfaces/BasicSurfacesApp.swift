//
//  BasicSurfacesApp.swift
//  BasicSurfaces
//
//  Copyright © 2024-2026 Colin Ford. All rights reserved.
//

import SwiftUI

/// The app entry point, presenting a single window containing ``Basic3DView``.
@main
struct BasicSurfacesApp: App {
  var body: some Scene {
    WindowGroup {
      Basic3DView()
    }
  }
}
