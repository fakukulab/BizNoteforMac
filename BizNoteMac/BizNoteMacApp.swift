import SwiftUI
import SwiftData

@main
struct BizNoteMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer
    @AppStorage("theme") private var theme: String = "system"

    init() {
        UserDefaults.standard.register(defaults: [
            "icloud.syncNotesEnabled": true,
            "icloud.syncBackupEnabled": true
        ])
        let syncNotesEnabled = UserDefaults.standard.bool(forKey: "icloud.syncNotesEnabled")

        let schema = Schema([
            Note.self,
            BusinessCard.self,
            CustomCategory.self,
            ExhibitionPreset.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: syncNotesEnabled ? .private("iCloud.com.fakuku.biznote") : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer 초기화 실패: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(container)
        .commands { AppCommands() }
        .defaultSize(width: 1200, height: 780)

        WindowGroup(String(localized: "exhibitions.add", defaultValue: "행사 추가"), id: "new-exhibition") {
            ExhibitionAddWindowView()
                .modelContainer(container)
                .preferredColorScheme(colorScheme)
        }
        .defaultSize(width: 620, height: 680)

        Settings {
            SettingsView()
                .modelContainer(container)
                .preferredColorScheme(colorScheme)
                .frame(width: 560, height: 460)
        }
    }

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
