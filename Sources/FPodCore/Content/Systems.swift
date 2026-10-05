import Foundation

// Systemic content: how jobs, favors, supplies and outfits, equipment, leisure,
// meals, group and watch review reach the player. Story quests build on these.

enum SystemInteractions {
    static let list: [InteractionDef] = jobs + favors + supplies + equipment + leisure + routine + review

    // MARK: Jobs — a tryout (performance) or a vouch (favor), then apply.

    static func job(_ j: JobID, _ boss: NPCID, tryout: Flag, when: Cond) -> [InteractionDef] {
        let d = Jobs.def(j)
        let key = j.rawValue
        return [
            InteractionDef("job.\(key).tryout", .npc(boss), d.minigame == .mop ? .mop : d.icon, "Ask for a \(d.title.lowercased()) tryout",
                           when: .all([.dayAtLeast(2), .notFlag(tryout), .not(.job(j)), when, .dailyOnce("tryout.\(key)")]),
                           reply: [d.icon, .clock, .thumbsUp], priority: 5, [
                            .markDaily("tryout.\(key)"),
                            .minigame(d.minigame, key: "tryout.\(key)", pass: 0.55,
                                      onPass: [.set(tryout), .staff(boss, 3), .toast(d.icon, "\(Cast.def(boss).short) liked that — you can apply")],
                                      onFail: [.toast(d.icon, "\(Cast.def(boss).short): Not yet. Try again tomorrow.")]),
                           ]),
            InteractionDef("job.\(key).apply", .npc(boss), d.icon, "Apply: \(d.title)",
                           when: .all([d.eligibility, .not(.job(j))]), reply: [d.icon, .thumbsUp, .clock], priority: 6, [
                            .setJob(j), .staff(boss, 2), .caption("\(Cast.def(boss).short): Shifts are 08:00–11:00 and 13:00–15:00. Don't be late."),
                           ]),
            InteractionDef("job.\(key).ask", .npc(boss), .question, "Ask about \(d.title.lowercased()) work",
                           when: .all([.not(d.eligibility), .not(.job(j))]), reply: [d.icon, .question], priority: 1, [
                            .caption("\(Cast.def(boss).short): \(d.eligibilityText) Or show me in a tryout."),
                           ]),
        ]
    }

    static let freeTime: Cond = .activity([.afternoon, .freeTime, .rec, .work, .breakfast, .chow, .dinner, .brunch])

    static let jobs: [InteractionDef] =
        job(.kitchen, .odell, tryout: .tryoutKitchen, when: freeTime)
        + job(.laundry, .feld, tryout: .tryoutLaundry, when: freeTime)
        + job(.library, .abernathy, tryout: .tryoutLibrary, when: freeTime)
        + job(.infirmary, .okonjo, tryout: .tryoutInfirmary, when: .all([freeTime, .trustTier(2)]))
        + job(.workshop, .feld, tryout: .tryoutWorkshop, when: freeTime)
        + job(.grounds, .feld, tryout: .tryoutGrounds, when: freeTime)
        + [
            InteractionDef("job.janitorial.ask", .npc(.haskins), .mop, "Ask for the janitorial job",
                           when: .all([.not(.job(.janitorial)), .dayAtLeast(2)]), reply: [.mop, .thumbsUp], priority: 6, [
                            .setJob(.janitorial), .staff(.haskins, 2), .caption("Haskins: Fine. The cart's in the bay; the mop's in the closet. Same hours as everyone."),
                           ]),
            InteractionDef("job.quit", .npc(.haskins), .cross, "Give up your job assignment",
                           when: .all([.not(.noJob), .activity([.freeTime, .afternoon])]), reply: [.form, .check], priority: 0, [
                            .setJob(nil), .staff(.haskins, -1),
                           ]),
            InteractionDef("board.jobs", .kind(.noticeBoard), .work, "Read the job board", priority: 3, [.doc(.jobBoard)]),
            InteractionDef("board.form", .kind(.noticeBoard), .form, "Take a request form", when: .not(.has(.requestForm)), priority: 2, [
                .give(.requestForm, 1),
            ]),
        ]

    // MARK: Favors — earned by trades and help, spent on things only that person can do.

    static func favor(_ npc: NPCID, _ id: String, _ icon: Icon, _ caption: String, flag: Flag, when: Cond = .always, reply: [Icon], _ effects: [Effect]) -> InteractionDef {
        InteractionDef("favor.\(id)", .npc(npc), icon, "Favor: \(caption)", when: .all([.favor(npc, 1), .notFlag(flag), when]), reply: reply, priority: 4,
                       [.favor(npc, -1), .set(flag)] + effects)
    }

