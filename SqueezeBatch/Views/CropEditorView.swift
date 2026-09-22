import AppKit
import SwiftUI

/// Per-image crop editor.
///
/// Works in normalized unit space (origin top-left, 0...1) so the crop
/// stays valid regardless of later resize settings. Drag inside to move,
/// drag a corner handle to resize, drag outside to draw a new crop.
struct CropEditorView: View {
    @ObservedObject var item: ImageItem
    var suggestedAspect: AspectRatio = .free
    var onClose: () -> Void

    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var aspect: AspectRatio = .free
    @State private var cgPreview: CGImage?
    @State private var pixelSize: CGSize = .zero
    @State private var dragState: DragState?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var savedURL: URL?

    private var showSaveError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    private enum DragMode { case move, resize(Corner), create }
    private struct DragState {
        var mode: DragMode
        var startView: CGPoint      // drag start in container coords
        var startCrop: CGRect       // crop at drag start (unit space)
        var priorCrop: CGRect       // crop before this drag (revert target)
        var startOffset: CGPoint    // for move: grab offset inside crop (unit space)
    }

    private let handleHitDistance: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "crop")
                    .foregroundStyle(.secondary)
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("Drag inside to move · corners to resize · outside to redraw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            aspectBar
            Divider()
            GeometryReader { geo in
                let frame = fitFrame(in: geo.size)
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    if let cg = cgPreview {
                        // Raw pixels, orientation `.up`: matches converter space exactly.
                        Image(decorative: cg, scale: 1.0, orientation: .up)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    } else {
                        ProgressView()
                    }
                    scrim(frame: frame, container: geo.size)
                    cropOverlay(frame: frame)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(frame: frame))
            }
            Divider()
            bottomBar
        }
        .frame(minWidth: 640, minHeight: 560)
        .onAppear {
            aspect = suggestedAspect
            if let existing = item.cropRectNormalized {
                crop = existing
            }
            loadImage()
        }
        .alert("Couldn't save", isPresented: showSaveError) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Aspect bar

    private var aspectBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AspectRatio.allCases) { preset in
                    Button {
                        aspect = preset
                        reshapeToAspect()
                    } label: {
                        Text(preset.displayName)
                            .font(.system(size: 12, weight: aspect == preset ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .tint(aspect == preset ? .accentColor : nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Overlays

    private func scrim(frame: CGRect, container: CGSize) -> some View {
        let hole = viewRect(from: crop, in: frame)
        let dim = Color.black.opacity(0.55)
        return ZStack {
            // Top band
            dim.frame(width: container.width, height: max(hole.minY, 0))
                .position(x: container.width / 2, y: hole.minY / 2)
            // Bottom band
            dim.frame(width: container.width, height: max(container.height - hole.maxY, 0))
                .position(x: container.width / 2, y: (container.height + hole.maxY) / 2)
            // Left band
            dim.frame(width: max(hole.minX, 0), height: max(hole.height, 0))
                .position(x: hole.minX / 2, y: hole.midY)
            // Right band
            dim.frame(width: max(container.width - hole.maxX, 0), height: max(hole.height, 0))
                .position(x: (container.width + hole.maxX) / 2, y: hole.midY)
        }
        .allowsHitTesting(false)
    }

    private func cropOverlay(frame: CGRect) -> some View {
        let rect = viewRect(from: crop, in: frame)
        return ZStack {
            // Rule-of-thirds grid
            Path { path in
                for i in 1..<3 {
                    let x = rect.minX + rect.width * CGFloat(i) / 3
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    let y = rect.minY + rect.height * CGFloat(i) / 3
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(radius: 2)
                    .position(handlePoint(rect, index: i))
            }
        }
        .allowsHitTesting(false)
    }

    private func handlePoint(_ rect: CGRect, index: Int) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.maxX, y: rect.minY)
        case 2: return CGPoint(x: rect.minX, y: rect.maxY)
        default: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cropSizeLabel)
                    .font(.callout)
                    .monospacedDigit()
                if let url = savedURL {
                    Button("Show saved file in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            Spacer()
            if isSaving {
                ProgressView().scaleEffect(0.8)
            }
            Button("Reset") {
                crop = CGRect(x: 0, y: 0, width: 1, height: 1)
                savedURL = nil
            }
            .buttonStyle(.bordered)
            Button("Save cropped copy…") { saveSingle() }
                .buttonStyle(.bordered)
                .disabled(isSaving || cgPreview == nil)
                .help("Save just this image cropped, in its original format — without running the batch")
            Button("Cancel") { onClose() }
                .keyboardShortcut(.cancelAction)
            Button("Apply crop") { applyAndClose() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var cropSizeLabel: String {
        guard pixelSize.width > 0 else { return "Loading…" }
        let w = Int(floor(pixelSize.width * crop.width))
        let h = Int(floor(pixelSize.height * crop.height))
        return "Crop \(w) × \(h)  ·  of \(Int(pixelSize.width)) × \(Int(pixelSize.height))"
    }

    // MARK: - Geometry

    private func fitFrame(in container: CGSize) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0,
              container.width > 0, container.height > 0
        else { return .zero }
        let scale = min(container.width / pixelSize.width, container.height / pixelSize.height)
        let size = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func viewRect(from unit: CGRect, in frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + unit.minX * frame.width,
            y: frame.minY + unit.minY * frame.height,
            width: unit.width * frame.width,
            height: unit.height * frame.height
        )
    }

    private func unitPoint(from view: CGPoint, in frame: CGRect) -> CGPoint {
        guard frame.width > 0, frame.height > 0 else { return .zero }
        return CGPoint(
            x: (view.x - frame.minX) / frame.width,
            y: (view.y - frame.minY) / frame.height
        )
    }

    // MARK: - Gestures

    private func dragGesture(frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                if dragState == nil {
                    dragState = beginDrag(at: value.startLocation, frame: frame)
                }
                guard let state = dragState else { return }
                crop = updateCrop(state: state, currentView: value.location, frame: frame)
            }
            .onEnded { _ in
                // Discard degenerate creates (plain clicks) — restore pre-drag crop.
                if let state = dragState, case .create = state.mode,
                   crop.width < minUnitWidth || crop.height < minUnitHeight {
                    crop = state.priorCrop
                }
                crop = clamped(crop)
                dragState = nil
            }
    }

    private func beginDrag(at point: CGPoint, frame: CGRect) -> DragState? {
        let rect = viewRect(from: crop, in: frame)
        let startCrop = crop
        let unit = unitPoint(from: point, in: frame)
        let corners: [(Corner, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY)),
        ]
        for (corner, center) in corners {
            if hypot(point.x - center.x, point.y - center.y) < handleHitDistance {
                return DragState(mode: .resize(corner), startView: point, startCrop: startCrop, priorCrop: crop, startOffset: .zero)
            }
        }
        if rect.insetBy(dx: -4, dy: -4).contains(point) {
            let offset = CGPoint(x: unit.x - startCrop.minX, y: unit.y - startCrop.minY)
            return DragState(mode: .move, startView: point, startCrop: startCrop, priorCrop: crop, startOffset: offset)
        }
        // Outside: start drawing a new crop.
        let clampedStart = CGPoint(x: min(max(unit.x, 0), 1), y: min(max(unit.y, 0), 1))
        let seed = CGRect(x: clampedStart.x, y: clampedStart.y, width: 0, height: 0)
        return DragState(mode: .create, startView: point, startCrop: seed, priorCrop: crop, startOffset: .zero)
    }

    private func updateCrop(state: DragState, currentView: CGPoint, frame: CGRect) -> CGRect {
        let unit = unitPoint(from: currentView, in: frame)
        switch state.mode {
        case .move:
            let origin = CGPoint(x: unit.x - state.startOffset.x, y: unit.y - state.startOffset.y)
            let maxX = 1 - state.startCrop.width
            let maxY = 1 - state.startCrop.height
            return CGRect(
                x: min(max(origin.x, 0), maxX),
                y: min(max(origin.y, 0), maxY),
                width: state.startCrop.width,
                height: state.startCrop.height
            )
        case .create:
            let start = CGPoint(x: state.startCrop.minX, y: state.startCrop.minY)
            return rectBetween(start, clampedUnit(unit), lockTo: aspectRatioValue())
        case .resize(let corner):
            let anchor = opposite(of: corner, in: state.startCrop)
            return rectBetween(anchor, clampedUnit(unit), lockTo: aspectRatioValue())
        }
    }

    private func opposite(of corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.minX, y: rect.minY)
        }
    }

    private func rectBetween(_ a: CGPoint, _ b: CGPoint, lockTo ratio: CGFloat?) -> CGRect {
        var w = abs(b.x - a.x)
        var h = abs(b.y - a.y)
        if let ratio, ratio > 0 {
            // Fit the ratio inside the dragged span, preserving drag direction.
            if w / max(h, 0.0001) > ratio {
                w = h * ratio
            } else {
                h = w / ratio
            }
        }
        let sx: CGFloat = b.x >= a.x ? 1 : -1
        let sy: CGFloat = b.y >= a.y ? 1 : -1
        var rect = CGRect(x: sx > 0 ? a.x : a.x - w, y: sy > 0 ? a.y : a.y - h, width: w, height: h)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        // Enforce a minimum size in unit space (≈16px on the source).
        if rect.width < minUnitWidth || rect.height < minUnitHeight {
            return crop
        }
        return rect
    }

    private var minUnitWidth: CGFloat {
        pixelSize.width > 0 ? 16 / pixelSize.width : 0.01
    }

    private var minUnitHeight: CGFloat {
        pixelSize.height > 0 ? 16 / pixelSize.height : 0.01
    }

    private func clampedUnit(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
    }

    private func clamped(_ rect: CGRect) -> CGRect {
        rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func aspectRatioValue() -> CGFloat? {
        aspect.resolved(for: pixelSize)
    }

    /// Reshape the current crop (or the full image) to the selected aspect,
    /// keeping it as large as possible and centered.
    private func reshapeToAspect() {
        guard let ratio = aspectRatioValue(), pixelSize.width > 0 else { return }
        let bounds = crop.width > 0.01 && crop.height > 0.01 ? crop : CGRect(x: 0, y: 0, width: 1, height: 1)
        var w = bounds.width
        var h = w / ratio
        if h > bounds.height {
            h = bounds.height
            w = h * ratio
        }
        crop = CGRect(
            x: bounds.midX - w / 2,
            y: bounds.midY - h / 2,
            width: w,
            height: h
        )
    }

    // MARK: - Actions

    private func loadImage() {
        let url = item.sourceURL
        let hadCrop = item.cropRectNormalized != nil
        DispatchQueue.global(qos: .userInitiated).async {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil)
            else { return }
            DispatchQueue.main.async {
                self.cgPreview = cg
                self.pixelSize = CGSize(width: cg.width, height: cg.height)
                // Apply the suggested aspect once real dimensions are known.
                if !hadCrop, aspect != .free {
                    reshapeToAspect()
                }
            }
        }
    }

    private func isFullBleed(_ rect: CGRect) -> Bool {
        rect.minX <= 0.001 && rect.minY <= 0.001 &&
        rect.maxX >= 0.999 && rect.maxY >= 0.999
    }

    private func effectiveCrop() -> CGRect? {
        let rect = clamped(crop)
        guard !isFullBleed(rect),
              rect.width >= minUnitWidth, rect.height >= minUnitHeight
        else { return nil }
        return rect
    }

    private func applyAndClose() {
        item.cropRectNormalized = effectiveCrop()
        // A new crop invalidates a previous conversion result.
        if item.status.isDone {
            item.status = .pending
            item.outputURL = nil
            item.outputSize = nil
        }
        onClose()
    }

    private func saveSingle() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        let rect = clamped(crop)
        let url = item.sourceURL
        Task.detached(priority: .userInitiated) {
            do {
                let result = try ImageConverter.saveCroppedCopy(sourceURL: url, normalized: rect)
                await MainActor.run {
                    self.savedURL = result.0
                    self.isSaving = false
                }
            } catch {
                await MainActor.run {
                    self.saveError = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}
