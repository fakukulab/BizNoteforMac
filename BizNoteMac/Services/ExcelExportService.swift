import Foundation
import AppKit
import UniformTypeIdentifiers

enum SpreadsheetFormat: String, CaseIterable, Identifiable {
    case csv, xlsx

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .csv:  return String(localized: "export.format.csv", defaultValue: "CSV")
        case .xlsx: return String(localized: "export.format.xlsx", defaultValue: "Excel (XLSX)")
        }
    }
}

@MainActor
enum ExcelExportService {

    static func exportBusinessCards(_ cards: [BusinessCard], format: SpreadsheetFormat, openAfter: Bool = true) {
        let defaultName = "명함_\(dateStamp())"
        switch format {
        case .csv:
            saveTextWithPanel(content: buildBusinessCardCSV(cards), defaultName: defaultName,
                               fileExtension: "csv", contentType: .commaSeparatedText, openAfter: openAfter)
        case .xlsx:
            let headers = businessCardHeaders
            let rows = cards.map(businessCardRow)
            saveDataWithPanel(data: buildXLSX(headers: headers, rows: rows), defaultName: defaultName,
                               fileExtension: "xlsx",
                               contentType: UTType(filenameExtension: "xlsx") ?? .data, openAfter: openAfter)
        }
    }

    // MARK: - Save

    private static func saveTextWithPanel(content: String, defaultName: String, fileExtension: String,
                                           contentType: UTType, openAfter: Bool) {
        saveDataWithPanel(data: Data(content.utf8), defaultName: defaultName,
                          fileExtension: fileExtension, contentType: contentType, openAfter: openAfter)
    }

    private static func saveDataWithPanel(data: Data, defaultName: String, fileExtension: String,
                                          contentType: UTType, openAfter: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(defaultName).\(fileExtension)"
        panel.allowedContentTypes = [contentType]
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

    // MARK: - CSV

    private static let bom = "\u{FEFF}"

    private static let businessCardHeaders = [
        "이름(Name)","이름(Phonetic)","회사(Company)","부서(Department)","직함(Title)",
        "이메일(Email)","휴대폰(Mobile)","사무실(Office)",
        "웹사이트(Website)","메모(Memo)",
        "인식언어(Language)","등록일(Date)"
    ]

    private static func businessCardRow(_ c: BusinessCard) -> [String] {
        [c.name, c.namePhonetic, c.company, c.department, c.jobTitle,
         c.email, c.phone, c.officePhone,
         c.website, c.memo,
         c.scannedLanguage, iso(c.createdAt)]
    }

    static func buildBusinessCardCSV(_ cards: [BusinessCard]) -> String {
        var csv = bom + businessCardHeaders.map(escape).joined(separator: ",") + "\n"
        for c in cards {
            csv += businessCardRow(c).map(escape).joined(separator: ",") + "\n"
        }
        return csv
    }

    private static func escape(_ s: String) -> String {
        let needsQuote = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuote ? "\"\(escaped)\"" : escaped
    }

    // MARK: - XLSX (minimal OOXML writer, no third-party dependency)

    private static func buildXLSX(headers: [String], rows: [[String]]) -> Data {
        func rowXML(_ values: [String], rowIndex: Int) -> String {
            var cells = ""
            for (i, value) in values.enumerated() {
                let ref = "\(columnLetter(i))\(rowIndex)"
                cells += "<c r=\"\(ref)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xmlEscape(value))</t></is></c>"
            }
            return "<row r=\"\(rowIndex)\">\(cells)</row>"
        }

        var sheetRows = rowXML(headers, rowIndex: 1)
        for (i, row) in rows.enumerated() {
            sheetRows += rowXML(row, rowIndex: i + 2)
        }

        let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(sheetRows)</sheetData></worksheet>
        """

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
        """

        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """

        let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """

        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
        """

        let entries = [
            MinimalZipEntry(name: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            MinimalZipEntry(name: "_rels/.rels", data: Data(rootRels.utf8)),
            MinimalZipEntry(name: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            MinimalZipEntry(name: "xl/_rels/workbook.xml.rels", data: Data(workbookRels.utf8)),
            MinimalZipEntry(name: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8))
        ]
        return MinimalZipWriter.write(entries)
    }

    private static func columnLetter(_ index: Int) -> String {
        var i = index
        var letters = ""
        repeat {
            let scalar = UnicodeScalar(65 + i % 26)!
            letters = String(scalar) + letters
            i = i / 26 - 1
        } while i >= 0
        return letters
    }

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Helpers

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    static func dateStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
}