    static let favors: [InteractionDef] = [
        favor(.dutch, "dutch", .laundry, "put in a word at laundry", flag: .favorDutchVouch, reply: [.laundry, .thumbsUp], [
            .peer(.dutch, 10), .caption("Dutch: Feld owes me for twenty years of folded sheets. Tell him I sent you."),
        ]),
        favor(.mouse, "mouse", .mapScrap, "what's under the closet?", flag: .favorMouseHatch, reply: [.mapScrap, .arrowDown, .quiet], [
            .set(.tunnelHatchKnown), .give(.mapScrapA, 1), .caption("Mouse: The closet panel lifts. Tunnels run everywhere. You didn't hear it from me."),
        ]),
        favor(.lou, "lou", .person, "watch my back", flag: .favorLouCover, reply: [.person, .eye, .thumbsUp], [
            .set(.louProtection), .caption("Lou: Anyone leans on you, they lean on me."),
        ]),
        favor(.marisol, "marisol", .form, "check my paperwork", flag: .favorMarisolPapers, reply: [.form, .gavel, .check], [
            .give(.recordsRequest, 1), .give(.grievanceForm, 1),
            .caption("Marisol: Records request, filled right. A grievance form, blank — for when you need it."),
        ]),
        favor(.ada, "ada", .gown, "how do deliveries reach isolation?", flag: .favorAdaRoute, reply: [.gown, .box, .door], [
            .set(.ppeRouteKnown), .caption("Ada: Yellow gown, a box in your hands, through the anteroom. Nobody stops a delivery."),
        ]),
        favor(.moss, "moss", .shirt, "borrow a chaplain's helper shirt", flag: .favorMossShirt, reply: [.shirt, .candle], [
            .give(.chaplainShirt, 1), .set(.chaplainShirtLent),
            .caption("Moss: Bring it back clean. The Lord sees stains and so does Chaplain Bell."),
        ]),
        favor(.abe, "abe", .van, "tell me about the transport van", flag: .favorAbeRoutes, reply: [.van, .clock, .map], [
            .set(.vanScheduleKnown), .caption("Abe: Tuesdays and Fridays it idles by the east lawn gate. Driver takes his coffee slow."),
        ]),
        favor(.staticFell, "static", .radio, "fix this radio", flag: .favorStaticRadio, when: .has(.brokenRadio), reply: [.radio, .wire, .thumbsUp], [
            .take(.brokenRadio, 1), .give(.radio, 1), .set(.radioRepaired), .caption("Static: Bad joint. Fixed. It hums at 104.5 — ignore that."),
        ]),
        favor(.kenji, "kenji", .drawing, "draw something for me", flag: .favorKenjiDrawing, reply: [.drawing, .pencil], [
            .give(.drawing, 1), .caption("Kenji: A dog. Everybody wants a dog."),
        ]),
        favor(.rosa, "rosa", .meal, "vouch for me in the kitchen", flag: .favorRosaVouch, reply: [.meal, .thumbsUp], [
            .set(.rosaVouched), .caption("Rosa: Odell listens to me. Don't make me a liar."),
        ]),
    ]

    // MARK: Supplies — props and outfits have job routes and quieter routes.

