import Foundation

public struct JobDef {
    public let id: JobID
    public let title: String
    public let icon: Icon
    public let supervisor: NPCID
    public let zone: String
    public let stationSpot: String
    public let stationObject: String
    public let minigame: MinigameID
    public let payMin: Int
    public let payMax: Int
    public let uniform: Outfit?
    public let access: String
    public let eligibility: Cond
    public let eligibilityText: String
    public let riskChoice: String
}

public enum Jobs {
    public static let all: [JobID: JobDef] = {
        var d: [JobID: JobDef] = [:]
        for j in list { d[j.id] = j }
        return d
    }()
    public static func def(_ id: JobID) -> JobDef { all[id]! }

    static let list: [JobDef] = [
        JobDef(id: .janitorial, title: "Janitorial", icon: .mop, supervisor: .haskins, zone: "fpod.closet",
               stationSpot: "fpod.center", stationObject: "fpod.closet.mop", minigame: .mop, payMin: 6, payMax: 9,
               uniform: nil, access: "Janitor closets, the cart, mopping anywhere on the route without raising eyebrows.",
               eligibility: .always, eligibilityText: "Open to new arrivals (trial shift on intake day).",
               riskChoice: "The closet hatch: report the loose panel, or keep it to yourself."),
        JobDef(id: .kitchen, title: "Kitchen", icon: .pan, supervisor: .odell, zone: "kitchen.prep",
               stationSpot: "prep.station", stationObject: "prep.table1", minigame: .kitchenLine, payMin: 7, payMax: 12,
               uniform: .kitchenWhites, access: "Kitchen and food storage on shift; kitchen whites.",
               eligibility: .any([.flag(.rosaVouched), .flag(.tryoutKitchen), .trustTier(2)]), eligibilityText: "Rosa vouches for you, or trust tier 2.",
               riskChoice: "Sugar packets in your pocket: Rosa's economy, Odell's rules."),
        JobDef(id: .laundry, title: "Laundry", icon: .laundry, supervisor: .feld, zone: "voc.laundry",
               stationSpot: "laundry.station", stationObject: "laundry.fold", minigame: .laundrySort, payMin: 6, payMax: 10,
               uniform: .laundryWhites, access: "Laundry, delivery routes, the cart bay; laundry whites.",
               eligibility: .any([.trustTier(2), .peer(.dutch, 20), .flag(.favorDutchVouch), .flag(.tryoutLaundry)]), eligibilityText: "Trust tier 2, or Dutch puts in a word.",
               riskChoice: "The uniform rack: every outfit on campus passes through here."),
        JobDef(id: .library, title: "Library", icon: .book, supervisor: .abernathy, zone: "support.library",
               stationSpot: "library.station", stationObject: "library.desk", minigame: .libraryShelve, payMin: 6, payMax: 10,
               uniform: nil, access: "Law library, case research, and the peer message trade.",
               eligibility: .any([.trustTier(2), .flag(.allyMarisol), .flag(.tryoutLibrary)]), eligibilityText: "Trust tier 2, or Marisol's recommendation.",
               riskChoice: "Carry a folded note between peers — or refuse."),
        JobDef(id: .infirmary, title: "Infirmary orderly", icon: .stethoscope, supervisor: .okonjo, zone: "support.infirmary",
               stationSpot: "infirmary.station", stationObject: "infirmary.desk", minigame: .supplyMatch, payMin: 7, payMax: 11,
               uniform: nil, access: "Infirmary corridors, escort deliveries, the PPE route.",
               eligibility: .any([.trustTier(3), .all([.trustTier(2), .any([.peer(.ada, 20), .flag(.tryoutInfirmary)])])]), eligibilityText: "Trust tier 3, or tier 2 with Ada's trust.",
               riskChoice: "A miscount on the supply sheet: report it or cover it."),
        JobDef(id: .workshop, title: "Workshop", icon: .tools, supervisor: .feld, zone: "voc.workshop",
               stationSpot: "workshop.station", stationObject: "workshop.bench1", minigame: .sewing, payMin: 6, payMax: 11,
               uniform: nil, access: "Tools (counted), repairs, the scrap crate.",
               eligibility: .any([.trustTier(2), .peer(.kenji, 15), .peer(.staticFell, 15), .flag(.tryoutWorkshop)]), eligibilityText: "Trust tier 2, or Kenji or Static vouches.",
               riskChoice: "Copper wire from the scrap crate: Static needs it; Feld counts it."),
        JobDef(id: .grounds, title: "Grounds", icon: .seed, supervisor: .feld, zone: "yard",
               stationSpot: "garden.tend", stationObject: "garden.2", minigame: .garden, payMin: 6, payMax: 10,
               uniform: nil, access: "Garden beds and the east lawn near the fence.",
               eligibility: .any([.trustTier(2), .flag(.allyLou), .flag(.tryoutGrounds)]), eligibilityText: "Trust tier 2, or Lou's say-so.",
               riskChoice: "From the lawn you can watch the K-9 patrol — and be watched."),
    ]
}
