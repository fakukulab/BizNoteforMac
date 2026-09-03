import SwiftUI

struct SyncStatusView: View {
    @ObservedObject private var sync = CloudSyncService.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: sync.status.iconName)
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, isActive: sync.status.isSyncing)
            VStack(alignment: .leading, spacing: 1) {
                Text(sync.status.localizedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let d = sync.lastSyncDate {
                    Text(d, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sync.status.localizedLabel)
    }

    private var iconColor: Color {
        switch sync.status {
        case .idle:    return .secondary
        case .syncing: return .accentColor
        case .success: return .green
        case .error:   return .red
        }
    }
}
