import Foundation

public enum TileKind: UInt8, Codable {
    case void = 0
    case wall
    case floor
    case door
    case window
    case fence
    case grass
    case concrete
    case track
    case road
    case woods
    case tunnel
    case water
    case court

    public var walkableBase: Bool {
        switch self {
        case .floor, .door, .grass, .concrete, .track, .road, .woods, .tunnel, .court: return true
        default: return false
        }
    }
    /// Blocks sight regardless of doors/props.
    public var opaqueBase: Bool {
        switch self {
        case .void, .wall: return true
        default: return false
        }
    }
    public var outdoor: Bool {
        switch self {
        case .grass, .concrete, .track, .road, .woods, .fence, .water, .court: return true
        default: return false
        }
    }
}

/// Districts double as camera areas.
public enum District: String, Codable, CaseIterable {
    case fpod, control, yard, vocrehab, kitchen, admin, support, restricted, service, perimeter, corridor, grounds

    public var title: String {
        switch self {
        case .fpod: return "F-Pod"
        case .control: return "Control"
        case .yard: return "Rec Yard"
        case .vocrehab: return "Vocational Rehab"
        case .kitchen: return "Kitchen & Chow"
        case .admin: return "Administration"
        case .support: return "Support Wing"
        case .restricted: return "Observation Wing"
        case .service: return "Service Tunnels"
        case .perimeter: return "Perimeter"
        case .corridor: return "Corridors"
        case .grounds: return "Grounds"
        }
    }
    /// Subtle floor tint per district (same art system, slight palette variation).
    public var floorTint: RGBA {
        switch self {
        case .fpod: return RGBA(hex: 0xD5DFE2)
        case .control: return RGBA(hex: 0xC9D2D8)
        case .yard: return Palette.grass
        case .vocrehab: return RGBA(hex: 0xD9DCD3)
        case .kitchen: return RGBA(hex: 0xDCE3DF)
        case .admin: return RGBA(hex: 0xDED9CF)
        case .support: return RGBA(hex: 0xD8DDE4)
        case .restricted: return RGBA(hex: 0xD2D6D9)
        case .service: return Palette.tunnel
        case .perimeter: return Palette.grassDark
        case .corridor: return RGBA(hex: 0xD3DCDF)
        case .grounds: return Palette.concrete
        }
    }
}

/// Access class of a zone; plausibility rules key off this.
public enum ZoneClass: String, Codable, CaseIterable {
    case home           // pod dayroom, showers, laundry alcove
    case ownCell        // assigned cell (resolved at runtime)
    case cell           // other patients' cells
    case closet         // janitor/supply closets
    case transit        // corridors
    case dining
    case yard
    case work           // job site (kitchen prep, laundry, workshop...)
    case program        // therapy, library, chapel
    case medical        // infirmary
    case isolation      // isolation room route
    case adminPublic    // visiting, commissary line, waiting
    case records        // records-facing desks
    case staffOnly      // officer station, staff corridors, offices
    case secure         // control booth, key storage
    case restricted     // observation wing
    case service        // tunnels, cart bays, maintenance
    case perimeter      // between fences, outside
}

public enum ObjKind: String, Codable, CaseIterable {
    case bunk, bed, table, bench, chair, tv, desk, counter, shelf, locker, toilet, sink
    case shower, divider, washer, dryer, foldTable, hamper, mopBucket, closetShelf
    case stove, prepTable, dishRack, fridge, pantry, crate, sewing, workbench, toolBoard
    case console, keyCabinet, phone, medWindow, commissary, noticeBoard, pew, altar, plant
    case weights, hoop, horseshoes, garden, bleacher, tree, tower, dumpster, vent, drain
    case hatch, donationBox, filing, rug, sign, lamp, chartRack, stack, cartBay, ramp
    case restraintChair, mattress, van, gate, fenceGap, culvert, kennel, trayCart, lawn
    case piano, mailbox, waterCooler, typewriter, easel

