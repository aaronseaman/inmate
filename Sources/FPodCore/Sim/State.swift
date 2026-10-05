import Foundation

public enum MoveMode: String, Codable { case walk, sneak, run }

public struct ItemStack: Codable, Hashable {
    public var id: ItemID
    public var qty: Int
    public var owner: NPCID?
    public init(_ id: ItemID, _ qty: Int = 1, owner: NPCID? = nil) { self.id = id; self.qty = qty; self.owner = owner }
}

public enum Slot: String, Codable, CaseIterable {
    case carried, pocket, sock, book
    public var title: String {
        switch self {
        case .carried: return "Carried"
        case .pocket: return "Waist pocket"
        case .sock: return "Sock"
        case .book: return "Hollow book"
        }
    }
    public var icon: Icon {
        switch self {
        case .carried: return .bag
        case .pocket: return .hand
        case .sock: return .hide
        case .book: return .book
        }
    }
}

public struct Inventory: Codable, Hashable {
    public var carried: [ItemStack] = []
    public var pocket: [ItemStack] = []
    public var sock: [ItemStack] = []
    public var book: [ItemStack] = []

    public static let carryCapacity = 6
    public static let pocketSlots = 2
    public static let sockSlots = 1
    public static let bookSlots = 1

    public func stacks(_ s: Slot) -> [ItemStack] {
        switch s {
        case .carried: return carried
        case .pocket: return pocket
        case .sock: return sock
        case .book: return book
        }
    }
    public mutating func set(_ s: Slot, _ v: [ItemStack]) {
        switch s {
        case .carried: carried = v
        case .pocket: pocket = v
        case .sock: sock = v
        case .book: book = v
        }
    }
    public var carriedBulk: Int { carried.reduce(0) { $0 + Items.def($1.id).size.bulk * $1.qty } }
    public func count(_ id: ItemID) -> Int {
        Slot.allCases.reduce(0) { acc, s in acc + stacks(s).filter { $0.id == id }.reduce(0) { $0 + $1.qty } }
    }
    public var all: [(Slot, ItemStack)] {
        var out: [(Slot, ItemStack)] = []
        for s in Slot.allCases { for st in stacks(s) { out.append((s, st)) } }
        return out
    }
    /// Max stack quantity inside a concealed slot.
    public static func slotMaxQty(_ s: Slot) -> Int {
        switch s {
        case .carried: return 99
        case .pocket: return 3
        case .sock: return 2
        case .book: return 2
        }
    }
    public static func slotMaxSize(_ s: Slot) -> ItemSize {
        switch s {
        case .carried: return .large
        case .pocket: return .small
        case .sock: return .tiny
        case .book: return .small
        }
    }
    public static func slotCount(_ s: Slot) -> Int {
        switch s {
        case .carried: return 99
        case .pocket: return pocketSlots
        case .sock: return sockSlots
        case .book: return bookSlots
        }
    }
}

public struct StashDef: Hashable {
    public let objectID: String
    public let title: String
    public let slots: Int
    public let maxSize: ItemSize
    /// Chance a targeted search finds the contents.
    public let discovery: Double
    /// Legal storage (lockers) is always opened in a cell search.
    public let legal: Bool
    public let needs: ItemID?
}

public struct LedgerEntry: Codable, Hashable {
    public var id: Int
    public var day: Int
    public var minute: Int
    public var delta: Int
    public var balance: Int
    public var reason: String
}

public struct Incident: Codable, Hashable {
    public var kind: IncidentKind
    public var day: Int
    public var minute: Int
    public var witness: NPCID?
    public var zone: String
    public var outcome: String
}

public enum QuestStatus: String, Codable { case inactive, active, done, failed }

public struct QuestProgress: Codable, Hashable {
    public var status: QuestStatus = .inactive
    public var stage: Int = 0
    public var startedDay: Int = 0
    public var finishedDay: Int = 0
}

