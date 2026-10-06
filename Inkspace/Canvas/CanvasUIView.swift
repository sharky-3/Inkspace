import UIKit

final class CanvasUIView: UIView, UIGestureRecognizerDelegate {
    private let store: CanvasStore
    private var live: Element?
    private var dragID: UUID?
    private var erasing = false
    private var committed = false
    private var snapped = false
    private var last = CGPoint.zero
    private var holdAnchor = CGPoint.zero
    private var holdWork: DispatchWorkItem?

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
        backgroundColor = .white
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(onUndo))
        tap.numberOfTouchesRequired = 2
        tap.numberOfTapsRequired = 2
        for g in [pan, pinch, tap] as [UIGestureRecognizer] {
            g.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            g.delegate = self
            addGestureRecognizer(g)
        }
        store.resetView = { [weak self] in
            self?.offset = .zero
            self?.scale = 1
            self?.refresh()
            self?.store.requestSave()
        }
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

    func refresh() {
        store.center = world(CGPoint(x: bounds.midX, y: bounds.midY))
        setNeedsDisplay()
    }

    @objc private func onUndo() { store.undo() }

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
        scale = min(max(scale * g.scale, 0.1), 8)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func snap() {
        guard var l = live, l.kind == .stroke,
              let result = ShapeRecognizer.recognize(l.points, scale: scale) else { return }
        l.kind = result.0
        l.points = result.1
        l.widths = []
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
            live = Element(kind: kind(t), points: [p, p], color: store.color, width: store.width, brush: t == .ruler ? .ballpoint : store.brush)
        } else if t == .eraser {
            erasing = true
            erase(at: p)
        } else if t == .move {
            if let i = store.elements.lastIndex(where: { $0.hit(p, tol: 8 / scale) }) {
                store.commit()
                dragID = store.elements[i].id
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
            if live?.kind == .stroke {
                let raw = pressureWidth(c)
                let smoothed = (live?.widths.last ?? raw) * 0.7 + raw * 0.3
                live?.points.append(p)
                live?.widths.append(smoothed)
                if hypot(screen.x - holdAnchor.x, screen.y - holdAnchor.y) > 4 { armHold(screen) }
            } else if live != nil {
                if !snapped || live?.kind == .line { live?.points[1] = p }
            } else if erasing {
                erase(at: p)
            } else if let id = dragID, let i = store.elements.firstIndex(where: { $0.id == id }) {
                store.elements[i].move(by: CGSize(width: p.x - last.x, height: p.y - last.y))
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
        dragID = nil
        erasing = false
        committed = false
        snapped = false
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.translateBy(x: offset.x, y: offset.y)
        ctx.scaleBy(x: scale, y: scale)
        drawBackground(ctx)
        for e in store.elements { ElementRenderer.draw(e, in: ctx) }
        if let l = live { ElementRenderer.draw(l, in: ctx) }
    }

    private func drawBackground(_ ctx: CGContext) {
        let kind = store.background
        guard kind != .none else { return }
        let step: CGFloat = scale < 0.4 ? 160 : 40
        let tl = world(.zero)
        let br = world(CGPoint(x: bounds.maxX, y: bounds.maxY))
        let startX = floor(tl.x / step) * step
        let startY = floor(tl.y / step) * step
        ctx.setStrokeColor(UIColor(white: 0.86, alpha: 1).cgColor)
        ctx.setFillColor(UIColor(white: 0.74, alpha: 1).cgColor)
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
