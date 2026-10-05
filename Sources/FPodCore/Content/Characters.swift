import Foundation

public enum HairStyle: Int, Codable, CaseIterable {
    case buzz, short, curls, bun, bald, long, braids, mohawk, afro, ponytail, sidePart, locs, gray
}

public enum Accessory: Int, Codable {
    case none, glasses, cap, beard, mustache, headband, earring, bandana, headscarf, kufi, stubble, glassesBeard
}

/// Clothing as drawn (broader than player outfits: staff uniforms, visitors).
public enum Garment: Int, Codable {
    case scrubs, maintenance, whiteCoat, co, visitor, kitchen, laundry, ppe, chaplain, nurse, tech, cardigan, suit, casual, sweater, workShirt

    public init(_ o: Outfit) {
        switch o {
        case .tanScrubs: self = .scrubs
        case .maintenance: self = .maintenance
        case .whiteCoat: self = .whiteCoat
        case .co: self = .co
        case .visitor: self = .visitor
        case .kitchenWhites: self = .kitchen
        case .laundryWhites: self = .laundry
        case .ppe: self = .ppe
        case .chaplain: self = .chaplain
        }
    }
    public var top: RGBA {
        switch self {
        case .scrubs: return Outfit.tanScrubs.color
        case .maintenance: return Outfit.maintenance.color
        case .whiteCoat: return Outfit.whiteCoat.color
        case .co: return Outfit.co.color
        case .visitor: return Outfit.visitor.color
        case .kitchen: return Outfit.kitchenWhites.color
        case .laundry: return Outfit.laundryWhites.color
        case .ppe: return Outfit.ppe.color
        case .chaplain: return Outfit.chaplain.color
        case .nurse: return Palette.turquoise
        case .tech: return RGBA(hex: 0x8CC2BF)
        case .cardigan: return Palette.ochre
        case .suit: return RGBA(hex: 0x3E4E5C)
        case .casual: return Palette.coral.lighter(0.15)
        case .sweater: return RGBA(hex: 0x9DB4BC)
        case .workShirt: return RGBA(hex: 0x7F8F86)
        }
    }
    public var bottom: RGBA {
        switch self {
        case .scrubs: return Outfit.tanScrubs.pants
        case .maintenance: return Outfit.maintenance.pants
        case .whiteCoat: return Outfit.whiteCoat.pants
        case .co: return Outfit.co.pants
        case .visitor: return Outfit.visitor.pants
        case .kitchen: return Outfit.kitchenWhites.pants
        case .laundry: return Outfit.laundryWhites.pants
        case .ppe: return Outfit.ppe.pants
        case .chaplain: return Outfit.chaplain.pants
        case .nurse: return Palette.turquoise.darker(0.15)
        case .tech: return RGBA(hex: 0xB9A783)
        case .cardigan: return Palette.slate
        case .suit: return RGBA(hex: 0x33404B)
        case .casual: return RGBA(hex: 0x4F6475)
        case .sweater: return RGBA(hex: 0x56656C)
        case .workShirt: return RGBA(hex: 0x5C6660)
        }
    }
}

public struct Appearance: Hashable, Codable {
    public var skin: Int
    public var hair: HairStyle
    public var hairColor: Int
    public var accessory: Accessory
    public var garment: Garment
    /// Width/height multipliers (adult proportions vary modestly).
    public var widthScale: Double
    public var heightScale: Double

    public init(skin: Int, hair: HairStyle, hairColor: Int, accessory: Accessory = .none, garment: Garment,
                width: Double = 1, height: Double = 1) {
        self.skin = skin; self.hair = hair; self.hairColor = hairColor; self.accessory = accessory
        self.garment = garment; self.widthScale = width; self.heightScale = height
    }
    public func wearing(_ g: Garment) -> Appearance { var a = self; a.garment = g; return a }
}

public enum Role: String, Codable {
    case peer, co, tech, nurse, doctor, clerk, chaplain, supervisor, librarian, lieutenant, maintenance, k9, lawyer, family, chef

