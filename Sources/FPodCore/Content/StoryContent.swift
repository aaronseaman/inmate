import Foundation

// Story content beyond the first day: aggregation, dialogue, documents, scenes,
// phone calls, visits, hearings, daily events and endings.

enum StoryQuests {
    static let main: [QuestDef] = MainArc.quests
    static let side: [QuestDef] = SideArc.quests
}

enum StoryInteractions {
    static let list: [InteractionDef] = MainArcInteractions.list + SideInteractions.list + ItemStories.interactions
}

enum StoryChoices {
    static let list: [ChoiceDef] = MainArcChoices.list + SideChoices.list + ItemStories.choices
}

// MARK: - Dialogue

enum StoryDialogue {
    static func line(for id: NPCID, game g: Game) -> DialogueLine? {
        func L(_ icons: [Icon], _ caption: String) -> DialogueLine { DialogueLine(icons: icons, caption: caption) }
        switch id {
        case .harlan:
            if g.has(.harlanRadioAngry) { return L([.angry, .radio, .eye], "Somebody took my radio. I know who.") }
            if g.has(.harlanReported) { return L([.angry, .badge], "Snitch.") }
        case .theo:
            if g.has(.theoAccused) && !g.has(.theoResolved) { return L([.sad, .quiet], "I didn't touch him. I didn't.") }
            if g.has(.theoCleared) { return L([.chess, .happy], "They gave me my set back. You play white.") }
            if g.has(.theoBeaten) { return L([.chess, .thumbsUp], "You beat me. Again tomorrow.") }
        case .strick:
            if g.has(.strickRetaliation) && !g.has(.strickDocumented) { return L([.eye, .stop], "Statements. Cute.") }
            if g.has(.strickDocumented) { return L([.eye, .form], "Paperwork goes both ways, Merritt.") }
        case .sato:
            if g.has(.chartCorrected) && !g.has(.reviewPassed) { return L([.clipboard, .check], "Your chart is correct now. Let's prepare you.") }
            if g.has(.reviewPassed) { return L([.house, .form], "Next: a plan. Housing, a clinic, work.") }
            if g.watchReviewReady { return L([.eye, .form], "Ready for your watch review?") }
        case .calloway:
            return L([.briefcase, .form], "Documents, Jo. Bring me documents.")
        case .fitz:
            if g.has(.kenjiPortraitDone) { return L([.drawing, .happy], "Look at him. Kenji got the ears right.") }
            if g.has(.cellAgreement) && !g.has(.fitzBoundaryResolved) { return L([.earplug, .question], "Earplugs. Then the treaty's real.") }
        case .marisol:
            if g.questActive(.m12Advocacy) { return L([.form, .people], "Five names. Make them count.") }
            if g.has(.contradictionFound) && !g.has(.chartCorrected) { return L([.gavel, .form], "Now you need the transport log.") }
        case .mouse:
            if g.questActive(.m12Escape) { return L([.map, .quiet], "Scraps. Key. A dark night. In that order.") }
        case .staticFell:
            if g.questActive(.m04Radio) && !g.has(.radioListened) { return L([.radio, .moon], "104.5 after nine. The legal-aid hour.") }
        case .bell:
            if g.has(.kenjiRestrained) && !g.has(.strickSearchWitnessed) { return L([.candle, .eye, .form], "If you saw something, tell me. I write things down.") }
        case .haskins:
            if g.has(.haskinsCardGiven) { return L([.heart, .count], "…Thanks for the card. Count's at six.") }
        default: break
        }
        return nil
    }
}

// MARK: - Documents

