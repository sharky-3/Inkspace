import UIKit
import PDFKit

final class CanvasUIView: UIView, UIGestureRecognizerDelegate {
    private let store: CanvasStore
    private var live: Element?
    private var moving = false
    private var marquee: CGRect?
    private var marqueeStart = CGPoint.zero
    private var erasing = false
    private var committed = false
    private var snapped = false
    private var last = CGPoint.zero
    private var holdAnchor = CGPoint.zero
    private var holdWork: DispatchWorkItem?

    // Cached rendering objects for an imported PDF/image.
    private var importedData: Data?
    private var importedPDF: PDFDocument?
    private var importedImage: UIImage?
    private var importedPageRects: [CGRect] = []

    private var scale: CGFloat {
        get { store.scale }
        set { store.scale = newValue }
    }

    private var offset: CGPoint {
        get { store.offset }
        set { store.offset = newValue }
    }

    init(store: CanvasStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : .white }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: CanvasUIView, _) in view.setNeedsDisplay() }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        var recognizers: [UIGestureRecognizer] = [pan, pinch]
        for n in 2...4 {
            let double = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))
            double.numberOfTouchesRequired = n
            double.numberOfTapsRequired = 2
            let single = UITapGestureRecognizer(target: self, action: #selector(onSingleTap(_:)))
            single.numberOfTouchesRequired = n
            single.require(toFail: double)
            recognizers += [double, single]
        }
        for g in recognizers {
            g.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            g.delegate = self
            addGestureRecognizer(g)
        }
        store.resetView = { [weak self] in self?.resetZoom() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    private func world(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - offset.x) / scale, y: (p.y - offset.y) / scale)
    }

    private func resetZoom() {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let w = world(c)
        scale = 0.8
        offset = CGPoint(x: c.x - w.x * scale, y: c.y - w.y * scale)
        refresh()
        store.requestSave()
    }

    func refresh() {
        store.center = world(CGPoint(x: bounds.midX, y: bounds.midY))
        setNeedsDisplay()
    }

    private func fingers(_ key: String, _ fallback: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? fallback
    }

    @objc private func onDoubleTap(_ g: UITapGestureRecognizer) {
        if g.numberOfTouchesRequired == fingers("undoFingers", 2) { store.undo() }
    }

    @objc private func onSingleTap(_ g: UITapGestureRecognizer) {
        if g.numberOfTouchesRequired == fingers("editorFingers", 3) { store.editorOpen.toggle() }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: self)
        offset.x += t.x
        offset.y += t.y
        g.setTranslation(.zero, in: self)
        refresh()
        if g.state == .ended { store.requestSave() }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        let c = g.location(in: self)
        let w = world(c)
        scale = min(max(scale * g.scale, 0.02), 16)
        offset = CGPoint(x: c.x - w.x * scale, y: c.y - w.y * scale)
        g.scale = 1
        refresh()
        if g.state == .ended { store.requestSave() }
    }

    private func pressureWidth(_ t: UITouch) -> CGFloat {
        let f = t.maximumPossibleForce > 0 ? t.force / t.maximumPossibleForce : 0.5
        let range = store.brush.pressureRange
        return store.width * store.brush.widthScale * (range.lowerBound + (range.upperBound - range.lowerBound) * f)
    }

    private func kind(_ t: Tool) -> Element.Kind {
        switch t {
        case .line: .line
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .template: .template
        default: .ruler
        }
    }

    private func erase(at p: CGPoint) {
        guard let i = store.elements.lastIndex(where: { $0.hit(p, tol: 10 / scale) }) else { return }
        if !committed {
            store.commit()
            committed = true
        }
        store.elements.remove(at: i)
    }

    private func armHold(_ p: CGPoint) {
        holdAnchor = p
        holdWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.snap() }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    private func snap() {
        guard var l = live, l.kind == .stroke,
              let result = ShapeRecognizer.recognize(l.points, scale: scale) else { return }
        let w = l.widths.isEmpty ? l.width : l.widths.reduce(0, +) / CGFloat(l.widths.count)
        l.kind = result.0
        l.points = result.1
        l.widths = Array(repeating: w, count: result.1.count)
        live = l
        snapped = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        let p = world(touch.location(in: self))
        last = p
        snapped = false
        let t = store.tool
        if t == .brush {
            let w = pressureWidth(touch)
            live = Element(kind: .stroke, points: [p, p], widths: [w, w], color: store.color, width: store.width, brush: store.brush)
            armHold(touch.location(in: self))
        } else if t.isShape {
            live = Element(kind: kind(t), points: [p, p], color: store.color, width: store.width, brush: t == .ruler ? .ballpoint : store.brush, template: store.template)
        } else if t == .eraser {
            erasing = true
            erase(at: p)
        } else if t == .move {
            if let b = selectionBounds(), b.insetBy(dx: -8 / scale, dy: -8 / scale).contains(p) {
                store.commit()
                moving = true
            } else if let e = store.elements.last(where: { $0.hit(p, tol: 8 / scale) }) {
                store.selection = [e.id]
                store.commit()
                moving = true
            } else {
                store.selection = []
                marqueeStart = p
                marquee = CGRect(origin: p, size: .zero)
            }
        } else if t == .text {
            store.textRequest = p
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first(where: { $0.type == .pencil }) else { return }
        for c in event?.coalescedTouches(for: touch) ?? [touch] {
            let screen = c.location(in: self)
            let p = world(screen)
            if live?.kind == .stroke, !snapped {
                let raw = pressureWidth(c)
                let smoothed = (live?.widths.last ?? raw) * 0.7 + raw * 0.3
                live?.points.append(p)
                live?.widths.append(smoothed)
                if hypot(screen.x - holdAnchor.x, screen.y - holdAnchor.y) > 4 { armHold(screen) }
            } else if live != nil {
                if !snapped || live?.kind == .line { live?.points[1] = p }
            } else if erasing {
                erase(at: p)
            } else if moving {
                let d = CGSize(width: p.x - last.x, height: p.y - last.y)
                var all = store.elements
                for i in all.indices where store.selection.contains(all[i].id) { all[i].move(by: d) }
                store.elements = all
            } else if marquee != nil {
                marquee = CGRect(x: min(marqueeStart.x, p.x), y: min(marqueeStart.y, p.y),
                                 width: abs(p.x - marqueeStart.x), height: abs(p.y - marqueeStart.y))
            }
            last = p
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.contains(where: { $0.type == .pencil }) else { return }
        finish(save: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(save: false)
    }

    private func finish(save: Bool) {
        holdWork?.cancel()
        if save, let l = live {
            store.commit()
            store.elements.append(l)
        }
        live = nil
        if let m = marquee {
            store.selection = Set(store.elements.filter { $0.bounds.intersects(m) }.map(\.id))
        }
        marquee = nil
        moving = false
        erasing = false
        committed = false
        snapped = false
        setNeedsDisplay()
    }

    private func selectionBounds() -> CGRect? {
        let boxes = store.elements.filter { store.selection.contains($0.id) }.map(\.bounds)
        guard let first = boxes.first else { return nil }
        return boxes.dropFirst().reduce(first) { $0.union($1) }
    }

    private func highlight(_ ctx: CGContext, _ r: CGRect) {
        ctx.saveGState()
        ctx.setFillColor(UIColor.label.withAlphaComponent(0.05).cgColor)
        ctx.fill(r)
        ctx.setStrokeColor(UIColor.label.cgColor)
        ctx.setLineWidth(1 / scale)
        ctx.setLineDash(phase: 0, lengths: [6 / scale, 4 / scale])
        ctx.stroke(r)
        ctx.restoreGState()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.translateBy(x: offset.x, y: offset.y)
        ctx.scaleBy(x: scale, y: scale)

        let pad = 100 / scale
        let visible = CGRect(
            x: -offset.x / scale,
            y: -offset.y / scale,
            width: bounds.width / scale,
            height: bounds.height / scale
        ).insetBy(dx: -pad, dy: -pad)

        drawBackground(ctx)
        drawImportedDocument(ctx, visible: visible)

        for e in store.elements where e.bounds.intersects(visible) {
            ElementRenderer.draw(e, in: ctx)
        }
        if let l = live { ElementRenderer.draw(l, in: ctx) }
        if store.tool == .move, let b = selectionBounds() { highlight(ctx, b.insetBy(dx: -6, dy: -6)) }
        if let m = marquee { highlight(ctx, m) }
    }

    private func syncImportedDocument() {
        guard importedData != store.fileData else { return }

        importedData = store.fileData
        importedPDF = nil
        importedImage = nil
        importedPageRects = []

        guard let data = store.fileData else { return }

        if store.fileKind == .pdf {
            importedPDF = PDFDocument(data: data)
            guard let pdf = importedPDF, pdf.pageCount > 0 else {
                importedPDF = nil
                return
            }

            let pageWidth: CGFloat = 794
            let gap: CGFloat = 32
            var y: CGFloat = 40

            for index in 0..<pdf.pageCount {
                guard let page = pdf.page(at: index) else { continue }
                let box = page.bounds(for: .mediaBox)
                let ratio = max(box.height, 1) / max(box.width, 1)
                let rect = CGRect(
                    x: 40,
                    y: y,
                    width: pageWidth,
                    height: pageWidth * ratio
                )
                importedPageRects.append(rect)
                y += rect.height + gap
            }
        } else {
            guard let image = UIImage(data: data) else { return }
            importedImage = image

            let maxWidth: CGFloat = 1000
            let ratio = image.size.height / max(image.size.width, 1)
            let width = min(maxWidth, max(image.size.width, 1))
            let height = width * ratio

            importedPageRects = [
                CGRect(x: 40, y: 40, width: width, height: height)
            ]
        }
    }

    private func drawImportedDocument(_ ctx: CGContext, visible: CGRect) {
        syncImportedDocument()

        if let image = importedImage, let rect = importedPageRects.first, rect.intersects(visible) {
            ctx.saveGState()
            UIColor.white.setFill()
            ctx.fill(rect)
            image.draw(in: rect)
            ctx.restoreGState()
            return
        }

        guard let pdf = importedPDF else { return }

        for (index, rect) in importedPageRects.enumerated() {
            guard rect.intersects(visible), let page = pdf.page(at: index) else { continue }

            ctx.saveGState()

            // Give each PDF page a real paper background.
            UIColor.white.setFill()
            ctx.fill(rect)

            let box = page.bounds(for: .mediaBox)
            let sx = rect.width / max(box.width, 1)
            let sy = rect.height / max(box.height, 1)

            // PDFKit uses a bottom-left coordinate system. Flip it into
            // the same top-left coordinate system used by the Inkspace canvas.
            ctx.translateBy(x: rect.minX, y: rect.maxY)
            ctx.scaleBy(x: sx, y: -sy)
            ctx.translateBy(x: -box.minX, y: -box.minY)
            page.draw(with: .mediaBox, to: ctx)

            ctx.restoreGState()
        }
    }

    private func drawBackground(_ ctx: CGContext) {
        let kind = store.background
        guard kind != .none else { return }
        let step: CGFloat = kind == .dots ? 20 : 40
        guard step * scale >= 4 else { return }
        let tl = world(.zero)
        let br = world(CGPoint(x: bounds.maxX, y: bounds.maxY))
        let startX = floor(tl.x / step) * step
        let startY = floor(tl.y / step) * step
        ctx.setStrokeColor(UIColor.label.withAlphaComponent(0.12).cgColor)
        ctx.setFillColor(UIColor.label.withAlphaComponent(0.28).cgColor)
        ctx.setLineWidth(1 / scale)

        if kind == .dots {
            let r = 1.2 / scale
            var x = startX
            while x < br.x {
                var y = startY
                while y < br.y {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                    y += step
                }
                x += step
            }
            return
        }

        if kind == .grid {
            var x = startX
            while x < br.x {
                ctx.move(to: CGPoint(x: x, y: tl.y))
                ctx.addLine(to: CGPoint(x: x, y: br.y))
                x += step
            }
        }
        var y = startY
        while y < br.y {
            ctx.move(to: CGPoint(x: tl.x, y: y))
            ctx.addLine(to: CGPoint(x: br.x, y: y))
            y += step
        }
        ctx.strokePath()
    }
}
