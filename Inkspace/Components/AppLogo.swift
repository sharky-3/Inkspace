import SwiftUI

struct AppLogo: View {
    var size: CGFloat = 120

    var body: some View {
        Group {
            if let image = UIImage(named: "Logo") {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ZStack {
                    Color.black
                    Image(systemName: "pencil.tip")
                        .font(.system(size: size * 0.45, weight: .light))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }
}