enum StoryDocs {
    static func def(_ id: DocID, _ g: Game) -> DocDef {
        func doc(_ title: String, _ sub: String, _ icon: Icon, _ sections: [DocSection], stamp: String? = nil, tint: RGBA = Palette.ivory) -> DocDef {
            DocDef(title: title, subtitle: sub, icon: icon, sections: sections, stamp: stamp, tint: tint)
        }
        switch id {
        case .docket:
            return doc("Court docket", "County Court · Criminal division", .gavel, [
                DocSection(heading: "Case: State v. Merritt, Jo", lines: [
                    DocLine("03/02 — Arrest, Harbor Street transit station. Charges: obstruction; assault (pending)."),
                    DocLine("03/05 — Arraignment. Counsel appointed: R. Calloway, Public Defender."),
                    DocLine("03/14, 09:00 — Hearing, Courtroom 4B. Defendant PRESENT. Continued to 04/02.", evidence: g.has(.contradictionFound)),
                    DocLine("03/21 — Order: competency evaluation, forensic psychiatric center, F-Pod."),
                ]),
            ], stamp: "CERTIFIED")
        case .transportLog:
            return doc("Transport log", "Transferring facility · 03/14", .van, [
                DocSection(heading: "Movements, 03/14", lines: [
                    DocLine("07:15 — MERRITT, JO · 40417-F · to County Court (Courtroom 4B). Escort: Deputy Haines.", evidence: true),
                    DocLine("09:40 — Incident, Unit C: MERRIT, JOEL · 40471-F · staff assault, restrained.", evidence: true),
                    DocLine("11:50 — MERRITT, JO · 40417-F · returned from court."),
                ]),
                DocSection(heading: "Your note", lines: [DocLine("Two people. One T and two Ts. 40417 and 40471. You were in a courtroom at 09:40.", evidence: true)]),
            ], stamp: g.has(.recordsTaken) && !g.has(.recordsHonest) ? "UNCERTIFIED COPY" : "CERTIFIED COPY", tint: Palette.blueGray)
        case .lawyerLetter:
            return doc("Letter", "Office of the Public Defender", .letter, [
                DocSection(heading: nil, lines: [
                    DocLine("Jo — I'm your attorney. Call me collect, weekdays before noon, or put me on your phone list."),
                    DocLine("If anything in your chart is wrong, I need it in writing: dates, names, documents."),
                    DocLine("— Ruth Calloway"),
                ]),
            ])
        case .sisterLetter:
            return doc("From Nadia", "Folded twice", .heart, [
                DocSection(heading: nil, lines: [
                    DocLine("Biscuit sleeps on your side of the couch. I let him."),
                    DocLine("Mr. Alvarez says the back room is yours as long as you need it. He wrote it down — it's attached."),
                    DocLine("Call me. Every Sunday. I mean it. — N."),
                ]),
            ])
        case .grievanceCopy:
            var lines = [DocLine("Filed by: \(Cast.playerName), \(Cast.playerNumber).")]
            if g.has(.strickSearchWitnessed) { lines.append(DocLine("Officer Strick searched cell F-4 and destroyed personal drawings; resident taken to the restraint room without documented cause.", evidence: true)) }
            if g.has(.theoTestified) { lines.append(DocLine("Officer Strick wrote a false 'assault on staff' report against resident T. (witness statement attached).", evidence: true)) }
            if g.has(.strickRetaliation) { lines.append(DocLine("Following my witness statement, my cell was searched and commissary restricted without stated reason.", evidence: true)) }
            if lines.count == 1 { lines.append(DocLine("Pattern of searches 'for sport' on F-Pod; request review of search logs.")) }
            lines.append(DocLine("Requested: review by the Administrator; written response within 10 days."))
            return doc("Grievance (copy)", "Form G-1 · stamped received", .form, [DocSection(heading: "Statement", lines: lines)], stamp: "RECEIVED")
        case .witnessTheo:
            return doc("Witness statement", "Re: incident report, resident T.", .form, [
                DocSection(heading: nil, lines: [
                    DocLine("I was at the next table. Officer Strick swept the chess set off the table. T. stood up and shouted. T. did not touch him."),
                    DocLine("Signed, \(Cast.playerName)."),
                ]),
            ], stamp: "FILED")
        case .reviewNotice:
            return doc("Notice of review", "Competency evaluation", .gavel, [
                DocSection(heading: nil, lines: [
                    DocLine("A review panel will meet to consider whether you understand the proceedings and can assist your counsel."),
                    DocLine("You may bring documents. You may ask questions. Your attorney may attend."),
                ]),
            ])
        case .dischargePlan:
            return doc("Discharge plan", "Signed: Dr. A. Sato", .house, [
                DocSection(heading: "Contact", lines: [DocLine("Nadia Merritt (sister). Weekly calls.")]),
                DocSection(heading: "Housing", lines: [DocLine(g.has(.housingFromNadia) ? "Back room at N. Merritt's apartment (landlord letter on file)." : "Saint Brendan's transitional house (6 beds).")]),
                DocSection(heading: "Supports", lines: [DocLine("Harbor Street clinic — walk-in Tuesdays."), DocLine("Job lead: reference from your work supervisor.")]),
            ], stamp: "APPROVED")
        case .restraintAftermath:
            return doc("Chaplain's note", "Written the same evening", .candle, [
                DocSection(heading: nil, lines: [
                    DocLine("Resident K. returned from the restraint room after approximately forty minutes. Visible marks at both wrists. Quiet; declined the infirmary."),
                    DocLine("Witness account (\(Cast.playerName)): the search began with drawings torn from the wall. No threat observed before the restraint."),
                    DocLine("Copy to: the Administrator. Copy to: resident's attorney on request."),
                ]),
            ], stamp: "NOTED")
        case .phoneList:
            return doc("Phone list", "Approved numbers", .phone, [
                DocSection(heading: nil, lines: [DocLine("Calloway, Ruth — Public Defender"), DocLine("Merritt, Nadia — sister")]),
            ], stamp: g.has(.phoneListApproved) ? "APPROVED" : "PENDING")
        case .privilegeAgreement:
            return doc("Privilege agreement", "F-Pod tiers", .trust, [
                DocSection(heading: "Tiers", lines: [
                    DocLine("1 — Limited movement; observation."),
                    DocLine("2 — Commissary, job applications, cell-change requests."),
                    DocLine("3 — Senior pay (+2 credits a shift). Reached early when your record is corrected."),
                    DocLine("4 — Selected unsupervised time: the yard gate opens in evening free time."),
                    DocLine("5 — Eligible for discharge planning. Reached when you are found competent."),
                ]),
                DocSection(heading: "You", lines: [DocLine("Current tier: \(g.trustTier). Trust: \(g.s.trust).")]),
            ])
        case .epilogueRelease, .epilogueAdvocacy, .epilogueEscape:
            let e: Ending = id == .epilogueRelease ? .release : (id == .epilogueAdvocacy ? .advocacy : .escape)
            return doc(e.title, "Epilogue", .star, [DocSection(heading: nil, lines: Endings.epilogue(e, g).map { DocLine($0) })], stamp: nil, tint: Palette.ivory)
        default:
            return doc(id.rawValue, "", .form, [])
        }
    }
}

