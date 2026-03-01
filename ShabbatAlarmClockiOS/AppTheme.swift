import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case blue
    case teal
    case green
    case mint
    case orange
    case rose
    case red
    case lavender = "indigo"

    static let storageKey = "appTheme"
    static let defaultTheme: AppTheme = .blue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:
            return "Blue"
        case .teal:
            return "Teal"
        case .green:
            return "Green"
        case .mint:
            return "Mint"
        case .orange:
            return "Orange"
        case .rose:
            return "Rose"
        case .red:
            return "Red"
        case .lavender:
            return "Lavender"
        }
    }

    var color: Color {
        Color(uiColor: uiColor)
    }

    func menuSwatch(isSelected: Bool) -> Image {
        Image(uiImage: menuSwatchImage(isSelected: isSelected))
            .renderingMode(.original)
    }

    private var uiColor: UIColor {
        switch self {
        case .blue:
            return .systemBlue
        case .teal:
            return .systemTeal
        case .green:
            return .systemGreen
        case .mint:
            return UIColor(red: 0.40, green: 0.88, blue: 0.74, alpha: 1.0)
        case .orange:
            return .systemOrange
        case .rose:
            return UIColor(red: 0.97, green: 0.42, blue: 0.62, alpha: 1.0)
        case .red:
            return .systemRed
        case .lavender:
            return UIColor(red: 0.73, green: 0.62, blue: 0.95, alpha: 1.0)
        }
    }

    private func menuSwatchImage(isSelected: Bool) -> UIImage {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let inset = isSelected ? 1.5 : 2.5
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            let path = UIBezierPath(ovalIn: rect)

            if isSelected {
                let ringRect = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
                let ringPath = UIBezierPath(ovalIn: ringRect)
                UIColor.white.withAlphaComponent(0.85).setStroke()
                ringPath.lineWidth = 1
                ringPath.stroke()
            }

            uiColor.setFill()
            path.fill()

            UIColor.black.withAlphaComponent(0.18).setStroke()
            path.lineWidth = 0.75
            path.stroke()
        }
    }
}
