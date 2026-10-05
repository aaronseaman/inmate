import Foundation

public struct DocLine: Hashable {
    public var text: String
    /// Contested by the player (shown with a flag marker).
    public var disputed: Bool
    /// Highlighted as newly discovered evidence.
    public var evidence: Bool
    public init(_ text: String, disputed: Bool = false, evidence: Bool = false) {
        self.text = text; self.disputed = disputed; self.evidence = evidence
    }
}

public struct DocSection: Hashable {
    public var heading: String?
    public var lines: [DocLine]
}

public struct DocDef {
    public var title: String
    public var subtitle: String
    public var icon: Icon
    public var sections: [DocSection]
    public var stamp: String?
    public var tint: RGBA
}

/// Institutional documents. Labels are records — incomplete, contested, sometimes wrong.
public enum Docs {
    public static func def(_ id: DocID, _ g: Game) -> DocDef {
        switch id {
        case .chart, .chartAnnotated: return chart(g)
        case .handbook: return handbook(g)
        case .intakeSheet: return intake()
        case .incidentReport: return incidents(g)
        case .watchOrder: return watchOrder(g)
        case .medInfo: return medInfo()
        case .jobBoard: return jobBoard(g)
        case .seclusionAftermath:
            return DocDef(title: "Seclusion review", subtitle: "Form SR-2", icon: .form, sections: [
                DocSection(heading: "What happened", lines: [DocLine("Placed in seclusion following an incident. Duration: 4 hours.")]),
                DocSection(heading: "Review", lines: [
                    DocLine("72-hour watch assigned. Constant observer for the first 24 hours."),
                    DocLine("Early review available: attend group, complete a clean shift, then meet Dr. Sato."),
                    DocLine("This does not affect your legal case or evaluation milestones."),
                ]),
                DocSection(heading: "Your rights", lines: [DocLine("You may file a grievance (Ms. Pruitt) or speak to the chaplain or your attorney about this event.")]),
            ], stamp: "REVIEW PENDING", tint: Palette.blueGray)
        default:
            return StoryDocs.def(id, g)
        }
    }

    static func chart(_ g: Game) -> DocDef {
        let found = g.has(.contradictionFound)
        return DocDef(title: "Patient chart", subtitle: "\(Cast.playerName.uppercased()) · #\(Cast.playerNumber) · Competency evaluation", icon: .clipboard, sections: [
            DocSection(heading: "Recorded impressions", lines: [
                DocLine("Mood disorder, recurrent — history of severe insomnia episodes. (Source: intake interview)"),
                DocLine("Psychotic disorder, unspecified — \"consider.\" (Source: transferring facility; no direct observation)", disputed: true),
                DocLine("Personality disorder traits. (Source: 10-minute screening)", disputed: true),
                DocLine("Malingering — \"rule out.\" (Source: one unsigned note)", disputed: true),
            ]),
            DocSection(heading: "Risk flags", lines: [
                DocLine("Suicide risk: low (self-report, reviewed)."),
                DocLine("Assault risk: HIGH — \"assaulted staff at transferring facility, 03/14, 09:40.\"", disputed: true, evidence: found),
            ]),
            DocSection(heading: "Incident log", lines: [
                DocLine("03/02 — Arrest at Harbor Street transit station. Charges: obstruction, assault (pending)."),
                DocLine("03/14 09:40 — \"Assault on staff\" (author: transfer packet, MERRIT, J.)", disputed: true, evidence: found),
                DocLine("03/21 — Transfer to F-Pod for evaluation."),
            ]),
            DocSection(heading: "Notes", lines: [
                DocLine("Patient insists on \"a mix-up.\" Requests medication discussion."),
                DocLine(found ? "YOUR NOTE: On 03/14 at 09:00 you were in court. The packet's name is spelled MERRIT — one T." : "YOUR NOTE: The 03/14 incident doesn't match anything you remember.", evidence: found),
            ]),
        ], stamp: found ? "DISPUTED" : nil, tint: Palette.blueGray)
    }

