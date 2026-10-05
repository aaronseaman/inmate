import Foundation

public enum TargetRef: Hashable, Codable {
    case npc(NPCID)
    case object(String)
    case door(String)
}

public enum GameEvent {
    case talked(NPCID)
    case interacted(String)
    case itemGained(ItemID)
    case itemLost(ItemID)
    case zoneEntered(String)
    case blockStarted(Activity)
    case dayStarted(Int)
    case minigameDone(MinigameID, Double)
    case shiftDone(JobID, Double)
    case countCleared
    case countMissed
    case caught(IncidentKind)
    case flagSet(Flag)
    case traded(String)
    case docRead(DocID)
    case appointmentKept(String)
    case questStarted(QuestID)
}

public struct NoisePulse {
    public var pos: Vec2
    public var radius: Double
    public var age: Double
    public var danger: Bool
}

public struct Viewport: Equatable {
    public var size: Vec2
    public var safe: (top: Double, left: Double, bottom: Double, right: Double)
    public var scale: Double
    public init(size: Vec2, safeTop: Double = 0, safeLeft: Double = 0, safeBottom: Double = 0, safeRight: Double = 0, scale: Double = 2) {
        self.size = size
        self.safe = (safeTop, safeLeft, safeBottom, safeRight)
        self.scale = scale
    }
    public static func == (a: Viewport, b: Viewport) -> Bool {
        a.size == b.size && a.scale == b.scale && a.safe.top == b.safe.top && a.safe.left == b.safe.left
            && a.safe.bottom == b.safe.bottom && a.safe.right == b.safe.right
    }
    /// Usable rect inside safe areas.
    public var safeRect: Rect {
        Rect(safe.left, safe.top, size.x - safe.left - safe.right, size.y - safe.top - safe.bottom)
    }
}

/// The whole game. Platform layers call `update`, `tap`, `buildFrame` and drain
/// `audioCommands` / `hapticCommands`.
public final class Game {
    public let map: WorldMap
    public internal(set) var s: GameState
    public var settings: Settings
    public var viewport: Viewport
    public var ui = UIState()
    public internal(set) var audioCommands: [AudioCommand] = []
    public internal(set) var hapticCommands: [Haptic] = []
    public var saveRequested = false
    public var settingsChanged = false
    public var isDevBuild = false

    var events: [GameEvent] = []
    var doorOpen: [Double]
    var dynamicOpaque: [Bool]
    var npcIndex: [NPCID: Int] = [:]
    var perceptionTimer: Double = 0
    var aiTimer: Double = 0
    var vehicleBumpCooldown: Double = 0
    var noisePulses: [NoisePulse] = []
    var cameraSuspicion: [String: Double] = [:]
    var cameraLastKnown: Vec2?
    public internal(set) var transition: Transition?
    public internal(set) var minigame: MinigameSession?
    var lastBlock: Activity?
    var lastBlockDay: Int = 0
    var occupiedHides: Set<String> = []
    var hideSpotByObject: [String: HideSpotDef] = [:]
    var stashByObject: [String: StashDef] = [:]
    var conePolys: [NPCID: [Vec2]] = [:]
    var cameraPolys: [String: [Vec2]] = [:]
    var shakedownSummary: ([String], [ItemStack]) = ([], [])
    var pendingDoc: DocID?
    var callTarget: NPCID?
    var lastCallLines: [String] = []
    var bufferSeconds: Double = 0
    var escortTrail: [Vec2] = []
    var pendingRetarget: Double = 0
    var pendingRetries = 0

    public init(seed: UInt64 = 0xF0D1, settings: Settings = .default, viewport: Viewport = Viewport(size: Vec2(844, 390))) {
        map = WorldShared.map
        self.settings = settings
        self.viewport = viewport
        let start = map.spot("fpod.entry.in")?.pos ?? Vec2(24.5, 48.5)
        s = GameState(seed: seed, playerPos: start)
        doorOpen = [Double](repeating: 0, count: map.doors.count)
        dynamicOpaque = map.propOpaque
        commonInit()
        newGameSetup()
    }

