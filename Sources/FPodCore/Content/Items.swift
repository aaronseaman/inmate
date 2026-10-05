import Foundation

public struct ItemDef {
    public let id: ItemID
    public let name: String
    public let icon: Icon
    public let size: ItemSize
    public let legality: Legality
    /// Informal barter value (abstract units, ~1 unit ≈ 1 credit).
    public let value: Int
    /// Commissary price in credits; nil = not sold.
    public let price: Int?
    /// Why the item exists in play.
    public let purpose: String
    /// Quest-critical: loss triggers a replacement/recovery route.
    public let critical: Bool
    /// Jobs whose assignment makes a restricted item permitted.
    public let permittedBy: [JobID]
    public let tint: RGBA?

    init(_ id: ItemID, _ name: String, _ icon: Icon, _ size: ItemSize, _ legality: Legality, value: Int, price: Int? = nil,
         purpose: String, critical: Bool = false, permittedBy: [JobID] = [], tint: RGBA? = nil) {
        self.id = id; self.name = name; self.icon = icon; self.size = size; self.legality = legality
        self.value = value; self.price = price; self.purpose = purpose; self.critical = critical
        self.permittedBy = permittedBy; self.tint = tint
    }
}

public enum Items {
    public static let all: [ItemID: ItemDef] = {
        var d: [ItemID: ItemDef] = [:]
        for def in list { d[def.id] = def }
        return d
    }()

    public static func def(_ id: ItemID) -> ItemDef { all[id]! }

