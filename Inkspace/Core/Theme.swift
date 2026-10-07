import UIKit

enum Theme {
    static let palette: [UIColor] = [
        UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1),
        UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),
        UIColor(red: 0.80, green: 0.22, blue: 0.22, alpha: 1),
        UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1),
        UIColor(red: 0.20, green: 0.55, blue: 0.35, alpha: 1),
        UIColor(red: 0.20, green: 0.40, blue: 0.80, alpha: 1),
        UIColor(red: 0.50, green: 0.30, blue: 0.75, alpha: 1)
    ]

    static let fonts = [
        "Helvetica Neue", "Avenir Next", "Georgia", "Palatino",
        "Times New Roman", "Menlo", "Noteworthy", "Marker Felt"
    ]
}

extension UIColor {
    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