enum StoryDocsList {
    static func available(_ g: Game) -> [(DocID, String, Icon, Bool)] {
        let items: [(DocID, String, Icon)] = [
            (.docket, "Court docket", .gavel), (.transportLog, "Transport log", .van), (.lawyerLetter, "Calloway's letter", .letter),
            (.sisterLetter, "Nadia's letter", .heart), (.grievanceCopy, "Grievance copy", .form), (.dischargePlan, "Discharge plan", .house),
            (.restraintAftermath, "Chaplain's note", .candle), (.privilegeAgreement, "Privilege tiers", .trust),
        ]
        return items.map { ($0.0, $0.1, $0.2, $0.0 == .privilegeAgreement || g.s.docsRead.contains($0.0)) }
    }
}

// MARK: - Scenes

enum StoryScenes {
    static func make(_ id: SceneID, _ g: Game) -> Transition? {
        switch id {
        case .phoneCall: return Transition([.duck(0.5), .card(SceneCard("Dayroom phone", icons: [.phone, .clock], lines: g.lastCallLines, tone: .quiet, button: "Hang up")), .duck(1)])
        case .restraint: return restraint(g)
        case .lockdown: return theoIncident(g)
        default: return nil
        }
    }

    static func card(_ title: String, _ icons: [Icon], _ lines: [String], tone: CardTone = .neutral, button: String = "Continue") -> SceneStep {
        .card(SceneCard(title, icons: icons, lines: lines, tone: tone, button: button))
    }