    public init(state: GameState, settings: Settings = .default, viewport: Viewport = Viewport(size: Vec2(844, 390))) {
        map = WorldShared.map
        self.settings = settings
        self.viewport = viewport
        s = state
        doorOpen = [Double](repeating: 0, count: map.doors.count)
        dynamicOpaque = map.propOpaque
        commonInit()
        // Ensure NPC list matches cast (forward compatible saves).
        for id in NPCID.allCases where npcIndex[id] == nil {
            s.npcs.append(makeNPC(id))
        }
        rebuildNPCIndex()
        // Resume calmly after an interruption: no mid-chase restores, no lost restrictions.
        for i in s.npcs.indices {
            switch s.npcs[i].mode {
            case .pursue, .approach, .question, .investigate, .search, .inspect, .escort, .notice:
                s.npcs[i].mode = .resume
                s.npcs[i].suspicion = min(s.npcs[i].suspicion, 20)
                s.npcs[i].path = []
                s.npcs[i].postKey = ""
            default: break
            }
            s.npcs[i].attendTimer = 0
        }
        s.player.escortedBy = nil
        s.player.changing = 0
        s.player.path = []
        lastBlock = currentBlock.activity
        lastBlockDay = s.day
        ui.camera = s.player.pos
        refreshDoors(instant: true)
    }

    func commonInit() {
        for h in HideSpots.all { hideSpotByObject[h.objectID] = h }
        for st in Stashes.all { stashByObject[st.objectID] = st }
        ui.camera = s.player.pos
    }

    func newGameSetup() {
        s.npcs = NPCID.allCases.map { makeNPC($0) }
        rebuildNPCIndex()
        s.minute = 350
        s.player.cell = 3
        s.inventory.carried = [ItemStack(.snack, 1)]
        s.inventory.pocket = [ItemStack(.requestForm, 1)]
        s.stashes["fpod.cell3.locker"] = [ItemStack(.soap, 1), ItemStack(.book, 1)]
        s.stashes["fpod.cell5.locker"] = [ItemStack(.radio, 1, owner: .harlan), ItemStack(.cigarettes, 2, owner: .harlan)]
        s.stashes["fpod.cell1.locker"] = [ItemStack(.coffee, 3, owner: .dutch)]
        s.stashes["donation.box"] = [ItemStack(.brokenRadio, 1), ItemStack(.book, 1)]
        s.stashes["fpod.hamper"] = [ItemStack(.laundryWhites, 1)]
        s.stashes["donation.box", default: []].append(ItemStack(.visitorClothes, 1))
        Systems.restock(self)
        for id in Cast.staffIDs { s.staffOpinion[id] = 0 }
        for id in Cast.peerIDs { s.peerRep[id] = 0 }
        s.peerRep[.fitz] = 5
        s.knownZones = ["fpod.dayroom", "fpod.cell3", "fpod.entry", "corridor.main"]
        creditDelta(8, "Intake balance")
        // Intake morning: a short settle window, then a later first count.
        s.storyOverrides[1] = [ScheduleBlock(330, 370, .settle), ScheduleBlock(370, 390, .wakeCount), ScheduleBlock(390, 425, .medPass)]
        lastBlock = nil
        refreshDoors(instant: true)
        startQuest(.m01Intake)
        transition = Scenes.intake(self)
    }

    func makeNPC(_ id: NPCID) -> NPCState {
        let def = Cast.def(id)
        var pos = Vec2(147.5, 42.5)
        if let c = def.cell, let sp = map.spot("fpod.cell\(c).bunk\(def.bunk == 0 ? "A" : "B")") { pos = sp.pos }
        var n = NPCState(id: id, pos: pos, heading: .pi / 2)
        n.present = def.role == .peer
        n.animPhase = Double(stableHash(id.rawValue) % 100) / 100.0
        return n
    }

    func rebuildNPCIndex() {
        npcIndex = [:]
        for (i, n) in s.npcs.enumerated() { npcIndex[n.id] = i }
    }

    // MARK: Accessors

    public var currentBlock: ScheduleBlock { Schedule.block(day: s.day, minute: s.minute, overrides: s.storyOverrides[s.day] ?? []) }
    public var activity: Activity { currentBlock.activity }
    public var nextBlock: ScheduleBlock? { Schedule.nextBlock(day: s.day, minute: s.minute, overrides: s.storyOverrides[s.day] ?? []) }

    public func npc(_ id: NPCID) -> NPCState? { npcIndex[id].map { s.npcs[$0] } }
    /// Copy-modify-write so closures may read other game state without exclusivity conflicts.
    func withNPC(_ id: NPCID, _ body: (inout NPCState) -> Void) {
        guard let i = npcIndex[id] else { return }
        var n = s.npcs[i]
        body(&n)
        s.npcs[i] = n
    }

    public func has(_ f: Flag) -> Bool { s.flags.contains(f) }
    public var playerZone: ZoneDef? { map.zone(at: s.player.pos) ?? map.zone(id: s.player.lastZone) }
    public var playerDistrict: District { playerZone?.district ?? s.player.lastDistrict }
    public var trustTier: Int { max(s.trustTierFloor, Game.tier(for: s.trust)) }
    public static let tierThresholds = [0, 40, 110, 210, 330]
    public static func tier(for trust: Int) -> Int {
        var t = 1
        for (i, th) in tierThresholds.enumerated() where trust >= th { t = i + 1 }
        return t
    }
    public var isPaused: Bool { ui.modal != nil || transition != nil || minigame != nil }

