import SwiftUI

struct NoteCard: View {
    let note: NoteInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Dark.ground)
                    Image(systemName: note.kind?.icon ?? "scribble.variable")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Dark.dim)

                    if let kind = note.kind {
                        Text(kind.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Dark.dim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Dark.card.opacity(0.9), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(10)
                    }
                }
                .frame(height: 120)
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(note.updated.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(Dark.dim)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Dark.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Dark.line))
        }
        .buttonStyle(.plain)
    }
}