public enum AIMode: String, Codable {
    case routine, notice, approach, question, investigate, search, pursue, escort, resume, scripted, inspect, count, follow
}

public struct NPCState: Codable {
    public var id: NPCID
    public var pos: Vec2
    public var heading: Double
    public var path: [Vec2] = []
    public var pathIndex: Int = 0
    public var goal: Vec2?
    public var goalFacing: Facing?
    public var postKey: String = ""
    public var patrolIndex: Int = 0
    public var waitTimer: Double = 0
    public var mode: AIMode = .routine
    public var modeTimer: Double = 0
    public var suspicion: Double = 0
    public var reactionDelay: Double = 0
    public var lastKnown: Vec2?
    public var sawPlayerEnterHide: String?
    public var inspectTarget: String?
    public var searchedSpots: [String] = []
    public var recognizedDisguise: Bool = false
    public var radioed: Bool = false
    public var present: Bool = true
    public var moving: Bool = false
    public var running: Bool = false
    public var bubble: [Icon] = []
    public var bubbleTimer: Double = 0
    public var bubbleCaption: String = ""
    public var animPhase: Double = 0
    public var stuckTimer: Double = 0
    public var repathTimer: Double = 0
    public var questionTimer: Double = 0
    public var questionReason: IncidentKind?
    public var followPlayer: Bool = false
    public var scriptedSpot: String?
    public var lastSeenTime: Double = 0
    public var reacting: Double = 0
    public var mumbleTimer: Double = 0
    public var failCount: Int = 0
    public var questionStart: Vec2?
    /// Pauses routine to wait for (or walk over to) the player who tapped them.
    public var attendTimer: Double = 0
    public var attendCome: Bool = false
    public var attendTotal: Double = 0
}

public struct PlayerState: Codable {
    public var pos: Vec2
    public var heading: Double = .pi / 2
    public var path: [Vec2] = []
    public var pathIndex: Int = 0
    public var mode: MoveMode = .walk
    public var sneakToggle: Bool = false
    public var runToggle: Bool = false
    public var runOnce: Bool = false
    public var moving: Bool = false
    public var hiddenIn: String?
    public var outfit: Outfit = .tanScrubs
    public var outfitCondition: Double = 100
    public var energy: Double = 80
    public var cell: Int = 3
    public var job: JobID?
    public var animPhase: Double = 0
    public var changing: Double = 0       // seconds remaining while changing
    public var changingTo: Outfit?
    public var actionTimer: Double = 0    // generic action progress (stealing, searching)
    public var escortedBy: NPCID?
    public var lastZone: String = "fpod.dayroom"
    public var lastDistrict: District = .fpod
    public var caughtImmunity: Double = 0 // seconds of reduced suspicion gain after recovery
    public var noiseTimer: Double = 0
    public var vehicle: Vehicle?
    public var hideReturn: Vec2?
}

public enum Vehicle: String, Codable, CaseIterable {
    case janitorCart, laundryCart, wheelchair, floorBuffer
    public var title: String {
        switch self {
        case .janitorCart: return "Janitor cart"
        case .laundryCart: return "Laundry cart"
        case .wheelchair: return "Wheelchair"
        case .floorBuffer: return "Floor buffer"
        }
    }
    public var speed: Double {
        switch self {
        case .janitorCart: return 1.9
        case .laundryCart: return 2.1
        case .wheelchair: return 3.2
        case .floorBuffer: return 3.6
        }
    }
    public var noise: Double {
        switch self {
        case .janitorCart: return 3.0
        case .laundryCart: return 3.5
        case .wheelchair: return 1.0
        case .floorBuffer: return 7.0
        }
    }
    public var icon: Icon {
        switch self {
        case .janitorCart: return .cart
        case .laundryCart: return .cart
        case .wheelchair: return .wheelchair
        case .floorBuffer: return .buffer
        }
    }
    public var extraBulk: Int {
        switch self {
        case .janitorCart: return 4
        case .laundryCart: return 8
        default: return 0
        }
    }
}

