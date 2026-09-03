import Foundation

struct CustomNoteTemplateData: Codable, Equatable {
    var sections: [CustomNoteTemplateSection] = []

    static var defaultSections: [CustomNoteTemplateSection] {
        CustomNoteTemplateSection.Kind.allCases.map { kind in
            CustomNoteTemplateSection(kind: kind, title: kind.defaultTitle, isEnabled: true)
        }
    }

    static var defaultTemplate: CustomNoteTemplateData {
        CustomNoteTemplateData(sections: defaultSections)
    }
}

struct CustomNoteTemplateSection: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var kind: Kind
    var title: String
    var isEnabled: Bool = true
    var text: String = ""
    var tasks: [CustomNoteTask] = []
    var participants: [CustomNoteParticipant] = []

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case taskBoard
        case achievement
        case attachments
        case participants
        case work
        case addEvent

        var id: String { rawValue }

        var defaultTitle: String {
            switch self {
            case .taskBoard:
                return String(localized: "customTemplate.taskBoard", defaultValue: "업무")
            case .achievement:
                return String(localized: "customTemplate.achievement", defaultValue: "성과")
            case .attachments:
                return String(localized: "customTemplate.attachments", defaultValue: "첨부파일")
            case .participants:
                return String(localized: "customTemplate.participants", defaultValue: "참석자")
            case .work:
                return String(localized: "customTemplate.work", defaultValue: "업무")
            case .addEvent:
                return String(localized: "customTemplate.addEvent", defaultValue: "행사추가")
            }
        }

        var systemImage: String {
            switch self {
            case .taskBoard:
                return "checklist"
            case .achievement:
                return "rosette"
            case .attachments:
                return "paperclip"
            case .participants:
                return "person.2.fill"
            case .work:
                return "doc.text.fill"
            case .addEvent:
                return "calendar.badge.plus"
            }
        }
    }
}

struct CustomNoteTask: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
    var status: Status = .todo

    enum Status: String, Codable, CaseIterable, Identifiable {
        case todo
        case inProgress
        case done

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .todo:
                return String(localized: "task.status.todo")
            case .inProgress:
                return String(localized: "task.status.inProgress")
            case .done:
                return String(localized: "task.status.done")
            }
        }
    }
}

struct CustomNoteParticipant: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var company: String = ""
}
