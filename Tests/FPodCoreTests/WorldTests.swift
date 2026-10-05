import XCTest
@testable import FPodCore

final class WorldTests: XCTestCase {
    let map = WorldShared.map

    func testMapBuildsWithoutProblems() {
        let b = MapBuilder(width: Campus.width, height: Campus.height)
        _ = b
        // Rebuild to collect problems.
        let builder = MapBuilder(width: Campus.width, height: Campus.height)
        Campus.buildPerimeter(builder); Campus.buildYard(builder); Campus.buildVocRehab(builder); Campus.buildKitchen(builder)
        Campus.buildCorridors(builder); Campus.buildFPod(builder); Campus.buildControl(builder); Campus.buildSupport(builder)
        Campus.buildAdmin(builder); Campus.buildObservation(builder); Campus.buildTunnels(builder)
        _ = builder.finalize()
        XCTAssertEqual(builder.problems, [], "map authoring problems")
    }

    func testAllSpotsWalkable() {
        for (id, sp) in map.spots {
            XCTAssertTrue(map.walkableStatic(sp.pos.tile), "spot \(id) at \(sp.pos) is not walkable")
        }
    }

    func testAllReferencedSpotsExist() {
        for def in Cast.all.values {
            var ids: [String] = def.jobSpots
            for p in Array(def.posts.values) + [def.fallback] {
                switch p {
                case .spot(let s): ids.append(s)
                case .patrol(let ss): ids += ss
                default: break
                }
            }
            for id in ids { XCTAssertNotNil(map.spot(id), "\(def.id) references missing spot \(id)") }
            if let c = def.cell {
                XCTAssertNotNil(map.spot("fpod.cell\(c).count"))
                XCTAssertNotNil(map.spot("fpod.cell\(c).bunk\(def.bunk == 0 ? "A" : "B")"))
            }
        }
        for j in Jobs.all.values {
            XCTAssertNotNil(map.spot(j.stationSpot), "job \(j.id) station spot")
            XCTAssertNotNil(map.object(id: j.stationObject), "job \(j.id) station object")
            XCTAssertNotNil(map.zone(id: j.zone), "job \(j.id) zone")
        }
        for h in HideSpots.all { XCTAssertNotNil(map.object(id: h.objectID), "hide spot \(h.objectID)") }
        for s in Stashes.all { XCTAssertNotNil(map.object(id: s.objectID), "stash \(s.objectID)") }
        for (o, _) in Hatches.objects { XCTAssertNotNil(map.object(id: o), "hatch object \(o)") }
    }

    func testHatchArrivalTilesWalkable() {
        for h in map.hatches {
            XCTAssertTrue(map.walkableStatic(h.a), "hatch \(h.id) side a")
            XCTAssertTrue(map.walkableStatic(h.b), "hatch \(h.id) side b")
        }
    }

    func testEveryCellReachableFromDayroomAndCorridor() {
        let start = map.spot("fpod.center")!.pos.tile
        for n in 1...10 {
            let target = map.spot("fpod.cell\(n).bunkA")!.pos.tile
            XCTAssertNotNil(Navigation.findPath(map, from: start, to: target, canPass: { _ in true }), "cell \(n)")
        }
        // Every district reachable with all doors open (structural connectivity).
        let probes = ["yard.post", "laundry.station", "workshop.station", "prep.station", "dining.t1.a", "control.seat",
                      "library.station", "chapel.lead", "infirmary.station", "clerk.client", "visit.t1.in", "hearing.self",
                      "obs.nurse.seat", "seclusion.in", "review.self", "sato.client", "lawlib.seat", "quiet.seat", "isolation.patient",
                      "commissary.line.1", "trust.client", "lobby.seat", "garden.tend", "grounds.shed"]
        for p in probes {
            let t = map.spot(p)!.pos.tile
            XCTAssertNotNil(Navigation.findPath(map, from: start, to: t, canPass: { _ in true }), "unreachable: \(p)")
        }
    }

    func testTunnelsReachableOnlyThroughHatches() {
        let start = map.spot("fpod.center")!.pos.tile
        let tunnel = map.spot("tunnels.patrol.1")!.pos.tile
        XCTAssertNil(Navigation.findPath(map, from: start, to: tunnel, canPass: { _ in true }), "tunnels must be a separate region")
        let landing = TilePos(167, 60)
        XCTAssertNotNil(Navigation.findPath(map, from: landing, to: tunnel, canPass: { _ in true }))
    }

    func testWallsBlockVision() {
        // Officer station (x 12..20) and cell F-1 (x 28..31) are separated by walls.
        let station = Vec2(14.5, 48.5)
        let cell = Vec2(29.5, 48.5)
        XCTAssertFalse(Sight.clear(map, station, cell, opaque: { self.map.kinds[$0] == .wall || self.map.kinds[$0] == .void || self.map.propOpaque[$0] }))
        // Station windows let the officer see the dayroom.
        let dayroom = Vec2(18.5, 58.5)
        XCTAssertTrue(Sight.clear(map, Vec2(18.5, 51.5), dayroom, opaque: { self.map.kinds[$0] == .wall || self.map.kinds[$0] == .void }))
    }

    func testNoisePropagationRespectsWallsAndDoors() {
        let src = map.spot("fpod.center")!.pos.tile
        let open = Sight.propagateNoise(map, from: src, loudness: 18, closedDoor: { _ in false })
        let closed = Sight.propagateNoise(map, from: src, loudness: 18, closedDoor: { _ in true })
        // Into cell F-2 (behind a door): audible when open, attenuated when closed.
        let inCell = map.idx(TilePos(34, 49))
        XCTAssertGreaterThan(open[inCell] ?? 0, closed[inCell] ?? 0)
        // Never through solid wall into the control booth.
        let booth = map.idx(TilePos(55, 49))
        XCTAssertNil(open[booth])
    }

    func testDoorsConnectWalkableTiles() {
        for d in map.doors {
            let a = d.vertical ? TilePos(d.tile.x - 1, d.tile.y) : TilePos(d.tile.x, d.tile.y - 1)
            let b = d.vertical ? TilePos(d.tile.x + 1, d.tile.y) : TilePos(d.tile.x, d.tile.y + 1)
            XCTAssertTrue(map.kind(a).walkableBase && map.kind(b).walkableBase, "door \(d.id)")
        }
    }

    func testPathNoCornerCutting() {
        let from = map.spot("fpod.center")!.pos.tile
        let to = map.spot("fpod.cell3.bunkA")!.pos.tile
        let path = Navigation.findPath(map, from: from, to: to, canPass: { _ in true })!
        for k in 1..<path.count {
            let a = path[k - 1], b = path[k]
            if a.x != b.x && a.y != b.y {
                XCTAssertTrue(map.walkableStatic(TilePos(a.x, b.y)) && map.walkableStatic(TilePos(b.x, a.y)), "corner cut at \(a)->\(b)")
            }
        }
    }
}
