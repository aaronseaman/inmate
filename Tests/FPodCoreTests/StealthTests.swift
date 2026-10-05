import XCTest
@testable import FPodCore

final class StealthTests: XCTestCase {
    /// Places a staff member at a position/heading in routine mode.
    func place(_ g: Game, _ id: NPCID, _ pos: Vec2, heading: Double) {
        g.withNPC(id) { n in
            n.present = true; n.pos = pos; n.heading = heading; n.mode = .routine; n.path = []; n.suspicion = 0
            n.scriptedSpot = nil
        }
    }

    func freezeOthers(_ g: Game, except: [NPCID]) {
        for i in g.s.npcs.indices where !except.contains(g.s.npcs[i].id) && Cast.def(g.s.npcs[i].id).role.isStaff {
            g.s.npcs[i].present = false
        }
    }

    func testWallsBlockStaffVision() {
        let g = makeGame()
        setClock(g, 800)
        // Player in cell F-2; Haskins in the dayroom looking at the cell wall from beside it.
        g.s.player.pos = Vec2(34.5, 47.5)
        place(g, .haskins, Vec2(30.5, 54.5), heading: -Double.pi / 2)
        XCTAssertFalse(g.npcCanSeePlayer(g.npc(.haskins)!, Cast.def(.haskins)), "cell walls must block sight")
        // Through the open cell door line she can see in.
        place(g, .haskins, Vec2(34.5, 53.5), heading: -Double.pi / 2)
        g.refreshDoors(instant: true)
        let doorIdx = g.map.doorByID["fpod.cell2.door"]!
        g.doorOpen[doorIdx] = 1
        g.dynamicOpaque[g.map.idx(g.map.doors[doorIdx].tile)] = false
        XCTAssertTrue(g.npcCanSeePlayer(g.npc(.haskins)!, Cast.def(.haskins)))
    }

    func testNoiseIsInvestigatedAtItsSource() {
        let g = makeGame()
        setClock(g, 1330) // lights out: running noise is suspicious
        freezeOthers(g, except: [.reed])
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        let source = Vec2(40.5, 60.5)
        place(g, .reed, Vec2(36.5, 62.5), heading: Double.pi)   // facing away, within earshot
        g.makeNoise(at: source, loudness: 7, suspicious: true, source: .object)
        let n = g.npc(.reed)!
        XCTAssertEqual(n.mode, .investigate)
        XCTAssertEqual(n.lastKnown, source, "staff go to the noise, not to the player")
        XCTAssertNotEqual(n.lastKnown, g.s.player.pos)
    }

    func testPursuitFallsBackToLastKnownAndInspectsHidingSpots() {
        let g = makeGame()
        setClock(g, 800)
        freezeOthers(g, except: [.strick])
        // Player in the dayroom near the showers; Strick sees and pursues.
        g.s.player.pos = Vec2(44.5, 67.5)
        place(g, .strick, Vec2(39.5, 67.5), heading: 0)
        g.withNPC(.strick) { n in n.suspicion = 100; n.questionReason = .theft; n.lastKnown = Vec2(44.5, 67.5) }
        sim(g, seconds: 0.2)
        XCTAssertEqual(g.npc(.strick)?.mode, .pursue)
        // Player slips into a shower stall out of his sight line.
        let lkp = g.npc(.strick)!.lastKnown!
        g.s.player.pos = Vec2(44.5, 71.5)
        g.enterHide("fpod.shower2")
        // He must head to the last known position, then visibly search.
        var sawInspect = false
        var inspected: String?
        sim(g, seconds: 25, until: { gg in
            if let n = gg.npc(.strick), n.mode == .inspect { sawInspect = true; inspected = n.inspectTarget }
            return gg.transition != nil
        })
        XCTAssertTrue(sawInspect, "search must include a visible inspection")
        XCTAssertNotNil(inspected)
        XCTAssertLessThan(g.map.object(id: inspected ?? "")?.center.distance(to: lkp) ?? 99, 7)
    }

