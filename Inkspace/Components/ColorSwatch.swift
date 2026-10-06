import SwiftUI

struct ColorSwatch: View {
    let color: UIColor
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(uiColor: color))
                .frame(width: 28, height: 28)
                .padding(4)
                .overlay(Circle().stroke(Color.black, lineWidth: selected ? 1.5 : 0))
        }
    }
}