    static let supplies: [InteractionDef] = [
        InteractionDef("supply.mop", .object("fpod.closet.mop"), .mop, "Take a mop", when: .all([.not(.has(.mop)), .any([.job(.janitorial), .outfit(.maintenance)])]), priority: 2, [
            .give(.mop, 1),
        ]),
        InteractionDef("supply.tray", .object("serving.counter"), .tray, "Take a serving tray", when: .all([.not(.has(.tray)), .job(.kitchen)]), priority: 1, [.give(.tray, 1)]),
        InteractionDef("supply.bag", .object("laundry.fold"), .sack, "Take a laundry bag", when: .all([.not(.has(.laundryBag)), .job(.laundry)]), priority: 1, [.give(.laundryBag, 1)]),
        InteractionDef("supply.clipboard", .object("infirmary.desk"), .clipboard, "Take a delivery clipboard", when: .all([.not(.has(.clipboard)), .job(.infirmary)]), priority: 1, [
            .give(.clipboard, 1),
        ]),
        InteractionDef("supply.coat", .npc(.okonjo), .coat, "Ask for a coat for supply runs", when: .all([.job(.infirmary), .notFlag(.whiteCoatFound), .not(.has(.whiteCoat))]),
                       reply: [.coat, .box], priority: 3, [
                        .give(.whiteCoat, 1), .set(.whiteCoatFound), .caption("Okonjo: Supply runs only. A coat makes people move out of your way."),
                       ]),
        InteractionDef("supply.ppe", .npc(.okonjo), .gown, "Ask for PPE for the isolation route", when: .all([.job(.infirmary), .not(.has(.ppeGown))]),
                       reply: [.gown, .box, .door], priority: 3, [
                        .give(.ppeGown, 1), .set(.ppeRouteKnown), .caption("Okonjo: Gown on in the anteroom, off on the way out. Every time."),
                       ]),
        InteractionDef("supply.coveralls", .npc(.haskins), .shirt, "Ask for maintenance coveralls", when: .all([.job(.janitorial), .notFlag(.maintenanceIssued)]),
                       reply: [.shirt, .mop], priority: 3, [
                        .give(.maintenanceJumpsuit, 1), .set(.maintenanceIssued), .caption("Haskins: Keep the scrubs clean for court. Wear these on the route."),
                       ]),
        InteractionDef("supply.street", .npc(.bell), .shirt, "Ask about clothes for court", when: .all([.dayAtLeast(3), .not(.has(.visitorClothes)), .dailyOnce("bell.clothes")]),
                       reply: [.shirt, .heart], priority: 2, [
                        .markDaily("bell.clothes"), .give(.visitorClothes, 1),
                        .caption("Bell: The clothing closet has a shirt and slacks your size. For hearings and visits — not for wandering."),
                       ]),
        InteractionDef("supply.whites", .npc(.rosa), .shirt, "Ask Rosa for spare kitchen whites", when: .all([.peer(.rosa, 15), .not(.has(.kitchenWhites)), .not(.job(.kitchen))]),
                       reply: [.shirt, .sugar], priority: 2, [
                        .give(.kitchenWhites, 1), .peer(.rosa, -2), .caption("Rosa: These are 'lost.' If Odell asks, you found them in the wash."),
                       ]),
        InteractionDef("supply.sell", .npc(.bell), .drawing, "Give a drawing to the craft sale", when: .all([.has(.drawing), .dailyOnce("craftsale")]),
                       reply: [.drawing, .coin, .heart], priority: 3, [
                        .markDaily("craftsale"), .sellDrawing(fallback: 4, reason: "Craft sale"), .staff(.bell, 1),
                        .caption("Bell: Volunteers buy these every Sunday. Four credits to your account."),
                       ]),
        InteractionDef("supply.commissary", .npc(.pruitt), .form, "Submit a commissary account request",
                       when: .all([.has(.requestForm), .notFlag(.commissaryUnlocked), .dayAtLeast(2)]), reply: [.form, .stamp, .check], priority: 6, [
                        .take(.requestForm, 1), .set(.commissaryUnlocked), .staff(.pruitt, 3),
                        .caption("Pruitt: Blue ink. Correct box. Approved — the window's open to you afternoons."),
                       ]),
    ]

    // MARK: Equipment

    static let equipment: [InteractionDef] = [
        InteractionDef("vehicle.janitor", .object("cartbay.janitorcart"), .cart, "Push the janitor cart",
                       when: .all([.vehicle(nil), .any([.job(.janitorial), .outfit(.maintenance)])]), priority: 6, [.vehicle(.janitorCart)]),
        InteractionDef("vehicle.laundry", .object("cartbay.laundrycart"), .cart, "Push the laundry cart",
                       when: .all([.vehicle(nil), .not(.hiddenIn("cartbay.laundrycart")), .any([.job(.laundry), .outfit(.laundryWhites)])]), priority: 6, [.vehicle(.laundryCart)]),
        InteractionDef("vehicle.laundry2", .object("laundry.cart"), .cart, "Push the laundry cart",
                       when: .all([.vehicle(nil), .any([.job(.laundry), .outfit(.laundryWhites)])]), priority: 6, [.vehicle(.laundryCart)]),
        InteractionDef("ride.laundry", .object("cartbay.laundrycart"), .cart, "Ask Dutch to wheel you out (admin linens)",
                       when: .all([.hiddenIn("cartbay.laundrycart"), .activity([.work, .afternoon]), .any([.peer(.dutch, 15), .favor(.dutch, 1)])]), risky: true, priority: 9, [
                        .concealedRide(to: "lobby.seat", pusher: .dutch),
                       ]),
        InteractionDef("vehicle.van", .object("transport.van"), .van, "Drive the supply run (Mr. Feld supervising)",
                       when: .all([.trustTier(4), .any([.job(.grounds), .job(.workshop), .job(.laundry)]), .activity([.work, .afternoon]), .dailyOnce("van")]), priority: 7, [
                        .markDaily("van"),
                        .minigame(.vanDrive, key: "van.{day}", pass: 0.5, onPass: [.credits(5, "Supply run"), .staff(.feld, 3)], onFail: [.caption("Feld: …I'll drive back.")]),
                       ]),
        InteractionDef("vehicle.buffer", .object("fpod.closet.mop"), .buffer, "Run the floor buffer",
                       when: .all([.vehicle(nil), .job(.janitorial), .activity([.work, .afternoon])]), priority: 4, [.vehicle(.floorBuffer)]),
    ]

