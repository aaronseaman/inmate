import XCTest
@testable import FPodCore

/// End-to-end story paths driven through the same interactions, choices, calls,
/// appointments and minigames a player uses (walking is skipped; time is set).
final class StoryTests: XCTestCase {
    // MARK: Helpers

    func day2(seed: UInt64 = 42) -> Game {
        let g = makeGame(seed: seed)
        g.s.flags.formUnion([.claimedBunk, .readChart, .firstCountDone, .metDutch, .trialDone, .jobTrialDone, .firstEveningCount])
        g.addItem(.chartCopy, 1, force: true)
        g.apply([.completeQuest(.m01Intake), .completeQuest(.m02Ally), .set(.allyMarisol)])
        g.startNewDay()
        g.processEvents()
        return g
    }

    func at(_ g: Game, _ minute: Double) { g.s.minute = minute; g.ui.modal = nil; g.update(dt: 1.0 / 30.0); finishTransition(g) }

    func nextDay(_ g: Game) {
        g.startNewDay()
        g.processEvents()
        finishTransition(g)
        g.ui.modal = nil
    }

    /// Asserts an option is offered on a target, then performs it.
    func act(_ g: Game, _ t: TargetRef, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        g.ui.modal = nil
        let opts = g.options(for: t).filter { $0.enabled }.map { $0.id }
        guard opts.contains(id) else {
            XCTFail("'\(id)' not offered on \(t) at day \(g.s.day) \(Schedule.clockString(g.s.minute)); offered: \(opts)", file: file, line: line)
            return
        }
        g.perform(id, on: t)
        g.processEvents()
        finishTransition(g)
    }

    func choose(_ g: Game, _ c: ChoiceID, _ option: Int, file: StaticString = #filePath, line: UInt = #line) {
        g.update(dt: 1.0 / 30.0)
        guard case .choice(let shown)? = g.ui.modal, shown == c else {
            XCTFail("expected choice \(c), modal is \(String(describing: g.ui.modal))", file: file, line: line)
            return
        }
        g.choose(c, option: option)
        g.ui.modal = nil
        g.processEvents()
        finishTransition(g)
    }

    func play(_ g: Game) {
        guard let mg = g.minigame else { return }
        g.minigameAction(.minigameStart)
        var t = 0.0, last = -1.0
        while mg.phase == .playing && t < 600 {
            g.update(dt: 1.0 / 30.0)
            if t - last > 0.16, let p = mg.game.botTap(canvas: g.minigameCanvas) { g.tap(p); last = t }
            t += 1.0 / 30.0
        }
        g.minigameAction(.minigameContinue)
        g.update(dt: 1.0 / 30.0)
        g.processEvents()
        finishTransition(g)
    }

    func keepAppointment(_ g: Game, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let ap = g.s.appointments.first(where: { $0.id == id && !$0.attended }) else {
            return XCTFail("no open appointment \(id): \(g.s.appointments.map { "\($0.id)@d\($0.day)" })", file: file, line: line)
        }
        while g.s.day < ap.day { nextDay(g) }
        at(g, Double(ap.start))
        guard let who = ap.npc else { return XCTFail("appointment \(id) has nobody", file: file, line: line) }
        act(g, .npc(who), "b.appt", file: file, line: line)
    }

    func stage(_ g: Game, _ q: QuestID) -> Int { g.questStage(q) }

    // MARK: Paths

