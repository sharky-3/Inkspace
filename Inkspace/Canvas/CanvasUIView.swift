import UIKit

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
    private var cache: UIImage?
    private var cacheKey: [CGFloat] = []
    private var boxCache: [UUID: (Int, CGRect)] = [:]
    private var lastScreen = CGPoint.zero
    private var lastBox = CGRect.null
    private var cacheVersion = -1
    private var gestureSnap: UIImage?
    private var snapScale: CGFloat = 1
    private var snapOffset = CGPoint.zero
    private var activeGestures = 0
    private var lastTime: TimeInterval = 0

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
        trackGesture(g.state)
        let t = g.translation(in: self)
        offset.x += t.x
        offset.y += t.y
        g.setTranslation(.zero, in: self)
        refresh()
        if g.state == .ended { store.requestSave() }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        trackGesture(g.state)
        let c = g.location(in: self)
        let w = world(c)
        scale = min(max(scale * g.scale, 0.02), 16)
        offset = CGPoint(x: c.x - w.x * scale, y: c.y - w.y * scale)
        g.scale = 1
        refresh()
        if g.state == .ended { store.requestSave() }
    }

    private func pressureWidth(_ t: UITouch, speed: CGFloat = 0) -> CGFloat {
        let f = t.maximumPossibleForce > 0 ? t.force / t.maximumPossibleForce : 0.5
        let b = store.brush
        let r = b.pressureRange
        var w = store.width * b.widthScale * (r.lowerBound + (r.upperBound - r.lowerBound) * f)
        if b == .fountain || b == .brush { w *= max(0.55, 1 - speed / 3500) }
        if b == .pencil { w *= 1 + 1.8 * (1 - t.altitudeAngle / (CGFloat.pi / 2)) }
        return w
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
        guard let i = store.elements.lastIndex(where: { box($0).insetBy(dx: -10 / scale, dy: -10 / scale).contains(p) && $0.hit(p, tol: 10 / scale) }) else { return }
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
        lastTime = touch.timestamp
        snapped = false
        let t = store.tool
        if t == .brush {
            let w = pressureWidth(touch)
            live = Element(kind: .stroke, points: [p, p], widths: [w, w], color: store.color, width: store.width, brush: store.brush)
            armHold(touch.location(in: self))
            beginCache(touch.location(in: self))
        } else if t.isShape {
            live = Element(kind: kind(t), points: [p, p], color: store.color, width: store.width, brush: t == .ruler ? .ballpoint : store.brush, template: store.template)
            beginCache(touch.location(in: self))
        } else if t == .eraser {
            erasing = true
            erase(at: p)
        } else if t == .move {
            if let b = selectionBounds(), b.insetBy(dx: -8 / scale, dy: -8 / scale).contains(p) {
                store.commit()
                moving = true
            } else if let e = store.elements.last(where: { box($0).insetBy(dx: -8 / scale, dy: -8 / scale).contains(p) && $0.hit(p, tol: 8 / scale) }) {
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
        var dirty = CGRect.null
        for c in event?.coalescedTouches(for: touch) ?? [touch] {
            let screen = c.location(in: self)
            let p = world(screen)
            if live?.kind == .stroke, !snapped {
                let dt = c.timestamp - lastTime
                let speed = dt > 0 ? hypot(screen.x - lastScreen.x, screen.y - lastScreen.y) / CGFloat(dt) : 0
                lastTime = c.timestamp
                let raw = pressureWidth(c, speed: speed)
                let smoothed = (live?.widths.last ?? raw) * 0.7 + raw * 0.3
                live?.points.append(p)
                live?.widths.append(smoothed)
                dirty = dirty.union(segmentBox(lastScreen, screen))
                lastScreen = screen
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
        if cache != nil {
            if let l = live, l.kind != .stroke {
                let nb = liveBox(l)
                dirty = dirty.union(lastBox).union(nb)
                lastBox = nb
            }
            setNeedsDisplay(dirty.isNull ? bounds : dirty)
        } else {
            setNeedsDisplay()
        }
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
        if save, var l = live {
            if l.kind == .stroke { l = compact(l) }
            let valid = cache != nil && cacheKey == currentKey && cacheVersion == store.version
            store.commit()
            store.elements.append(l)
            if valid, let old = cache {
                let format = UIGraphicsImageRendererFormat.default()
                format.opaque = false
                let done = l
                cache = UIGraphicsImageRenderer(bounds: bounds, format: format).image { r in
                    old.draw(in: bounds)
                    traitCollection.performAsCurrent {
                        ElementRenderer.dark = traitCollection.userInterfaceStyle == .dark
                        r.cgContext.translateBy(x: offset.x, y: offset.y)
                        r.cgContext.scaleBy(x: scale, y: scale)
                        ElementRenderer.draw(done, in: r.cgContext)
                    }
                }
                cacheVersion = store.version
            }
        }
        lastBox = .null
        live = nil
        if let m = marquee {
            store.selection = Set(store.elements.filter { box($0).intersects(m) }.map(\.id))
        }
        marquee = nil
        moving = false
        erasing = false
        committed = false
        snapped = false
        setNeedsDisplay()
    }

    private var currentKey: [CGFloat] {
        [scale, offset.x, offset.y, bounds.width, bounds.height,
         CGFloat(traitCollection.userInterfaceStyle.rawValue),
         CGFloat(Background.allCases.firstIndex(of: store.background) ?? 0)]
    }

    private func renderScene() -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { r in
            traitCollection.performAsCurrent {
                ElementRenderer.dark = traitCollection.userInterfaceStyle == .dark
                r.cgContext.translateBy(x: offset.x, y: offset.y)
                r.cgContext.scaleBy(x: scale, y: scale)
                drawScene(r.cgContext)
            }
        }
    }

    private func trackGesture(_ state: UIGestureRecognizer.State) {
        switch state {
        case .began:
            activeGestures += 1
            if activeGestures == 1 {
                snapScale = scale
                snapOffset = offset
                let valid = cache != nil && cacheKey == currentKey && cacheVersion == store.version
                gestureSnap = valid ? cache : renderScene()
            }
        case .ended, .cancelled, .failed:
            activeGestures = max(0, activeGestures - 1)
            if activeGestures == 0 {
                gestureSnap = nil
                setNeedsDisplay()
            }
        default:
            break
        }
    }

    private func box(_ e: Element) -> CGRect {
        var h = Hasher()
        h.combine(e.kind)
        h.combine(e.points.count)
        h.combine(e.points.first?.x)
        h.combine(e.points.first?.y)
        h.combine(e.points.last?.x)
        h.combine(e.points.last?.y)
        h.combine(e.width)
        h.combine(e.rect.minX)
        h.combine(e.rect.minY)
        h.combine(e.rect.width)
        h.combine(e.text)
        h.combine(e.fontSize)
        h.combine(e.fontFamily)
        let key = h.finalize()
        if let hit = boxCache[e.id], hit.0 == key { return hit.1 }
        let b = e.bounds
        boxCache[e.id] = (key, b)
        return b
    }

    private func beginCache(_ screen: CGPoint) {
        lastScreen = screen
        lastBox = .null
        if cache != nil, cacheKey == currentKey, cacheVersion == store.version { return }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        cache = UIGraphicsImageRenderer(bounds: bounds, format: format).image { r in
            traitCollection.performAsCurrent {
                ElementRenderer.dark = traitCollection.userInterfaceStyle == .dark
                r.cgContext.translateBy(x: offset.x, y: offset.y)
                r.cgContext.scaleBy(x: scale, y: scale)
                drawScene(r.cgContext)
            }
        }
        cacheKey = currentKey
        cacheVersion = store.version
    }

    private func segmentBox(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        let w = (live?.width ?? 3) * (live?.brush.widthScale ?? 1) * scale
        let pad = w * 1.6 + 6
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            .insetBy(dx: -pad, dy: -pad)
    }

    private func liveBox(_ e: Element) -> CGRect {
        let b = e.bounds
        return CGRect(x: b.minX * scale + offset.x, y: b.minY * scale + offset.y, width: b.width * scale, height: b.height * scale)
            .insetBy(dx: -190, dy: -190)
    }

    private func compact(_ e: Element) -> Element {
        var out = e
        let idx = ShapeRecognizer.keep(e.points, 0.15 / scale)
        out.points = idx.map { e.points[$0] }
        out.widths = idx.map { e.widths[min($0, e.widths.count - 1)] }
        if e.brush == .fountain || e.brush == .brush, out.widths.count > 6 {
            for i in 0..<4 {
                let k = 0.4 + 0.15 * CGFloat(i)
                out.widths[i] *= k
                out.widths[out.widths.count - 1 - i] *= k
            }
        }
        return out
    }

    private func selectionBounds() -> CGRect? {
        let boxes = store.elements.filter { store.selection.contains($0.id) }.map { box($0) }
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
        ElementRenderer.dark = traitCollection.userInterfaceStyle == .dark
        if let snap = gestureSnap {
            let k = scale / snapScale
            ctx.translateBy(x: offset.x - snapOffset.x * k, y: offset.y - snapOffset.y * k)
            ctx.scaleBy(x: k, y: k)
            snap.draw(in: bounds)
            return
        }
        if let image = cache, cacheKey == currentKey, cacheVersion == store.version {
            image.draw(in: bounds)
            ctx.translateBy(x: offset.x, y: offset.y)
            ctx.scaleBy(x: scale, y: scale)
            if let l = live { ElementRenderer.draw(l, in: ctx) }
            if store.tool == .move, let b = selectionBounds() { highlight(ctx, b.insetBy(dx: -6, dy: -6)) }
            if let m = marquee { highlight(ctx, m) }
            return
        }
        ctx.translateBy(x: offset.x, y: offset.y)
        ctx.scaleBy(x: scale, y: scale)
        drawScene(ctx)
        if let l = live { ElementRenderer.draw(l, in: ctx) }
        if store.tool == .move, let b = selectionBounds() { highlight(ctx, b.insetBy(dx: -6, dy: -6)) }
        if let m = marquee { highlight(ctx, m) }
    }

    private func drawScene(_ ctx: CGContext) {
        drawBackground(ctx)
        let pad = 100 / scale
        let visible = CGRect(x: -offset.x / scale, y: -offset.y / scale, width: bounds.width / scale, height: bounds.height / scale)
            .insetBy(dx: -pad, dy: -pad)
        let tiny = 0.6 / scale
        for e in store.elements {
            let b = box(e)
            guard b.intersects(visible), b.width > tiny || b.height > tiny else { continue }
            ElementRenderer.draw(e, in: ctx)
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