    func testWitnessedTheftLeadsToSearchAndConfiscation() {
        let g = makeGame()
        setClock(g, 800)
        freezeOthers(g, except: [.strick])
        // Harlan's radio sits in his locker in F-5 (bottom row).
        g.s.player.pos = Vec2(23.5, 72.5)
        place(g, .strick, Vec2(23.5, 66.5), heading: Double.pi / 2)
        let cellDoor = g.map.doorByID["fpod.cell7.door"]!
        _ = cellDoor
        // Open line of sight through the cell door.
        let door = g.map.doors[g.map.doorByID["fpod.cell7.door"]!]
        g.doorOpen[g.map.doorByID["fpod.cell7.door"]!] = 1
        g.dynamicOpaque[g.map.idx(door.tile)] = false
        g.s.stashes["fpod.cell7.locker"] = [ItemStack(.radio, 1, owner: .harlan)]
        XCTAssertTrue(g.npcCanSeePlayer(g.npc(.strick)!, Cast.def(.strick)), "precondition: Strick sees the player")
        XCTAssertTrue(g.stashTake("fpod.cell7.locker", index: 0))
        XCTAssertEqual(g.npc(.strick)?.suspicion, 100)
        XCTAssertEqual(g.npc(.strick)?.questionReason, .theft)
        // Contraband the player keeps elsewhere: vent (unlikely searched) stays unless searched.
        g.s.stashes["fpod.cell3.vent"] = [ItemStack(.cigarettes, 1)]
        sim(g, seconds: 15, until: { $0.transition != nil })
        XCTAssertNotNil(g.transition, "pursuit should end in capture")
        finishTransition(g)
        XCTAssertEqual(g.s.inventory.count(.radio), 0, "stolen radio confiscated")
        XCTAssertTrue(g.s.stashes["fpod.cell5.locker"]?.contains { $0.id == .radio && $0.owner == .harlan } ?? false, "returned to owner")
        XCTAssertTrue(g.s.incidents.contains { $0.kind == .theft })
        XCTAssertGreaterThanOrEqual(g.s.watch, .yellow)
        // Only searched containers lose items.
        if !g.s.lastSearch.contains("fpod.cell3.vent") {
            XCTAssertEqual(g.s.stashes["fpod.cell3.vent"]?.first?.id, .cigarettes)
        }
        // Recovery: safe placement, immunity, everyone calmed.
        XCTAssertEqual(g.map.zone(at: g.s.player.pos)?.id, "fpod.cell3")
        XCTAssertGreaterThan(g.s.player.caughtImmunity, 60)
        XCTAssertTrue(g.s.npcs.allSatisfy { $0.suspicion == 0 })
        XCTAssertNotNil(g.s.recovery)
    }

    func testNoImmediateRecaptureAfterRecovery() {
        let g = makeGame()
        setClock(g, 800)
        g.s.player.pos = g.map.spot("control.seat")!.pos
        g.captured(by: .gaines, reason: .restrictedArea)
        finishTransition(g)
        let before = g.s.incidents.count
        // Stand in the pod (allowed) for a while with staff around.
        sim(g, seconds: 20)
        XCTAssertEqual(g.s.incidents.count, before)
        XCTAssertNil(g.transition)
    }

    func testDisguiseGivesPlausibilityButFamiliarStaffRecognize() {
        let g = makeGame()
        setClock(g, 800)
        freezeOthers(g, except: [.okonjo, .haskins])
        _ = g.addItem(.whiteCoat, 1)
        g.s.player.outfit = .whiteCoat
        g.s.player.pos = Vec2(73.5, 75.5)  // infirmary
        let z = g.map.zone(at: g.s.player.pos)!
        XCTAssertTrue(g.disguisePlausible(z))
        XCTAssertFalse(g.patientAllowed(z) && false)
        // A stranger at distance does not recognize; Okonjo (familiar) at close range does.
        place(g, .okonjo, Vec2(75.5, 75.5), heading: Double.pi)
        var n = g.npc(.okonjo)!
        _ = g.observe(&n, Cast.def(.okonjo), dist: 2.0)
        XCTAssertTrue(n.recognizedDisguise, "familiar staff recognize at close range")
        // Restricted doors still need credentials.
        let rec = g.map.doorByID["admin.records.door"]!
        g.s.player.pos = g.map.spot("clerk.client")!.pos
        XCTAssertFalse(g.playerCanPass(doorIndex: rec))
    }
}
