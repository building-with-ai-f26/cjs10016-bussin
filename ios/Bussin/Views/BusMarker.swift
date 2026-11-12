import SwiftUI

struct BusMarker: View {
    let letter: String
    let colorHex: String
    let heading: Double?    // degrees, 0 = north
    let isStale: Bool
    var isSelected = false

    var body: some View {
        let size: CGFloat = isSelected ? 34 : 26
        ZStack {
            if let heading {
                ArrowHead()
                    .fill(Color(hex: colorHex))
                    .frame(width: 12, height: 9)
                    .offset(y: -(size / 2 + 7))
                    .rotationEffect(.degrees(heading))
            }
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 2.5))
                .overlay(Text(letter)
                    .font(.system(size: isSelected ? 15 : 12, weight: .bold))
                    .foregroundStyle(Color.textOn(hex: colorHex)))
                .shadow(color: isSelected ? .blue.opacity(0.45) : .black.opacity(0.3),
                        radius: isSelected ? 7 : 2, y: isSelected ? 0 : 1)
        }
        .frame(width: 44, height: 44)          // full-size tap target
        .contentShape(Circle())
        .opacity(isStale ? 0.4 : 1)
        .animation(.spring(duration: 0.3), value: isSelected)
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
