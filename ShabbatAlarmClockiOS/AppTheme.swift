import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case black
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

    static func resolve(storedValue: String) -> AppTheme {
        if storedValue == "white" {
            return .black
        }

        return AppTheme(rawValue: storedValue) ?? .defaultTheme
    }

    var localizationKey: String {
        switch self {
        case .black:
            return "theme.black"
        case .blue:
            return "theme.blue"
        case .teal:
            return "theme.teal"
        case .green:
            return "theme.green"
        case .mint:
            return "theme.mint"
        case .orange:
            return "theme.orange"
        case .rose:
            return "theme.rose"
        case .red:
            return "theme.red"
        case .lavender:
            return "theme.lavender"
        }
    }

    func displayName(in language: AppLanguage = AppLanguagePreferenceStore.currentLanguage()) -> String {
        AppStrings(language: language).themeDisplayName(self)
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
        case .black:
            return UIColor(white: 0.08, alpha: 1.0)
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
                let ringColor = UIColor.white.withAlphaComponent(0.85)
                ringColor.setStroke()
                ringPath.lineWidth = 1
                ringPath.stroke()
            }

            uiColor.setFill()
            path.fill()

            let borderColor = self == .black
                ? UIColor.white.withAlphaComponent(0.28)
                : UIColor.black.withAlphaComponent(0.18)
            borderColor.setStroke()
            path.lineWidth = 0.75
            path.stroke()
        }
    }
}
