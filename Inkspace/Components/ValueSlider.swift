import SwiftUI

struct ValueSlider: View {
    let icon: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24)
            Slider(value: $value, in: range).tint(.black)
            Text("\(Int(value))")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(width: 32, alignment: .trailing)
        }
        .foregroundStyle(.black)
    }
}