public struct Toast: Codable, Hashable {
    public var icon: Icon
    public var text: String
    public var time: Double
    public var danger: Bool = false
}

public struct GameState: Codable {
    public var version: Int = SaveSystem.currentVersion
    public var seed: UInt64
    public var rng: RNG
    public var day: Int = 1
    public var minute: Double = 350
    public var realTime: Double = 0
    public var player: PlayerState
    public var npcs: [NPCState] = []
    public var inventory = Inventory()
    public var stashes: [String: [ItemStack]] = [:]
    public var credits: Int = 0
    public var ledger: [LedgerEntry] = []
    public var ledgerCounter: Int = 0
    public var favors: [NPCID: Int] = [:]
    public var trust: Int = 0
    public var trustTierFloor: Int = 1
    public var trustGainedToday: Int = 0
    public var staffOpinion: [NPCID: Int] = [:]
    public var peerRep: [NPCID: Int] = [:]
    public var flags: Set<Flag> = []
    public var quests: [QuestID: QuestProgress] = [:]
    public var usedInteractions: Set<String> = []
    public var claimedRewards: Set<String> = []
    public var tradesToday: [String: Int] = [:]
    public var purchasesToday: Int = 0
    public var watch: WatchLevel = .green
    public var watchUntil: Double = 0          // absolute game minutes
    public var watchReason: String = ""
    public var watch72: Bool = false
    public var restrictions: [Restriction: Double] = [:]   // until absolute minute
    public var incidents: [Incident] = []
    public var missedCounts: [Int] = []
    public var countState: CountState = CountState()
    public var appointments: [Appointment] = []
    public var storyOverrides: [Int: [ScheduleBlock]] = [:]
    public var facilityAlert: Double = 0
    public var lockdown: Bool = false
    public var jobPerformance: [JobID: Double] = [:]
    public var shiftsWorked: [JobID: Int] = [:]
    public var shiftDoneKeys: Set<String> = []
    public var knownZones: Set<String> = []
    public var knownTrades: Set<String> = []
    public var docsRead: Set<DocID> = []
    public var docsOwned: Set<DocID> = []
    public var endingsSeen: Set<Ending> = []
    public var batteryDays: Int = 0
    public var mealsToday: Int = 0
    public var medPassResult: [Int: String] = [:]
    public var shakedownsDone: Set<Int> = []
    public var pendingChoices: [ChoiceID] = []
    public var stats: [String: Int] = [:]
    public var dayLog: [String] = []
    public var watchReviewProgress: Int = 0
    public var metStaff: Set<NPCID> = []
    public var outfitConditions: [Outfit: Double] = [:]
    /// Items held in the property room after a search (legal ones are claimable).
    public var confiscated: [ItemStack] = []
    public var lastSearch: [String] = []
    public var recovery: RecoveryTask?
    public var recoveryHints: [ItemID: String] = [:]
    // Fields added after save v1 are optional so older saves decode unchanged.
    /// Zones where unattended cameras recorded the player tonight.
    public var footage: [String]?
    /// Vehicle parked away from its bay (object id -> position).
    public var parkedVehicles: [String: Vec2]?
    public var bigOrderDay: Int?
    /// Yellow-watch room checks.
    public var watchCheck: WatchCheckState?
    /// Sale values of art-therapy drawings still held (other drawings have none).
    public var artValues: [Int]?

    public init(seed: UInt64, playerPos: Vec2) {
        self.seed = seed
        self.rng = RNG(seed: seed)
        self.player = PlayerState(pos: playerPos)
    }

    public var absMinute: Double { Double(day) * 1440 + minute }
}

public struct CountState: Codable, Hashable {
    public var activeDay: Int = 0
    public var activeStart: Int = 0
    public var warned: Bool = false
    public var resolved: Bool = false
    public var present: Bool = false
    public var lateLogged: Bool = false
}