    // MARK: Main loop

    public func update(dt rawDt: Double) {
        let dt = min(max(rawDt, 0), 0.1)
        ui.realTime += dt
        s.realTime += dt
        updateToasts(dt)
        if transition != nil {
            updateTransition(dt)
            updateCamera(dt)
            return
        }
        if let mg = minigame {
            mg.update(dt: dt)
            playMinigameCues(mg)
            if mg.finishedAndAcknowledged { finishMinigame() }
            return
        }
        presentPendingChoices()
        if ui.modal != nil {
            updateCamera(dt)
            return
        }
        advanceClock(dt)
        updateSchedule()
        updatePlayer(dt)
        updateVehicleCollisions(dt)
        updateRiders(dt)
        aiTimer += dt
        updateNPCs(dt)
        refreshDoors(instant: false, dt: dt)
        perceptionTimer += dt
        if perceptionTimer >= 0.1 {
            let step = perceptionTimer
            perceptionTimer = 0
            updatePerception(step)
        }
        updateNoisePulses(dt)
        processEvents()
        updateCamera(dt)
        updateInteractTarget()
    }

    func advanceClock(_ dt: Double) {
        s.minute += dt * settings.clockRate
        if s.minute >= 1440 { s.minute = 1439.9 }
        decayTimers(dt)
    }

    func decayTimers(_ dt: Double) {
        // Energy drifts down while awake (~40 points across a waking day).
        s.player.energy = max(0, s.player.energy - dt * settings.clockRate * 0.042)
        if s.player.caughtImmunity > 0 { s.player.caughtImmunity = max(0, s.player.caughtImmunity - dt) }
        s.facilityAlert = max(0, s.facilityAlert - dt * 0.02)
    }

    // MARK: Events

    func emit(_ e: GameEvent) { events.append(e) }

    func processEvents() {
        var guardCount = 0
        while !events.isEmpty && guardCount < 50 {
            guardCount += 1
            let batch = events
            events = []
            for e in batch { handleEvent(e) }
            checkQuests()
        }
        checkQuests()
    }

    func handleEvent(_ e: GameEvent) {
        if case .zoneEntered(let z) = e, !s.knownZones.contains(z) { s.knownZones.insert(z) }
        Story.onEvent(self, e)
    }

    // MARK: Output

    func sound(_ sfx: SFX, at: Vec2? = nil, volume: Double = 1) {
        var pan = 0.0, vol = volume
        if let p = at {
            let d = p - ui.camera
            pan = clamp(d.x / 14, -1, 1)
            vol *= clamp(1.2 - d.length / 18, 0, 1)
            if vol <= 0.01 { return }
        }
        audioCommands.append(.sfx(sfx, volume: vol, pan: pan, pitch: 1))
    }

    func mumble(_ npc: NPCID) {
        let def = Cast.def(npc)
        guard let n = self.npc(npc) else { return }
        let d = n.pos - ui.camera
        let vol = clamp(1.2 - d.length / 16, 0, 1)
        if vol > 0.02 { audioCommands.append(.mumble(pitch: def.pitch, volume: vol, pan: clamp(d.x / 14, -1, 1), seed: Int(s.realTime * 10) % 97)) }
    }

    func haptic(_ h: Haptic) { if settings.haptics { hapticCommands.append(h) } }

    public func drainAudio() -> [AudioCommand] { defer { audioCommands = [] }; return audioCommands }
    public func drainHaptics() -> [Haptic] { defer { hapticCommands = [] }; return hapticCommands }

    func toast(_ icon: Icon, _ text: String, danger: Bool = false) {
        ui.toasts.append(Toast(icon: icon, text: text, time: 0, danger: danger))
        if ui.toasts.count > 3 { ui.toasts.removeFirst(ui.toasts.count - 3) }
    }

    func updateToasts(_ dt: Double) {
        for i in ui.toasts.indices { ui.toasts[i].time += dt }
        ui.toasts.removeAll { $0.time > 3.6 }
    }

    func log(_ line: String) {
        s.dayLog.append("D\(s.day) \(Schedule.clockString(s.minute)) \(line)")
        if s.dayLog.count > 200 { s.dayLog.removeFirst(s.dayLog.count - 200) }
    }

    func stat(_ key: String, _ add: Int = 1) { s.stats[key, default: 0] += add }
}

/// The campus map is immutable and shared across games.
public enum WorldShared {
    public static let map: WorldMap = Campus.build()
}
