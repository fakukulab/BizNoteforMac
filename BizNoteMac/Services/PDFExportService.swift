import Foundation
import AppKit
import CoreText
import UniformTypeIdentifiers

@MainActor
enum PDFExportService {
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 48

    static func exportNotes(_ notes: [Note], openAfter: Bool = true) {
        let data = buildNotesPDF(notes)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "노트_\(ExcelExportService.dateStamp()).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = String(localized: "export.panelTitle")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            if openAfter { NSWorkspace.shared.open(url) }
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "export.error")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    static func buildNotesPDF(_ notes: [Note]) -> Data {
        let pdfData = NSMutableData()
        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }
        for note in notes {
            drawNote(note, in: ctx)
        }
        ctx.closePDF()
        return pdfData as Data
    }

    private static func drawNote(_ note: Note, in ctx: CGContext) {
        let textRect = pageRect.insetBy(dx: margin, dy: margin)
        let attributed = buildAttributedString(for: note)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: textRect, transform: nil)

        var location = 0
        let fullLength = attributed.length
        repeat {
            ctx.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
            ctx.endPDFPage()

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            let consumed = visibleRange.length
            location += max(consumed, 1)
        } while location < fullLength
    }

    private static func buildAttributedString(for note: Note) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleFont = NSFont.boldSystemFont(ofSize: 18)
        let metaFont = NSFont.systemFont(ofSize: 10)
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let metaColor = NSColor.darkGray.cgColor
        let bodyColor = NSColor.black.cgColor

        let title = note.title.isEmpty ? String(localized: "note.untitled") : note.title
        result.append(NSAttributedString(string: title + "\n",
                                          attributes: [.font: titleFont, .foregroundColor: bodyColor]))

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var meta = "\(note.categoryName)  ·  \(df.string(from: note.contentDate))"
        if !note.tags.isEmpty {
            meta += "  ·  #" + note.tags.joined(separator: " #")
        }
        result.append(NSAttributedString(string: meta + "\n\n",
                                          attributes: [.font: metaFont, .foregroundColor: metaColor]))

        result.append(NSAttributedString(string: note.content,
                                          attributes: [.font: bodyFont, .foregroundColor: bodyColor]))
        result.append(NSAttributedString(string: "\n\n"))
        return result
    }
}
