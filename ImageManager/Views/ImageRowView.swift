import SwiftUI

struct ImageRowView: View {
    @ObservedObject var item: ImageItem
    var onRemove: () -> Void
    var onReveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            // Middle: fixed-width flexible column, all lines truncated.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(item.formatHint)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.35), in: Capsule())
                    Text(ImageConverter.formatBytes(item.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let dims = item.dimensions {
                        Text("\(Int(dims.width))×\(Int(dims.height))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Fixed height so rows don't jump between states.
                statusLine
                    .frame(height: 16, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing: fixed-width result column, always right-aligned.
            VStack(alignment: .trailing, spacing: 3) {
                statusBadge
                resultLine
                    .frame(height: 16, alignment: .trailing)
            }
            .frame(width: 110, alignment: .trailing)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.vertical, 6)
        .contextMenu {
            if item.status.isDone {
                Button("Show in Finder") { onReveal() }
            }
            Button("Remove") { onRemove() }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = item.thumbnail {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch item.status {
        case .pending:
            Text("Queued")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .converting:
            ProgressView()
                .progressViewStyle(.linear)
                .frame(maxWidth: 140)
        case .done:
            Text(item.outputURL?.lastPathComponent ?? "Converted")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var resultLine: some View {
        switch item.status {
        case .done:
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                if let out = item.outputSize {
                    Text(ImageConverter.formatBytes(out))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let pct = item.savingsPercent {
                    Text(String(format: "%+.0f%%", pct))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(pct >= 0 ? .green : .orange)
                        .lineLimit(1)
                }
            }
        case .failed:
            Text("Failed")
                .font(.caption)
                .foregroundStyle(.red)
        default:
            Text("")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .converting:
            ProgressView().scaleEffect(0.7).frame(width: 20, height: 16)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }
}
