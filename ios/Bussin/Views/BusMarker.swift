import SwiftUI

struct BusMarker: View {
    let letter: String
    let colorHex: String
    let heading: Double?    // degrees, 0 = north
    let isStale: Bool

    var body: some View {
        ZStack {
            if let heading {
                ArrowHead()
                    .fill(Color(hex: colorHex))
                    .frame(width: 12, height: 9)
                    .offset(y: -20)
                    .rotationEffect(.degrees(heading))
            }
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .overlay(Text(letter)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textOn(hex: colorHex)))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .opacity(isStale ? 0.4 : 1)
    }
}

struct ArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
