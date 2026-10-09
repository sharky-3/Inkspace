import SwiftUI

struct LoadingView: View {
    @State private var started = false
    @State private var drawn: CGFloat = 0
    @State private var drift = false
    @State private var progress: CGFloat = 0
    private let letters = Array("Inkspace")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            glow
            VStack(spacing: 30) {
                tile
                wordmark
                tagline
            }
            VStack {
                Spacer()
                bar
            }
            .padding(.bottom, 64)
        }
        .onAppear {
            started = true
            drift = true
            withAnimation(.easeInOut(duration: 1.2).delay(0.25)) { drawn = 1 }
            withAnimation(.easeInOut(duration: 1.6).delay(0.1)) { progress = 1}
        }
    }

    private var glow: some View {
        ZStack {
            orb(Color(red: 0.25, green: 0.35, blue: 1), size: 420, x: drift ? -140 : -60, y: drift ? -120 : -200)
            orb(Color(red: 0.72, green: 0.3, blue: 0.92), size: 380, x: drift ? 160 : 80, y: drift ? 60 : 140)
            orb(Color(red: 1, green: 0.55, blue: 0.35), size: 320, x: drift ? -60 : 40, y: drift ? 240 : 160)
        }
        .blur(radius: 90)
        .opacity(started ? 0.5 : 0)
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: drift)
        .animation(.easeOut(duration: 1.2), value: started)
        .ignoresSafeArea()
    }

    private func orb(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(color).frame(width: size, height: size).offset(x: x, y: y)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(0.04))
            swash
                .trim(from: 0, to: drawn)
                .stroke(
                    LinearGradient(colors: [.white, Color.white.opacity(0.55)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 120, height: 120)
            Circle()
                .fill(.white)
                .frame(width: 11, height: 11)
                .offset(x: 34, y: 32)
                .scaleEffect(drawn > 0.95 ? 1 : 0.01)
                .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(1.25), value: drawn)
        }
        .frame(width: 156, height: 156)
        .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .scaleEffect(started ? 1 : 0.82)
        .opacity(started ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.78), value: started)
    }

    private var swash: Path {
        var p = Path()
        p.move(to: CGPoint(x: 26, y: 92))
        p.addCurve(to: CGPoint(x: 62, y: 28), control1: CGPoint(x: 26, y: 50), control2: CGPoint(x: 40, y: 28))
        p.addCurve(to: CGPoint(x: 94, y: 78), control1: CGPoint(x: 86, y: 28), control2: CGPoint(x: 94, y: 56))
        return p
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            ForEach(Array(letters.enumerated()), id: \.offset) { i, l in
                Text(String(l))
                    .font(.system(size: 46, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .opacity(started ? 1 : 0)
                    .blur(radius: started ? 0 : 14)
                    .offset(y: started ? 0 : 16)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.5 + Double(i) * 0.05), value: started)
            }
        }
    }

    private var tagline: some View {
        Text("WRITE · DRAW · THINK")
            .font(.system(size: 12, weight: .medium))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.5))
            .opacity(started ? 1 : 0)
            .offset(y: started ? 0 : 8)
            .animation(.easeOut(duration: 0.8).delay(1.0), value: started)
    }

    private var bar: some View {
        Capsule()
            .fill(.white.opacity(0.12))
            .frame(width: 120, height: 3)
            .overlay(alignment: .leading) {
                Capsule().fill(.white).frame(width: 120 * progress, height: 3)
            }
            .opacity(started ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.4), value: started)
    }
}
