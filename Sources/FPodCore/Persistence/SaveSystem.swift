import Foundation

/// Versioned, validated saves with an atomic write and a backup.
public enum SaveSystem {
    public static let currentVersion = 1

    public struct Envelope: Codable {
        public var version: Int
        public var checksum: UInt64
        public var savedAt: Double
        public var label: String
        /// The encoded GameState; the checksum covers these exact bytes.
        public var body: Data
    }

    public enum SaveError: Error { case corrupt, versionTooNew, invalid(String) }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    public static func encode(_ state: GameState, label: String = "") throws -> Data {
        let body = try encoder().encode(state)
        let env = Envelope(version: currentVersion, checksum: stableHashData(body), savedAt: Date().timeIntervalSince1970, label: label, body: body)
        return try encoder().encode(env)
    }

    public static func decode(_ data: Data) throws -> GameState {
        let env = try JSONDecoder().decode(Envelope.self, from: data)
        if env.version > currentVersion { throw SaveError.versionTooNew }
        if stableHashData(env.body) != env.checksum { throw SaveError.corrupt }
        var st = try JSONDecoder().decode(GameState.self, from: env.body)
        try migrate(&st, from: env.version)
        try validate(st)
        return st
    }

    /// Upgrades older save layouts in place.
    static func migrate(_ s: inout GameState, from v: Int) throws {
        if v < 1 { throw SaveError.invalid("pre-release save") }
        s.version = currentVersion
    }

    public static func validate(_ s: GameState) throws {
        if s.day < 1 { throw SaveError.invalid("day") }
        if s.minute < 0 || s.minute >= 1440 { throw SaveError.invalid("minute") }
        if s.credits < 0 { throw SaveError.invalid("credits") }
        let ledgerSum = s.ledger.reduce(0) { $0 + $1.delta }
        if let last = s.ledger.last, last.balance != s.credits { throw SaveError.invalid("ledger balance") }
        if s.ledger.count < 400 && ledgerSum != s.credits { throw SaveError.invalid("ledger sum") }
        for st in s.inventory.all where st.1.qty <= 0 { throw SaveError.invalid("stack qty") }
        let map = WorldShared.map
        if !map.walkableStatic(s.player.pos.tile) && s.player.hiddenIn == nil { throw SaveError.invalid("player position") }
    }

    public static func stableHashData(_ d: Data) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in d {
            h ^= UInt64(b)
            h = h &* 0x100_0000_01b3
        }
        return h
    }

    // MARK: Files

    public static func write(_ state: GameState, to url: URL, label: String = "") throws {
        try writeData(try encode(state, label: label), to: url)
    }

    /// Atomic write with a backup of the previous file.
    public static func writeData(_ data: Data, to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        let backup = url.appendingPathExtension("bak")
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: url, to: backup)
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: tmp, to: url)
    }

    /// Loads the save, falling back to the backup if the main file is damaged.
    public static func load(from url: URL) -> GameState? {
        if let d = try? Data(contentsOf: url), let s = try? decode(d) { return s }
        let backup = url.appendingPathExtension("bak")
        if let d = try? Data(contentsOf: backup), let s = try? decode(d) { return s }
        return nil
    }
}
