import SwiftUI

/// Layout families for the camera workspace.  They are derived from the
/// available canvas rather than a particular device model, so Split View and
/// future iPhone sizes continue to use the appropriate control density.
enum CaptureLayoutMode: Equatable {
    case phonePortrait
    case phoneLandscape
    case regularSideRail

    static func resolve(
        size: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> CaptureLayoutMode {
        let isLandscape = size.width > size.height
        let hasRegularCanvas = horizontalSizeClass == .regular && min(size.width, size.height) >= 600

        if hasRegularCanvas {
            return .regularSideRail
        }
        return isLandscape ? .phoneLandscape : .phonePortrait
    }
}

/// One source of truth for camera controls and the visible framing area.
/// Values are deliberately fixed in points so tall phones do not lose a
/// percentage of the preview merely because they have a larger display.
struct CaptureLayoutMetrics {
    static let phoneBottomControlHeight: CGFloat = 92
    static let phoneSideControlWidth: CGFloat = 88

    let mode: CaptureLayoutMode
    let size: CGSize
    let safeAreaInsets: EdgeInsets

    var framingInsets: FramingSafeInsets {
        switch mode {
        case .phonePortrait:
            return FramingSafeInsets(
                top: max(12, safeAreaInsets.top + 8),
                leading: 12,
                bottom: safeAreaInsets.bottom + Self.phoneBottomControlHeight,
                trailing: 12
            )
        case .phoneLandscape:
            return FramingSafeInsets(
                top: max(12, safeAreaInsets.top + 8),
                leading: 12,
                bottom: max(12, safeAreaInsets.bottom + 8),
                trailing: safeAreaInsets.trailing + Self.phoneSideControlWidth
            )
        case .regularSideRail:
            return FramingSafeInsets(
                top: max(72, safeAreaInsets.top + 14),
                leading: 16,
                bottom: max(28, safeAreaInsets.bottom + 14),
                trailing: max(112, safeAreaInsets.trailing + 92)
            )
        }
    }

    var topPadding: CGFloat {
        8
    }

    var phoneTopBarTrailingInset: CGFloat {
        mode == .phoneLandscape ? safeAreaInsets.trailing + Self.phoneSideControlWidth + 8 : 12
    }
}