    /// Work → radio → cellmate → lawyer → contradiction → records → Theo → review → plan → release.
    func testReleasePath() {
        let g = day2()
        XCTAssertEqual(stage(g, .m03Work), 0)
        // m03: work, a shift, a commissary account.
        at(g, 790)
        act(g, .npc(.haskins), "c.job.janitorial.ask")
        XCTAssertEqual(g.s.player.job, .janitorial)
        at(g, 800)
        g.startShift(.janitorial); play(g)
        XCTAssertTrue(g.has(.firstShiftWorked))
        if g.s.inventory.count(.requestForm) == 0 { act(g, .object("fpod.board"), "c.board.form") }
        act(g, .npc(.pruitt), "c.supply.commissary")
        XCTAssertTrue(g.questDone(.m03Work), "m03 should be done; stage \(stage(g, .m03Work))")

        // Day 3: radio, cellmate, lawyer chapters open.
        nextDay(g)
        XCTAssertTrue(g.questActive(.m04Radio))
        XCTAssertTrue(g.questActive(.m05Cellmate))
        XCTAssertTrue(g.questActive(.m06Lawyer))
        g.creditDelta(40, "test wages")
        at(g, 800)
        XCTAssertTrue(g.buy(.radio))
        at(g, 1270)
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        act(g, .object("fpod.cell3.bunk"), "c.radio.listen")
        XCTAssertTrue(g.has(.lawyerNumberKnown))
        XCTAssertTrue(g.questDone(.m04Radio))

        // Cellmate: mediation with Cole tomorrow.
        at(g, 1110)
        act(g, .npc(.fitz), "c.fitz.talk")
        choose(g, .cellmateRoute, 1)
        XCTAssertEqual(stage(g, .m05Cellmate), 1)

        // Lawyer: phone list today, approved tomorrow.
        act(g, .object("fpod.board"), "c.board.phoneform")
        act(g, .npc(.pruitt), "c.pruitt.phonelist")
        nextDay(g)
        XCTAssertTrue(g.has(.phoneListApproved))
        keepAppointment(g, "cole.mediate")
        XCTAssertTrue(g.questDone(.m05Cellmate))
        at(g, 1110)
        g.placeCall(.calloway); finishTransition(g)
        XCTAssertTrue(g.has(.calledLawyer))
        keepAppointment(g, "calloway.visit1")
        XCTAssertTrue(g.has(.lawyerMet))
        XCTAssertGreaterThan(g.s.inventory.count(.courtDocket), 0)
        XCTAssertTrue(g.questDone(.m06Lawyer))

        // m07: compare the papers on your bunk, tell Sato.
        XCTAssertTrue(g.questActive(.m07Contradiction))
        at(g, 1110)
        g.s.player.pos = g.map.spot("fpod.cell3.bunkA")!.pos
        act(g, .object("fpod.cell3.bunk"), "c.papers.bunk")
        choose(g, .compareDocs, 0)
        XCTAssertFalse(g.has(.contradictionFound), "the harmless pair isn't the contradiction")
        act(g, .object("fpod.cell3.bunk"), "c.papers.bunk")
        choose(g, .compareDocs, 1)
        XCTAssertTrue(g.has(.contradictionFound))
        g.ui.modal = nil
        act(g, .npc(.sato), "c.tell.sato")
        XCTAssertTrue(g.questDone(.m07Contradiction))

        // m08: authorized records request.
        act(g, .npc(.pruitt), "c.pruitt.recordsform")
        act(g, .npc(.pruitt), "c.pruitt.records")
        keepAppointment(g, "pruitt.records")
        XCTAssertGreaterThan(g.s.inventory.count(.transportLog), 0)
        g.openDoc(.transportLog); g.ui.modal = nil; g.processEvents()
        act(g, .npc(.sato), "c.sato.log")
        XCTAssertTrue(g.has(.chartCorrected))
        XCTAssertTrue(g.questDone(.m08Records))

        // m09: Theo (day 5+), free time incident, a decision, the outcome next morning.
        while g.s.day < 5 { nextDay(g) }
        XCTAssertTrue(g.questActive(.m09Theo))
        at(g, 1079); at(g, 1081)
        XCTAssertTrue(g.has(.theoAccused), "Theo's incident should play at free time")
        act(g, .npc(.moss), "c.theo.decide.moss")
        choose(g, .theoDecision, 1)
        nextDay(g)
        XCTAssertTrue(g.questDone(.m09Theo))

        // m10: three preparations, then the hearing.
        XCTAssertTrue(g.questActive(.m10Review))
        at(g, 800)
        act(g, .npc(.abernathy), "c.review.roles")
        choose(g, .courtQuiz, 0)
        act(g, .npc(.marisol), "c.review.charges.marisol")
        at(g, 670)
        act(g, .npc(.cole), "c.review.practice")
        XCTAssertTrue(g.has(.reviewPrepped))
        keepAppointment(g, "review.hearing")
        XCTAssertTrue(g.has(.reviewPassed))
        XCTAssertTrue(g.questDone(.m10Review))

        // m11: contact, housing, supports, signatures.
        XCTAssertTrue(g.questActive(.m11Plan))
        at(g, 1110)
        g.placeCall(.nadia); finishTransition(g)
        act(g, .npc(.bell), "c.plan.house.bell")
        act(g, .npc(.sato), "c.plan.referral")
        g.s.shiftsWorked[.janitorial] = 3
        act(g, .npc(.haskins), "c.plan.lead.janitorial")
        act(g, .npc(.sato), "c.plan.sign")
        g.placeCall(.calloway); finishTransition(g)
        XCTAssertTrue(g.questDone(.m11Plan), "m11 stage \(stage(g, .m11Plan))")

        // m12: the release hearing (a pre-finale save is made first).
        XCTAssertTrue(g.has(.preFinaleSaved))
        keepAppointment(g, "release.hearing")
        finishTransition(g)
        XCTAssertTrue(g.has(.endingRelease))
        XCTAssertTrue(g.has(.gameFinished))
        if case .ending(.release)? = g.ui.modal {} else { XCTFail("ending screen not shown: \(String(describing: g.ui.modal))") }
    }