    /// Non-graphic: the door, the time, the aftermath. Never the procedure.
    static func restraint(_ g: Game) -> Transition {
        Transition([
            .duck(0.4), .music(.tense), .fade(0.6, 0.5),
            card("Cell F-4", [.search, .drawing, .cross], [
                "Officer Strick tosses Kenji's cell. Drawings come off the wall in strips.",
                "Kenji says \"Those are mine.\" Strick calls it a threat and calls it in.",
            ], tone: .danger),
            .sound(.doorLock),
            card("The restraint room", [.cellDoor, .clock], [
                "The door at the end of the observation hall closes.",
                "Forty minutes. Kenji walks back rubbing his wrists, not talking.",
            ], tone: .quiet),
            .run { g in g.setFlag(.restraintEventSeen); g.setFlag(.kenjiRestrained); g.adjustPeer(.kenji, 2, silent: true) },
            .fade(0, 0.6), .music(.day), .duck(1),
        ])
    }

    static func theoIncident(_ g: Game) -> Transition {
        Transition([
            .duck(0.4), .music(.tense), .fade(0.5, 0.4),
            card("Dayroom, free time", [.chess, .exclaim, .badge], [
                "Strick stops at Theo's table and sweeps the chess set onto the floor.",
                "Theo stands up and shouts. He doesn't touch anyone.",
                "By count, the write-up says 'assault on staff.' Theo is on a 72-hour watch.",
            ], tone: .danger),
            .run { g in g.setFlag(.theoAccused); g.setFlag(.theoEventSeen); g.s.lockdown = false },
            .fade(0, 0.5), .music(.day), .duck(1),
        ])
    }

    static func visit(_ title: String, _ icons: [Icon], _ lines: [String], _ after: @escaping (Game) -> Void) -> Transition {
        Transition([.duck(0.5), .fade(0.35, 0.4), card(title, icons, lines, tone: .warm), .run(after), .fade(0, 0.5), .duck(1)])
    }
}

// MARK: - Endings

enum Endings {
    static func epilogue(_ e: Ending, _ g: Game) -> [String] {
        switch e {
        case .release:
            var l = ["The judge reads the corrected chart, the transport log, the plan. Conditional release, with conditions you can meet.",
                     g.has(.housingFromNadia) ? "Nadia's back room smells like dog. Biscuit loses his mind." : "Saint Brendan's has six beds and a curfew. The soup is good.",
                     "Tuesdays at Harbor Street. A job interview with a reference letter in your pocket."]
            if g.has(.theoTestified) || g.has(.theoHelped) { l.append("A letter from Theo, in pencil: a chess problem, and 'your move.'") }
            l.append("The case against you is dropped in June. The chart, finally, has your name spelled right.")
            return l
        case .advocacy:
            return ["The Administrator reads the grievance, the petition, the chaplain's notes. Twice.",
                    "Strick is moved off patient units pending review. Search logs are posted weekly.",
                    "Your evaluation transfers to a community program with day passes. Smaller rooms, open doors.",
                    "Marisol frames the petition. Moss sings at the posting. Nobody makes it a speech.",
                    "Your case is still open. You're not facing it alone, and it's no longer built on someone else's name."]
        case .escape:
            return ["The culvert, the cold, the loose panel, the trees. Then a road, then morning.",
                    "It is a fiction, and it costs: a warrant now, where there was a mistake before.",
                    "The transport log that would have cleared you sits in a drawer you'll never open again.",
                    "Nadia answers on the third ring and doesn't say anything for a long time.",
                    "Somewhere Theo is setting up the board, waiting for someone to play white."]
        }
    }
}

