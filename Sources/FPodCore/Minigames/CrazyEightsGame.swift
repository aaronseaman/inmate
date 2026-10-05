import Foundation

/// Crazy eights at card night. Match the suit or the rank on the pile; eights are wild
/// (you name the suit). Can't play? Draw — up to three. First to empty their hand wins.
public final class CrazyEightsGame: MinigameBase, Minigame {
    public let id = MinigameID.crazyEights
    public let title = "Crazy eights"
    public let icon = Icon.cards
    public var isContest: Bool { true }
    public var controls: [(Icon, String)] {
        [(.cards, "Match the suit or the rank on the pile"), (.star, "Eights are wild — then pick a suit"),
         (.box, "Nothing to play? Draw (up to three)"), (.people, "First to empty their hand wins")]
    }

    public struct Card: Equatable { let rank: Int; let suit: Int }
    public enum Outcome { case win, loss, draw }

    var hand: [Card] = []
    var opp: [Card] = []
    var deck: [Card] = []
    var pile: [Card] = []
    var suit = 0
    var playerTurn = true
    var drawnThisTurn = 0
    var choosingSuit = false
    var oppDelay: Double = 0
    var turnTimer: Double
    let turnLimit: Double
    var turns = 0
    let turnCap = 60
    var outcome: Outcome?
    var shake: (Int, Double)?
    let sloppy: Double

    public init(_ cfg: MinigameConfig) {
        turnLimit = 20 * cfg.difficulty.window
        turnTimer = turnLimit
        sloppy = cfg.difficulty == .sharp ? 0.05 : (cfg.difficulty == .standard ? 0.4 : 0.6)
        super.init(cfg, salt: "eights")
        for s in 0..<4 { for r in 1...13 { deck.append(Card(rank: r, suit: s)) } }
        rng.shuffle(&deck)
        hand = Array(deck.suffix(7)); deck.removeLast(7)
        opp = Array(deck.suffix(7)); deck.removeLast(7)
        var start = deck.removeLast()
        while start.rank == 8 { deck.insert(start, at: 0); start = deck.removeLast() }
        pile = [start]
        suit = start.suit
    }

    var top: Card { pile.last! }
    func playable(_ c: Card) -> Bool { c.rank == 8 || c.suit == suit || c.rank == top.rank }

    public var score: Double {
        switch outcome {
        case .win?: return clamp(0.78 + 0.22 * Double(opp.count) / 6, 0, 1)
        case .draw?: return 0.5
        case .loss?: return clamp(0.25 * (1 - Double(hand.count) / 10), 0, 0.25)
        case nil: return 0
        }
    }

    public var summary: String {
        switch outcome {
        case .win?: return "You went out first — Dutch holds \(opp.count)"
        case .loss?: return "Dutch went out — you held \(hand.count)"
        case .draw?: return "Card night ran late: even hands"
        case nil: return "Unfinished"
        }
    }

    static func rankText(_ r: Int) -> String { r == 1 ? "A" : (r == 11 ? "J" : (r == 12 ? "Q" : (r == 13 ? "K" : "\(r)"))) }
    static let suitNames = ["spades", "hearts", "diamonds", "clubs"]

    func finish(_ o: Outcome) { outcome = o; isOver = true; cue(o == .win ? .success : (o == .draw ? .confirm : .fail)) }

    func drawCard() -> Card? {
        if deck.isEmpty {
            guard pile.count > 1 else { return nil }
            let keep = pile.removeLast()
            deck = pile
            rng.shuffle(&deck)
            pile = [keep]
        }
        return deck.popLast()
    }

    func endTurn(byPlayer: Bool) {
        turns += 1
        if byPlayer && hand.isEmpty { finish(.win); return }
        if !byPlayer && opp.isEmpty { finish(.loss); return }
        if turns >= turnCap { finish(hand.count < opp.count ? .win : (hand.count > opp.count ? .loss : .draw)); return }
        playerTurn = !byPlayer
        drawnThisTurn = 0
        choosingSuit = false
        if playerTurn { turnTimer = turnLimit } else { oppDelay = 0.8 }
    }

    func mostHeldSuit(_ cards: [Card]) -> Int {
        (0..<4).max { a, b in cards.filter { $0.suit == a && $0.rank != 8 }.count < cards.filter { $0.suit == b && $0.rank != 8 }.count } ?? 0
    }

