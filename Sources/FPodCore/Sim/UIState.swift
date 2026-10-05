import Foundation

public enum JournalTab: Int, CaseIterable { case quests, chart, people, ledger, incidents }

public enum Modal {
    case fan(TargetRef, [InteractOption])
    case inventory
    case map
    case journal(JournalTab)
    case settings
    case doc(DocID)
    case trade(TradeQuote)
    case tradeList(NPCID)
    case commissary
    case stash(String)
    case choice(ChoiceID)
    case outfit
    case phone
    case dev
    case menu
    case help
    case ending(Ending)
}

public struct UIState {
    public var modal: Modal?
    public var camera = Vec2(24, 50)
    public var cameraSnap = true
    public var districtFade: Double = 0
    public var fade: Double = 0
    public var toasts: [Toast] = []
    public var realTime: Double = 0
    public var devMove = Vec2.zero
    public var pendingTarget: TargetRef?
    public var questionedBy: NPCID?
    public var complied: NPCID?
    public var quoteNonce = 0
    public var contextTarget: TargetRef?
    public var statusExpanded = false
    public var tapMarker: (pos: Vec2, time: Double)?
    public var lastTap: (pos: Vec2, time: Double)?
    public var caption = ""
    public var captionTime: Double = 99
    public var inventorySelection: (Slot, Int)?
    public var stashSelection: Int?
    public var preFinaleSaveRequested = false
    /// Asks the host app to swap the running game (load the pre-finale save, or start over).
    public var platformRequest: PlatformRequest?
    public var confirmNewGame = false
    public var devPage = 0
    public var mapScroll = Vec2.zero
    public var docScroll: Double = 0
    public var journalScroll: Double = 0
    public var showHelp = false
    public var hitRegions: [HitRegion] = []
    public var accessibility: [AXElement] = []
    public var lastFrameHash = 0
    public init() {}
}

public struct InteractOption: Hashable {
    public var id: String
    public var icon: Icon
    public var caption: String
    public var risky: Bool
    public var enabled: Bool
    public var note: String?
}

public enum PlatformRequest: Equatable { case loadPreFinale, newGame }
