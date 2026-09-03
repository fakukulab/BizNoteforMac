import SwiftUI
import AppKit

struct BusinessCardResultView: View {
    @Binding var draft: BusinessCardDraft
    let image: NSImage?
    let review: BusinessCardParseReview?
    var onSave: () -> Void
    var onCancel: () -> Void

    @State private var duplicateCandidates: [BusinessCardDuplicateCandidate] = []
    @State private var duplicateMessage: String? = nil
    @State private var isCheckingDuplicates = false

    private var canSave: Bool {
        [draft.name, draft.company, draft.phone, draft.officePhone, draft.email]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            }

            Form {
                Section {
                    editableField(String(localized: "card.field.name"), text: $draft.name)
                    editableField(String(localized: "card.field.company"), text: $draft.company)
                    editableField(String(localized: "card.field.department"), text: $draft.department)
                    editableField(String(localized: "card.field.jobTitle"), text: $draft.jobTitle)
                }
                Section {
                    editableField(String(localized: "card.field.email"), text: $draft.email)
                    editableField(String(localized: "card.field.phone"), text: $draft.phone)
                    editableField(String(localized: "card.field.officePhone"), text: $draft.officePhone)
                }
                Section {
                    editableField(String(localized: "card.field.website"), text: $draft.website)
                    LabeledContent(String(localized: "card.field.memo")) {
                        TextEditor(text: $draft.memo)
                            .frame(minHeight: 60)
                            .padding(4)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .scrollContentBackground(.hidden)
                    }
                }
                duplicateSection
            }
            .formStyle(.grouped)

            HStack {
                Button(String(localized: "action.cancel"), action: onCancel)
                Spacer()
                Button(String(localized: "action.save")) {
                    onSave()
                }
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
                .help(canSave ? String(localized: "action.save") : String(localized: "card.review.saveDisabled", defaultValue: "이름, 회사, 전화번호, 이메일 중 하나 이상이 필요합니다."))
            }
        }
        .padding(12)
    }

    private func editableField(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        Section {
            Button {
                checkDuplicates()
            } label: {
                if isCheckingDuplicates {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(String(localized: "card.review.checkDuplicates", defaultValue: "중복 연락처 확인"), systemImage: "person.crop.circle.badge.questionmark")
                }
            }
            .disabled(isCheckingDuplicates || !canSave)

            if let duplicateMessage {
                Text(duplicateMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(duplicateCandidates) { candidate in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(candidate.displayName.isEmpty ? String(localized: "note.untitled") : candidate.displayName)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text("\(candidate.score)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(candidate.strength == .strong ? .red : .secondary)
                    }
                    if !candidate.organizationName.isEmpty {
                        Text(candidate.organizationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(candidate.reasons.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func checkDuplicates() {
        isCheckingDuplicates = true
        duplicateMessage = nil
        Task {
            let granted = await ContactsService.requestAccess()
            guard granted else {
                await MainActor.run {
                    duplicateCandidates = []
                    duplicateMessage = String(localized: "contacts.access.denied", defaultValue: "주소록 접근 권한이 필요합니다.")
                    isCheckingDuplicates = false
                }
                return
            }
            let contacts = ContactsService.fetchAllContacts()
            let candidates = BusinessCardDuplicateDetector.candidates(for: draft, contacts: contacts)
            await MainActor.run {
                duplicateCandidates = Array(candidates.prefix(5))
                duplicateMessage = candidates.isEmpty ? String(localized: "card.review.noDuplicates", defaultValue: "중복 후보가 없습니다.") : nil
                isCheckingDuplicates = false
            }
        }
    }
}
