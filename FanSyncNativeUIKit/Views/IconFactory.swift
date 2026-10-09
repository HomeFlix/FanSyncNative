import UIKit

/// Hand-drawn stand-ins for the small set of SF Symbols this app used, since SF Symbols
/// and `UIImage(systemName:)` require iOS 13+ and this app targets iOS 12. Each icon is
/// rendered into a UIImage via UIGraphicsImageRenderer (iOS 10+) as a template image so
/// `tintColor` still works like it would with a real SF Symbol.
enum IconFactory {
    static func hamburger(size: CGFloat = 24) -> UIImage {
        render(size: size) { ctx, rect in
            let lineWidth: CGFloat = rect.width * 0.09
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            let xs = rect.minX + rect.width * 0.1
            let xe = rect.maxX - rect.width * 0.1
            for fraction: CGFloat in [0.22, 0.5, 0.78] {
                let y = rect.minY + rect.height * fraction
                ctx.move(to: CGPoint(x: xs, y: y))
                ctx.addLine(to: CGPoint(x: xe, y: y))
            }
            ctx.strokePath()
        }
    }

    static func plus(size: CGFloat = 24) -> UIImage {
        render(size: size) { ctx, rect in
            let lineWidth: CGFloat = rect.width * 0.1
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12))
            ctx.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12))
            ctx.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.midY))
            ctx.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY))
            ctx.strokePath()
        }
    }

    static func chevronRight(size: CGFloat = 16) -> UIImage {
        render(size: size) { ctx, rect in
            let lineWidth: CGFloat = rect.width * 0.14
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.15))
            ctx.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.midY))
            ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY - rect.height * 0.15))
            ctx.strokePath()
        }
    }

    static func gear(size: CGFloat = 24) -> UIImage {
        render(size: size) { ctx, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = rect.width * 0.46
            let innerRadius = rect.width * 0.3
            let toothCount = 8
            let path = CGMutablePath()
            for i in 0..<(toothCount * 2) {
                let angle = CGFloat(i) * .pi / CGFloat(toothCount)
                let radius = i % 2 == 0 ? outerRadius : outerRadius * 0.8
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillPath()
            ctx.addEllipse(in: CGRect(x: center.x - innerRadius / 1.4, y: center.y - innerRadius / 1.4, width: innerRadius * 1.4, height: innerRadius * 1.4))
            ctx.setBlendMode(.clear)
            ctx.fillPath()
        }
    }

    static func calendar(size: CGFloat = 40) -> UIImage {
        render(size: size) { ctx, rect in
            let lineWidth = rect.width * 0.06
            ctx.setLineWidth(lineWidth)
            let bodyRect = rect.insetBy(dx: rect.width * 0.1, dy: rect.height * 0.15)
            let path = UIBezierPath(roundedRect: bodyRect, cornerRadius: rect.width * 0.08)
            ctx.addPath(path.cgPath)
            ctx.strokePath()

            ctx.move(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + bodyRect.height * 0.22))
            ctx.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.minY + bodyRect.height * 0.22))
            ctx.strokePath()

            let dotRadius = rect.width * 0.045
            for row in 0..<2 {
                for col in 0..<3 {
                    let x = bodyRect.minX + bodyRect.width * (0.2 + CGFloat(col) * 0.3)
                    let y = bodyRect.minY + bodyRect.height * (0.5 + CGFloat(row) * 0.25)
                    ctx.addEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
                }
            }
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillPath()
        }
    }

    static func questionMarkCircle(size: CGFloat = 48) -> UIImage {
        render(size: size) { ctx, rect in
            let lineWidth = rect.width * 0.05
            ctx.setLineWidth(lineWidth)
            ctx.addEllipse(in: rect.insetBy(dx: lineWidth, dy: lineWidth))
            ctx.strokePath()
        }
    }

    // MARK: - Rendering

    private static func render(size: CGFloat, draw: @escaping (CGContext, CGRect) -> Void) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        let image = renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setFillColor(UIColor.black.cgColor)
            draw(ctx, rect)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }
}