    /// Theo's testimony and Strick's search open the advocacy path; five signatures and a meeting end it.
    func testAdvocacyPath() {
        let g = day2(seed: 7)
        g.apply([.completeQuest(.m03Work), .completeQuest(.m04Radio), .completeQuest(.m05Cellmate), .completeQuest(.m06Lawyer)])
        while g.s.day < 5 { nextDay(g) }
        at(g, 1079); at(g, 1081)
        act(g, .npc(.moss), "c.theo.decide.moss")
        choose(g, .theoDecision, 0)
        XCTAssertTrue(g.has(.theoTestified))
        nextDay(g)
        XCTAssertTrue(g.questDone(.m09Theo))
        at(g, 900)
        act(g, .npc(.bell), "c.adv.start")
        XCTAssertTrue(g.questActive(.m12Advocacy))
        act(g, .npc(.pruitt), "c.adv.form")
        act(g, .npc(.pruitt), "c.adv.file")
        XCTAssertTrue(g.has(.grievanceFiled))
        // Five people who have reasons to sign.
        g.s.flags.formUnion([.allyLou, .hymnalReturned])
        g.s.peerRep[.ada] = 20
        for (npc, id) in [(NPCID.dutch, "dutch"), (.marisol, "marisol"), (.theo, "theo"), (.lou, "lou"), (.moss, "moss")] {
            act(g, .npc(npc), "c.adv.sign.\(id)")
        }
        XCTAssertTrue(g.has(.petitionSigned))
        act(g, .npc(.bell), "c.adv.meet")
        XCTAssertTrue(g.has(.preFinaleSaved))
        keepAppointment(g, "admin.meeting")
        finishTransition(g)
        XCTAssertTrue(g.has(.endingAdvocacy))
    }

