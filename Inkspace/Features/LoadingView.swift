import SwiftUI

struct LoadingView: View {
    private let ink = Color.black

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.93, green: 0.92, blue: 0.89).ignoresSafeArea()
            Text("Inkspace")
                .font(.custom("Georgia-Italic", size: 34))
                .foregroundStyle(ink)
                .padding(48)
            VStack(alignment: .leading, spacing: 2) {
                word("WRITE")
                HStack(spacing: 16) {
                    ZStack {
                        ink
                        Image(systemName: "pencil.tip").font(.system(size: 30, weight: .light)).foregroundStyle(Color.white)
                    }
                    .frame(width: 130, height: 70)
                    word("DRAW").overlay(alignment: .bottom) { Rectangle().fill(ink.opacity(0.7)).frame(height: 1) }
                }
                word("THINK")
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6).tint(ink)
                    Text("LOADING").font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(ink)
                }
                .padding(.horizontal, 16)
                .frame(height: 30)
                .overlay(Capsule().stroke(ink.opacity(0.6), lineWidth: 1))
                .padding(.top, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .trailing) {
            Text("(INKSPACE STUDIO)")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(ink)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 14, height: 150)
                .padding(.trailing, 40)
        }
    }

    private func word(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 104, weight: .light))
            .tracking(-3)
            .foregroundStyle(ink)
    }
}
