import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 30) {
                AppLogo(size: 128)
                VStack(spacing: 6) {
                    Text("Inkspace")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("Preparing your canvas")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                ProgressView().tint(.black)
            }
        }
    }
}