    /// Mouse's tunnels: three scraps, a key, a way through the fence, a night.
    func testEscapePath() {
        let g = day2(seed: 11)
        g.s.favors[.mouse] = 1
        at(g, 1110)
        act(g, .npc(.mouse), "c.favor.mouse")
        XCTAssertTrue(g.has(.tunnelHatchKnown))
        while g.s.day < 6 { nextDay(g) }
        at(g, 1110)
        act(g, .npc(.mouse), "c.esc.start")
        XCTAssertTrue(g.questActive(.m12Escape))
        // Scrap B from the drain, scrap C from Abe's sketch (granted here), then Mouse assembles.
        g.s.peerRep[.mouse] = 15
        act(g, .npc(.mouse), "c.side.start.sMouseDrain")
        at(g, 1110)
        act(g, .object("fpod.shower1"), "c.side.drain")
        play(g)
        XCTAssertGreaterThan(g.s.inventory.count(.mapScrapB), 0)
        g.addItem(.mapScrapC, 1, force: true)
        act(g, .npc(.mouse), "c.esc.map")
        XCTAssertGreaterThan(g.s.inventory.count(.tunnelMap), 0)
        g.addItem(.copperWire, 1, force: true)
        act(g, .npc(.staticFell), "c.esc.key.static")
        XCTAssertGreaterThan(g.s.inventory.count(.utilityKey), 0)
        g.addItem(.fenceTool, 1, force: true)
        g.processEvents()
        XCTAssertEqual(g.questStage(.m12Escape), 3)
        // Night: into the closet hatch, through the tunnels, out the culvert and the fence.
        at(g, 1400)
        g.s.player.pos = g.map.spot("tunnels.patrol.3")!.pos
        g.s.player.lastZone = "tunnels.a"
        g.processEvents()
        g.emit(.zoneEntered("tunnels.a")); g.processEvents()
        finishTransition(g)
        XCTAssertTrue(g.has(.escapeStarted))
        XCTAssertTrue(g.has(.preFinaleSaved))
        g.emit(.zoneEntered("perimeter.woods")); g.processEvents()
        finishTransition(g)
        XCTAssertTrue(g.has(.endingEscape))
    }

    // MARK: Content shape

    func testQuestCounts() {
        XCTAssertGreaterThanOrEqual(Quests.main.count, 12)
        XCTAssertGreaterThanOrEqual(Quests.side.count, 24)
        for q in Quests.all { XCTAssertFalse(q.stages.isEmpty, "\(q.id) has no stages") }
        // Every side errand can begin: a giver offers it, or it starts on its own.
        for q in Quests.side { XCTAssertTrue(q.autoStart || q.giver != nil, "\(q.id) can never start") }
        // Every quest id referenced exists.
        XCTAssertEqual(Set(Quests.all.map { $0.id }).count, Quests.all.count)
    }

    func testNamedCast() {
        let peers = Cast.all.values.filter { $0.role == .peer }.count
        let staff = Cast.all.values.filter { $0.role.isStaff }.count
        XCTAssertGreaterThanOrEqual(peers, 12)
        XCTAssertGreaterThanOrEqual(staff, 8)
    }

    func testEveryChoiceIsReachable() {
        // A choice is reachable if some interaction, stage, hook table or appointment opens it.
        var opened: Set<ChoiceID> = [.medPass, .reedDecision, .watchReview, .medTalk, .uniformDecision, .adaDecision]
        for (_, (c, _)) in Systems.jobChoices { opened.insert(c) }
        func scan(_ es: [Effect]) {
            for e in es {
                switch e {
                case .choice(let c): opened.insert(c)
                case .minigame(_, _, _, let a, let b): scan(a); scan(b)
                case .ifThen(_, let a, let b): scan(a); scan(b)
                default: break
                }
            }
        }
        for i in Interactions.all { scan(i.effects) }
        for c in Choices.all { XCTAssertTrue(opened.contains(c.id), "choice \(c.id) is never offered") }
    }

    func testEveryItemHasASourceAndAUse() {
        let cov = ContentAudit.itemCoverage()
        for d in Items.list {
            let c = cov[d.id] ?? ContentAudit.Coverage()
            XCTAssertFalse(c.sources.isEmpty, "\(d.id) can never be obtained")
            XCTAssertFalse(c.uses.isEmpty, "\(d.id) has no use")
        }
    }

    func testNoMinigameIsAPlaceholder() {
        for id in MinigameID.allCases { XCTAssertTrue(Minigames.isImplemented(id), "\(id) is not implemented") }
    }
}
