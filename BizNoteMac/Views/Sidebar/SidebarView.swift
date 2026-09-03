import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCategory.createdAt) private var customCategories: [CustomCategory]
    @Query private var allNotes: [Note]
    @Query private var exhibitionPresets: [ExhibitionPreset]

    @State private var showAddCategory: Bool = false
    @State private var pendingDeleteCategory: CustomCategory? = nil

    var body: some View {
        List(selection: $selection) {
            Section(String(localized: "sidebar.smartFolders")) {
                row(String(localized: "sidebar.allNotes"), "tray.full", tag: .allNotes,
                    count: allNotes.count)
                row(String(localized: "sidebar.favorites"), "star", tag: .favorites,
                    count: allNotes.filter(\.isFavorite).count)
                row(String(localized: "sidebar.recent"), "clock", tag: .recent,
                    count: allNotes.filter { $0.updatedAt >= sevenDaysAgo }.count)
                row(String(localized: "sidebar.businessCards"), "person.text.rectangle",
                    tag: .businessCards, count: nil)
            }

            Section(String(localized: "sidebar.eventsList", defaultValue: "행사 목록")) {
                row(String(localized: "sidebar.events", defaultValue: "행사"), "building.columns.fill",
                    tag: .exhibitions, count: exhibitionPresets.count)
            }

            Section {
                Button {
                    showAddCategory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text(String(localized: "sidebar.addNote", defaultValue: "노트"))
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showAddCategory) {
                    CustomCategoryTemplateSheetView(isPresented: $showAddCategory)
                }

                ForEach(NoteCategory.allCases) { category in
                    HStack {
                        Label(category.localizedName, systemImage: category.systemIconName)
                            .foregroundStyle(selection == .builtin(category) ? Color.white : category.accentColor)
                        Spacer()
                        badge(count(for: category))
                    }
                    .tag(SidebarSelection.builtin(category))
                }
                ForEach(customCategories) { c in
                    HStack {
                        Label(c.name, systemImage: c.systemIconName)
                            .foregroundStyle(selection == .custom(c) ? Color.white : c.accentColor)
                        Spacer()
                        badge(count(for: c))
                    }
                    .tag(SidebarSelection.custom(c))
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingDeleteCategory = c
                        } label: {
                            Label(String(localized: "note.delete"), systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(String(localized: "sidebar.categories"))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BizNote")
        .safeAreaInset(edge: .bottom) {
            SyncStatusView()
                .background(.bar)
        }
        .confirmationDialog(
            String(localized: "settings.categories.delete.title"),
            isPresented: Binding(get: { pendingDeleteCategory != nil }, set: { if !$0 { pendingDeleteCategory = nil } }),
            presenting: pendingDeleteCategory
        ) { c in
            Button(String(localized: "note.delete"), role: .destructive) {
                context.delete(c)
                try? context.save()
                pendingDeleteCategory = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                pendingDeleteCategory = nil
            }
        } message: { _ in
            Text(String(localized: "settings.categories.delete.message"))
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ icon: String, tag: SidebarSelection, count: Int?) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if let count { badge(count) }
        }
        .tag(tag)
    }

    @ViewBuilder
    private func badge(_ n: Int) -> some View {
        if n > 0 {
            Text("\(n)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
    }

    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    private func count(for category: NoteCategory) -> Int {
        allNotes.filter { !$0.isCustomCategory && $0.category == category }.count
    }

    private func count(for custom: CustomCategory) -> Int {
        allNotes.filter { $0.isCustomCategory && $0.customCategory?.id == custom.id }.count
    }
}

private struct CustomCategoryTemplateSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var color: Color = Color(red: 0.486, green: 0.227, blue: 0.929)
    @State private var icon: String = "folder.fill"
    @State private var sections: [CustomNoteTemplateSection] = CustomNoteTemplateData.defaultSections

    private let iconOptions = [
        "folder.fill", "star.fill", "bookmark.fill", "flag.fill",
        "tag.fill", "briefcase.fill", "graduationcap.fill",
        "airplane", "book.fill", "cart.fill", "chart.bar.fill",
        "person.2.fill", "building.2.fill", "leaf.fill", "sparkles"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "settings.categories.add"))
                .font(.title2.weight(.semibold))

            categoryFields
            Divider()
            templateFields
            Spacer(minLength: 0)
            actionButtons
        }
        .padding(22)
        .frame(width: 560)
        .frame(minHeight: 620)
    }

    private var categoryFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(String(localized: "settings.categories.namePlaceholder"), text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addCategory)
            HStack {
                Picker("", selection: $icon) {
                    ForEach(iconOptions, id: \.self) { name in
                        Image(systemName: name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(width: 70)
                ColorPicker("", selection: $color).labelsHidden()
                Spacer()
            }
        }
    }

    private var templateFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "customTemplate.configure", defaultValue: "노트 항목"))
                .font(.callout.weight(.semibold))
            Text(String(localized: "customTemplate.configure.message", defaultValue: "오른쪽 노트 상세 화면에 표시할 항목을 선택하고 제목을 변경하세요."))
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach($sections) { $section in
                    CustomTemplateSectionOption(
                        section: $section,
                        canMoveUp: section.id != sections.first?.id,
                        canMoveDown: section.id != sections.last?.id,
                        moveUp: { moveSection(section.id, by: -1) },
                        moveDown: { moveSection(section.id, by: 1) }
                    )
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button(String(localized: "action.cancel")) {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
            Button(String(localized: "action.save", defaultValue: "저장")) {
                addCategory()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSections.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var selectedSections: [CustomNoteTemplateSection] {
        sections.filter(\.isEnabled)
    }

    private func moveSection(_ id: UUID, by offset: Int) {
        guard let sourceIndex = sections.firstIndex(where: { $0.id == id }) else { return }
        let destinationIndex = sourceIndex + offset
        guard sections.indices.contains(destinationIndex) else { return }
        sections.swapAt(sourceIndex, destinationIndex)
    }

    private func addCategory() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !selectedSections.isEmpty else { return }
        let template = CustomNoteTemplateData(sections: selectedSections)
        let category = CustomCategory(
            name: trimmed,
            systemIconName: icon,
            accentColor: color,
            templateData: TemplateCoder.encode(template)
        )
        context.insert(category)
        try? context.save()
        isPresented = false
    }
}

private struct CustomTemplateSectionOption: View {
    @Binding var section: CustomNoteTemplateSection
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $section.isEnabled)
                .labelsHidden()
            Image(systemName: section.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(section.kind.defaultTitle)
                .frame(width: 80, alignment: .leading)
            TextField(section.kind.defaultTitle, text: $section.title)
                .textFieldStyle(.roundedBorder)
                .disabled(!section.isEnabled)
            orderButtons
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var orderButtons: some View {
        HStack(spacing: 4) {
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help(String(localized: "customTemplate.moveUp", defaultValue: "위로 이동"))

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help(String(localized: "customTemplate.moveDown", defaultValue: "아래로 이동"))
        }
        .frame(width: 56)
    }
}
