import SwiftUI

struct SettingsView: View {
    @Binding var settings: ConversionSettings
    var isConverting: Bool

    var body: some View {
        VStack(spacing: 14) {
            formatSection
            compressionSection
            resizeSection
            destinationSection
        }
        .padding(12)
    }

    // MARK: - Format

    private var formatSection: some View {
        SettingsSection(title: "Output format") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(OutputFormat.allCases) { format in
                    Button {
                        settings.format = format
                        // JPEG/HEIC have no lossless mode — reset stale state.
                        if !format.supportsLossless { settings.lossless = false }
                    } label: {
                        Text(format.displayName)
                            .font(.system(size: 12, weight: settings.format == format ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.format == format ? .accentColor : nil)
                    .disabled(isConverting)
                }
            }
            Text(settings.format.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Compression

    private var compressionSection: some View {
        SettingsSection(title: "Compression") {
            if settings.format.supportsLossless {
                Toggle("Lossless", isOn: $settings.lossless)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(isConverting)
            }
            if settings.format.usesQuality && !settings.lossless {
                HStack(spacing: 8) {
                    Text("Quality")
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $settings.quality, in: 1...100, step: 1)
                        .disabled(isConverting)
                    Text("\(Int(settings.quality))")
                        .monospacedDigit()
                        .frame(width: 28, alignment: .trailing)
                }
                Text(qualityHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Lossless — maximum quality, larger file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Resize

    private var resizeSection: some View {
        SettingsSection(title: "Resize") {
            Picker("", selection: $settings.resizeMode) {
                ForEach(ResizeMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isConverting)

            if settings.resizeMode == .maxDimension {
                HStack(spacing: 8) {
                    Text("Max")
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $settings.maxDimension, in: 256...8192, step: 64)
                        .disabled(isConverting)
                    Text("\(Int(settings.maxDimension))px")
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }
            }
            if settings.resizeMode == .percentage {
                HStack(spacing: 8) {
                    Text("Scale")
                        .frame(width: 52, alignment: .leading)
                    Slider(value: $settings.scalePercent, in: 1...100, step: 1)
                        .disabled(isConverting)
                    Text("\(Int(settings.scalePercent))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
            if settings.resizeMode == .exactDimensions {
                HStack(spacing: 8) {
                    Text("Size")
                        .frame(width: 52, alignment: .leading)
                    TextField("", value: $settings.targetWidth, formatter: Self.intFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .disabled(isConverting)
                        .onChange(of: settings.targetWidth) { _, newWidth in
                            matchAspect(changed: .width, value: newWidth)
                        }
                    Text("×")
                        .foregroundStyle(.secondary)
                    TextField("", value: $settings.targetHeight, formatter: Self.intFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                        .disabled(isConverting)
                        .onChange(of: settings.targetHeight) { _, newHeight in
                            matchAspect(changed: .height, value: newHeight)
                        }
                    Text("px")
                        .foregroundStyle(.secondary)
                }
                Picker("Aspect", selection: $settings.resizeAspect) {
                    ForEach(AspectRatio.allCases) { a in
                        Text(a.displayName).tag(a)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isConverting)
                .onChange(of: settings.resizeAspect) { _, newAspect in
                    applyAspect(newAspect)
                }
                Text("Aspect also seeds the per-image crop editor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private enum ChangedField { case width, height }

    private static let intFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.minimum = 16
        f.maximum = 16384
        return f
    }()

    /// When an aspect preset is locked, keep W×H on-ratio as fields change.
    private func matchAspect(changed: ChangedField, value: Double) {
        guard let ratio = settings.resizeAspect.ratio, value > 0 else { return }
        switch changed {
        case .width:
            settings.targetHeight = (value / ratio).rounded()
        case .height:
            settings.targetWidth = (value * ratio).rounded()
        }
    }

    private func applyAspect(_ aspect: AspectRatio) {
        guard let ratio = aspect.ratio, settings.targetWidth > 0 else { return }
        settings.targetHeight = (settings.targetWidth / ratio).rounded()
    }

    // MARK: - Destination

    private var destinationSection: some View {
        SettingsSection(title: "Destination") {
            Picker("", selection: $settings.destination) {
                ForEach(OutputDestination.allCases) { d in
                    Text(d.displayName).tag(d)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isConverting)

            if settings.destination == .custom {
                HStack(spacing: 8) {
                    Text(settings.customFolder?.path ?? "No folder chosen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") { chooseFolder() }
                        .controlSize(.small)
                        .disabled(isConverting)
                }
            }

            Toggle("Overwrite existing files", isOn: $settings.overwriteExisting)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isConverting)
        }
    }

    private var qualityHint: String {
        switch settings.quality {
        case ..<40: return "Low — smallest file, visible artifacts."
        case ..<75: return "Balanced — good for web."
        case ..<95: return "High — recommended."
        default: return "Near-lossless — large file."
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.customFolder = url
        }
    }
}

/// Native-looking grouped section with a consistent header + hairline.
struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
