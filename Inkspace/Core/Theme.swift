import UIKit

enum Theme {
    static let palette: [UIColor] = [
        UIColor.black,
        UIColor.white,
        UIColor.red,
        UIColor.orange,
        UIColor.yellow,
        UIColor.green,
        UIColor.blue,
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