    public var isStaff: Bool {
        switch self {
        case .peer, .lawyer, .family: return false
        default: return true
        }
    }
    /// Vision range (tiles) and field of view (radians) — tunable.
    public var vision: (range: Double, fov: Double) {
        switch self {
        case .co, .lieutenant, .k9: return (7.0, 65 * .pi / 180)
        case .tech, .nurse: return (4.5, 110 * .pi / 180)
        case .doctor, .clerk, .librarian, .chaplain, .supervisor, .chef: return (4.5, 100 * .pi / 180)
        case .maintenance: return (5.0, 90 * .pi / 180)
        default: return (0, 0)
        }
    }
    /// Observers with authority to intervene (others report to a CO).
    public var canIntervene: Bool {
        switch self {
        case .co, .lieutenant, .k9, .tech: return true
        default: return false
        }
    }
    public var title: String {
        switch self {
        case .peer: return "Patient"
        case .co: return "Correctional officer"
        case .tech: return "Psychiatric technician"
        case .nurse: return "Nurse"
        case .doctor: return "Forensic psychologist"
        case .clerk: return "Clerk"
        case .chaplain: return "Chaplain"
        case .supervisor: return "Vocational supervisor"
        case .librarian: return "Librarian"
        case .lieutenant: return "Shift lieutenant"
        case .maintenance: return "Maintenance"
        case .k9: return "K-9 officer"
        case .lawyer: return "Public defender"
        case .family: return "Family"
        case .chef: return "Kitchen supervisor"
        }
    }
}

/// Where an NPC should be during an activity.
public enum Post: Hashable {
    case spot(String)
    case patrol([String])
    case offsite
    case cellCount
    case bunk
    case medLine
    case jobSite
}

public struct NPCDef {
    /// Uses a wheelchair (drawn seated; never a gag).
    public var usesWheelchair: Bool { id == .abe }
    public let id: NPCID
    public let name: String
    public let short: String
    public let role: Role
    public let look: Appearance
    public let cell: Int?
    public let bunk: Int            // 0 = A, 1 = B
    public let job: JobID?
    public let pitch: Double        // mumble voice pitch multiplier
    public let pace: Double         // walking speed multiplier
    public let blurb: String        // journal personality line
    public let wants: [ItemID]
    public let boundary: String
    public let shift: (start: Int, end: Int)? // minutes; nil = always (peers)
    public let posts: [Activity: Post]
    public let fallback: Post
    /// Knows the player by face at the start (F-Pod staff).
    public let familiar: Bool
    /// Rough temperament for reactions: lenient (0) ... strict (1).
    public let strictness: Double
    /// Abusive staff escalate harder and can trigger authored abuse scenes.
    public let abusive: Bool
    public let jobSpots: [String]
}

public enum Cast {
    public static let all: [NPCID: NPCDef] = {
        var d: [NPCID: NPCDef] = [:]
        for n in peers + staff + visitors { d[n.id] = n }
        return d
    }()
    public static func def(_ id: NPCID) -> NPCDef { all[id]! }
    public static var staffIDs: [NPCID] { staff.map { $0.id } }
    public static var peerIDs: [NPCID] { peers.map { $0.id } }