extension Game {
    func startEnding(_ e: Ending) {
        guard !has(.gameFinished) || !s.endingsSeen.contains(e) else { return }
        s.endingsSeen.insert(e)
        switch e {
        case .release: setFlag(.endingRelease)
        case .advocacy: setFlag(.endingAdvocacy)
        case .escape: setFlag(.endingEscape)
        }
        setFlag(.gameFinished)
        stat("endings")
        let lines = Endings.epilogue(e, self)
        transition = Transition([
            .duck(0.5), .music(.finale), .fade(1, 1.2),
            .card(SceneCard(e.title, icons: e == .escape ? [.map, .moon, .sun] : (e == .advocacy ? [.people, .form, .sun] : [.gavel, .house, .sun]),
                            lines: Array(lines.prefix(3)), tone: .warm, button: "Continue")),
            .card(SceneCard("Afterward", icons: [.heart], lines: Array(lines.dropFirst(3)), tone: .quiet, button: "Continue")),
            .run { g in g.ui.modal = .ending(e) },
            .fade(0, 0.5), .duck(1),
        ])
        saveRequested = true
    }

    /// Places a call: the story hook decides what happens; the card shows it.
    func placeCall(_ who: NPCID) {
        callTarget = who
        lastCallLines = StoryHooks.phoneCall(self, who)
        transition = StoryScenes.make(.phoneCall, self)
        stat("calls")
    }
}

// MARK: - Hooks

enum StoryHooks {
    static func onEvent(_ g: Game, _ e: GameEvent) {
        switch e {
        case .questStarted(let q):
            if let fx = autoStartEffects[q] { g.apply(fx) }
        case .minigameDone(let id, let score):
            if id == .chess && score >= 0.75 { g.setFlag(.theoBeaten) }
            if id == .weights && score >= 0.5 && g.questActive(.sLouSpotter) {
                let key = "lou.spot.d\(g.s.day)"
                if !g.s.usedInteractions.contains(key) { g.s.usedInteractions.insert(key); g.stat("lou.spot"); g.toast(.dumbbell, "Lou: That's \(g.s.stats["lou.spot"] ?? 0).") }
                if (g.s.stats["lou.spot"] ?? 0) >= 3 { g.setFlag(.lousSpotterDone); g.setFlag(.louProtection) }
            }
        case .traded(let id):
            if id == "fitz.earplugs" && g.has(.cellAgreement) { g.setFlag(.fitzBoundaryResolved); g.adjustPeer(.fitz, 5) }
        case .appointmentKept(let id):
            appointmentKept(g, id)
        case .zoneEntered(let z):
            zoneEntered(g, z)
        case .blockStarted(let a):
            blockStarted(g, a)
        default: break
        }
        pulse(g)
    }

    /// Effects for errands and chapters that start on their own.
    static let autoStartEffects: [QuestID: [Effect]] = [
        .sCommissaryError: [.credits(-3, "Commissary: snack cakes (duplicate line)"), .toast(.coin, "Your statement shows the same snack cakes twice")],
        .sReedNap: [.choice(.reedDecision)],
        .sHarlanDebt: [.bubble(.harlan, [.angry, .coin])],
        .sVisitorDay: [.caption("A note under your door, in Nadia's handwriting: 'Put me on your list. I'm coming.'")],
        .m12Release: [.savePreFinale,
                      .appointment(id: "release.hearing", dayOffset: 1, start: 600, end: 690, title: "Release hearing", icon: .gavel, spot: "hearing.self", npc: .calloway, quest: .m12Release)],
    ]

