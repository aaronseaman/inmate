import Foundation

public struct DialogueLine {
    public var icons: [Icon]
    public var caption: String
}

/// World speech is pictograms + mumbles; captions are optional accessibility text.
public enum Dialogue {
    public static func line(for id: NPCID, game g: Game) -> DialogueLine? {
        if let l = StoryDialogue.line(for: id, game: g) { return l }
        let a = g.activity
        switch id {
        case .haskins:
            if a.isCount || g.s.countState.warned && !g.s.countState.resolved { return DialogueLine(icons: [.count, .cellDoor], caption: "Count. Cell. Now.") }
            if !g.has(.claimedBunk) { return DialogueLine(icons: [.bed, .arrowRight], caption: "F-3. Top row of cells.") }
            return DialogueLine(icons: [Schedule.icon(a), .clock], caption: "\(a.title) till \(Schedule.clockString(Double(g.currentBlock.end))).")
        case .reed:
            return DialogueLine(icons: [.zzz, .thumbsUp], caption: "Long day. Don't make it longer.")
        case .strick:
            return DialogueLine(icons: [.stop, .eye], caption: "I'm watching you, Merritt.")
        case .cole:
            if !g.has(.readChart) { return DialogueLine(icons: [.clipboard, .group, .clock], caption: "Group at eleven. I'll have your chart.") }
            return DialogueLine(icons: [.heart, .question], caption: "How are you holding up?")
        case .okonjo:
            return DialogueLine(icons: [.pills, .clock], caption: "Med pass is 06:20 to 07:00. Questions welcome.")
        case .fitz:
            if !g.has(.fitzBoundaryResolved) { return DialogueLine(icons: [.bed, .stop], caption: "Bottom bunk's mine. Don't touch my stuff.") }
            return DialogueLine(icons: [.happy, .photo], caption: "My kid's ten next month.")
        case .dutch:
            return DialogueLine(icons: [.cup, .swap], caption: "Coffee trades fair here.")
        case .mouse:
            return DialogueLine(icons: [.quiet, .eye], caption: "Psst. Not here.")
        case .theo:
            return DialogueLine(icons: [.chess, .question], caption: "Do you play?")
        case .lou:
            return DialogueLine(icons: [.dumbbell, .thumbsUp], caption: "Benches at rec. Bring effort.")
        case .marisol:
            return DialogueLine(icons: [.gavel, .form], caption: "Paper beats promises.")
        case .harlan:
            return DialogueLine(icons: [.angry, .radio], caption: "That's my radio you're looking at.")
        case .benny:
            return DialogueLine(icons: [.dice, .coin], caption: "Benny's got what you need. Mostly.")
        case .moss:
            return DialogueLine(icons: [.candle, .music], caption: "This little light of mine…")
        case .kenji:
            return DialogueLine(icons: [.drawing, .pencil], caption: "I draw what people let me.")
        case .staticFell:
            return DialogueLine(icons: [.radio, .wire], caption: "The signal's in the walls, man.")
        case .ada:
            return DialogueLine(icons: [.stethoscope, .heart], caption: "Drink water. Sleep if you can.")
        case .rosa:
            return DialogueLine(icons: [.pan, .tomato], caption: "You work, you eat. Simple.")
        case .abe:
            return DialogueLine(icons: [.van, .map], caption: "The 14 used to run right past here.")
        case .pruitt:
            return DialogueLine(icons: [.form, .stamp], caption: "Form first. Then we talk.")
        case .sato:
            return DialogueLine(icons: [.clipboard, .clock], caption: "We'll talk at your appointment.")
        case .gaines:
            return DialogueLine(icons: [.badge, .eye], caption: "Something you want to tell me?")
        case .bell:
            return DialogueLine(icons: [.candle, .heart], caption: "The chapel door is open to you.")
        case .feld:
            return DialogueLine(icons: [.tools, .count], caption: "Every tool. Every day.")
        case .odell:
            return DialogueLine(icons: [.pan, .stop], caption: "Hands off the knife board.")
        case .abernathy:
            return DialogueLine(icons: [.quiet, .book], caption: "Due Friday.")
        case .nico:
            return DialogueLine(icons: [.whistleIcon, .tools], caption: "Just fixing pipes.")
        case .tran:
            return DialogueLine(icons: [.dog, .stop], caption: "Ask before you pet him.")
        case .varga:
            return DialogueLine(icons: [.happy, .question], caption: "Heard the one about the lifeguard?")
        case .calloway:
            return DialogueLine(icons: [.briefcase, .form], caption: "Documents, Jo. Bring me documents.")
        case .nadia:
            return DialogueLine(icons: [.heart, .dog], caption: "Biscuit misses you.")
        }
    }
}

extension Icon {
    static var whistleIcon: Icon { .music }
}