    static func peer(_ id: NPCID, _ name: String, _ short: String, _ look: Appearance, cell: Int, bunk: Int, job: JobID?,
                     pitch: Double, pace: Double = 1, blurb: String, wants: [ItemID], boundary: String,
                     dining: String, group: String?, yard: String, free: [String], jobSpots: [String] = []) -> NPCDef {
        var posts: [Activity: Post] = [
            .wakeCount: .cellCount, .eveningCount: .cellCount, .medPass: .medLine, .settle: .bunk,
            .lightsOut: .bunk, .sleep: .bunk,
            .breakfast: .spot(dining), .chow: .spot(dining), .dinner: .spot(dining), .brunch: .spot(dining),
            .rec: .spot(yard), .freeTime: .patrol(free), .chapel: .patrol(free), .visiting: .patrol(free),
            .review: .patrol(free),
        ]
        posts[.therapy] = group.map { .spot($0) } ?? .patrol(free)
        posts[.work] = job != nil ? .jobSite : .patrol(free)
        posts[.afternoon] = job != nil ? .jobSite : .spot(yard)
        return NPCDef(id: id, name: name, short: short, role: .peer, look: look, cell: cell, bunk: bunk, job: job,
                      pitch: pitch, pace: pace, blurb: blurb, wants: wants, boundary: boundary, shift: nil,
                      posts: posts, fallback: .patrol(free), familiar: false, strictness: 0, abusive: false, jobSpots: jobSpots)
    }

    static func staffer(_ id: NPCID, _ name: String, _ short: String, _ role: Role, _ look: Appearance, shift: (Int, Int)?,
                        pitch: Double, pace: Double = 1, blurb: String, boundary: String, posts: [Activity: Post],
                        fallback: Post, familiar: Bool, strictness: Double, abusive: Bool = false) -> NPCDef {
        NPCDef(id: id, name: name, short: short, role: role, look: look, cell: nil, bunk: 0, job: nil, pitch: pitch, pace: pace,
               blurb: blurb, wants: [], boundary: boundary, shift: shift, posts: posts, fallback: fallback,
               familiar: familiar, strictness: strictness, abusive: abusive, jobSpots: [])
    }

    // MARK: Peers

