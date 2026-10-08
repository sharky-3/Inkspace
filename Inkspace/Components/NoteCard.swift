import SwiftUI

struct NoteCard: View {
    let note: NoteInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .secondarySystemBackground))
                    Image(systemName: note.kind?.icon ?? "scribble.variable")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.secondary)
                    if let kind = note.kind {
                        Text(kind.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .systemBackground), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(10)
                    }
                }
                .frame(height: 110)
                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.primary).lineLimit(1)
                    Text(note.updated.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
