import Foundation

/// Shared contract: enter, explain controls, play, score, reward once, exit safely.
public protocol Minigame: AnyObject {
    var id: MinigameID { get }
    var title: String { get }
    var icon: Icon { get }
    /// Control explanations shown before play.
    var controls: [(Icon, String)] { get }
    var isOver: Bool { get }
    /// 0...1
    var score: Double { get }
    var summary: String { get }
    func update(_ dt: Double)
    func tap(_ p: Vec2, canvas: Rect)
    func render(_ ui: inout UIBuilder, canvas: Rect, time: Double)
    /// Sound cues produced since the last call (played by the host, mapped to haptics).
    func drainCues() -> [SFX]
    /// A competent player's next tap (tests, attract mode). nil = wait.
    func botTap(canvas: Rect) -> Vec2?
    /// Played against an opponent: a competent player wins often, not always.
    var isContest: Bool { get }
}

extension Minigame {
    public func drainCues() -> [SFX] { [] }
    public func botTap(canvas: Rect) -> Vec2? { nil }
    public var isContest: Bool { false }
}

public struct MinigameConfig {
    public var seed: UInt64
    public var difficulty: Difficulty
    public var stakes: Int
    public var level: Int
    public init(seed: UInt64, difficulty: Difficulty, stakes: Int = 0, level: Int = 1) {
        self.seed = seed; self.difficulty = difficulty; self.stakes = stakes; self.level = level
    }
}

public enum MinigameOutcomeKind {
    case script(onPass: [Effect], onFail: [Effect])
    case shift(JobID)
}

public final class MinigameSession {
    public enum Phase { case intro, playing, result }
    public let game: Minigame
    public internal(set) var phase: Phase = .intro
    public let key: String
    public let pass: Double
    let outcome: MinigameOutcomeKind
    let npc: NPCID?
    public internal(set) var finishedAndAcknowledged = false
    public internal(set) var applied = false
    public internal(set) var assisted = false
    public internal(set) var quit = false
    var resultCuePlayed = false
    public var rewardLines: [String] = []
    var time: Double = 0
    public let alreadyClaimed: Bool

    init(game: Minigame, key: String, pass: Double, outcome: MinigameOutcomeKind, npc: NPCID?, alreadyClaimed: Bool) {
        self.game = game; self.key = key; self.pass = pass; self.outcome = outcome; self.npc = npc; self.alreadyClaimed = alreadyClaimed
    }

    public var passed: Bool { !quit && (assisted || game.score >= pass) }
    public var finalScore: Double { quit ? 0 : (assisted ? max(pass, min(game.score, pass)) : game.score) }

    public func update(dt: Double) {
        time += dt
        if phase == .playing {
            game.update(dt)
            if game.isOver { phase = .result }
        }
    }

    func start() { phase = .playing; time = 0 }
    func assist() { assisted = true; phase = .result }
    func abandon() { quit = true; phase = .result }
    func acknowledge() { finishedAndAcknowledged = true }

    public var stars: Int {
        let sc = finalScore
        if quit { return 0 }
        if sc >= 0.85 { return 3 }
        if sc >= 0.6 { return 2 }
        if sc >= 0.3 { return 1 }
        return 0
    }
}

public enum Minigames {
    public static func make(_ id: MinigameID, _ cfg: MinigameConfig) -> Minigame {
        switch id {
        case .mop: return MopGame(cfg)
        default: return MinigameRegistry.factory[id]?(cfg) ?? MopGame(cfg)
        }
    }
    public static func isImplemented(_ id: MinigameID) -> Bool { id == .mop || MinigameRegistry.factory[id] != nil }
}

/// Additional minigames register here (keeps `make` simple).
public enum MinigameRegistry {
    public static var factory: [MinigameID: (MinigameConfig) -> Minigame] {
        var f: [MinigameID: (MinigameConfig) -> Minigame] = [:]
        for (k, v) in extraFactories { f[k] = v }
        return f
    }
    static var extraFactories: [MinigameID: (MinigameConfig) -> Minigame] = MinigameCatalog.all
}

// MARK: - Game integration