    static let peers: [NPCDef] = [
        peer(.dutch, "Hendrik \"Dutch\" Vos", "Dutch",
             Appearance(skin: 0, hair: .gray, hairColor: 4, accessory: .beard, garment: .scrubs, width: 1.1, height: 1.0),
             cell: 1, bunk: 0, job: .laundry, pitch: 0.78, pace: 0.85,
             blurb: "Retired merchant sailor. Runs the coffee trade; gruff, scrupulously fair.",
             wants: [.coffee, .glasses, .tomatoes], boundary: "Never touch the photo taped inside his locker.",
             dining: "dining.t1.a", group: "group.seat1", yard: "yard.bench.1", free: ["fpod.t1.a", "fpod.t1.b"],
             jobSpots: ["laundry.worker.1"]),
        peer(.marisol, "Marisol Quintero", "Marisol",
             Appearance(skin: 3, hair: .bun, hairColor: 0, accessory: .glasses, garment: .scrubs, width: 0.92, height: 0.98),
             cell: 2, bunk: 0, job: .library, pitch: 1.18,
             blurb: "Law-library savant who files motions for half the pod. Sharp, impatient, loyal.",
             wants: [.lawBook, .pencils, .coffee], boundary: "Don't waste her time — show up with paper, not promises.",
             dining: "dining.t2.a", group: "group.seat2", yard: "yard.bleacher.1", free: ["lawlib.seat", "fpod.t2.a"],
             jobSpots: ["lawlib.seat"]),
        peer(.benny, "Benny \"Two-Times\" Ortiz", "Benny",
             Appearance(skin: 2, hair: .sidePart, hairColor: 1, accessory: .mustache, garment: .scrubs, width: 1.0, height: 0.95),
             cell: 5, bunk: 0, job: .kitchen, pitch: 1.05, pace: 1.1,
             blurb: "Cheerful hustler. Dice, snacks, a phone nobody admits exists.",
             wants: [.cigarettes, .snack, .peanutButter], boundary: "Owes everybody; hates being called a liar in public.",
             dining: "dining.t4.b", group: nil, yard: "yard.corner", free: ["fpod.t4.a", "fpod.t4.b"],
             jobSpots: ["serving.worker.1"]),
        peer(.theo, "Theo Park", "Theo",
             Appearance(skin: 7, hair: .short, hairColor: 0, garment: .scrubs, width: 0.88, height: 1.02),
             cell: 4, bunk: 0, job: nil, pitch: 1.12, pace: 0.95,
             blurb: "Twenty-three, anxious, brilliant at chess. Sometimes the radiators talk to him.",
             wants: [.chessSet, .book, .snack], boundary: "Loud voices and sudden touches scare him.",
             dining: "dining.t2.b", group: "group.seat3", yard: "yard.bleacher.2", free: ["fpod.t3.a", "fpod.piano.sit"]),
        peer(.lou, "Louise \"Big Lou\" Akers", "Lou",
             Appearance(skin: 4, hair: .braids, hairColor: 0, accessory: .headband, garment: .scrubs, width: 1.22, height: 1.06),
             cell: 6, bunk: 0, job: .grounds, pitch: 0.92,
             blurb: "Runs the weight benches. Protective of anyone who puts in the effort.",
             wants: [.peanutButter, .tomatoes, .snack], boundary: "Don't cut in line at the benches.",
             dining: "dining.t3.a", group: nil, yard: "yard.weights.a", free: ["fpod.t5.a", "fpod.tv.1"],
             jobSpots: ["garden.tend"]),
        peer(.moss, "Rev. Clyde Moss", "Moss",
             Appearance(skin: 5, hair: .bald, hairColor: 4, accessory: .glassesBeard, garment: .scrubs, width: 1.05, height: 1.0),
             cell: 7, bunk: 0, job: nil, pitch: 0.82, pace: 0.9,
             blurb: "Self-appointed chaplain's helper. Quotes scripture and old soul records with equal conviction.",
             wants: [.hymnal, .coffee], boundary: "Will not lie for you, even kindly.",
             dining: "dining.t3.b", group: "group.seat4", yard: "yard.shoes.throw", free: ["chapel.seat1", "fpod.t5.b"]),
        peer(.kenji, "Kenji Watanabe", "Kenji",
             Appearance(skin: 1, hair: .ponytail, hairColor: 1, accessory: .stubble, garment: .scrubs, width: 0.95, height: 1.03),
             cell: 4, bunk: 1, job: .workshop, pitch: 0.96,
             blurb: "Quiet artist. Sells drawings, keeps a tattoo device, keeps promises.",
             wants: [.pencils, .drawing, .coffee], boundary: "Never sells a drawing of a real person without asking them.",
             dining: "dining.t4.a", group: "group.seat5", yard: "yard.bleacher.3", free: ["fpod.t6.a", "group.art"],
             jobSpots: ["workshop.worker.1"]),
        peer(.staticFell, "Dorian \"Static\" Fell", "Static",
             Appearance(skin: 0, hair: .mohawk, hairColor: 7, accessory: .earring, garment: .scrubs, width: 0.9, height: 1.04),
             cell: 7, bunk: 1, job: .workshop, pitch: 1.22, pace: 1.15,
             blurb: "Radio obsessive. Half conspiracy, half genius with a soldering iron.",
             wants: [.copperWire, .batteries, .brokenRadio], boundary: "Don't touch his antenna.",
             dining: "dining.t5.a", group: nil, yard: "yard.corner", free: ["fpod.t6.b", "fpod.tv.2"],
             jobSpots: ["workshop.worker.2"]),
        peer(.ada, "Ada Nwosu", "Ada",
             Appearance(skin: 5, hair: .headscarfStyle, hairColor: 0, accessory: .headscarf, garment: .scrubs, width: 0.98, height: 1.0),
             cell: 2, bunk: 1, job: .infirmary, pitch: 1.08,
             blurb: "Former nurse, now a patient. Knows the infirmary's routines and its blind spots.",
             wants: [.workbook, .soap, .book], boundary: "Won't touch medication or help anyone hoard it.",
             dining: "dining.t2.c", group: "group.seat6", yard: "yard.track.1", free: ["fpod.t2.b", "library.seat1"],
             jobSpots: ["infirmary.orderly"]),
        peer(.fitz, "Gerald Fitzpatrick", "Fitz",
             Appearance(skin: 1, hair: .short, hairColor: 2, accessory: .stubble, garment: .scrubs, width: 1.12, height: 0.97),
             cell: 3, bunk: 1, job: .janitorial, pitch: 0.88, pace: 0.95,
             blurb: "Your cellmate. Snores like a ferry horn, guards the bottom bunk, misses his son.",
             wants: [.earplugs, .snack, .photo], boundary: "Borrows without asking; hates having his own things touched.",
             dining: "dining.t1.b", group: nil, yard: "yard.weights.b", free: ["fpod.tv.3", "fpod.t3.b"],
             jobSpots: ["fpod.patrol.3"]),
        peer(.rosa, "Rosa Delgado", "Rosa",
             Appearance(skin: 2, hair: .curls, hairColor: 1, garment: .scrubs, width: 1.08, height: 0.94),
             cell: 6, bunk: 1, job: .kitchen, pitch: 1.1,
             blurb: "Kitchen veteran and boss of the food economy. Generous with anyone who works.",
             wants: [.tomatoes, .sugar, .cards], boundary: "Nobody steals from her line. Nobody.",
             dining: "dining.t5.b", group: nil, yard: "yard.bench.2", free: ["fpod.t4.c", "fpod.t5.c"],
             jobSpots: ["prep.worker.1"]),
        peer(.harlan, "Harlan Pike", "Harlan",
             Appearance(skin: 0, hair: .buzz, hairColor: 3, accessory: .none, garment: .scrubs, width: 1.15, height: 1.07),
             cell: 5, bunk: 1, job: nil, pitch: 0.86, pace: 1.05,
             blurb: "Volatile, bullying, terrified of his court date. Owns a radio and won't let you forget it.",
             wants: [.cigarettes, .hooch, .phone], boundary: "Don't look at him while he's on the phone.",
             dining: "dining.t6.a", group: nil, yard: "yard.weights.b", free: ["fpod.t6.c", "fpod.tv.1"]),
        peer(.mouse, "Priya \"Mouse\" Shah", "Mouse",
             Appearance(skin: 3, hair: .long, hairColor: 0, garment: .scrubs, width: 0.8, height: 0.9),
             cell: 8, bunk: 0, job: nil, pitch: 1.3, pace: 1.2,
             blurb: "Small, quick, collects secrets. Knows the vents and maybe more.",
             wants: [.peanutButter, .note, .snack], boundary: "Never tell staff where she gets things.",
             dining: "dining.t6.b", group: nil, yard: "yard.corner", free: ["fpod.t6.d", "fpod.patrol.4"]),
        peer(.abe, "Abe Lindqvist", "Abe",
             Appearance(skin: 0, hair: .gray, hairColor: 5, accessory: .glasses, garment: .scrubs, width: 0.95, height: 0.95),
             cell: 1, bunk: 1, job: nil, pitch: 0.74, pace: 0.6,
             blurb: "Retired city bus driver, wheelchair user. Knows every route, forgets which day it is.",
             wants: [.book, .coffee], boundary: "Ask before you push his chair.",
             dining: "dining.t1.c", group: nil, yard: "yard.bleacher.1", free: ["fpod.t1.c", "fpod.tv.2"]),
    ]

