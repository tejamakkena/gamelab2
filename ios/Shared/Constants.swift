import Foundation
import SwiftUI

enum AppConstants {
    // Change this to your server's address (local dev or deployed)
    static let serverURL = URL(string: "http://localhost:5000")!

    /// The native apps talk to their own Socket.IO namespace, kept separate
    /// from the browser games so the two cannot collide.
    static let socketNamespace = "/native"

    // Stable per-device identifier (persisted in UserDefaults)
    static var deviceID: String {
        let key = "gamelab_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

// MARK: - Color(hex:) convenience

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double((int >>  0) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