    // MARK: Leisure — yard, dayroom and group room.

    static let rec: Cond = .any([.activity([.rec]), .all([.weekend, .activity([.freeTime, .afternoon, .visiting])])])
    static let dayroom: Cond = .activity([.freeTime, .afternoon])

    static let leisure: [InteractionDef] = [
        InteractionDef("play.hoop", .object("yard.hoop"), .ball, "Shoot around", when: rec, priority: 3, [
            .minigame(.basketball, key: "bball.{day}", pass: 0.5, onPass: [.energy(4), .peer(.lou, 1)], onFail: []),
        ]),
        InteractionDef("bet.hoop", .object("yard.hoop"), .coin, "Bet Benny 3 credits on a shooting round", when: .all([rec, .betting, .credits(3), .npcHere(.benny), .dailyOnce("bet.hoop")]),
                       risky: true, priority: 2, [
                        .markDaily("bet.hoop"),
                        .minigame(.basketball, key: "bet.hoop.{day}", pass: 0.6, onPass: [.credits(3, "Won a bet with Benny"), .peer(.benny, -1)],
                                  onFail: [.credits(-3, "Lost a bet to Benny"), .peer(.benny, 2)]),
                       ]),
        InteractionDef("play.weights1", .object("yard.weights1"), .dumbbell, "Lift", when: rec, priority: 3, [
            .minigame(.weights, key: "weights.{day}", pass: 0.5, onPass: [.peer(.lou, 2), .trust(1, "Steady routine")], onFail: []),
        ]),
        InteractionDef("play.weights2", .object("yard.weights2"), .dumbbell, "Lift", when: rec, priority: 3, [
            .minigame(.weights, key: "weights.{day}", pass: 0.5, onPass: [.peer(.lou, 2), .trust(1, "Steady routine")], onFail: []),
        ]),
        InteractionDef("play.shoes1", .object("yard.shoes1"), .horseshoe, "Pitch horseshoes", when: rec, priority: 3, [
            .minigame(.horseshoes, key: "shoes.{day}", pass: 0.6, onPass: [.peer(.abe, 3), .set(.horseshoeWon)], onFail: [.peer(.abe, 1)]),
        ]),
        InteractionDef("play.shoes2", .object("yard.shoes2"), .horseshoe, "Pitch horseshoes", when: rec, priority: 3, [
            .minigame(.horseshoes, key: "shoes.{day}", pass: 0.6, onPass: [.peer(.abe, 3), .set(.horseshoeWon)], onFail: [.peer(.abe, 1)]),
        ]),
        InteractionDef("play.chess", .npc(.theo), .chess, "Play chess", when: .all([dayroom, .zone("fpod.dayroom")]), reply: [.chess, .happy], priority: 3, [
            .minigame(.chess, key: "chess.{day}", pass: 0.75, onPass: [.peer(.theo, 4), .favor(.theo, 1)], onFail: [.peer(.theo, 2)]),
        ]),
        InteractionDef("play.art", .object("group.arttable"), .palette, "Art therapy", when: .activity([.therapy, .afternoon]), priority: 3, [
            .minigame(.art, key: "art.{day}", pass: 0.4, onPass: [.give(.drawing, 1), .staff(.cole, 1)], onFail: []),
        ]),
    ]

    // MARK: Routine

    static let mealTime: Cond = .activity([.breakfast, .chow, .dinner, .brunch])

    static let routine: [InteractionDef] = [
        InteractionDef("meal.tray", .object("serving.counter"), .meal, "Get a tray", when: mealTime, priority: 7, [.meal]),
        InteractionDef("group.join", .npc(.cole), .group, "Join group", when: .all([.activity([.therapy]), .dailyOnce("group")]), reply: [.group, .heart], priority: 7, [
            .markDaily("group"), .trust(2, "Attended group"), .energy(4), .staff(.cole, 1),
        ]),
        InteractionDef("help.rosa", .npc(.rosa), .meal, "Help Rosa on the line", when: .all([mealTime, .notFlag(.rosaVouched), .dailyOnce("rosa.line")]),
                       reply: [.meal, .clock], priority: 4, [
                        .markDaily("rosa.line"),
                        .minigame(.kitchenLine, key: "rosa.line", pass: 0.6, onPass: [.peer(.rosa, 8), .set(.rosaVouched), .toast(.meal, "Rosa will vouch for you in the kitchen")],
                                  onFail: [.peer(.rosa, 2)]),
                       ]),
    ]

