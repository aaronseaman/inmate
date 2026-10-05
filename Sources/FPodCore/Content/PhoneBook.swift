import Foundation

public struct PhoneContact {
    public var icon: Icon
    public var label: String
    public var enabled: Bool
}

/// Approved numbers. Calls are short authored scenes.
public enum PhoneBook {
    public static func contacts(_ g: Game) -> [PhoneContact] {
        var out: [PhoneContact] = []
        if g.has(.lawyerNumberKnown) { out.append(PhoneContact(icon: .briefcase, label: "Ruth Calloway (public defender)", enabled: true)) }
        if g.has(.phoneListApproved) { out.append(PhoneContact(icon: .heart, label: "Nadia Merritt (sister)", enabled: true)) }
        return out
    }

    public static func call(_ g: Game, _ index: Int) {
        let list = contacts(g)
        guard index < list.count else { return }
        g.ui.modal = nil
        g.placeCall(list[index].label.hasPrefix("Ruth") ? .calloway : .nadia)
    }
}
