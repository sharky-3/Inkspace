import SwiftUI

struct SettingsPanel: View {
    @ObservedObject var store: CanvasStore

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: store.color) },
            set: { store.color = UIColor($0) }
        )
    }

    var body: some View {
        let t = store.tool
        if t == .brush || t.isShape || t == .text {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(Theme.palette, id: \.self) { c in
                        ColorSwatch(color: c, selected: store.color == c) { store.color = c }
                    }
                    ColorPicker("", selection: colorBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 36, height: 36)
                }
                if t == .text {
                    ValueSlider(icon: "textformat.size", value: $store.fontSize, range: 12...120)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Theme.fonts, id: \.self) { f in
                                Chip(title: f, font: .custom(f, size: 15), selected: store.fontFamily == f) {
                                    store.fontFamily = f
                                }
                            }
                        }
                    }
                } else {
                    ValueSlider(icon: "scribble", value: $store.width, range: 1...24)
                    if t != .ruler {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Brush.allCases) { b in
                                    Chip(title: b.title, selected: store.brush == b) { store.brush = b }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(width: 460)
            .glass(26)
        }
    }
}
