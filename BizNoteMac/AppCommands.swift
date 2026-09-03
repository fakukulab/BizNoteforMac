import SwiftUI
import AppKit

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "menu.aboutBizNote", defaultValue: "About BizNote")) {
                showAboutPanel()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(String(localized: "action.newNote")) {
                NotificationCenter.default.post(name: .newNoteRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button(String(localized: "action.importCard") + "…") {
                NotificationCenter.default.post(name: .importCardRequested, object: nil)
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button(String(localized: "action.export") + "…") {
                NotificationCenter.default.post(name: .exportRequested, object: nil)
            }
            .keyboardShortcut("e", modifiers: .command)
        }

        CommandMenu(String(localized: "menu.view")) {
            Button(String(localized: "menu.toggleSidebar")) {
                NSApp.keyWindow?.firstResponder?
                    .tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button(String(localized: "menu.toggleInspector")) {
                NotificationCenter.default.post(name: .toggleInspectorRequested, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Button(NoteCategory.workLog.localizedName) {
                NotificationCenter.default.post(name: .categorySelectRequested, object: NoteCategory.workLog)
            }.keyboardShortcut("1", modifiers: .command)

            Button(NoteCategory.meetingMinutes.localizedName) {
                NotificationCenter.default.post(name: .categorySelectRequested, object: NoteCategory.meetingMinutes)
            }.keyboardShortcut("2", modifiers: .command)

            Button(NoteCategory.exhibition.localizedName) {
                NotificationCenter.default.post(name: .categorySelectRequested, object: NoteCategory.exhibition)
            }.keyboardShortcut("3", modifiers: .command)
        }
    }

    private func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }
}

extension Notification.Name {
    static let newNoteRequested          = Notification.Name("BizNote.newNoteRequested")
    static let importCardRequested       = Notification.Name("BizNote.importCardRequested")
    static let exportRequested           = Notification.Name("BizNote.exportRequested")
    static let toggleInspectorRequested  = Notification.Name("BizNote.toggleInspectorRequested")
    static let categorySelectRequested   = Notification.Name("BizNote.categorySelectRequested")
}