    // MARK: Watch review

    static let review: [InteractionDef] = [
        InteractionDef("watch.review", .npc(.sato), .eye, "Ask for your watch review", when: .watchReviewReady, reply: [.eye, .form, .clock], priority: 9, [
            .choice(.watchReview),
        ]),
        InteractionDef("watch.reviewInfo", .npc(.sato), .question, "Ask about the 72-hour watch", when: .all([.watch72, .not(.watchReviewReady)]),
                       reply: [.group, .count, .work], priority: 5, [
                        .caption("Sato: Group, a count on time, a worked shift. Then we review — you don't have to wait out all 72 hours."),
                       ]),
        InteractionDef("watch.reviewCole", .npc(.cole), .eye, "Ask Cole to book your watch review", when: .all([.watchReviewReady, .dailyOnce("cole.review")]),
                       reply: [.eye, .clock, .check], priority: 6, [
                        .markDaily("cole.review"),
                        .appointment(id: "sato.review", dayOffset: 0, start: 810, end: 900, title: "Dr. Sato: watch review", icon: .eye, spot: "sato.client", npc: .sato, quest: nil),
                        .caption("Cole: Booked you with Dr. Sato this afternoon. I'll walk you over if I have to."),
                       ]),
    ]
}

// MARK: - Choices