    /// Blocks movement.
    public var solid: Bool {
        switch self {
        case .rug, .sign, .drain, .hatch, .vent, .garden, .lawn, .mattress, .horseshoes, .fenceGap, .culvert, .ramp: return false
        default: return true
        }
    }
    /// Tall enough to block line of sight.
    public var tall: Bool {
        switch self {
        case .shelf, .locker, .shower, .divider, .closetShelf, .pantry, .fridge, .toolBoard, .keyCabinet,
             .tree, .tower, .stack, .dumpster, .filing, .washer, .dryer, .van, .kennel:
            return true
        default: return false
        }
    }
}

public enum DoorKind: String, Codable {
    case interior   // ordinary room door
    case cell       // cell door
    case secure     // controlled sally/secure door
    case gate       // outdoor fence gate
    case hatch      // utility hatch (portal)
}

public enum Activity: String, Codable, CaseIterable {
    case sleep, wakeCount, medPass, breakfast, work, therapy, chow, afternoon, rec, dinner, freeTime
    case eveningCount, settle, lightsOut, brunch, visiting, chapel, review

    public var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .wakeCount: return "Wake & count"
        case .medPass: return "Med pass"
        case .breakfast: return "Breakfast"
        case .work: return "Work detail"
        case .therapy: return "Therapy group"
        case .chow: return "Chow"
        case .afternoon: return "Work & errands"
        case .rec: return "Rec yard"
        case .dinner: return "Dinner"
        case .freeTime: return "Free time"
        case .eveningCount: return "Evening count"
        case .settle: return "Return & settle"
        case .lightsOut: return "Lights out"
        case .brunch: return "Brunch"
        case .visiting: return "Visiting"
        case .chapel: return "Chapel & quiet"
        case .review: return "Review hearing"
        }
    }
    public var isCount: Bool { self == .wakeCount || self == .eveningCount }
    /// Patients confined to the pod (cell doors may still open).
    public var podLocked: Bool {
        switch self {
        case .sleep, .wakeCount, .medPass, .eveningCount, .settle, .lightsOut: return true
        default: return false
        }
    }
}

public indirect enum AccessRule: Codable, Hashable {
    case open
    case never
    case staff
    case schedule([Activity])
    case key(ItemID)
    case flag(Flag)
    case job(JobID)
    case trust(Int)
    case any([AccessRule])
    case all([AccessRule])
}

public struct ZoneDef: Codable, Hashable {
    public var id: String
    public var name: String
    public var district: District
    public var cls: ZoneClass
    public var rects: [TileRect]
    public var outdoor: Bool
    /// Optional owner (cell number) for cells.
    public var cellNumber: Int?
}

public struct WorldObject: Codable, Hashable {
    public var id: String
    public var kind: ObjKind
    public var tile: TilePos
    public var w: Int
    public var h: Int
    public var facing: Facing
    public var zone: String
    public var variant: Int
    public var rect: TileRect { TileRect(tile.x, tile.y, w, h) }
    public var center: Vec2 { rect.center }
}

public struct DoorDef: Codable, Hashable {
    public var id: String
    public var tile: TilePos
    /// True if the door sits in a vertical wall (passage runs east-west).
    public var vertical: Bool
    public var kind: DoorKind
    public var rule: AccessRule
    public var name: String
}

public struct Spot: Codable, Hashable {
    public var id: String
    public var pos: Vec2
    public var facing: Facing
}

public struct HatchLink: Codable, Hashable {
    public var id: String
    public var a: TilePos
    public var b: TilePos
    public var rule: AccessRule
    /// Flag that reveals this hatch on the map / makes it usable.
    public var discoveredBy: Flag?
}

public struct CameraDef: Codable, Hashable {
    public var id: String
    public var pos: Vec2
    public var heading: Double
    public var sweep: Double      // radians of sweep amplitude (0 = fixed)
    public var period: Double     // seconds for a full sweep cycle
    public var range: Double
    public var fov: Double
}
