import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var theme = 0
    @AppStorage("barRight") private var barRight = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings").font(.system(size: 30, weight: .semibold)).padding(.bottom, 8)
            group("Theme") {
                HStack {
                    ForEach(Array(["System", "Light", "Dark"].enumerated()), id: \.offset) { i, name in
                        Chip(title: name, selected: theme == i) { theme = i }
                    }
                }
            }
            group("Tool bar side") {
                HStack {
                    Chip(title: "Left", selected: !barRight) { barRight = false }
                    Chip(title: "Right", selected: barRight) { barRight = true }
                }
            }
            group("Gestures") { GestureSettings() }
            Spacer()
        }
        .foregroundStyle(Color.white)
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13)).foregroundStyle(Dark.dim)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Dark.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Dark.line))
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            AppLogo(size: 96)
            Text("Inkspace").font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.white)
            Text("An infinite canvas for Apple Pencil").font(.system(size: 15)).foregroundStyle(Dark.dim)
            Text("Version 1.0").font(.system(size: 12, design: .monospaced)).foregroundStyle(Dark.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