    /// Checks that don't belong to a single event.
    static func pulse(_ g: Game) {
        // Nights in the tunnels during the escape chapter begin the finale.
        if g.questStage(.m12Escape) == 3, !g.has(.escapeStarted), g.map.zone(at: g.s.player.pos)?.district == .service,
           [.lightsOut, .sleep, .settle].contains(g.activity) {
            g.apply([.savePreFinale, .set(.escapeStarted), .set(.escapeNight)])
            g.transition = StoryScenes.visit("The tunnels", [.moon, .arrowDown, .map], [
                "Pipes tick. Somewhere a pump breathes.",
                "Mouse's map says: trunk line, pump room, culvert. The grate is rusted through.",
                "(A save was made. You can come back to this moment.)",
            ]) { _ in }
        }
    }

    static func zoneEntered(_ g: Game, _ z: String) {
        if z == "admin.visiting" && g.has(.abeRiding) && g.s.player.vehicle == .wheelchair {
            g.s.flags.remove(.abeRiding)
            g.parkVehicle()
            g.apply([.set(.abeRideDone), .npcGoto(.abe, "visit.t2.in"), .peer(.abe, 8), .give(.mapScrapC, 1),
                     .caption("Abe: Right on time. Here — my old route sketch. The service tunnels are on it; I drove maintenance for a year.")])
        }
        if z == "perimeter.woods" && g.has(.escapeStarted) && !g.has(.endingEscape) {
            g.apply([.set(.perimeterReached), .ending(.escape)])
        }
    }

    static func blockStarted(_ g: Game, _ a: Activity) {
        // Theo's incident: the first free time once his chapter is open.
        if a == .freeTime && g.questStage(.m09Theo) == 0 && !g.has(.theoEventSeen) {
            g.transition = StoryScenes.theoIncident(g)
        }
        // Strick's search of Kenji's cell (authored once, day 6+ afternoon).
        if a == .afternoon && g.s.day >= 6 && !g.has(.restraintEventSeen) && g.has(.contradictionFound) {
            g.transition = StoryScenes.restraint(g)
        }
    }

    static func appointmentKept(_ g: Game, _ id: String) {
        switch id {
        case "calloway.visit1":
            g.transition = StoryScenes.visit("Visiting room, table one", [.briefcase, .form, .clock], [
                "Ruth Calloway: tired eyes, a rolling bag of files, a firm handshake.",
                "\"Here's your docket. Read the dates. Anything that doesn't match your chart, I need to know.\"",
                "\"I'll be back when you've got something. Call me.\"",
            ]) { g in g.apply([.give(.courtDocket, 1), .set(.gotCourtDocket), .set(.lawyerMet), .visitor(.calloway, ""), .doc(.docket)]) }
        case "calloway.visit2":
            g.transition = StoryScenes.visit("Visiting room", [.briefcase, .van, .check], [
                "Calloway slides a certified envelope across the table.",
                "\"Subpoenaed transport log, 03/14. Read it — then take it to your evaluator.\"",
            ]) { g in g.apply([.give(.transportLog, 1), .set(.transportLogHave), .set(.recordsApproved), .visitor(.calloway, "")]) }
        case "pruitt.records":
            g.apply([.ifThen(.not(.has(.transportLog)), [.give(.transportLog, 1), .set(.transportLogHave)], []),
                     .caption("Pruitt: One transport log, certified copy. Sign here. Blue ink.")])
        case "nadia.visit":
            let dressed = g.s.player.outfit == .visitor
            g.transition = StoryScenes.visit("Visiting room, table two", [.heart, .dog, .house], [
                "Nadia, in Dad's old coat. She cries for a second and then pretends she didn't.",
                dressed ? "\"You look like you,\" she says, about the shirt. It matters more than it should." : "\"They feed you okay?\" Two Ts, she says, when they spelled your name wrong.",
                "She leaves her landlord's letter: the back room is yours. And a letter of her own.",
            ]) { g in g.apply([.give(.housingLetter, 1), .give(.supportLetter, 1), .set(.housingFromNadia), .set(.visitorDayDone), .set(.planContact), .visitor(.nadia, ""), .doc(.sisterLetter)]) }
        case "review.hearing":
            reviewHearing(g)
        case "release.hearing":
            g.apply([.ending(.release)])
        case "admin.meeting":
            g.apply([.set(.administratorMet), .set(.advocacyMeeting), .ending(.advocacy)])
        case "cole.mediate":
            g.apply([.set(.cellMediated), .set(.fitzBoundaryResolved), .peer(.fitz, 6), .staff(.cole, 2),
                     .caption("Cole gets you both talking about sleep, not soap. Fitz agrees to ask first. You agree to stop sighing at him.")])
        default: break
        }
    }