enum SystemChoices {
    static let list: [ChoiceDef] = [
        ChoiceDef(id: .watchReview, title: "Watch review", icon: .eye,
                  prompt: "Dr. Sato has your observation notes, your group attendance and your shift record. \"Tell me what you want me to know.\"",
                  speaker: .sato, options: [
                    ChoiceOption(.voice, "Walk through what happened", "Plain facts, your side. Watch steps down to yellow for 12 hours.", [
                        .lowerWatch(.yellow, hours: 12), .staff(.sato, 2), .trust(3, "Watch review"), .set(.watch72Reviewed),
                    ]),
                    ChoiceOption(.candle, "Ask Chaplain Bell to sit in", "A witness in the room. Same step-down; Bell writes her own note.", when: .staff(.bell, 3), [
                        .lowerWatch(.yellow, hours: 12), .staff(.bell, 2), .trust(3, "Watch review"), .set(.watch72Reviewed),
                    ]),
                    ChoiceOption(.form, "Ask how to file a complaint", "Sato explains the grievance process. The review continues either way.",
                                 when: .any([.flag(.restraintEventSeen), .flag(.seclusionEventSeen)]), [
                        .set(.complaintOpened), .give(.grievanceForm, 1), .lowerWatch(.yellow, hours: 12), .set(.watch72Reviewed),
                    ]),
                    ChoiceOption(.quiet, "Say nothing today", "No change. You can ask again later.", []),
                  ]),
        ChoiceDef(id: .medTalk, title: "Medication talk", icon: .stethoscope,
                  prompt: "Dr. Sato pulls up your chart. \"You asked to talk about the morning dose. What's on your mind?\"",
                  speaker: .sato, options: [
                    ChoiceOption(.question, "What is each one for?", "She explains in plain terms and gives you the info sheet.", [
                        .doc(.medInfo), .staff(.sato, 2),
                    ]),
                    ChoiceOption(.moon, "It's wrecking my sleep", "She agrees to try a change and asks you to report back to Okonjo.", [
                        .set(.medAdjusted), .staff(.sato, 1), .caption("Sato: Let's move it to evenings and see. Tell Nurse Okonjo how you sleep."),
                    ]),
                    ChoiceOption(.check, "Keep the current plan", "Nothing changes; she notes you engaged.", [.staff(.sato, 1), .trust(1, "Med talk")]),
                    ChoiceOption(.stop, "I'd rather not take it", "She explains what refusing means for your evaluation — it is your call, and it's recorded either way.", [
                        .set(.medRefusedInformed), .caption("Sato: It's your decision. I'll note that we talked and that you understood the options."),
                    ]),
                  ]),
        // Job risk choices: each job's moment of temptation or loyalty.
        ChoiceDef(id: .jobJanitorial, title: "The loose panel", icon: .mop,
                  prompt: "Mopping behind the closet shelf, the mop catches a floor panel. It lifts. Cool air, and a ladder down into the service tunnels.",
                  speaker: nil, options: [
                    ChoiceOption(.badge, "Report it to Haskins", "Trust rises. Maintenance bolts it shut tomorrow.", [
                        .set(.closetHatchReported), .trust(5, "Reported a security gap"), .staff(.haskins, 4),
                    ]),
                    ChoiceOption(.quiet, "Put the panel back and say nothing", "You know something they don't.", risky: true, [
                        .set(.closetHatchKept), .set(.tunnelHatchKnown),
                    ]),
                    ChoiceOption(.note, "Tell Mouse", "She'll owe you — and she'll use it.", risky: true, [
                        .set(.closetHatchKept), .set(.tunnelHatchKnown), .peer(.mouse, 10), .favor(.mouse, 1),
                    ]),
                  ]),
        ChoiceDef(id: .jobKitchen, title: "Sugar packets", icon: .sugar,
                  prompt: "Rosa slides three sugar packets toward your apron. \"Economy,\" she says. Odell is across the kitchen, tasting soup.",
                  speaker: .rosa, options: [
                    ChoiceOption(.hand, "Pocket them", "Rosa grins. Sugar trades well on the pod.", risky: true, [
                        .set(.sugarSkimmed), .give(.sugar, 3), .peer(.rosa, 5),
                    ]),
                    ChoiceOption(.cross, "Slide them back", "Rosa shrugs. Odell notices you're careful.", [
                        .set(.sugarRefused), .peer(.rosa, -2), .staff(.odell, 3),
                    ]),
                  ]),
        ChoiceDef(id: .jobLaundry, title: "The uniform rack", icon: .shirt,
                  prompt: "The pressed uniforms hang unlocked tonight: white coats, coveralls, even a navy officer's shirt. Every outfit on campus passes through here.",
                  speaker: nil, options: [
                    ChoiceOption(.coat, "Fold a white coat into your bag", "Nobody counts coats.", risky: true, [.set(.rackSpareTaken), .give(.whiteCoat, 1)]),
                    ChoiceOption(.shirt, "Take a set of coveralls", "Maintenance gray goes everywhere.", risky: true, [.set(.rackSpareTaken), .give(.maintenanceJumpsuit, 1)]),
                    ChoiceOption(.badge, "Tell Feld the rack is open", "He locks it and remembers you told him.", [
                        .set(.rackReported), .staff(.feld, 4), .trust(3, "Reported an open rack"),
                    ]),
                    ChoiceOption(.cross, "Leave it", "Not your business.", []),
                  ]),
        ChoiceDef(id: .jobLibrary, title: "A folded note", icon: .note,
                  prompt: "Benny drops a folded note on the returns cart. \"Put it in the law book for Harlan. Nobody checks returns.\"",
                  speaker: .benny, options: [
                    ChoiceOption(.note, "Carry it", "Benny owes you. Getting caught with it is another story.", risky: true, [
                        .set(.libraryNoteCarried), .peer(.benny, 8), .favor(.benny, 1), .peer(.harlan, 3),
                    ]),
                    ChoiceOption(.cross, "Refuse", "Benny's annoyed; Abernathy never knows.", [.set(.libraryNoteRefused), .peer(.benny, -4)]),
                    ChoiceOption(.badge, "Hand it to Ms. Abernathy", "Trust rises. Benny and Harlan hear about it.", [
                        .set(.libraryNoteRefused), .staff(.abernathy, 4), .trust(3, "Reported a note"), .peer(.benny, -10), .peer(.harlan, -8),
                    ]),
                  ]),
        ChoiceDef(id: .jobInfirmary, title: "A miscount", icon: .list,
                  prompt: "The supply sheet says forty gloves. The box holds thirty-two. Ada watches you count. \"They go to the kitchen. Hands crack in the dish pit.\"",
                  speaker: .ada, options: [
                    ChoiceOption(.badge, "Report the count", "The sheet is right again. Ada stops talking to you for a while.", [
                        .set(.adaMiscountReported), .staff(.okonjo, 3), .trust(3, "Accurate count"), .peer(.ada, -6),
                    ]),
                    ChoiceOption(.check, "Sign it as forty", "Ada nods. The dish pit keeps its gloves.", risky: true, [
                        .set(.adaMiscountCovered), .peer(.ada, 8), .favor(.ada, 1), .peer(.rosa, 3),
                    ]),
                    ChoiceOption(.question, "Ask Ada to tell Okonjo herself", "She does — and asks for a proper glove order for the kitchen.", when: .peer(.ada, 10), [
                        .set(.adaMiscountReported), .peer(.ada, 3), .staff(.okonjo, 2),
                    ]),
                  ]),
        ChoiceDef(id: .jobWorkshop, title: "Copper wire", icon: .wire,
                  prompt: "The scrap crate holds a coil of copper wire. Static has been asking for weeks. Feld counts the crate on Fridays.",
                  speaker: nil, options: [
                    ChoiceOption(.hand, "Pocket a length", "Static will be thrilled. Feld will count.", risky: true, [
                        .set(.copperTaken), .give(.copperWire, 1), .staff(.feld, -2),
                    ]),
                    ChoiceOption(.question, "Ask Feld for the offcuts", "He gives you the short ends — legitimately.", when: .staff(.feld, 6), [
                        .set(.copperOffcuts), .give(.copperWire, 1), .staff(.feld, 1),
                    ]),
                    ChoiceOption(.cross, "Leave it", "Feld's count stays clean.", [.set(.copperDeclined), .staff(.feld, 2)]),
                  ]),
        ChoiceDef(id: .jobGrounds, title: "The perimeter road", icon: .dog,
                  prompt: "From the east lawn you can see the perimeter road. Officer Tran walks Duke past the van gate at the same time every day.",
                  speaker: nil, options: [
                    ChoiceOption(.clock, "Note the times", "You know when the road is empty.", risky: true, [.set(.k9Noted), .set(.vanScheduleKnown)]),
                    ChoiceOption(.dog, "Wave at Duke", "Tran waves back. Duke wags.", [.set(.k9Waved), .staff(.tran, 4)]),
                    ChoiceOption(.seed, "Keep your eyes on the tomatoes", "The tomatoes appreciate it.", [.give(.tomatoes, 2)]),
                  ]),
    ]
}

