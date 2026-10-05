import Foundation

/// Authored hiding place. Occupancy is explicit; discovery requires a visible search.
public struct HideSpotDef: Hashable {
    public let objectID: String
    public let title: String
    public let capacity: Int
    /// Base chance a staff inspection finds the player (scaled up if they saw you enter).
    public let discovery: Double
    public let icon: Icon
}

public enum HideSpots {
    public static let all: [HideSpotDef] = {
        var out: [HideSpotDef] = []
        for n in 1...10 { out.append(HideSpotDef(objectID: "fpod.cell\(n).bunk", title: "Under the bunk", capacity: 1, discovery: 0.35, icon: .bed)) }
        for k in 1...3 { out.append(HideSpotDef(objectID: "fpod.shower\(k)", title: "Shower stall", capacity: 1, discovery: 0.3, icon: .shower)) }
        out.append(HideSpotDef(objectID: "fpod.hamper", title: "Laundry hamper", capacity: 1, discovery: 0.25, icon: .laundry))
        out.append(HideSpotDef(objectID: "fpod.hamper2", title: "Laundry hamper", capacity: 1, discovery: 0.25, icon: .laundry))
        out.append(HideSpotDef(objectID: "fpod.closet.shelf", title: "Behind closet shelving", capacity: 1, discovery: 0.3, icon: .door))
        for k in 1...3 { out.append(HideSpotDef(objectID: "laundry.bin\(k)", title: "Laundry bin", capacity: 1, discovery: 0.25, icon: .laundry)) }
        out.append(HideSpotDef(objectID: "laundry.uniforms", title: "Uniform rack", capacity: 1, discovery: 0.3, icon: .shirt))
        out.append(HideSpotDef(objectID: "library.stacks", title: "Library stacks", capacity: 1, discovery: 0.2, icon: .book))
        for k in 1...4 { out.append(HideSpotDef(objectID: "chapel.pew\(k)", title: "Behind a pew", capacity: 1, discovery: 0.3, icon: .candle)) }
        for k in 1...4 { out.append(HideSpotDef(objectID: "chapel.pewb\(k)", title: "Behind a pew", capacity: 1, discovery: 0.3, icon: .candle)) }
        out.append(HideSpotDef(objectID: "yard.dumpster", title: "Dumpster", capacity: 1, discovery: 0.2, icon: .box))
        out.append(HideSpotDef(objectID: "cartbay.dumpster", title: "Dumpster", capacity: 1, discovery: 0.2, icon: .box))
        out.append(HideSpotDef(objectID: "cartbay.laundrycart", title: "Inside a laundry cart", capacity: 1, discovery: 0.3, icon: .cart))
        out.append(HideSpotDef(objectID: "storage.crate", title: "Behind crates", capacity: 1, discovery: 0.3, icon: .box))
        out.append(HideSpotDef(objectID: "cold.crate", title: "Behind crates", capacity: 1, discovery: 0.35, icon: .box))
        out.append(HideSpotDef(objectID: "ante.bin", title: "Linen bin", capacity: 1, discovery: 0.3, icon: .laundry))
        out.append(HideSpotDef(objectID: "tunnel.alcove1", title: "Tunnel alcove", capacity: 2, discovery: 0.25, icon: .hide))
        out.append(HideSpotDef(objectID: "tunnel.alcove2", title: "Tunnel alcove", capacity: 2, discovery: 0.25, icon: .hide))
        out.append(HideSpotDef(objectID: "tunnel.alcove3", title: "Tunnel alcove", capacity: 2, discovery: 0.25, icon: .hide))
        out.append(HideSpotDef(objectID: "ceiling.records", title: "Ceiling space", capacity: 1, discovery: 0.1, icon: .arrowUp))
        out.append(HideSpotDef(objectID: "ceiling.voc", title: "Ceiling space", capacity: 1, discovery: 0.1, icon: .arrowUp))
        out.append(HideSpotDef(objectID: "pump.crate", title: "Behind the pump", capacity: 1, discovery: 0.2, icon: .tools))
        return out
    }()
}

public enum Stashes {
    public static let all: [StashDef] = {
        var out: [StashDef] = []
        for n in 1...10 {
            out.append(StashDef(objectID: "fpod.cell\(n).locker", title: "Locker", slots: 6, maxSize: .medium, discovery: 0.95, legal: true, needs: nil))
            out.append(StashDef(objectID: "fpod.cell\(n).bunk", title: "Under the mattress", slots: 2, maxSize: .small, discovery: 0.6, legal: false, needs: nil))
            out.append(StashDef(objectID: "fpod.cell\(n).toilet", title: "Toilet tank", slots: 1, maxSize: .small, discovery: 0.35, legal: false, needs: nil))
            out.append(StashDef(objectID: "fpod.cell\(n).vent", title: "Vent", slots: 2, maxSize: .small, discovery: 0.15, legal: false, needs: .screwdriver))
        }
        out.append(StashDef(objectID: "fpod.hamper", title: "Laundry hamper", slots: 2, maxSize: .medium, discovery: 0.3, legal: false, needs: nil))
        out.append(StashDef(objectID: "fpod.hamper2", title: "Laundry hamper", slots: 2, maxSize: .medium, discovery: 0.3, legal: false, needs: nil))
        out.append(StashDef(objectID: "library.stacks", title: "Library stacks", slots: 1, maxSize: .small, discovery: 0.2, legal: false, needs: nil))
        out.append(StashDef(objectID: "donation.box", title: "Donation box", slots: 3, maxSize: .medium, discovery: 0.25, legal: false, needs: nil))
        out.append(StashDef(objectID: "laundry.bin1", title: "Laundry bin", slots: 2, maxSize: .medium, discovery: 0.3, legal: false, needs: nil))
        return out + SupplyStashes.list
    }()
}

/// Hatches: interacting with the object moves the player across the link.
public enum Hatches {
    /// object id -> (link id, side true = building side 'a')
    public static let objects: [String: (link: String, sideA: Bool)] = [
        "hatch.fpod": ("hatch.fpod", true), "hatch.t.a": ("hatch.fpod", false),
        "hatch.cartbay": ("hatch.cartbay", true), "hatch.t.b": ("hatch.cartbay", false),
        "hatch.kitchen": ("hatch.kitchen", true), "hatch.t.c": ("hatch.kitchen", false),
        "hatch.records": ("hatch.records", true), "hatch.t.d": ("hatch.records", false),
        "hatch.infirmary": ("hatch.infirmary", true), "hatch.t.e": ("hatch.infirmary", false),
        "culvert.in": ("culvert", true), "culvert.out": ("culvert", false),
    ]
}
