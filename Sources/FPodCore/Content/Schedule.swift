import Foundation

public struct ScheduleBlock: Codable, Hashable {
    public var start: Int   // minutes from midnight
    public var end: Int
    public var activity: Activity
    public init(_ start: Int, _ end: Int, _ activity: Activity) { self.start = start; self.end = end; self.activity = activity }
}

/// A personal appointment that overrides the player's ordinary obligation.
public struct Appointment: Codable, Hashable {
    public var id: String
    public var day: Int
    public var start: Int
    public var end: Int
    public var title: String
    public var icon: Icon
    public var spot: String
    public var npc: NPCID?
    public var quest: QuestID?
    public var attended: Bool = false
}

public enum Schedule {
    public static let wakeMinute = 360
    public static let lightsOutMinute = 1320

    public static let weekday: [ScheduleBlock] = [
        ScheduleBlock(0, 360, .sleep),
        ScheduleBlock(360, 380, .wakeCount),
        ScheduleBlock(380, 420, .medPass),
        ScheduleBlock(420, 480, .breakfast),
        ScheduleBlock(480, 660, .work),
        ScheduleBlock(660, 720, .therapy),
        ScheduleBlock(720, 780, .chow),
        ScheduleBlock(780, 900, .afternoon),
        ScheduleBlock(900, 1020, .rec),
        ScheduleBlock(1020, 1080, .dinner),
        ScheduleBlock(1080, 1260, .freeTime),
        ScheduleBlock(1260, 1280, .eveningCount),
        ScheduleBlock(1280, 1320, .settle),
        ScheduleBlock(1320, 1440, .lightsOut),
    ]

    public static let weekend: [ScheduleBlock] = [
        ScheduleBlock(0, 360, .sleep),
        ScheduleBlock(360, 380, .wakeCount),
        ScheduleBlock(380, 420, .medPass),
        ScheduleBlock(420, 510, .brunch),
        ScheduleBlock(510, 600, .chapel),
        ScheduleBlock(600, 780, .visiting),
        ScheduleBlock(780, 960, .rec),
        ScheduleBlock(960, 1020, .dinner),
        ScheduleBlock(1020, 1260, .freeTime),
        ScheduleBlock(1260, 1280, .eveningCount),
        ScheduleBlock(1280, 1320, .settle),
        ScheduleBlock(1320, 1440, .lightsOut),
    ]

    /// Day 1 is a Monday.
    public static func weekdayIndex(_ day: Int) -> Int { (day - 1) % 7 }
    public static func isWeekend(_ day: Int) -> Bool { weekdayIndex(day) >= 5 }
    public static let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    public static func dayName(_ day: Int) -> String { dayNames[weekdayIndex(day)] }

    public static func blocks(day: Int, storyOverrides: [ScheduleBlock] = []) -> [ScheduleBlock] {
        var base = isWeekend(day) ? weekend : weekday
        for o in storyOverrides {
            // Replace overlapped portions with the override block.
            var out: [ScheduleBlock] = []
            for b in base {
                if b.end <= o.start || b.start >= o.end { out.append(b); continue }
                if b.start < o.start { out.append(ScheduleBlock(b.start, o.start, b.activity)) }
                if b.end > o.end { out.append(ScheduleBlock(o.end, b.end, b.activity)) }
            }
            out.append(o)
            base = out.sorted { $0.start < $1.start }
        }
        return base
    }

    public static func block(day: Int, minute: Double, overrides: [ScheduleBlock] = []) -> ScheduleBlock {
        let m = Int(minute)
        for b in blocks(day: day, storyOverrides: overrides) where m >= b.start && m < b.end { return b }
        return ScheduleBlock(1320, 1440, .lightsOut)
    }

    public static func nextBlock(day: Int, minute: Double, overrides: [ScheduleBlock] = []) -> ScheduleBlock? {
        let m = Int(minute)
        return blocks(day: day, storyOverrides: overrides).first { $0.start > m }
    }

    public static func clockString(_ minute: Double) -> String {
        let m = Int(minute) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    public static func icon(_ a: Activity) -> Icon {
        switch a {
        case .sleep, .lightsOut: return .moon
        case .wakeCount, .eveningCount: return .count
        case .medPass: return .pills
        case .breakfast, .chow, .dinner, .brunch: return .meal
        case .work: return .work
        case .therapy: return .group
        case .afternoon: return .work
        case .rec: return .ball
        case .freeTime: return .sun
        case .settle: return .bed
        case .visiting: return .visit
        case .chapel: return .candle
        case .review: return .gavel
        }
    }
}