    static func reviewHearing(_ g: Game) {
        let ready = g.has(.contradictionFound) && g.has(.chartCorrected) && g.has(.reviewPrepped)
        let certified = !(g.has(.recordsLied) && !g.has(.reviewAttempted))
        let dressed = g.s.player.outfit == .visitor
        g.setFlag(.reviewHeld)
        if ready && certified {
            var lines = ["Dr. Sato, a panel member, Calloway. You name the roles. You explain the charges. You show them the log.",
                         "\"Do you understand why you're here?\" You do. You say so, in order, without your hands shaking much."]
            lines.append(dressed ? "The panel notes you came prepared — clothes and all." : "The panel notes you came prepared.")
            g.transition = StoryScenes.visit("Competency review", [.gavel, .check, .sun], lines) { g in
                g.apply([.set(.reviewPassed), .trust(10, "Review passed"), .doc(.reviewNotice)])
                if dressed { g.setFlag(.hearingDressed) }
            }
        } else {
            var missing: [String] = []
            if !g.has(.chartCorrected) { missing.append("a corrected chart") }
            if !g.has(.reviewPrepped) { missing.append("preparation") }
            if !certified { missing.append("a certified copy of the log (Dr. Sato is requesting one)") }
            g.setFlag(.reviewAttempted)
            g.setFlag(.reviewDeferred)
            g.transition = StoryScenes.visit("Review deferred", [.gavel, .clock], [
                "The panel is kind and brief: they need \(missing.isEmpty ? "more time" : missing.joined(separator: " and ")).",
                "A new date is set for two days from now.",
            ]) { g in
                g.apply([.appointment(id: "review.hearing", dayOffset: 2, start: 600, end: 690, title: "Competency review", icon: .gavel, spot: "hearing.self", npc: .sato, quest: .m10Review)])
            }
        }
    }

    static func daily(_ g: Game) {
        if g.has(.phoneListPending) && !g.has(.phoneListApproved) {
            g.apply([.set(.phoneListApproved), .clear(.phoneListPending), .toast(.phone, "Phone list approved — Calloway and Nadia")])
        }
        if g.has(.recordsRequested) && !g.has(.recordsApproved) {
            g.apply([.set(.recordsApproved), .toast(.form, "Records desk: your request is ready for pickup")])
        }
        // Theo's outcome lands the morning after the decision.
        if g.questStage(.m09Theo) == 2 && !g.has(.theoResolved) {
            if g.has(.theoTestified) {
                g.apply([.set(.theoCleared), .set(.theoResolved), .toast(.chess, "Theo's write-up was withdrawn. He has his chess set back.")])
            } else if g.has(.theoHelped) {
                g.apply([.set(.theoResolved), .toast(.candle, "Bell's note shortened Theo's watch.")])
            } else {
                g.apply([.set(.theoResolved), .toast(.chess, "Theo serves the full 72 hours.")])
            }
        }
        // Strick retaliates for a witness statement — documented, grievable, temporary.
        if g.has(.strickRetaliation) && !g.has(.strickDocumented) && !g.s.shakedownsDone.contains(g.s.day) && g.s.day % 2 == 0 {
            g.s.shakedownsDone.insert(g.s.day)
            g.apply([.restrict(.noCommissary, hours: 24), .shakedown(cell: true)])
        }
        // Night camera footage and the garden's tomatoes.
        if g.has(.gardenPlanted) { g.s.stashes["storage.shelf1", default: []].append(ItemStack(.tomatoes, 1)) }
    }

