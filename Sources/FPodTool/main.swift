import Foundation
@testable import FPodCore

// fpod-tool: development utilities that drive the real game core on Linux.
//   fpod-tool snapshot <scenario> <out.svg> [width height]
//   fpod-tool scenarios
//   fpod-tool ascii x0 y0 x1 y1

func stepGame(_ g: Game, seconds: Double, until: ((Game) -> Bool)? = nil) {
    var t = 0.0
    while t < seconds {
        if let tr = g.transition, tr.card != nil { tr.cardAge = 1; g.sceneContinue() }
        g.update(dt: 1.0 / 30.0)
        t += 1.0 / 30.0
        if let u = until, u(g) { return }
    }
}

func newGame(_ w: Double, _ h: Double) -> Game {
    let g = Game(seed: 7, viewport: Viewport(size: Vec2(w, h), safeTop: 0, safeLeft: 47, safeBottom: 21, safeRight: 47, scale: 3))
    return g
}

func settle(_ g: Game) {
    stepGame(g, seconds: 6, until: { $0.transition == nil })
    stepGame(g, seconds: 0.5)
}

let scenarios: [String: (Game) -> Void] = [
    "intake": { g in for _ in 0..<10 { g.update(dt: 1.0 / 30.0) } },
    "pod": { g in settle(g); stepGame(g, seconds: 1.2) },
    "walk": { g in settle(g); _ = g.walk(to: g.map.spot("fpod.center")!.pos); stepGame(g, seconds: 1.4) },
    "fan": { g in
        settle(g)
        g.engage(.object("fpod.cell3.bunk"))
        stepGame(g, seconds: 20, until: { $0.ui.modal != nil })
        stepGame(g, seconds: 0.2)
    },
    "cell": { g in
        settle(g)
        g.s.flags.insert(.claimedBunk)
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        g.s.minute = 368
        stepGame(g, seconds: 1)
    },
    "dayroom": { g in
        settle(g); g.s.flags.insert(.claimedBunk); g.s.flags.insert(.firstCountDone)
        g.s.minute = 600; g.s.player.pos = g.map.spot("fpod.center")!.pos; g.ui.cameraSnap = true
        stepGame(g, seconds: 30)
    },
    "sneak": { g in
        settle(g); g.s.minute = 800; g.s.player.pos = Vec2(30.5, 66.5); g.s.player.sneakToggle = true; g.ui.cameraSnap = true
        stepGame(g, seconds: 25)
    },
    "inventory": { g in settle(g); g.perform(.openInventory); g.perform(.invSelect(.carried, 0)) },
    "map": { g in settle(g); g.s.knownZones.formUnion(["corridor.main", "kitchen.dining", "yard", "support.group", "support.library"]); g.perform(.openMap) },
    "journal": { g in settle(g); g.perform(.openJournal) },
    "settings": { g in settle(g); g.perform(.openSettings) },
    "help": { g in settle(g); g.perform(.openHelp) },
    "menu": { g in settle(g); g.perform(.openMenu) },
    "chart": { g in settle(g); g.openDoc(.chart) },
    "medchoice": { g in settle(g); g.ui.modal = .choice(.medPass) },
    "trade": { g in settle(g); g.ui.modal = .trade(g.quote(Trades.byID["dutch.welcome"]!)) },
    "status": { g in settle(g); g.perform(.toggleStatus) },
    "mopintro": { g in settle(g); g.assignJob(.janitorial); g.s.minute = 500; g.startShift(.janitorial) },
    "mop": { g in
        settle(g); g.assignJob(.janitorial); g.s.minute = 500; g.startShift(.janitorial); g.minigameAction(.minigameStart)
        stepGame(g, seconds: 3)
        // Tap a few tiles to show the route.
        let c = g.minigameCanvas
        if let mop = g.minigame?.game as? MopGame {
            let (o, size) = mop.layout(c)
            g.tap(o + Vec2(size * 1.5, size * 0.5)); g.tap(o + Vec2(size * 2.5, size * 0.5)); g.tap(o + Vec2(size * 2.5, size * 1.5))
        }
        stepGame(g, seconds: 0.5)
    },
    "capture": { g in
        settle(g); g.s.minute = 800
        g.s.player.pos = g.map.spot("control.seat")!.pos
        g.captured(by: .strick, reason: .restrictedArea)
        for _ in 0..<40 { g.update(dt: 1.0 / 30.0) }
    },
    "commissary": { g in settle(g); g.s.trust = 50; g.s.minute = 1100; g.perform(.closeModal); g.ui.modal = .commissary },
    "stash": { g in settle(g); g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos; g.ui.modal = .stash("fpod.cell3.locker") },
    "lefty": { g in settle(g); g.settings.leftHanded = true; g.ui.contextTarget = .npc(.haskins); stepGame(g, seconds: 0.2) },
    "yard": { g in settle(g); g.s.minute = 930; g.apply([.teleport("yard.post")]); stepGame(g, seconds: 25) },
    "kitchen": { g in settle(g); g.s.minute = 730; g.apply([.teleport("dining.post")]); stepGame(g, seconds: 25) },
    "voc": { g in settle(g); g.s.minute = 520; g.apply([.teleport("voc.hall.post")]); stepGame(g, seconds: 20) },
    "support": { g in settle(g); g.s.minute = 670; g.apply([.teleport("support.hall.post")]); stepGame(g, seconds: 20) },
    "admin": { g in settle(g); g.s.minute = 800; g.apply([.teleport("clerk.client")]); stepGame(g, seconds: 15) },
    "control": { g in settle(g); g.s.minute = 800; g.apply([.teleport("control.seat")]); stepGame(g, seconds: 2) },
    "obs": { g in settle(g); g.s.minute = 800; g.apply([.teleport("obs.hall.w")]); g.s.player.pos = Vec2(80.5, 93.5); g.ui.cameraSnap = true; stepGame(g, seconds: 2) },
    "tunnels": { g in settle(g); g.s.minute = 1000; g.apply([.teleport("tunnels.patrol.3")]); stepGame(g, seconds: 3) },
    "perimeter": { g in settle(g); g.s.minute = 800; g.apply([.teleport("k9.a")]); stepGame(g, seconds: 3) },
    "cart": { g in
        settle(g); g.s.minute = 800; g.assignJob(.janitorial); g.apply([.teleport("cartbay.drive")]); g.apply([.vehicle(.janitorCart)])
        _ = g.walk(to: g.s.player.pos + Vec2(-6, 4)); stepGame(g, seconds: 1.0)
    },
    "buffer": { g in
        settle(g); g.s.minute = 600; g.assignJob(.janitorial); g.s.player.pos = g.map.spot("fpod.center")!.pos; g.ui.cameraSnap = true
        g.apply([.vehicle(.floorBuffer)]); _ = g.walk(to: g.s.player.pos + Vec2(4, 2)); stepGame(g, seconds: 0.8)
    },
    "jobboard": { g in settle(g); g.s.day = 2; g.openDoc(.jobBoard) },
    "abe": { g in
        settle(g); g.s.minute = 1110; let abe = g.npc(.abe)!; g.s.player.pos = abe.pos + Vec2(1.5, 0); g.ui.cameraSnap = true; stepGame(g, seconds: 1)
    },
    "ending": { g in settle(g); g.setFlag(.preFinaleSaved); g.startEnding(.release); stepGame(g, seconds: 8) },
    "journal3": { g in
        settle(g)
        g.s.flags.formUnion([.claimedBunk, .readChart, .firstCountDone, .metDutch, .trialDone])
        g.apply([.completeQuest(.m01Intake), .completeQuest(.m02Ally)]); g.startNewDay(); g.startNewDay(); g.processEvents()
        stepGame(g, seconds: 1); g.perform(.openJournal)
    },
    "dev": { g in settle(g); g.isDevBuild = true; g.perform(.dev("open")) },
    "dev2": { g in settle(g); g.isDevBuild = true; g.perform(.dev("open")); g.perform(.dev("page+")) },
    "phonecall": { g in settle(g); g.s.flags.insert(.lawyerNumberKnown); g.placeCall(.calloway); stepGame(g, seconds: 0.5) },
    "visit": { g in
        settle(g); g.s.minute = 840; g.s.appointments.append(Appointment(id: "nadia.visit", day: 1, start: 840, end: 930, title: "Visit: Nadia", icon: .heart, spot: "visit.t2.in", npc: .nadia, quest: nil))
        g.apply([.teleport("visit.t2.in")]); stepGame(g, seconds: 1)
    },
    "visitcard": { g in
        settle(g); g.s.minute = 840; g.s.appointments.append(Appointment(id: "nadia.visit", day: 1, start: 840, end: 930, title: "Visit: Nadia", icon: .heart, spot: "visit.t2.in", npc: .nadia, quest: nil))
        g.apply([.teleport("visit.t2.in")]); stepGame(g, seconds: 1); g.perform("b.appt", on: .npc(.nadia)); g.processEvents(); stepGame(g, seconds: 1)
    },
    "fanjobs": { g in
        settle(g); g.s.day = 2; g.s.minute = 790; g.apply([.teleport("fpod.center")])
        g.ui.modal = .fan(.npc(.haskins), g.options(for: .npc(.haskins)))
    },
    "lawn": { g in settle(g); g.s.minute = 800; g.apply([.teleport("grounds.shed")]); stepGame(g, seconds: 3) },
]

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: fpod-tool snapshot <scenario> <out.svg> [w h] | scenarios | ascii x0 y0 x1 y1 | overview <out.svg> <tile>")
    exit(1)
}
switch args[1] {
case "scenarios":
    print(scenarios.keys.sorted().joined(separator: "\n"))
case "snapshot":
    let name = args[2], out = args[3]
    let w = args.count > 5 ? Double(args[4])! : 844, h = args.count > 5 ? Double(args[5])! : 390
    let g = newGame(w, h)
    if name.hasPrefix("mg-"), let id = MinigameID(rawValue: String(name.dropFirst(3)).components(separatedBy: "@")[0]) {
        // mg-<id>[@seconds]: start a minigame and let the bot play for a while.
        let secs = Double(name.components(separatedBy: "@").dropFirst().first ?? "") ?? 6
        settle(g)
        g.startMinigame(id, key: "snap", pass: 0.5, onPass: [], onFail: [], npc: nil)
        if secs > 0 {
            g.minigameAction(.minigameStart)
            var t = 0.0, last = -1.0
            while t < secs, let mg = g.minigame, mg.phase == .playing {
                g.update(dt: 1.0 / 30.0)
                if t - last > 0.3, let p = mg.game.botTap(canvas: g.minigameCanvas) { g.tap(p); last = t }
                t += 1.0 / 30.0
            }
        }
    } else {
        guard let sc = scenarios[name] else { print("unknown scenario \(name)"); exit(2) }
        sc(g)
    }
    let frame = g.buildFrame()
    let svg = SVGRenderer(tileSize: g.settings.zoom).render(frame)
    try svg.write(toFile: out, atomically: true, encoding: .utf8)
    print("wrote \(out): items=\(frame.items.count) polys=\(frame.polys.count) hits=\(g.ui.hitRegions.count) ax=\(frame.accessibility.count)")
case "objects":
    // Content reference: zones, objects and spots.
    let map = WorldShared.map
    for z in map.zones { print("ZONE \(z.id) | \(z.name) | \(z.cls) | \(z.district)") }
    for o in map.objects { print("OBJ \(o.id) | \(o.kind) | \(o.zone) | \(o.rect.x),\(o.rect.y)") }
    for sp in map.spots.values.sorted(by: { $0.id < $1.id }) { print("SPOT \(sp.id) | \(map.zone(at: sp.pos)?.id ?? "-") | \(Int(sp.pos.x)),\(Int(sp.pos.y))") }
    for d in map.doors { print("DOOR \(d.id) | \(d.name) | \(d.kind)") }
case "stats":
    let map = WorldShared.map
    print("main quests: \(Quests.main.count) (stages \(Quests.main.reduce(0) { $0 + $1.stages.count }))")
    print("side quests: \(Quests.side.count) (stages \(Quests.side.reduce(0) { $0 + $1.stages.count }))")
    print("interactions: \(Interactions.all.count)  choices: \(Choices.all.count) (options \(Choices.all.reduce(0) { $0 + $1.options.count }))  trades: \(Trades.all.count)")
    print("minigames: \(MinigameID.allCases.filter { Minigames.isImplemented($0) }.count)/\(MinigameID.allCases.count)")
    print("peers: \(Cast.all.values.filter { $0.role == .peer }.count)  staff: \(Cast.all.values.filter { $0.role.isStaff }.count)  visitors: \(Cast.all.values.filter { $0.role == .lawyer || $0.role == .family }.count)")
    print("items: \(Items.list.count)  outfits: \(Outfit.allCases.count)  docs: \(DocID.allCases.count)  flags: \(Flag.allCases.count)")
    print("zones: \(map.zones.count)  objects: \(map.objects.count)  doors: \(map.doors.count)  spots: \(map.spots.count)  cameras: \(map.cameras.count)  hide spots: \(HideSpots.all.count)  stashes: \(Stashes.all.count)")
    print("map: \(map.width)x\(map.height) tiles; sfx: \(SFX.allCases.count); music moods: \(MusicMood.allCases.count); icons: \(Icon.allCases.count)")
case "items":
    // Content audit: every item needs a way in (source) and a reason to exist (use).
    let cov = ContentAudit.itemCoverage()
    for d in Items.list {
        let c = cov[d.id] ?? ContentAudit.Coverage()
        print("\(d.id.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)) src=\(c.sources.count) use=\(c.uses.count)  \(c.sources.isEmpty ? "NO-SOURCE " : "")\(c.uses.isEmpty ? "NO-USE" : "")")
    }
case "overview":
    // Whole-campus render at a small tile size (layout check).
    let out = args[2]
    let T = args.count > 3 ? Double(args[3])! : 6
    let map = WorldShared.map
    let art = ArtLibrary(tileSize: T)
    var frame = Frame()
    frame.tileSize = T
    frame.viewport = Vec2(200 * T, 140 * T)
    frame.camera = Vec2(100, 70)
    for cy in 0..<((map.height + 15) / 16) {
        for cx in 0..<((map.width + 15) / 16) {
            frame.items.append(RenderItem(id: "c\(cx).\(cy)", art: .chunk(cx, cy), pos: Vec2(Double(cx * 16), Double(cy * 16)), z: 0, layer: .world))
        }
    }
    _ = art
    let svg = SVGRenderer(tileSize: T).render(frame)
    try svg.write(toFile: out, atomically: true, encoding: .utf8)
    print("wrote \(out)")
case "audio":
    // Renders every SFX and music loop to WAV for listening, with timing.
    let dir = args.count > 2 ? args[2] : "out/audio"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    var t0 = Date()
    for s in SFX.allCases {
        let x = SFXBank.render(s)
        try DSP.wav(left: x).write(to: URL(fileURLWithPath: "\(dir)/sfx-\(s.rawValue).wav"))
    }
    print("sfx: \(SFX.allCases.count) in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    for p in [0.75, 1.0, 1.25] {
        try DSP.wav(left: SFXBank.mumble(pitch: p, seed: 3)).write(to: URL(fileURLWithPath: "\(dir)/mumble-\(p).wav"))
    }
    for m in MusicMood.allCases {
        t0 = Date()
        let loop = MusicComposer.render(m)
        try DSP.wav(left: loop.left, right: loop.right).write(to: URL(fileURLWithPath: "\(dir)/music-\(m.rawValue).wav"))
        print("music \(m.rawValue): \(String(format: "%.1f", loop.seconds))s loop, rendered in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    }
case "icon":
    // App icon: a paper-doll patient in tan scrubs before cell bars (512pt SVG → 1024px PNG).
    let out = args.count > 2 ? args[2] : "out/icon.svg"
    let T = 300.0
    let art = ArtLibrary(tileSize: T)
    var frame = Frame()
    frame.viewport = Vec2(512, 512)
    frame.background = Palette.ivory
    var ui = UIBuilder(z: 0, labels: false)
    ui.shape("glow", ShapeSpec(.circle, w: 330, h: 330, fill: Palette.ochre.lighter(0.25)), at: Vec2(150, 40))
    ui.shape("bars.bg", ShapeSpec(.rect, w: 420, h: 360, radius: 28, fill: Palette.blueGray.lighter(0.1), shadow: true), at: Vec2(46, 70))
    for k in 0..<5 { ui.shape("bar\(k)", ShapeSpec(.rect, w: 22, h: 360, radius: 11, fill: Palette.slate, shadow: true), at: Vec2(92 + Double(k) * 76, 70)) }
    ui.shape("rail", ShapeSpec(.rect, w: 420, h: 26, radius: 10, fill: Palette.navy, shadow: true), at: Vec2(46, 236))
    ui.shape("floor", ShapeSpec(.rect, w: 512, h: 96, fill: Palette.tan.lighter(0.35)), at: Vec2(0, 416))
    frame.items = ui.items
    let look = Cast.playerLook
    let feet = Vec2(256, 470)
    func part(_ p: FigurePart, _ off: Vec2, z: Double, rot: Double = 0) {
        frame.items.append(RenderItem(id: "p\(p)", art: FigureArt.key(p, look, .down), pos: feet + off * T, z: 100 + z, layer: .screen, rotation: rot))
    }
    part(.shadow, Vec2(0, -0.01), z: 0)
    part(.legL, Vec2(-0.085, -0.36), z: 1); part(.legR, Vec2(0.085, -0.36), z: 1)
    part(.body, Vec2(0, -0.34), z: 2)
    part(.armL, Vec2(-0.215, -0.74), z: 3, rot: 0.1); part(.armR, Vec2(0.215, -0.74), z: 3, rot: -0.1)
    part(.head, Vec2(0, -0.8), z: 4); part(.hair, Vec2(0, -0.8), z: 5)
    _ = art
    let svg = SVGRenderer(tileSize: T).render(frame)
    try svg.write(toFile: out, atomically: true, encoding: .utf8)
    print("wrote \(out)")
case "ascii":
    let map = WorldShared.map
    let x0 = Int(args[2])!, y0 = Int(args[3])!, x1 = Int(args[4])!, y1 = Int(args[5])!
    for y in y0...y1 {
        var line = ""
        for x in x0...x1 {
            let p = TilePos(x, y)
            var c: Character
            switch map.kind(p) {
            case .void: c = " "
            case .wall: c = "#"
            case .floor, .tunnel: c = "."
            case .door: c = "+"
            case .window: c = "="
            case .fence: c = "|"
            case .grass: c = ","
            case .concrete: c = ":"
            case .track: c = "~"
            case .road: c = "_"
            case .woods: c = "^"
            case .water: c = "w"
            case .court: c = ";"
            }
            if let o = map.object(at: p) { c = o.kind.solid ? "o" : "x" }
            line.append(c)
        }
        print(line)
    }
default:
    print("unknown command")
}