    func opponentMove() {
        var draws = 0
        while true {
            let options = opp.indices.filter { playable(opp[$0]) }
            if !options.isEmpty {
                let plain = options.filter { opp[$0].rank != 8 }
                let held = mostHeldSuit(opp)
                func value(_ i: Int) -> Int { (opp[i].suit == held ? 20 : 0) + opp[i].rank }
                var pick = plain.max { value($0) < value($1) } ?? options[0]
                if rng.chance(sloppy), let r = rng.pick(options) { pick = r }
                let c = opp.remove(at: pick)
                pile.append(c)
                suit = c.rank == 8 ? mostHeldSuit(opp) : c.suit
                cue(.paper)
                endTurn(byPlayer: false)
                return
            }
            if draws >= 3 { endTurn(byPlayer: false); return }
            guard let c = drawCard() else { endTurn(byPlayer: false); return }
            opp.append(c)
            draws += 1
        }
    }

    public func update(_ dt: Double) {
        guard !isOver else { return }
        elapsed += dt
        if let s = shake { shake = s.1 - dt > 0 ? (s.0, s.1 - dt) : nil }
        if playerTurn {
            turnTimer -= dt
            if turnTimer <= 0 {
                // Sat out: draw one and pass (an eight left mid-choice names the current suit).
                if choosingSuit { choosingSuit = false; endTurn(byPlayer: true); return }
                if let c = drawCard() { hand.append(c) }
                cue(.error)
                endTurn(byPlayer: true)
            }
        } else {
            oppDelay -= dt
            if oppDelay <= 0 { opponentMove() }
        }
    }

    var canPlay: Bool { hand.contains { playable($0) } }

    // MARK: Layout

    struct Layout { var hand: [Rect]; var pile: Rect; var deck: Rect; var pass: Rect; var suits: [Rect] }

    func layout(_ c: Rect) -> Layout {
        let n = max(1, hand.count)
        let cw = min(54, (c.w - 40) / Double(n) - 6)
        let ch = cw * 1.4
        let total = Double(n) * cw + Double(n - 1) * 6
        let x0 = c.midX - total / 2
        let hy = c.maxY - ch - 6
        let handR = (0..<hand.count).map { Rect(x0 + Double($0) * (cw + 6), hy, cw, ch) }
        let pile = Rect(c.midX + 10, c.y + 50, 60, 84)
        let deck = Rect(c.midX - 80, c.y + 50, 60, 84)
        let pass = Rect(c.midX + 110, c.y + 70, 120, 44)
        let suits = (0..<4).map { Rect(c.midX - 140 + Double($0) * 72, c.y + 52, 60, 60) }
        return Layout(hand: handR, pile: pile, deck: deck, pass: pass, suits: suits)
    }

    public func tap(_ p: Vec2, canvas: Rect) {
        guard !isOver, playerTurn else { return }
        let L = layout(canvas)
        if choosingSuit {
            if let s = L.suits.firstIndex(where: { $0.contains(p) }) { suit = s; cue(.confirm); endTurn(byPlayer: true) }
            return
        }
        if let i = L.hand.firstIndex(where: { $0.contains(p) }) {
            let c = hand[i]
            guard playable(c) else { shake = (i, 0.3); cue(.error); return }
            hand.remove(at: i)
            pile.append(c)
            cue(.paper)
            if c.rank == 8 && !hand.isEmpty { choosingSuit = true; return }
            suit = c.suit
            endTurn(byPlayer: true)
            return
        }
        if L.deck.insetBy(-6).contains(p) && !canPlay && drawnThisTurn < 3 {
            if let c = drawCard() { hand.append(c); drawnThisTurn += 1; cue(.pickup) }
            return
        }
        if UIBuilder.touchTarget(L.pass).contains(p) && !canPlay && (drawnThisTurn >= 3 || deck.isEmpty && pile.count <= 1) {
            endTurn(byPlayer: true)
        }
    }

    /// Bot: plain cards first (current suit, highest rank), eights last, then draw, then pass.
    public func botTap(canvas: Rect) -> Vec2? {
        guard playerTurn, !isOver, elapsed > 0.3 else { return nil }
        let L = layout(canvas)
        if choosingSuit { return L.suits[mostHeldSuit(hand)].center }
        let options = hand.indices.filter { playable(hand[$0]) }
        let plain = options.filter { hand[$0].rank != 8 }
        let held = mostHeldSuit(hand)
        if let best = plain.max(by: { (hand[$0].suit == held ? 20 : 0) + hand[$0].rank < (hand[$1].suit == held ? 20 : 0) + hand[$1].rank }) { return L.hand[best].center }
        if let eight = options.first { return L.hand[eight].center }
        return drawnThisTurn < 3 && !(deck.isEmpty && pile.count <= 1) ? L.deck.center : L.pass.center
    }

