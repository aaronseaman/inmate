import Foundation

public enum WatchLevel: Int, Codable, Comparable, CaseIterable {
    case green = 0, yellow = 1, red = 2
    public static func < (a: WatchLevel, b: WatchLevel) -> Bool { a.rawValue < b.rawValue }
    public var title: String {
        switch self {
        case .green: return "Green — routine"
        case .yellow: return "Yellow — closer rounds"
        case .red: return "Red — constant observation"
        }
    }
    public var short: String {
        switch self {
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .red: return "Red"
        }
    }
    public var color: RGBA {
        switch self {
        case .green: return Palette.statusGreen
        case .yellow: return Palette.statusYellow
        case .red: return Palette.statusRed
        }
    }
}

public enum IncidentKind: String, Codable, CaseIterable {
    case restrictedArea, missedCount, lateCount, theft, contraband, dangerousItem, brokenDisguise
    case fleeing, assault, hidingFromStaff, lockdownRunning, curfew, missedShift, changingWatched
    case equipmentCollision

    public var title: String {
        switch self {
        case .restrictedArea: return "Out of bounds"
        case .missedCount: return "Missed count"
        case .lateCount: return "Late to count"
        case .theft: return "Theft witnessed"
        case .contraband: return "Contraband found"
        case .dangerousItem: return "Dangerous item found"
        case .brokenDisguise: return "Unauthorized clothing"
        case .fleeing: return "Ran from staff"
        case .assault: return "Assault witnessed"
        case .hidingFromStaff: return "Hiding from staff"
        case .lockdownRunning: return "Running during lockdown"
        case .curfew: return "Out after lights out"
        case .missedShift: return "Missed work shift"
        case .changingWatched: return "Changing clothes in view"
        case .equipmentCollision: return "Equipment collision"
        }
    }
    /// 0 minor ... 3 severe.
    public var severity: Int {
        switch self {
        case .lateCount, .missedShift: return 0
        case .restrictedArea, .curfew, .changingWatched, .hidingFromStaff, .equipmentCollision: return 1
        case .missedCount, .theft, .contraband, .brokenDisguise, .fleeing, .lockdownRunning: return 2
        case .dangerousItem, .assault: return 3
        }
    }
    public var icon: Icon {
        switch self {
        case .restrictedArea: return .lock
        case .missedCount, .lateCount: return .count
        case .theft: return .hand
        case .contraband, .dangerousItem: return .search
        case .brokenDisguise, .changingWatched: return .shirt
        case .fleeing, .lockdownRunning: return .run
        case .assault: return .exclaim
        case .hidingFromStaff: return .hide
        case .curfew: return .moon
        case .missedShift: return .work
        case .equipmentCollision: return .buffer
        }
    }
}

public enum DocID: String, Codable, CaseIterable {
    case chart, chartAnnotated, docket, transportLog, lawyerLetter, sisterLetter, handbook, privilegeAgreement
    case grievanceCopy, witnessTheo, reviewNotice, dischargePlan, incidentReport, watchOrder, jobBoard, epilogueRelease
    case epilogueAdvocacy, epilogueEscape, restraintAftermath, seclusionAftermath, intakeSheet, medInfo, phoneList
}

/// What an interaction attaches to.
public enum Target: Hashable {
    case npc(NPCID)
    case object(String)
    case kind(ObjKind)
}

public indirect enum Cond {
    case always, never
    case flag(Flag), notFlag(Flag)
    case has(ItemID, Int)
    case hasAny([ItemID])
    case credits(Int)
    case trustTier(Int)
    case peer(NPCID, Int)
    case staff(NPCID, Int)
    case favor(NPCID, Int)
    case activity([Activity])
    case minuteBetween(Int, Int)
    case dayAtLeast(Int)
    case weekend
    case questActive(QuestID)
    case questStage(QuestID, Int)
    case questStageAtLeast(QuestID, Int)
    case questDone(QuestID)
    case questNotStarted(QuestID)
    case questAvailable(QuestID)
    case job(JobID)
    case noJob
    case outfit(Outfit)
    case watchAtMost(WatchLevel)
    case zone(String)
    case unobserved
    case shiftDone
    case vehicle(Vehicle?)
    case betting
    case watch72
    case watchReviewReady
    case npcHere(NPCID)
    case dailyOnce(String)
    case countFlags([Flag], Int)
    case hasOwned(ItemID, NPCID)
    case stat(String, Int)
    case hiddenIn(String)
    case inOwnCell
    case docRead(DocID)
    case hasJob
    case shiftsWorked(Int)
    case all([Cond]), any([Cond]), not(Cond)

    public static func has(_ i: ItemID) -> Cond { .has(i, 1) }
}

