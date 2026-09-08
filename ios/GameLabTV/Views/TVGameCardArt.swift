import SwiftUI

/// Per-category visual identity for the TV game grid.
///
/// Forty-one cards that were all the same purple rectangle read as one
/// undifferentiated wall -- reported directly as "icons for each app look too
/// basic with just an emoji". Giving every `GameCategory` its own two-stop
/// gradient, a single accent for glows/rings (a gradient muddies a glow) and a
/// corner glyph lets the grid be scanned by colour before a single title is
/// read, and makes the sidebar's category pills read as that grid's legend.
///
/// Kept as one table rather than a switch per property, for exactly the reason
/// `GameMeta` is: one exhaustive switch means the compiler catches a newly
/// added category instead of a `default:` arm silently answering "grey", and
/// every field has to be stated deliberately.
///
/// Everything here is drawn procedurally -- no image assets -- so it costs
/// nothing to ship and scales cleanly from 1080p to 4K.
struct TVCategoryStyle {
    /// Top-leading stop of the card's wash.
    let top: Color
    /// Bottom-trailing stop of the card's wash.
    let bottom: Color
    /// One flat colour for the focus glow and the ring behind the emoji.
    let accent: Color
    /// Small SF Symbol pinned to the card's top-leading corner. All of these
    /// ship in SF Symbols 1-4, so they are safe on the tvOS 17 deployment
    /// target with no availability check.
    let symbol: String
}

extension GameCategory {
    var tvStyle: TVCategoryStyle {
        switch self {
        case .party:
            return .init(top: Color(hex: "FF3CAC"), bottom: Color(hex: "FF7A45"),
                         accent: Color(hex: "FF5C8A"), symbol: "party.popper.fill")
        case .knowledge:
            return .init(top: Color(hex: "22D3EE"), bottom: Color(hex: "2563EB"),
                         accent: Color(hex: "38BDF8"), symbol: "lightbulb.fill")
        case .social:
            return .init(top: Color(hex: "C084FC"), bottom: Color(hex: "7C3AED"),
                         accent: Color(hex: "A855F7"), symbol: "person.2.fill")
        case .strategy:
            return .init(top: Color(hex: "2DD4BF"), bottom: Color(hex: "0E7490"),
                         accent: Color(hex: "14B8A6"), symbol: "square.grid.3x3.fill")
        case .casino:
            return .init(top: Color(hex: "FACC15"), bottom: Color(hex: "15803D"),
                         accent: Color(hex: "EAB308"), symbol: "suit.spade.fill")
        case .coop:
            return .init(top: Color(hex: "BEF264"), bottom: Color(hex: "4D7C0F"),
                         accent: Color(hex: "84CC16"), symbol: "person.3.fill")
        case .creative:
            return .init(top: Color(hex: "F0ABFC"), bottom: Color(hex: "D946EF"),
                         accent: Color(hex: "E879F9"), symbol: "paintbrush.fill")
        case .action:
            return .init(top: Color(hex: "FB923C"), bottom: Color(hex: "EF4444"),
                         accent: Color(hex: "F97316"), symbol: "bolt.fill")
        case .solo:
            return .init(top: Color(hex: "E2E8F0"), bottom: Color(hex: "64748B"),
                         accent: Color(hex: "CBD5E1"), symbol: "person.fill")
        }
    }
}
