import SwiftUI
import SwiftData
import AppKit

struct BusinessCardPanelView: View {
    let note: Note

    @Environment(\.modelContext) private var context

    enum Phase {
        case idle
        case processing
        case editing(BusinessCardDraft, NSImage?, BusinessCardParseReview?)
    }

    @State private var phase: Phase = .idle
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "cardPanel.title"))
                    .font(.headline)
                Spacer()
                Text("\(note.businessCards?.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Group {
                switch phase {
                case .idle:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            BusinessCardImportView(onImage: process(image:))
                                .padding(.horizontal, 12)
                            if let msg = errorMessage {
                                Text(msg).font(.caption).foregroundStyle(.red).padding(.horizontal, 12)
                            }
                            existingCards
                        }
                    }
                case .processing:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(String(localized: "ocr.processing"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .editing(let draft, let image, let review):
                    BusinessCardResultView(
                        draft: bindingDraft(initial: draft),
                        image: image,
                        review: review,
                        onSave: { save(draft: currentDraft ?? draft, image: image) },
                        onCancel: { phase = .idle }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: .importCardRequested)) { _ in
            // Trigger open panel via the import view — for now, prompt directly
            promptOpenPanel()
        }
    }

    @State private var currentDraft: BusinessCardDraft? = nil

    private func bindingDraft(initial: BusinessCardDraft) -> Binding<BusinessCardDraft> {
        Binding(
            get: { currentDraft ?? initial },
            set: { currentDraft = $0 }
        )
    }

    @ViewBuilder
    private var existingCards: some View {
        if let cards = note.businessCards, !cards.isEmpty {
            Divider().padding(.horizontal, 12)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "cardPanel.attached"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                ForEach(cards, id: \.id) { card in
                    cardRow(card)
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func cardRow(_ card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(card.name.isEmpty ? "—" : card.name)
                    .font(.callout.weight(.semibold))
                Spacer()
                Button(role: .destructive) {
                    context.delete(card)
                    try? context.save()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            if !card.company.isEmpty || !card.jobTitle.isEmpty {
                Text([card.company, card.jobTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !card.email.isEmpty {
                Text(card.email).font(.caption2).foregroundStyle(.tertiary)
            }
            if !card.phone.isEmpty {
                Text(card.phone).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func promptOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            process(image: img)
        }
    }

    private func process(image: NSImage) {
        errorMessage = nil
        phase = .processing
        Task {
            do {
                let processedImage = BusinessCardImageProcessor.processedBusinessCardImage(from: image)
                let preferredResult = try await recognizedCardResult(from: processedImage, originalImage: image)
                let review = BusinessCardParser.parseForReview(preferredResult.ocrResult)
                await MainActor.run {
                    currentDraft = review.draft
                    phase = .editing(review.draft, preferredResult.image, review)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .idle
                }
            }
        }
    }

    private func recognizedCardResult(
        from processedImage: BusinessCardImageProcessor.ProcessingResult,
        originalImage: NSImage
    ) async throws -> (image: NSImage, ocrResult: OCRResult) {
        do {
            let processedOCR = try await OCRService.shared.recognizeText(from: processedImage.image)
            guard processedImage.usedDetectedCardRegion else {
                return (processedImage.image, processedOCR)
            }

            if isReliableOCRResult(processedOCR) {
                return (processedImage.image, processedOCR)
            }

            let originalOCR = try await OCRService.shared.recognizeText(from: originalImage)
            return (originalImage, originalOCR)
        } catch {
            guard processedImage.usedDetectedCardRegion else {
                throw error
            }
            let originalOCR = try await OCRService.shared.recognizeText(from: originalImage)
            return (originalImage, originalOCR)
        }
    }

    private func isReliableOCRResult(_ result: OCRResult) -> Bool {
        result.recognizedLines.count >= 3 && result.averageConfidence >= 0.35
    }

    private func save(draft: BusinessCardDraft, image: NSImage?) {
        var d = draft
        if let image {
            if let path = AttachmentStorage.saveCardImage(image, id: d.id) {
                d.imagePath = path
            }
        }
        let card = d.makeBusinessCard()
        card.note = note
        context.insert(card)
        if note.businessCards == nil {
            note.businessCards = [card]
        } else {
            note.businessCards?.append(card)
        }
        note.updatedAt = Date()
        try? context.save()

        currentDraft = nil
        phase = .idle
    }
}
