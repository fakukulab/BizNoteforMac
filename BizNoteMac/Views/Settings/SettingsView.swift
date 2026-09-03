import SwiftUI
import AppKit

struct SettingsView: View {
    enum Tab: Hashable { case general, iCloud, export, about }
    @State private var tab: Tab = .general

    var body: some View {
        TabView(selection: $tab) {
            SettingsGeneralView()
                .tabItem { Label(String(localized: "settings.general"), systemImage: "gearshape") }
                .tag(Tab.general)

            SettingsICloudView()
                .tabItem { Label(String(localized: "settings.iCloud"), systemImage: "icloud") }
                .tag(Tab.iCloud)

            SettingsExportView()
                .tabItem { Label(String(localized: "settings.export"), systemImage: "square.and.arrow.up") }
                .tag(Tab.export)

            SettingsAboutView()
                .tabItem { Label(String(localized: "settings.about"), systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .padding(20)
    }
}

struct SettingsGeneralView: View {
    @AppStorage("theme") private var theme: String = "system"

    var body: some View {
        Form {
            Picker(String(localized: "settings.theme"), selection: $theme) {
                Text(String(localized: "settings.theme.system")).tag("system")
                Text(String(localized: "settings.theme.light")).tag("light")
                Text(String(localized: "settings.theme.dark")).tag("dark")
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }
}

struct SettingsAboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("BizNote for Mac").font(.title2.weight(.semibold))
            let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            Text("Version \(ver)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Copyright © 2026 Fakuku Lab. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let privacyPolicyURL = URL(string: "https://fakukulab.github.io/BizNoteforMac/privacy.html") {
                    Link("Privacy Policy", destination: privacyPolicyURL)
                }
                if let supportURL = URL(string: "https://fakukulab.github.io/BizNoteforMac/support.html") {
                    Link("Support", destination: supportURL)
                }
            }
            .font(.caption)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsPlaceholderView: View {
    let title: String
    var body: some View {
        VStack {
            Text(title).font(.title3)
            Text(String(localized: "settings.comingSoon"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
