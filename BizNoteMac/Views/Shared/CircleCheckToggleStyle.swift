import SwiftUI

/// Renders a toggle as a circle that fills with `fillColor` (typically the
/// note list's own accent color) when on, instead of the native square
/// checkbox — used for task/item completion checkmarks throughout the app.
/// The whole circle (including its transparent center when unchecked) is
/// tappable, not just the stroked ring.
struct CircleCheckToggleStyle: ToggleStyle {
    var fillColor: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Circle()
                .fill(configuration.isOn ? fillColor : Color.clear)
                .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
                .contentShape(Circle())
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == CircleCheckToggleStyle {
    static var circleCheck: CircleCheckToggleStyle { CircleCheckToggleStyle() }
    static func circleCheck(fillColor: Color) -> CircleCheckToggleStyle {
        CircleCheckToggleStyle(fillColor: fillColor)
    }
}