    // MARK: Render

    func drawCardFace(_ ui: inout UIBuilder, _ id: String, _ c: Card, _ r: Rect, dim: Bool = false) {
        ui.shape(id, ShapeSpec(.rect, w: r.w, h: r.h, radius: 6, fill: Palette.paper, stroke: Palette.ink.alpha(0.35), lineWidth: 1.2, shadow: true), at: r.origin, alpha: dim ? 0.55 : 1)
        let red = c.suit == 1 || c.suit == 2
        ui.text(id + ".r", CrazyEightsGame.rankText(c.rank), Vec2(r.x + 5, r.y + 3), size: max(11, r.w * 0.3), weight: .bold,
                color: red ? Palette.coral.darker(0.1) : Palette.ink, width: r.w - 6, alpha: dim ? 0.55 : 1)
        let s = r.w * 0.5
        ui.art(id + ".s", .named("suit", c.suit, Int(s)), at: Vec2(r.midX - s / 2, r.maxY - s - 6), alpha: dim ? 0.55 : 1)
    }

    public func render(_ ui: inout UIBuilder, canvas c: Rect, time: Double) {
        let L = layout(c)
        ui.mgHeader("ce", choosingSuit ? "Name a suit" : (playerTurn ? "Your turn" : "Dutch is thinking…"), canvas: c)
        ui.text("ce.opp", "Dutch: \(opp.count) cards", Vec2(c.maxX - 200, c.y + 18), size: 12.5, weight: .semibold, color: Palette.inkSoft, width: 180)
        if choosingSuit {
            for (s, r) in L.suits.enumerated() {
                ui.mgButton("ce.su\(s)", r, style: .tile, ax: "Choose \(CrazyEightsGame.suitNames[s])")
                ui.art("ce.sui\(s)", .named("suit", s, 34), at: Vec2(r.midX - 17, r.midY - 17))
            }
        } else {
            ui.shape("ce.deck", ShapeSpec(.rect, w: L.deck.w, h: L.deck.h, radius: 6, fill: Palette.navy, shadow: true), at: L.deck.origin)
            ui.text("ce.dn", "\(deck.count)", Vec2(L.deck.midX, L.deck.midY - 9), size: 16, weight: .bold, color: Palette.paper, align: .center, width: 50)
            ui.mgTarget("ce.deckt", L.deck, ax: "Draw a card (\(deck.count) left)")
            drawCardFace(&ui, "ce.top", top, L.pile)
            if top.rank == 8 || suit != top.suit {
                ui.text("ce.suitlbl", "Suit:", Vec2(L.pile.maxX + 8, L.pile.y + 4), size: 11, color: Palette.inkSoft, width: 40)
                ui.art("ce.suit", .named("suit", suit, 26), at: Vec2(L.pile.maxX + 8, L.pile.y + 20))
            }
            if playerTurn && !canPlay {
                let canPass = drawnThisTurn >= 3 || (deck.isEmpty && pile.count <= 1)
                if canPass { ui.mgButton("ce.pass", L.pass, icon: .stop, label: "Pass", style: .pill, ax: "Pass") }
                else { ui.text("ce.hint", "No match — tap the deck to draw (\(3 - drawnThisTurn) left)", Vec2(L.pass.x, L.pass.y + 12), size: 12, color: Palette.inkSoft, width: 220, maxLines: 2) }
            }
        }
        for (i, r) in L.hand.enumerated() {
            let card = hand[i]
            let ok = playerTurn && !choosingSuit && playable(card)
            let dx = shake.map { $0.0 == i ? sin($0.1 * 60) * 3 : 0 } ?? 0
            drawCardFace(&ui, "ce.h\(i)", card, r.offsetBy(Vec2(dx, ok ? -8 : 0)), dim: playerTurn && !ok && !choosingSuit)
            ui.mgTarget("ce.ht\(i)", r, ax: "\(CrazyEightsGame.rankText(card.rank)) of \(CrazyEightsGame.suitNames[card.suit])\(ok ? ", playable" : "")")
        }
    }
}