// MARK: - Trades that earn favors

enum SystemTrades {
    static let list: [TradeDef] = [
        TradeDef("dutch.favor", .dutch, give: [(.tomatoes, 1)], get: [], when: .flag(.metDutch), dailyLimit: 1, favor: 1),
        TradeDef("ada.workbook", .ada, give: [(.workbook, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("kenji.pencils", .kenji, give: [(.pencils, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("rosa.sugar", .rosa, give: [(.sugar, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("abe.read", .abe, give: [(.book, 1)], get: [], dailyLimit: 1, favor: 1),
        TradeDef("static.batteries", .staticFell, give: [(.batteries, 1)], get: [], dailyLimit: 1, favor: 1),
    ] + ItemStories.trades
}

// MARK: - Supply containers

enum SupplyStashes {
    static let list: [StashDef] = [
        StashDef(objectID: "laundry.uniforms", title: "Uniform rack", slots: 6, maxSize: .medium, discovery: 0.5, legal: false, needs: nil),
        StashDef(objectID: "ante.ppe", title: "PPE shelf", slots: 4, maxSize: .medium, discovery: 0.5, legal: false, needs: nil),
        StashDef(objectID: "chapel.hymnals", title: "Vestry shelf", slots: 4, maxSize: .medium, discovery: 0.3, legal: false, needs: nil),
        StashDef(objectID: "pump.crate", title: "Maintenance crate", slots: 4, maxSize: .medium, discovery: 0.2, legal: false, needs: nil),
        StashDef(objectID: "workshop.scrap", title: "Scrap crate", slots: 3, maxSize: .small, discovery: 0.5, legal: false, needs: nil),
        StashDef(objectID: "grounds.toolbox", title: "Tool box", slots: 3, maxSize: .small, discovery: 0.4, legal: false, needs: nil),
        StashDef(objectID: "storage.shelf1", title: "Pantry shelf", slots: 4, maxSize: .small, discovery: 0.5, legal: false, needs: nil),
        StashDef(objectID: "library.returns", title: "Returns cart", slots: 4, maxSize: .medium, discovery: 0.3, legal: false, needs: nil),
        StashDef(objectID: "sewing.shelf", title: "Notions shelf", slots: 3, maxSize: .small, discovery: 0.4, legal: false, needs: nil),
        StashDef(objectID: "cartbay.laundrycart", title: "Laundry cart", slots: 6, maxSize: .large, discovery: 0.35, legal: false, needs: nil),
        StashDef(objectID: "cartbay.janitorcart", title: "Janitor cart", slots: 6, maxSize: .large, discovery: 0.35, legal: false, needs: nil),
    ] + ItemStories.stashes

    /// Facility stock: refilled each morning up to these counts (never above).
    static let stock: [String: [(ItemID, Int)]] = baseStock.merging(ItemStories.stock) { a, _ in a }
    static let baseStock: [String: [(ItemID, Int)]] = [
        "laundry.uniforms": [(.coUniform, 1), (.whiteCoat, 1), (.kitchenWhites, 1), (.maintenanceJumpsuit, 1)],
        "ante.ppe": [(.ppeGown, 2), (.deliveryBox, 1)],
        "chapel.hymnals": [(.hymnal, 1), (.chaplainShirt, 1)],
        "pump.crate": [(.maintenanceJumpsuit, 1), (.screwdriver, 1)],
        "workshop.scrap": [(.copperWire, 2)],
        "grounds.toolbox": [(.screwdriver, 1), (.fenceTool, 1)],
        "storage.shelf1": [(.sugar, 3), (.tomatoes, 2)],
        "library.returns": [(.book, 1), (.lawBook, 1)],
        "sewing.shelf": [(.pencils, 1), (.glasses, 1)],
        // Staff laundry rides through the cart bay on its way back to the locker room.
        "cartbay.laundrycart": [(.coUniform, 1), (.laundryBag, 1)],
    ]
}

// MARK: - Hooks

enum Systems {
    static let jobChoices: [JobID: (ChoiceID, Flag)] = [
        .kitchen: (.jobKitchen, .jobChoiceKitchen), .laundry: (.jobLaundry, .jobChoiceLaundry), .janitorial: (.jobJanitorial, .jobChoiceJanitorial),
        .library: (.jobLibrary, .jobChoiceLibrary), .infirmary: (.jobInfirmary, .jobChoiceInfirmary), .workshop: (.jobWorkshop, .jobChoiceWorkshop),
        .grounds: (.jobGrounds, .jobChoiceGrounds),
    ]

    /// Each job's risk/trust moment arrives on the second shift.
    static func afterShift(_ g: Game, _ job: JobID, _ score: Double) {
        // The day-1 trial isn't a real shift; anything after it is.
        if g.has(.trialDone) { g.setFlag(.firstShiftWorked) }
        guard let (choice, flag) = jobChoices[job], !g.has(flag), (g.s.shiftsWorked[job] ?? 0) >= 2 else { return }
        g.setFlag(flag)
        g.s.pendingChoices.append(choice)
    }

    static func appointmentKept(_ g: Game, _ id: String) {
        switch id {
        case "sato.meds": g.s.pendingChoices.append(.medTalk)
        case "sato.review": g.s.pendingChoices.append(.watchReview)
        default: break
        }
    }

    /// Facility stock refills each morning (never above the stocked count).
    static func restock(_ g: Game) {
        for (container, items) in SupplyStashes.stock {
            var stacks = g.s.stashes[container] ?? []
            for (item, n) in items {
                let have = stacks.filter { $0.id == item }.reduce(0) { $0 + $1.qty }
                if have < n { stacks.append(ItemStack(item, n - have)) }
            }
            g.s.stashes[container] = stacks
        }
    }

    static func daily(_ g: Game) {
        restock(g)
        variation(g)
    }

    public enum DayFlavor: Int { case ordinary, movieNight, soupDay, sweep }

    /// Seeded daily variation: a little texture, one real system effect.
    public static func flavor(day: Int, seed: UInt64) -> DayFlavor {
        guard day >= 3 else { return .ordinary }
        return DayFlavor(rawValue: Int(stableHash([seed, UInt64(day), 0xF1A7]) % 4)) ?? .ordinary
    }

    static func variation(_ g: Game) {
        switch flavor(day: g.s.day, seed: g.s.seed) {
        case .ordinary: break
        case .movieNight: g.toast(.tv, "Movie night in the dayroom after dinner")
        case .soupDay: g.toast(.meal, "Odell's soup day: lunch fills you up")
        case .sweep: sweepCommonStashes(g)
        }
    }

    /// Staff sweep two common-area hiding places. Each container uses its own discovery
    /// odds; only contraband and dangerous items are removed; cells are not touched.
    static func sweepCommonStashes(_ g: Game) {
        let candidates = Stashes.all.map { $0.objectID }.filter { id in
            !id.hasPrefix("fpod.cell") && SupplyStashes.stock[id] == nil && !(g.s.stashes[id]?.isEmpty ?? true)
        }.sorted()
        guard !candidates.isEmpty else { g.toast(.search, "Staff swept the common areas"); return }
        var rng = RNG(seed: stableHash([g.s.seed, UInt64(g.s.day), 0x5E]))
        var picks = candidates
        rng.shuffle(&picks)
        var removed: [String] = []
        for id in picks.prefix(2) {
            guard let def = g.stashByObject[id], var stacks = g.s.stashes[id] else { continue }
            let before = stacks.count
            stacks.removeAll { Items.def($0.id).legality >= .contraband && rng.chance(def.discovery + 0.4) }
            if stacks.count < before { removed.append(def.title.lowercased()) }
            g.s.stashes[id] = stacks
        }
        g.toast(.search, removed.isEmpty ? "Staff swept the common areas — nothing found" : "Common-area sweep: contraband taken from the \(removed.joined(separator: " and "))",
                danger: !removed.isEmpty)
    }
}