public struct RewardSpec {
    public var credits: Int
    public var trust: Int
    public var items: [(ItemID, Int)]
    public init(credits: Int = 0, trust: Int = 0, items: [(ItemID, Int)] = []) {
        self.credits = credits; self.trust = trust; self.items = items
    }
}

public indirect enum Effect {
    case set(Flag), clear(Flag)
    case give(ItemID, Int), take(ItemID, Int)
    case credits(Int, String)
    case trust(Int, String)
    case staff(NPCID, Int), peer(NPCID, Int), favor(NPCID, Int)
    case startQuest(QuestID), stage(QuestID, Int), completeQuest(QuestID), failQuest(QuestID)
    /// Plays a minigame; `key` makes the reward claimable once.
    case minigame(MinigameID, key: String, pass: Double, onPass: [Effect], onFail: [Effect])
    case doc(DocID)
    case bubble(NPCID, [Icon])
    case toast(Icon, String)
    case caption(String)
    case setJob(JobID?)
    case watch(WatchLevel, hours: Int, reason: String)
    case watch72(String)
    case incident(IncidentKind, witness: NPCID?)
    case teleport(String)
    case advanceMinutes(Int)
    case scene(SceneID)
    case trade(String)
    case sound(SFX)
    case appointment(id: String, dayOffset: Int, start: Int, end: Int, title: String, icon: Icon, spot: String, npc: NPCID?, quest: QuestID?)
    case wear(Outfit)
    case energy(Double)
    case condition(Double)
    case reward(key: String, RewardSpec)
    case restrict(Restriction, hours: Int)
    case lockdown(Bool)
    case npcGoto(NPCID, String)
    case npcFollowPlayer(NPCID, Bool)
    case shakedown(cell: Bool)
    case ending(Ending)
    case savePreFinale
    case ifThen(Cond, [Effect], [Effect])
    case openCommissary
    case openStash(String)
    case cellAssign(Int)
    case music(MusicMood?)
    case reviewWatch
    /// Lowers (never raises) watch to `level` for `hours` (0 = until cleared).
    case lowerWatch(WatchLevel, hours: Int)
    case choice(ChoiceID)
    case keepAppointment(String)
    case vehicle(Vehicle?)
    /// Eat this meal (once per meal block).
    case meal
    /// Marks a per-day key used (pairs with Cond.dailyOnce).
    case markDaily(String)
    /// Places a phone call (authored scene + story hook).
    case call(NPCID)
    /// Brings an offsite visitor to a spot (empty spot = they leave).
    case visitor(NPCID, String)
    /// Returns an owned item to its owner (no theft).
    case returnOwned(ItemID, NPCID)
    /// Places an item in a world container (authored setup).
    case putInStash(String, ItemID, Int)
    /// Concealed ride (laundry cart): little control, little view, some risk.
    case concealedRide(to: String, pusher: NPCID)
}

public enum Restriction: String, Codable, CaseIterable {
    case noYard, noCommissary, noPhone, noVisits, noJob, escortOnly
    public var title: String {
        switch self {
        case .noYard: return "No yard"
        case .noCommissary: return "No commissary"
        case .noPhone: return "No phone"
        case .noVisits: return "No visits"
        case .noJob: return "Job suspended"
        case .escortOnly: return "Escort only"
        }
    }
}

public enum Ending: String, Codable, CaseIterable {
    case release, advocacy, escape
    public var title: String {
        switch self {
        case .release: return "Conditional Release"
        case .advocacy: return "A Better Placement"
        case .escape: return "Through the Trees"
        }
    }
}

public enum MusicMood: String, Codable, CaseIterable {
    case day, night, search, tense, quiet, finale
}

public enum SFX: String, Codable, CaseIterable {
    case tap, confirm, cancel, buzzer, chime, keys, door, doorLock, cartWheels, tvMumble, laundry, step, stepSoft, stepRun
    case pickup, drop, coin, alert, question, caught, paper, whistle, mumble, hatch, error, success, fail, minigameTick, thud, splash, swish, clank, sleep
}

public enum SceneID: String, Codable, CaseIterable {
    case intake, sleep, seclusion, restraint, search, medPass, phoneCall, lawyerVisit, sisterVisit, reviewHearing
    case advocacyMeeting, escapeStart, endingRelease, endingAdvocacy, endingEscape, watch72Review, lockdown, shakedown
}

