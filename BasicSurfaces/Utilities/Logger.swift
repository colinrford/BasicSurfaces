//
//  Logger.swift
//  BasicSurfaces
//
//  Copyright © 2026 Colin Ford. All rights reserved.
//

import OSLog

/// Extension of `Logger` for use in BasicSurfaces app.
///
/// - Note: Falls back to `"com.colinford.basicsurfaces"` when
///   `Bundle.main.bundleIdentifier` is `nil` (e.g., in unit tests or Xcode Previews).
extension Logger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.colinford.basicsurfaces"
  /// Renderer and Metal resource lifecycle events.
  static let renderer = Logger(subsystem: subsystem, category: "Renderer")
  /// Surface geometry and GPU compute events.
  static let basicSurfaces = Logger(subsystem: subsystem, category: "basicSurfaces")
}

/// Extension of `OSSignposter` for use in BasicSurfaces app
extension OSSignposter {
  /// Renderer and Metal resource lifecycle events.
  static let renderer = OSSignposter(logger: .renderer)
  /// Surface geometry and GPU compute events.
  static let basicSurfaces = OSSignposter(logger: .basicSurfaces)
}