    static let list: [ItemDef] = [
        ItemDef(.snack, "Snack cakes", .snack, .small, .legal, value: 2, price: 2, purpose: "Restores a little energy; easy barter."),
        ItemDef(.peanutButter, "Peanut butter", .jar, .small, .legal, value: 3, price: 3, purpose: "Prized barter. Mouse's favorite."),
        ItemDef(.coffee, "Instant coffee", .cup, .small, .legal, value: 3, price: 3, purpose: "Restores energy; Dutch's trade staple."),
        ItemDef(.soap, "Soap", .soap, .tiny, .legal, value: 1, price: 1, purpose: "Restores outfit condition when used at a sink."),
        ItemDef(.tomatoes, "Garden tomatoes", .tomato, .small, .legal, value: 3, purpose: "Grounds produce; Rosa and Dutch trade for them."),
        ItemDef(.sugar, "Sugar packets", .sugar, .tiny, .restricted, value: 2, purpose: "Kitchen supply; tempting to pocket.", permittedBy: [.kitchen]),
        ItemDef(.earplugs, "Foam earplugs", .earplug, .tiny, .legal, value: 1, price: 1, purpose: "A cellmate compromise for snoring."),
        ItemDef(.batteries, "Batteries", .battery, .tiny, .legal, value: 2, price: 2, purpose: "Radio upkeep; a radio drains them every two days."),
        ItemDef(.cigarettes, "Cigarettes", .cigarette, .small, .contraband, value: 4, purpose: "Informal currency in a tobacco-free facility."),
        ItemDef(.pillToken, "Hoarded pill tokens", .token, .tiny, .contraband, value: 5, purpose: "Abstract story token. Theo's hoard; returning it matters."),
        ItemDef(.hooch, "Hooch bag", .bottle, .medium, .contraband, value: 6, purpose: "Harlan's batch. Dump it, return it, or keep it — each costs something."),
        ItemDef(.phone, "Contraband phone", .phone, .small, .contraband, value: 14, purpose: "Benny's phone; a risky route to the lawyer."),
        ItemDef(.charger, "Phone charger", .charger, .small, .contraband, value: 5, purpose: "Needed to use the contraband phone."),
        ItemDef(.dice, "Dice", .dice, .tiny, .contraband, value: 2, purpose: "Benny's games. Loaded? Find out."),
        ItemDef(.tattooDevice, "Tattoo device", .needle, .small, .contraband, value: 8, purpose: "Kenji's tool; a promise kept or broken."),
        ItemDef(.weaponToken, "Sharpened shard", .shard, .small, .dangerous, value: 0, purpose: "Abstract weapon token from an authored incident. Surrendering it changes the story."),
        ItemDef(.note, "Folded note", .note, .tiny, .contraband, value: 1, purpose: "Peer messages (kites)."),
        ItemDef(.radio, "Radio", .radio, .medium, .legal, value: 30, price: 35, purpose: "News, music, and the court station; a main-quest goal.", critical: true),
        ItemDef(.brokenRadio, "Broken radio", .radio, .medium, .legal, value: 4, purpose: "Repairable at the workshop with wire and help.", tint: Palette.metal),
        ItemDef(.headphones, "Headphones", .headphones, .small, .legal, value: 15, price: 18, purpose: "Quiet hours for a cellmate; required for radio after lights out."),
        ItemDef(.book, "Paperback", .book, .medium, .legal, value: 5, price: 6, purpose: "Reading calms watch reviews; can be hollowed."),
        ItemDef(.hollowBook, "Hollow book", .book, .medium, .contraband, value: 5, purpose: "One concealed slot while carried.", tint: Palette.ochre),
        ItemDef(.workbook, "Coping workbook", .workbook, .small, .legal, value: 3, price: 4, purpose: "Counts toward review preparation and watch recovery."),
        ItemDef(.lawBook, "Law library volume", .book, .medium, .restricted, value: 2, purpose: "Library property for case research.", critical: true, permittedBy: [.library], tint: Palette.navy),
        ItemDef(.chessSet, "Pocket chess set", .chess, .small, .legal, value: 4, purpose: "Play Theo; library loans one."),
        ItemDef(.cards, "Deck of cards", .cards, .small, .legal, value: 2, price: 2, purpose: "Card nights with Dutch."),
        ItemDef(.pencils, "Colored pencils", .pencil, .tiny, .legal, value: 3, price: 3, purpose: "Kenji's portrait; art therapy."),
        ItemDef(.drawing, "Drawing", .drawing, .small, .legal, value: 4, purpose: "Made in art therapy; sell, gift, or bring to a visit."),
        ItemDef(.hymnal, "Hymnal", .hymnal, .medium, .legal, value: 2, purpose: "Chapel property; a prop for the chaplain role."),
        ItemDef(.glasses, "Reading glasses", .glasses, .tiny, .legal, value: 2, purpose: "Dutch's lost glasses."),
        ItemDef(.photo, "Photograph", .photo, .tiny, .legal, value: 0, purpose: "Fitz's photo of his son. Not for trade."),
        ItemDef(.janitorKey, "Janitor key", .key, .tiny, .restricted, value: 6, purpose: "Opens janitor closets while on janitorial detail.", critical: true, permittedBy: [.janitorial]),
        ItemDef(.utilityKey, "Utility key", .key, .tiny, .contraband, value: 10, purpose: "Opens maintenance hatches.", critical: true, tint: Palette.ochre),
        ItemDef(.recordsKey, "Records key", .key, .tiny, .contraband, value: 10, purpose: "Opens the records room after hours.", critical: true, tint: Palette.coral),
        ItemDef(.screwdriver, "Screwdriver", .tools, .small, .restricted, value: 5, purpose: "Workshop tool; opens vents and radio backs.", permittedBy: [.workshop]),
        ItemDef(.copperWire, "Copper wire", .wire, .tiny, .restricted, value: 3, purpose: "Radio repair; Static's antenna.", permittedBy: [.workshop]),
        ItemDef(.fenceTool, "Fence tool", .cutter, .medium, .dangerous, value: 0, purpose: "Fictional escape tool. Its existence is an incident.", critical: true),
        ItemDef(.clipboard, "Clipboard", .clipboard, .small, .restricted, value: 2, purpose: "Prop that makes staff roles more plausible.", permittedBy: [.library, .infirmary]),
        ItemDef(.mop, "Mop", .mop, .large, .restricted, value: 1, purpose: "Janitorial prop; mopping normalizes presence.", permittedBy: [.janitorial]),
        ItemDef(.tray, "Serving tray", .tray, .medium, .restricted, value: 1, purpose: "Kitchen prop; carrying one looks like work.", permittedBy: [.kitchen]),
        ItemDef(.laundryBag, "Laundry bag", .sack, .medium, .restricted, value: 1, purpose: "Laundry prop; deliveries look routine.", permittedBy: [.laundry]),
        ItemDef(.deliveryBox, "Delivery box", .box, .medium, .restricted, value: 1, purpose: "Supply delivery prop.", permittedBy: [.infirmary, .laundry]),
        ItemDef(.visitorBadge, "Visitor badge", .badge, .tiny, .contraband, value: 6, purpose: "Makes visitor clothes plausible during visiting hours."),
        ItemDef(.mapScrapA, "Map scrap (tunnels)", .mapScrap, .tiny, .contraband, value: 4, purpose: "One of three pieces of the old utility map.", critical: true),
        ItemDef(.mapScrapB, "Map scrap (culvert)", .mapScrap, .tiny, .contraband, value: 4, purpose: "One of three pieces of the old utility map.", critical: true),
        ItemDef(.mapScrapC, "Map scrap (perimeter)", .mapScrap, .tiny, .contraband, value: 4, purpose: "One of three pieces of the old utility map.", critical: true),
        ItemDef(.tunnelMap, "Assembled tunnel map", .map, .small, .contraband, value: 12, purpose: "Reveals the service network.", critical: true),
        ItemDef(.requestForm, "Request form", .form, .tiny, .legal, value: 0, price: 0, purpose: "Blank form; Ms. Pruitt insists."),
        ItemDef(.recordsRequest, "Records request", .form, .tiny, .legal, value: 0, purpose: "Authorized route to your transport log.", critical: true),
        ItemDef(.grievanceForm, "Grievance form", .form, .tiny, .legal, value: 0, purpose: "Complaint path for abuse incidents.", critical: true, tint: Palette.coral),
        ItemDef(.visitForm, "Visiting form", .form, .tiny, .legal, value: 0, purpose: "Puts a visitor on the list."),
        ItemDef(.letter, "Letter", .letter, .tiny, .legal, value: 0, purpose: "Mail from outside."),
        ItemDef(.chartCopy, "Chart copy", .clipboard, .tiny, .legal, value: 0, purpose: "Your disputed chart — evidence for the contradiction.", critical: true, tint: Palette.blueGray),
        ItemDef(.courtDocket, "Court docket", .form, .tiny, .legal, value: 0, purpose: "Court dates from your lawyer.", critical: true, tint: Palette.ochre),
        ItemDef(.transportLog, "Transport log copy", .form, .tiny, .legal, value: 0, purpose: "Proof you were in court that day.", critical: true, tint: Palette.turquoise),
        ItemDef(.witnessStatement, "Witness statement", .form, .tiny, .legal, value: 0, purpose: "A peer's account; supports a grievance or Theo.", critical: true),
        ItemDef(.supportLetter, "Support letter", .letter, .tiny, .legal, value: 0, purpose: "Nadia's letter: a place to stay.", critical: true),
        ItemDef(.housingLetter, "Housing letter", .letter, .tiny, .legal, value: 0, purpose: "Supportive housing acceptance.", critical: true),
        ItemDef(.clinicReferral, "Clinic referral", .form, .tiny, .legal, value: 0, purpose: "Outpatient appointment for the discharge plan.", critical: true),
        ItemDef(.jobLead, "Job lead", .card, .tiny, .legal, value: 0, purpose: "Feld's reference for work outside.", critical: true),
        ItemDef(.petition, "Signed petition", .form, .tiny, .legal, value: 0, purpose: "Peers' signatures for the advocacy meeting.", critical: true),
        ItemDef(.lawyerCard, "Lawyer's card", .card, .tiny, .legal, value: 0, purpose: "Ruth Calloway's number.", critical: true),
        ItemDef(.tanScrubs, "Tan scrubs", .shirt, .medium, .legal, value: 1, purpose: "Your own clothes.", tint: Outfit.tanScrubs.color),
        ItemDef(.maintenanceJumpsuit, "Maintenance jumpsuit", .shirt, .medium, .contraband, value: 6, purpose: "Workshop, closets and service routes.", tint: Outfit.maintenance.color),
        ItemDef(.whiteCoat, "White coat", .coat, .medium, .contraband, value: 8, purpose: "Infirmary corridors and records-facing desks.", tint: Outfit.whiteCoat.color),
        ItemDef(.coUniform, "CO uniform", .shirt, .medium, .contraband, value: 12, purpose: "Staff corridors; strong close-inspection risk.", tint: Outfit.co.color),
        ItemDef(.visitorClothes, "Visitor clothes", .shirt, .medium, .contraband, value: 7, purpose: "Visiting and admin waiting areas during visiting hours.", tint: Outfit.visitor.color),
        ItemDef(.kitchenWhites, "Kitchen whites", .shirt, .medium, .restricted, value: 3, purpose: "Kitchen and food storage on shift.", permittedBy: [.kitchen], tint: Outfit.kitchenWhites.color),
        ItemDef(.laundryWhites, "Laundry whites", .shirt, .medium, .restricted, value: 3, purpose: "Laundry, delivery routes, cart bays.", permittedBy: [.laundry], tint: Outfit.laundryWhites.color),
        ItemDef(.ppeGown, "PPE gown & mask", .gown, .medium, .restricted, value: 3, purpose: "The isolation delivery route.", permittedBy: [.infirmary], tint: Outfit.ppe.color),
        ItemDef(.chaplainShirt, "Chaplain shirt", .shirt, .medium, .contraband, value: 6, purpose: "Chapel and quiet-room service areas.", tint: Outfit.chaplain.color),
    ]

    /// Is this item allowed for the player given their job/flags?
    public static func isPermitted(_ id: ItemID, job: JobID?) -> Bool {
        let d = def(id)
        switch d.legality {
        case .legal: return true
        case .restricted: return job.map { d.permittedBy.contains($0) } ?? false
        case .contraband, .dangerous: return false
        }
    }
}
