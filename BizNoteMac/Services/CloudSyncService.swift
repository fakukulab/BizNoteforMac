import Foundation
import CoreData
import Combine

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    enum Status {
        case idle
        case syncing
        case success
        case error(String)

        var iconName: String {
            switch self {
            case .idle:    return "cloud"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .success: return "checkmark.icloud"
            case .error:   return "exclamationmark.icloud"
            }
        }

        var localizedLabel: String {
            switch self {
            case .idle:            return String(localized: "sync.idle")
            case .syncing:         return String(localized: "sync.syncing")
            case .success:         return String(localized: "sync.success")
            case .error(let msg):  return String(localized: "sync.error") + ": " + msg
            }
        }

        var isSyncing: Bool {
            if case .syncing = self { return true }; return false
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSyncDate: Date? = nil

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.status = .success
                self?.lastSyncDate = Date()
            }
            .store(in: &cancellables)
    }

    func markSyncing() {
        status = .syncing
    }
}