public enum ChoiceID: String, Codable, CaseIterable {
    case medPass, firstAlly, mouseErrand, theoDecision, hoochDecision, weaponDecision, uniformDecision, reedDecision
    case adaDecision, radioRoute, recordsRoute, cellmateRoute, finale
    case watchReview, medTalk
    case compareDocs, recordsHonesty, courtQuiz, harlanDemand, bennyDice, kenjiConsent, contrabandPhone, strickWitness
    case jobKitchen, jobLaundry, jobJanitorial, jobLibrary, jobInfirmary, jobWorkshop, jobGrounds
}

/// A tappable option on a person or object.
public struct InteractionDef {
    public let id: String
    public let target: Target
    public let icon: Icon
    public let caption: String
    public let when: Cond
    public let effects: [Effect]
    /// Shown with a danger accent; never auto-executed.
    public let risky: Bool
    /// If a staff member witnesses this act, it is this incident.
    public let witnessed: IncidentKind?
    public let once: Bool
    /// NPC reply pictograms (mumble).
    public let reply: [Icon]
    public let priority: Int

    public init(_ id: String, _ target: Target, _ icon: Icon, _ caption: String, when: Cond = .always, risky: Bool = false,
                witnessed: IncidentKind? = nil, once: Bool = false, reply: [Icon] = [], priority: Int = 0, _ effects: [Effect]) {
        self.id = id; self.target = target; self.icon = icon; self.caption = caption; self.when = when
        self.effects = effects; self.risky = risky; self.witnessed = witnessed; self.once = once
        self.reply = reply; self.priority = priority
    }
}

public struct StageDef {
    public let objective: String
    public let icon: Icon
    /// Marker target for the map/HUD arrow.
    public let marker: Marker?
    /// Auto-advance when this holds.
    public let completeWhen: Cond?
    public let onComplete: [Effect]
    /// Alternate approaches shown in the journal.
    public let approaches: [String]
    /// Optional recovery hint shown when the stage's critical item is lost.
    public let recovery: String?

    public init(_ objective: String, icon: Icon, marker: Marker? = nil, completeWhen: Cond? = nil, onComplete: [Effect] = [],
                approaches: [String] = [], recovery: String? = nil) {
        self.objective = objective; self.icon = icon; self.marker = marker; self.completeWhen = completeWhen
        self.onComplete = onComplete; self.approaches = approaches; self.recovery = recovery
    }
}

public enum Marker: Hashable {
    case npc(NPCID)
    case object(String)
    case spot(String)
    case zone(String)
}

public enum QuestKind: String, Codable { case main, side }

public struct QuestDef {
    public let id: QuestID
    public let kind: QuestKind
    public let title: String
    public let icon: Icon
    public let giver: NPCID?
    public let location: String
    public let summary: String
    /// Becomes available (auto-starts if `autoStart`) when this holds.
    public let prerequisite: Cond
    public let autoStart: Bool
    public let stages: [StageDef]
    public let rewardText: String
    public let worldChange: String
    public let failure: String

    public init(_ id: QuestID, _ kind: QuestKind, _ title: String, icon: Icon, giver: NPCID?, location: String, summary: String,
                prerequisite: Cond, autoStart: Bool = false, stages: [StageDef], reward: String, worldChange: String, failure: String) {
        self.id = id; self.kind = kind; self.title = title; self.icon = icon; self.giver = giver; self.location = location
        self.summary = summary; self.prerequisite = prerequisite; self.autoStart = autoStart; self.stages = stages
        self.rewardText = reward; self.worldChange = worldChange; self.failure = failure
    }
}

/// Fixed-quote barter offer. Quotes are frozen when the trade card opens.
public struct TradeDef {
    public let id: String
    public let npc: NPCID
    public let give: [(ItemID, Int)]     // player gives
    public let get: [(ItemID, Int)]      // player receives
    public let credits: Int              // >0 player pays credits (commissary-style), <0 player receives
    public let when: Cond
    public let dailyLimit: Int
    public let favor: Int                // favor gained with npc
    public init(_ id: String, _ npc: NPCID, give: [(ItemID, Int)], get: [(ItemID, Int)], credits: Int = 0, when: Cond = .always,
                dailyLimit: Int = 2, favor: Int = 0) {
        self.id = id; self.npc = npc; self.give = give; self.get = get; self.credits = credits; self.when = when
        self.dailyLimit = dailyLimit; self.favor = favor
    }
}
