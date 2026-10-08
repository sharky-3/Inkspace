import SwiftUI

struct MiniSegment<T: Hashable>: View {
    let items: [T]
    let title: (T) -> String
    var icon: ((T) -> String)? = nil
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button { selection = item } label: {
                    HStack(spacing: 5) {
                        if let icon { Image(systemName: icon(item)).font(.system(size: 11)) }
                        Text(title(item)).font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .foregroundStyle(selection == item ? Color.blue : Color.secondary)
                    .background(selection == item ? Color(uiColor: .systemBackground) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(selection == item ? 0.08 : 0), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DropdownField: View {
    let options: [Int]
    let label: (Int) -> String
    @Binding var selection: Int

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { n in
                Button(label(n)) { selection = n }
            }
        } label: {
            HStack(spacing: 8) {
                Text(label(selection)).font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.14)))
        }
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var theme = 0
    @AppStorage("barRight") private var barRight = true
    @AppStorage("undoTaps") private var undoTaps = 2
    @AppStorage("undoFingers") private var undoFingers = 2
    @AppStorage("editorFingers") private var editorFingers = 3
    @AppStorage("pencilMenu") private var pencilMenu = true
    @AppStorage("menuAtTap") private var menuAtTap = true
    @AppStorage("holdSnap") private var holdSnap = true
    @AppStorage("keepAwake") private var keepAwake = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings").font(.system(size: 22, weight: .semibold)).padding(.bottom, 16)
                row("Color theme", "Personalize the visual aesthetics of your interface") {
                    MiniSegment(items: [0, 1, 2], title: { ["System", "Light", "Dark"][$0] }, icon: { ["laptopcomputer", "sun.max", "moon"][$0] }, selection: $theme)
                }
                row("Tool bar side", "Show the tool bar on the left or right edge") {
                    MiniSegment(items: [false, true], title: { $0 ? "Right" : "Left" }, selection: $barRight)
                }
                row("Undo taps", "Tap once or twice to undo the last change") {
                    MiniSegment(items: [2, 1], title: { $0 == 2 ? "Double tap" : "Single tap" }, selection: $undoTaps)
                }
                row("Undo fingers", "How many fingers to use for the undo tap") {
                    DropdownField(options: [2, 3, 4], label: { "\($0) fingers" }, selection: $undoFingers)
                }
                row("Editor menu fingers", "Tap the canvas with this many fingers to open the editor menu") {
                    DropdownField(options: [2, 3, 4], label: { "\($0) fingers" }, selection: $editorFingers)
                }
                row("Pencil double tap", "Open the editor menu by tapping twice with Apple Pencil") {
                    Toggle("", isOn: $pencilMenu).labelsHidden().tint(.blue)
                }
                row("Menu position", "Open the editor menu where you tap, or in the center of the screen") {
                    MiniSegment(items: [true, false], title: { $0 ? "At tap" : "Center" }, selection: $menuAtTap)
                }
                row("Hold to straighten", "Hold still to turn strokes into clean lines, curves and shapes") {
                    Toggle("", isOn: $holdSnap).labelsHidden().tint(.blue)
                }
                row("Keep screen awake", "Stop the iPad from going to sleep while you use Inkspace") {
                    Toggle("", isOn: $keepAwake).labelsHidden().tint(.blue)
                }
                Divider()
            }
            .padding(28)
        }
    }

    private func row<C: View>(_ title: String, _ detail: String, @ViewBuilder control: () -> C) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.primary)
                    Text(detail).font(.system(size: 12)).foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 16)
                control()
            }
            .padding(.vertical, 14)
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            AppLogo(size: 96)
            Text("Inkspace").font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.primary)
            Text("An infinite canvas for Apple Pencil").font(.system(size: 15)).foregroundStyle(Color.secondary)
            Text("Version 1.0").font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
