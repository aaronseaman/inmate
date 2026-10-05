import Foundation

// MARK: - Outfit wear: dirt, tears and stains (sweat is in the movement step)

extension Game {
    /// Condition lost per tile walked through grimy places while disguised.
    public static let grimeWearPerTile = 0.35

    static func grimyZone(_ z: ZoneDef) -> Bool {
        z.cls == .service || z.cls == .perimeter || (z.outdoor && z.district == .grounds)
    }

    /// Lowers a disguise's condition with a short note. Own scrubs don't wear out.
    func wearOutfit(_ amount: Double, _ icon: Icon, _ text: String) {
        guard s.player.outfit != .tanScrubs else { return }
        let before = s.player.outfitCondition
        s.player.outfitCondition = max(0, before - amount)
        toast(icon, "\(text) — outfit \(Int(s.player.outfitCondition.rounded()))%")
        if before >= 35 && s.player.outfitCondition < 35 {
            toast(.soap, "That disguise won't pass a close look now. Wash it at a sink.", danger: true)
        }
    }

    /// Crawling through a hatch or culvert snags cloth.
    func outfitThroughHatch(_ objectID: String) {
        guard let o = map.object(id: objectID) else { return }
        switch o.kind {
        case .culvert: wearOutfit(18, .needle, "Snagged a sleeve in the culvert")
        case .hatch: wearOutfit(8, .needle, "Caught a hem on the hatch frame")
        default: break
        }
    }

    /// Some hiding places leave a mark.
    func outfitAfterHide(_ objectID: String) {
        guard let o = map.object(id: objectID) else { return }
        switch o.kind {
        case .dumpster: wearOutfit(22, .water, "Something in the dumpster was wet")
        case .vent, .drain: wearOutfit(10, .water, "Dust and grime from the \(o.kind == .vent ? "vent" : "drain")")
        default: break
        }
    }

    /// Meals in a disguise risk a stain: always on soup day, otherwise one day in three.
    func outfitAtMeal(soup: Bool) {
        guard s.player.outfit != .tanScrubs else { return }
        if soup {
            wearOutfit(20, .meal, "Soup on the cuff")
        } else if stableHash("stain\(s.seed)\(s.day)") % 3 == 0 {
            wearOutfit(15, .cup, "Somebody's coffee, down your front")
        }
    }
}