    // MARK: Staff

    static let staff: [NPCDef] = [
        staffer(.haskins, "CO Brenda Haskins", "Haskins", .co,
                Appearance(skin: 1, hair: .ponytail, hairColor: 2, accessory: .cap, garment: .co, width: 1.0, height: 1.0),
                shift: (330, 840), pitch: 1.0,
                blurb: "Day officer on F-Pod. By the book, counts to the second, fair if you are.",
                boundary: "Don't make her count twice.",
                posts: [.wakeCount: .patrol(["fpod.patrol.1", "fpod.patrol.2", "fpod.patrol.3", "fpod.patrol.4"]),
                        .medPass: .spot("fpod.station.window"),
                        .breakfast: .spot("fpod.entry.in"), .work: .patrol(["fpod.station.seat", "fpod.patrol.1", "fpod.patrol.2", "fpod.patrol.3", "fpod.patrol.4", "fpod.patrol.5"]),
                        .therapy: .spot("fpod.station.seat"), .chow: .spot("dining.post"),
                        .brunch: .spot("dining.post"), .chapel: .patrol(["fpod.station.seat", "fpod.patrol.2", "fpod.patrol.4"])],
                fallback: .patrol(["fpod.station.seat", "fpod.patrol.2", "fpod.patrol.4"]), familiar: true, strictness: 0.8),
        staffer(.reed, "CO Marcus Reed", "Reed", .co,
                Appearance(skin: 4, hair: .short, hairColor: 0, accessory: .mustache, garment: .co, width: 1.08, height: 1.02),
                shift: (840, 1330), pitch: 0.84, pace: 0.8,
                blurb: "Evening officer. Exhausted, kind in a tired way, lets small things slide.",
                boundary: "Don't make his shift longer.",
                posts: [.eveningCount: .patrol(["fpod.patrol.1", "fpod.patrol.2", "fpod.patrol.3", "fpod.patrol.4"]),
                        .rec: .spot("yard.post"), .dinner: .spot("dining.post2"),
                        .freeTime: .patrol(["fpod.station.seat", "fpod.station.seat", "fpod.patrol.5", "fpod.patrol.2"]),
                        .settle: .patrol(["fpod.patrol.1", "fpod.patrol.3"]), .lightsOut: .spot("fpod.station.seat")],
                fallback: .spot("fpod.station.seat"), familiar: true, strictness: 0.3),
        staffer(.strick, "CO Dale Strick", "Strick", .co,
                Appearance(skin: 0, hair: .buzz, hairColor: 2, accessory: .cap, garment: .co, width: 1.12, height: 1.05),
                shift: (360, 1320), pitch: 0.92, pace: 1.1,
                blurb: "Roving officer. Petty, searches for sport. Some of what he does has names in the grievance manual.",
                boundary: "There isn't one he respects.",
                posts: [.wakeCount: .patrol(["corridor.post.w", "corridor.post.c"]),
                        .work: .patrol(["corridor.post.w", "fpod.patrol.2", "fpod.patrol.4", "corridor.post.c", "voc.hall.post"]),
                        .afternoon: .patrol(["corridor.post.c", "fpod.patrol.1", "fpod.patrol.3", "fpod.patrol.5", "corridor.post.w"]),
                        .rec: .patrol(["yard.track.1", "yard.track.2", "yard.track.3", "yard.track.4"]),
                        .freeTime: .patrol(["fpod.patrol.2", "fpod.patrol.4", "corridor.post.w", "support.hall.post"]),
                        .chow: .spot("dining.post2"), .dinner: .spot("dining.post"), .breakfast: .spot("dining.post2")],
                fallback: .patrol(["corridor.post.w", "corridor.post.c", "corridor.post.e"]), familiar: true, strictness: 1.0, abusive: true),
        staffer(.cole, "Tech Imani Cole", "Cole", .tech,
                Appearance(skin: 4, hair: .afro, hairColor: 0, accessory: .earring, garment: .tech, width: 0.96, height: 1.0),
                shift: (420, 1080), pitch: 1.12,
                blurb: "Psychiatric technician. Runs group, remembers birthdays, writes notes that matter.",
                boundary: "Won't promise what she can't deliver.",
                posts: [.breakfast: .patrol(["fpod.patrol.5", "fpod.center"]), .work: .patrol(["fpod.center", "fpod.patrol.2", "fpod.t3.a"]),
                        .therapy: .spot("group.lead"), .chow: .spot("fpod.center"),
                        .afternoon: .patrol(["support.hall.post", "group.lead", "fpod.center"]),
                        .rec: .spot("fpod.center"), .dinner: .spot("fpod.center")],
                fallback: .spot("fpod.center"), familiar: true, strictness: 0.35),
        staffer(.varga, "Tech Gus Varga", "Varga", .tech,
                Appearance(skin: 2, hair: .short, hairColor: 1, accessory: .beard, garment: .tech, width: 1.1, height: 0.98),
                shift: (600, 1200), pitch: 0.9,
                blurb: "Technician. Jokes constantly, gossips more, notices less than he thinks.",
                boundary: "Hates paperwork.",
                posts: [.therapy: .patrol(["support.hall.post", "corridor.post.c"]),
                        .afternoon: .patrol(["support.hall.post", "corridor.post.c", "corridor.mid"]),
                        .rec: .spot("yard.bench.2"), .freeTime: .patrol(["support.hall.post", "library.seat3"]),
                        .work: .patrol(["support.hall.post", "corridor.mid"])],
                fallback: .patrol(["support.hall.post", "corridor.mid"]), familiar: true, strictness: 0.25),
        staffer(.sato, "Dr. Elaine Sato", "Dr. Sato", .doctor,
                Appearance(skin: 7, hair: .bun, hairColor: 5, accessory: .glasses, garment: .whiteCoat, width: 0.9, height: 0.98),
                shift: (540, 1020), pitch: 1.05,
                blurb: "Forensic psychologist running your evaluation. Skeptical, careful, persuadable by evidence.",
                boundary: "Won't discuss another patient.",
                posts: [:], fallback: .spot("sato.seat"), familiar: true, strictness: 0.5),
        staffer(.okonjo, "Nurse Felix Okonjo", "Okonjo", .nurse,
                Appearance(skin: 5, hair: .buzz, hairColor: 0, accessory: .glasses, garment: .nurse, width: 1.0, height: 1.04),
                shift: (360, 1080), pitch: 0.95,
                blurb: "Med-pass nurse. Brisk, kind, explains every pill if you ask.",
                boundary: "Medication is his job; requests go through Dr. Sato.",
                posts: [.medPass: .spot("fpod.nurse")], fallback: .spot("infirmary.nurse"), familiar: true, strictness: 0.45),
        staffer(.pruitt, "Doreen Pruitt", "Ms. Pruitt", .clerk,
                Appearance(skin: 0, hair: .curls, hairColor: 4, accessory: .glasses, garment: .cardigan, width: 1.02, height: 0.92),
                shift: (480, 1020), pitch: 1.15, pace: 0.85,
                blurb: "Records clerk. Every form has a form. Secretly delighted by a correctly filled one.",
                boundary: "Ink must be blue.",
                posts: [:], fallback: .spot("clerk.pruitt"), familiar: false, strictness: 0.6),
        staffer(.gaines, "Lt. Ray Gaines", "Lt. Gaines", .lieutenant,
                Appearance(skin: 3, hair: .gray, hairColor: 5, accessory: .mustache, garment: .co, width: 1.05, height: 1.06),
                shift: (360, 1320), pitch: 0.8,
                blurb: "Shift lieutenant in control. Strategic, unreadable, fair when cornered by facts.",
                boundary: "Lies told to him are remembered.",
                posts: [:], fallback: .spot("control.seat"), familiar: true, strictness: 0.7),
        staffer(.bell, "Chaplain Iris Bell", "Chaplain Bell", .chaplain,
                Appearance(skin: 6, hair: .locs, hairColor: 0, garment: .chaplain, width: 0.95, height: 1.0),
                shift: (540, 1140), pitch: 1.0, pace: 0.9,
                blurb: "Chaplain. Listens more than she talks; documents what she sees.",
                boundary: "Confidences stay confidences.",
                posts: [:], fallback: .patrol(["chapel.lead", "quiet.seat", "chapel.lead"]), familiar: false, strictness: 0.2),
        staffer(.feld, "Victor Feld", "Mr. Feld", .supervisor,
                Appearance(skin: 1, hair: .bald, hairColor: 3, accessory: .glasses, garment: .workShirt, width: 1.08, height: 1.0),
                shift: (480, 900), pitch: 0.88,
                blurb: "Vocational supervisor. Grumbles, then writes the best job references on campus.",
                boundary: "Tools get counted. Every tool.",
                posts: [:], fallback: .patrol(["workshop.feld", "laundry.feld", "voc.hall.post"]), familiar: false, strictness: 0.55),
        staffer(.odell, "Chef Marvin Odell", "Chef Odell", .chef,
                Appearance(skin: 5, hair: .short, hairColor: 0, accessory: .beard, garment: .kitchen, width: 1.2, height: 1.02),
                shift: (360, 1140), pitch: 0.86,
                blurb: "Kitchen supervisor. Loud, sentimental about soup, strict about knives.",
                boundary: "The knife board is sacred.",
                posts: [:], fallback: .patrol(["prep.odell", "serving.station", "prep.odell"]), familiar: false, strictness: 0.6),
        staffer(.abernathy, "Ms. June Abernathy", "Ms. Abernathy", .librarian,
                Appearance(skin: 4, hair: .gray, hairColor: 4, accessory: .glasses, garment: .sweater, width: 0.92, height: 0.94),
                shift: (780, 1260), pitch: 1.1, pace: 0.85,
                blurb: "Librarian. Believes in due dates and due process in that order.",
                boundary: "Shh.",
                posts: [:], fallback: .spot("library.abernathy"), familiar: false, strictness: 0.4),
        staffer(.nico, "Nico Barros", "Nico", .maintenance,
                Appearance(skin: 2, hair: .short, hairColor: 1, accessory: .cap, garment: .maintenance, width: 1.0, height: 1.0),
                shift: (840, 1320), pitch: 1.0,
                blurb: "Maintenance tech. Whistles in the tunnels at night.",
                boundary: "His tunnels, his rules.",
                posts: [:], fallback: .patrol(["tunnels.patrol.1", "tunnels.patrol.3", "tunnels.patrol.2", "tunnels.patrol.4"]),
                familiar: false, strictness: 0.5),
        staffer(.tran, "Officer Linh Tran", "Officer Tran", .k9,
                Appearance(skin: 7, hair: .ponytail, hairColor: 0, accessory: .cap, garment: .co, width: 0.94, height: 1.0),
                shift: (360, 1320), pitch: 1.05, pace: 0.9,
                blurb: "K-9 officer on the perimeter road with Duke, who is a very good dog.",
                boundary: "Don't pet Duke without asking.",
                posts: [:], fallback: .patrol(["k9.a", "k9.b", "k9.c"]), familiar: false, strictness: 0.8),
    ]

