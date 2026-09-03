import SwiftUI

struct SettingsExportView: View {
    @AppStorage("export.openAfterSave") private var openAfterSave: Bool = true
    @AppStorage("export.dateFormat")     private var dateFormat: String = "yyyy-MM-dd HH:mm"
    @AppStorage("export.cardFormat")     private var cardFormatRaw: String = SpreadsheetFormat.xlsx.rawValue

    var body: some View {
        Form {
            Section(String(localized: "settings.export.general")) {
                Toggle(String(localized: "export.openAfterSave"), isOn: $openAfterSave)
                    .toggleStyle(.switch)
                LabeledContent(String(localized: "settings.export.dateFormat")) {
                    TextField("", text: $dateFormat)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                Picker(String(localized: "export.cardFormat", defaultValue: "명함 파일 형식"), selection: $cardFormatRaw) {
                    ForEach(SpreadsheetFormat.allCases) { f in
                        Text(f.localizedName).tag(f.rawValue)
                    }
                }
            }
            Section(String(localized: "settings.export.formats", defaultValue: "내보내기 형식")) {
                Text(String(localized: "settings.export.formats.note",
                            defaultValue: "명함은 XLSX 또는 CSV로, 노트는 PDF로 내보낼 수 있습니다."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
