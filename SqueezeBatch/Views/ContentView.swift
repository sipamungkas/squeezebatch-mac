import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = ImageStore()
    @State private var isDropTargeted = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Convert")
                        .font(.headline)
                    Text("to \(store.settings.format.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SettingsView(settings: $store.settings, isConverting: store.isConverting)
                }
                .padding(.top, 8)
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 310)
        } detail: {
            VStack(spacing: 0) {
                headerBar
                Divider()
                if store.items.isEmpty {
                    emptyState
                } else {
                    fileList
                }
                Divider()
                footerBar
            }
        }
        .frame(minWidth: 920, minHeight: 620)
        .dropDestination(for: URL.self) { urls, _ in
            store.add(urls: urls)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(0.08))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentColor, lineWidth: 2)
                    Text("Drop images to add")
                        .font(.title3.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button { pickFiles() } label: {
                Label("Add images", systemImage: "plus")
            }
            Button { pickFolder() } label: {
                Label("Add folder", systemImage: "folder")
            }
            .buttonStyle(.link)

            Spacer()

            Text("\(store.items.count) files · \(store.pendingCount) queued")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if store.isConverting {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20)
            }

            Button { Task { await store.convertAll() } } label: {
                Label("Convert all", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(store.items.isEmpty || store.isConverting || store.pendingCount == 0)
            .help("Convert all queued images with current settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Drag & drop images here")
                .font(.title3.bold())
            Text("PNG · JPEG · WebP · HEIC · TIFF · BMP · GIF\nOutput: \(store.settings.format.displayName) — set quality on the left, then Convert all.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            HStack(spacing: 8) {
                Button("Choose images…") { pickFiles() }
                    .buttonStyle(.borderedProminent)
                Button("Choose folder…") { pickFolder() }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - List

    private var fileList: some View {
        List {
            ForEach(store.items) { item in
                ImageRowView(
                    item: item,
                    onRemove: { store.remove(item) },
                    onReveal: {
                        if let out = item.outputURL {
                            NSWorkspace.shared.activateFileViewerSelecting([out])
                        }
                    }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 12) {
            if let savings = store.totalSavings {
                Label(
                    String(format: "Saved %@ (%+.0f%%)", ImageConverter.formatBytes(savings.saved), savings.percent ?? 0),
                    systemImage: "chart.bar.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            } else {
                Text(store.items.isEmpty ? "Tip: drop a folder to bulk-add images." : "\(store.doneCount) converted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let err = store.lastError, store.doneCount < store.items.count {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button("Clear completed") { store.removeCompleted() }
                .buttonStyle(.link)
                .disabled(store.isConverting || store.doneCount == 0)
            Button("Clear all") { store.removeAll() }
                .buttonStyle(.link)
                .disabled(store.isConverting || store.items.isEmpty)
            Button {
                openWindow(id: "about")
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.link)
            .help("About SqueezeBatch")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Pickers

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .png, .jpeg, .tiff, .bmp, .heic, .gif,
            UTType(filenameExtension: "webp") ?? .data,
            UTType(filenameExtension: "heif") ?? .data
        ]
        if panel.runModal() == .OK {
            store.add(urls: panel.urls)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.add(urls: [url])
        }
    }
}

#Preview {
    ContentView()
}