    static func handbook(_ g: Game) -> DocDef {
        let blocks = Schedule.blocks(day: g.s.day, storyOverrides: g.s.storyOverrides[g.s.day] ?? []).filter { $0.activity != .sleep }
        return DocDef(title: "F-Pod board", subtitle: "\(Schedule.dayName(g.s.day)) schedule & rules", icon: .list, sections: [
            DocSection(heading: "Today", lines: blocks.map { DocLine("\(Schedule.clockString(Double($0.start)))–\(Schedule.clockString(Double($0.end)))  \($0.activity.title)") }),
            DocSection(heading: "Rules (abridged)", lines: [
                DocLine("Count: be in your cell at 06:00 and 21:00. Two minutes' grace."),
                DocLine("Walk, don't run, indoors. Doors open on schedule — not on request."),
                DocLine("Money buys goods and privileges. It does not buy court dates."),
                DocLine("Contraband is confiscated. Searches cover only what officers open."),
                DocLine("Grievances: Ms. Pruitt, records desk. You may also speak to the chaplain or your attorney."),
            ]),
        ], stamp: nil, tint: Palette.ivory)
    }

    static func intake() -> DocDef {
        DocDef(title: "Intake sheet", subtitle: Cast.playerNumber, icon: .form, sections: [
            DocSection(heading: "About you", lines: [
                DocLine("\(Cast.playerName). Thirty-four. Piano tuner. Sister: Nadia. Dog: Biscuit (with Nadia)."),
                DocLine("Talent: fixing small electronics. Fear: losing the apartment lease while you're inside."),
            ]),
        ], stamp: "RECEIVED", tint: Palette.ivory)
    }

    static func incidents(_ g: Game) -> DocDef {
        let lines = g.s.incidents.suffix(12).reversed().map { DocLine("D\($0.day) \(Schedule.clockString(Double($0.minute))) · \($0.kind.title) — \($0.outcome)") }
        return DocDef(title: "Incident record", subtitle: "As written by staff", icon: .form, sections: [
            DocSection(heading: nil, lines: lines.isEmpty ? [DocLine("No incidents on file.")] : Array(lines)),
        ], stamp: nil, tint: Palette.ivory)
    }

    static func watchOrder(_ g: Game) -> DocDef {
        DocDef(title: "Behavioral watch", subtitle: g.s.watch.title, icon: .eye, sections: [
            DocSection(heading: "Status", lines: [
                DocLine("Level: \(g.s.watch.short). Remaining: \(Int(g.watchHoursLeft.rounded()))h (simulated)."),
                DocLine("Reason: \(g.s.watchReason.isEmpty ? "—" : g.s.watchReason)"),
            ]),
            DocSection(heading: "What it means", lines: [
                DocLine("Yellow: closer rounds, reduced movement, no commissary."),
                DocLine("On yellow, an officer comes to see you about once an hour. Be where they can find you; two missed checks mean red."),
                DocLine("Red: an observer stays with you; no yard; limited privacy."),
                DocLine("Restrictions never erase legal progress."),
            ]),
            DocSection(heading: "Review", lines: [DocLine(g.s.recovery?.text ?? "No review task pending.")]),
        ], stamp: nil, tint: Palette.blueGray)
    }

    static func medInfo() -> DocDef {
        DocDef(title: "About your medication", subtitle: "From Nurse Okonjo", icon: .pills, sections: [
            DocSection(heading: nil, lines: [
                DocLine("Your chart lists a nightly and a morning dose. Staff administer all medication."),
                DocLine("You can ask questions at the window, or request a discussion with Dr. Sato at any time."),
                DocLine("Declining is recorded and discussed. It is not, by itself, a rule violation."),
            ]),
        ], stamp: nil, tint: Palette.ivory)
    }

    static func jobBoard(_ g: Game) -> DocDef {
        var lines: [DocLine] = []
        for j in JobID.allCases {
            let d = Jobs.def(j)
            let open = g.eval(d.eligibility)
            let mine = g.s.player.job == j
            let status = mine ? "your job" : (open ? "you can apply" : "not yet")
            lines.append(DocLine("\(d.title) — \(Cast.def(d.supervisor).name) · \(d.payMin)–\(d.payMax) cr/shift · \(status)", evidence: mine))
            if !mine && !open { lines.append(DocLine("   \(d.eligibilityText) Or ask \(Cast.def(d.supervisor).short) for a tryout.")) }
        }
        return DocDef(title: "Work assignments", subtitle: "Posted by Vocational Services", icon: .work, sections: [
            DocSection(heading: "Jobs", lines: lines),
            DocSection(heading: "How it works", lines: [
                DocLine("Shifts: 08:00–11:00 and 13:00–15:00 (kitchen also serves meals). Pay goes to your commissary account."),
                DocLine("Every supervisor gives tryouts from day 2. A good tryout counts as a recommendation."),
                DocLine("Missing a shift costs that shift's pay, nothing more."),
            ]),
        ], stamp: nil, tint: Palette.ivory)
    }
}
