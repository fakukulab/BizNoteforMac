import Foundation
import AppKit

enum AttachmentStorage {
    static var cardsDirectory: URL? {
        let fm = FileManager.default
        if UserDefaults.standard.bool(forKey: "icloud.syncBackupEnabled"),
           let ubiquityBase = fm.url(forUbiquityContainerIdentifier: "iCloud.com.fakuku.biznote") {
            let dir = ubiquityBase.appendingPathComponent("Documents/BizNote/BusinessCards", isDirectory: true)
            if (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil {
                return dir
            }
        }
        do {
            let base = try fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = base.appendingPathComponent("BizNote/BusinessCards", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    @discardableResult
    static func saveCardImage(_ image: NSImage, id: UUID) -> String? {
        guard let dir = cardsDirectory,
              let data = image.pngData() else { return nil }
        let url = dir.appendingPathComponent("\(id.uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    static func loadCardImage(path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }

    static func removeCardImage(path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    static var exhibitionLogosDirectory: URL? {
        let fm = FileManager.default
        if UserDefaults.standard.bool(forKey: "icloud.syncBackupEnabled"),
           let ubiquityBase = fm.url(forUbiquityContainerIdentifier: "iCloud.com.fakuku.biznote") {
            let dir = ubiquityBase.appendingPathComponent("Documents/BizNote/ExhibitionLogos", isDirectory: true)
            if (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil {
                return dir
            }
        }
        do {
            let base = try fm.url(for: .applicationSupportDirectory,
                                  in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = base.appendingPathComponent("BizNote/ExhibitionLogos", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    @discardableResult
    static func saveExhibitionLogo(_ image: NSImage, id: UUID) -> String? {
        guard let dir = exhibitionLogosDirectory,
              let data = image.pngData() else { return nil }
        let url = dir.appendingPathComponent("\(id.uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    static func loadExhibitionLogo(path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }

    static func removeExhibitionLogo(path: String) {
        guard !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    static var filesDirectory: URL? {
        let fm = FileManager.default
        if UserDefaults.standard.bool(forKey: "icloud.syncBackupEnabled"),
           let ubiquityBase = fm.url(forUbiquityContainerIdentifier: "iCloud.com.fakuku.biznote") {
            let dir = ubiquityBase.appendingPathComponent("Documents/BizNote/Files", isDirectory: true)
            if (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil {
                return dir
            }
        }
        do {
            let base = try fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = base.appendingPathComponent("BizNote/Files", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    /// Copies the file at `sourceURL` into a per-attachment folder (named by a
    /// fresh UUID) so the original filename is preserved for display and for
    /// opening later, while avoiding collisions between attachments that share
    /// a filename.
    @discardableResult
    static func saveAttachment(from sourceURL: URL) -> String? {
        guard let dir = filesDirectory else { return nil }
        let fm = FileManager.default
        let folder = dir.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(sourceURL.lastPathComponent)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }

    static func attachmentDisplayName(path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func openAttachment(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    static func removeAttachment(path: String) {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        try? FileManager.default.removeItem(at: folder)
    }
}