    static let visitors: [NPCDef] = [
        staffer(.calloway, "Ruth Calloway", "Ms. Calloway", .lawyer,
                Appearance(skin: 3, hair: .short, hairColor: 5, accessory: .glasses, garment: .suit, width: 0.95, height: 1.0),
                shift: nil, pitch: 1.0, blurb: "Your public defender. Forty other clients and still returns calls.",
                boundary: "Needs documents, not speeches.", posts: [:], fallback: .offsite, familiar: false, strictness: 0),
        staffer(.nadia, "Nadia Merritt", "Nadia", .family,
                Appearance(skin: 2, hair: .long, hairColor: 1, garment: .casual, width: 0.95, height: 0.97),
                shift: nil, pitch: 1.15, blurb: "Your sister. Has your dog, Biscuit, and your back.",
                boundary: "Won't be lied to again.", posts: [:], fallback: .offsite, familiar: false, strictness: 0),
    ]

    /// The player character.
    public static let playerLook = Appearance(skin: 2, hair: .curls, hairColor: 1, accessory: .none, garment: .scrubs, width: 1.0, height: 1.0)
    public static let playerName = "Jo Merritt"
    public static let playerNumber = "40417-F"
}

extension HairStyle {
    static var headscarfStyle: HairStyle { .bun }
}