    /// What happens on the phone; returns the lines shown on the call card.
    static func phoneCall(_ g: Game, _ who: NPCID) -> [String] {
        switch who {
        case .calloway:
            if !g.has(.calledLawyer) {
                g.apply([.set(.calledLawyer), .set(.lawyerVisitScheduled),
                         .appointment(id: "calloway.visit1", dayOffset: 1, start: 840, end: 930, title: "Visit: Ruth Calloway", icon: .briefcase, spot: "visit.t1.in", npc: .calloway, quest: .m06Lawyer)])
                return ["\"Calloway.\" Paper rustling. \"Jo Merritt — yes. I have you.\"",
                        "\"I'll come tomorrow afternoon with your docket. Visiting room, two o'clock.\""]
            }
            if g.questStage(.m08Records) == 0 && !g.has(.subpoenaRequested) && g.s.inventory.count(.transportLog) == 0 {
                g.apply([.set(.subpoenaRequested),
                         .appointment(id: "calloway.visit2", dayOffset: 2, start: 840, end: 930, title: "Visit: Calloway (subpoena)", icon: .briefcase, spot: "visit.t1.in", npc: .calloway, quest: .m08Records)])
                return ["\"A transport log from the transferring facility? I can subpoena it.\"", "\"Two days. Don't do anything I'll have to explain to a judge.\""]
            }
            if g.has(.contradictionFound) && !g.has(.contradictionReported) {
                g.apply([.set(.contradictionReported)])
                return ["\"Three-fourteen, nine-forty? You were in 4B at nine. I was there.\"", "\"Tell Dr. Sato. And get that transport log.\""]
            }
            if g.questStage(.m10Review) == 0 && !g.has(.reviewPrepCharges) {
                g.apply([.set(.reviewPrepCharges)])
                return ["\"Obstruction: you didn't move when told. Assault: pending — and it's the 03/14 thing.\"",
                        "\"With the corrected chart, that count is weak. Say that in your own words at the review.\""]
            }
            if g.questStage(.m11Plan) == 3 && g.has(.planApprovedSato) && !g.has(.planApprovedCalloway) {
                g.apply([.set(.planApprovedCalloway)])
                return ["\"Sato signed? Then I'm filing it today.\"", "\"Release hearing as soon as the court calendar allows. Get some sleep, Jo.\""]
            }
            if g.has(.lawyerMet) && g.s.inventory.count(.courtDocket) == 0 && !g.has(.chartCorrected) {
                g.apply([.give(.courtDocket, 1)])
                return ["\"Lost the docket? I'm leaving a copy with Ms. Pruitt — she'll pass it to you.\"", "\"Keep it somewhere better than your pocket.\""]
            }
            return ["\"Still here. Still working on it. Send me documents, not worries.\""]
        case .nadia:
            g.apply([.set(.planContact), .set(.nadiaCalled)])
            return ["\"Jo?\" Nadia's voice, and Biscuit barking behind it.",
                    g.questActive(.m11Plan) ? "\"The back room's yours. Mr. Alvarez will write a letter — I'll bring it on visiting day.\"" : "\"Call me Sundays. I mean it.\""]
        default:
            return ["The line clicks. Nobody there."]
        }
    }
}

extension Game {
    func questActive(_ q: QuestID) -> Bool { s.quests[q]?.status == .active }
    func questDone(_ q: QuestID) -> Bool { s.quests[q]?.status == .done }
    /// Current stage of an active quest, or -1.
    func questStage(_ q: QuestID) -> Int { s.quests[q]?.status == .active ? (s.quests[q]?.stage ?? 0) : -1 }
}