extension Game {
    func startMinigame(_ id: MinigameID, key: String, pass: Double, onPass: [Effect], onFail: [Effect], npc: NPCID?) {
        guard minigame == nil else { return }
        if let warn = countGuardMessage() { toast(.count, warn, danger: true); return }
        let cfg = MinigameConfig(seed: s.seed ^ stableHash("\(key).\(s.day).\(Int(s.minute))"), difficulty: settings.difficulty)
        let g = Minigames.make(id, cfg)
        minigame = MinigameSession(game: g, key: key, pass: pass, outcome: .script(onPass: onPass, onFail: onFail), npc: npc,
                                   alreadyClaimed: s.claimedRewards.contains(key))
        stopWalking()
        audioCommands.append(.duck(0.5))
        sound(.paper)
    }

    func startShift(_ job: JobID) {
        guard minigame == nil else { return }
        if let warn = countGuardMessage() { toast(.count, warn, danger: true); return }
        let key = "shift.d\(s.day).\(activity.rawValue)"
        let def = Jobs.def(job)
        let level = 1 + min(3, (s.shiftsWorked[job] ?? 0) / 3)
        let cfg = MinigameConfig(seed: s.seed ^ stableHash(key), difficulty: settings.difficulty, level: level)
        minigame = MinigameSession(game: Minigames.make(def.minigame, cfg), key: key, pass: 0.0, outcome: .shift(job), npc: def.supervisor,
                                   alreadyClaimed: s.claimedRewards.contains(key))
        stopWalking()
        audioCommands.append(.duck(0.5))
        sound(.paper)
    }

    /// Minigames pause the clock, but never start them right before count.
    func countGuardMessage() -> String? {
        let m = s.minute
        for c in countStarts where m >= c - 4 && m < c + countGraceMinutes && !playerInOwnCell() {
            return "Count is about to start — go to your cell first"
        }
        return nil
    }

    public func minigameAction(_ a: UIAction) {
        guard let mg = minigame else { return }
        switch a {
        case .minigameStart: if mg.phase == .intro { mg.start(); sound(.confirm) }
        case .minigameAssist: if mg.phase == .intro && settings.assistMinigames { mg.assist() }
        case .minigameQuit:
            if mg.phase == .intro { mg.abandon(); mg.acknowledge() } else if mg.phase == .playing { mg.abandon() }
        case .minigameContinue: if mg.phase == .result { mg.acknowledge() }
        default: break
        }
    }

    func finishMinigame() {
        guard let mg = minigame else { return }
        minigame = nil
        audioCommands.append(.duck(1))
        defer { processEvents(); saveRequested = true }
        if mg.quit {
            toast(.back, "Left without finishing — no reward")
            return
        }
        stat("minigames")
        emit(.minigameDone(mg.game.id, mg.finalScore))
        applyMinigameOutcome(mg)
    }

    func applyMinigameOutcome(_ mg: MinigameSession) {
        guard !mg.applied else { return }
        mg.applied = true
        switch mg.outcome {
        case .script(let onPass, let onFail):
            if mg.passed {
                if s.claimedRewards.contains(mg.key) {
                    toast(.check, "Done (already rewarded)")
                } else {
                    s.claimedRewards.insert(mg.key)
                    apply(onPass, npc: mg.npc)
                }
            } else {
                apply(onFail, npc: mg.npc)
            }
        case .shift(let job):
            let def = Jobs.def(job)
            let blockKey = "d\(s.day).\(activity.rawValue)"
            s.shiftDoneKeys.insert(blockKey)
            let score = mg.finalScore
            let prev = s.jobPerformance[job] ?? 0.6
            s.jobPerformance[job] = prev * 0.7 + score * 0.3
            s.shiftsWorked[job, default: 0] += 1
            let pay = shiftPay(job, score: score)
            if claimReward(mg.key, RewardSpec(credits: pay, trust: score >= 0.5 ? 2 : 1), reason: "\(def.title) shift") {
                toast(.coin, "+\(pay) credits · \(def.title) shift")
            }
            s.player.energy = max(0, s.player.energy - 8)
            adjustStaff(def.supervisor, score >= 0.6 ? 2 : 0)
            emit(.shiftDone(job, score))
            log("Shift \(def.title) score \(Int(score * 100))%")
        }
    }
}

extension Game {
    /// Shift pay: the job's range scaled by score, plus a senior bonus from trust tier 3.
    public func shiftPay(_ job: JobID, score: Double) -> Int {
        let def = Jobs.def(job)
        let base = Int((Double(def.payMin) + Double(def.payMax - def.payMin) * score).rounded())
        return base + (trustTier >= 3 ? 2 : 0)
    }
}
