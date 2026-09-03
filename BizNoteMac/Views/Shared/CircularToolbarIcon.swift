import SwiftUI

struct CircularToolbarIcon: View {
    let systemName: String
    var isActive: Bool = false
    var tint: Color = .secondary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isActive ? Color.accentColor : tint)
            .frame(width: 28, height: 28)
            .background(
                isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(isActive ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.24), lineWidth: 1)
            }
            .contentShape(Circle())
    }
}
