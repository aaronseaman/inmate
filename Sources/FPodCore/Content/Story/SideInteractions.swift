import Foundation

enum SideInteractions {
    static let free: Cond = .activity([.freeTime, .afternoon])

    static let list: [InteractionDef] = SideArc.starters + [
        // Small print
        InteractionDef("side.dutch.glasses", .npc(.dutch), .glasses, "Give Dutch the glasses",
                       when: .all([.questActive(.sDutchLetters), .has(.glasses), .notFlag(.dutchGlassesFound)]), reply: [.glasses, .happy], priority: 8, [
                        .take(.glasses, 1), .set(.dutchGlassesFound), .peer(.dutch, 8), .favor(.dutch, 1),
                       ]),
        InteractionDef("side.dutch.read", .npc(.dutch), .letter, "Sit with Dutch while he reads", when: .all([.flag(.dutchGlassesFound), .notFlag(.dutchLetterRead)]),
                       reply: [.letter, .heart], priority: 8, [
                        .set(.dutchLetterRead), .give(.coffee, 2), .caption("Dutch: 'Dad, I got the job.' …Read it to me again. Slower."),
                       ]),
        // Loaded
        InteractionDef("side.benny.dice", .npc(.benny), .dice, "Play dice (one snack)", when: .all([.questActive(.sBennyDice), free, .has(.snack)]),
                       reply: [.dice, .coin], priority: 8, [.take(.snack, 1), .choice(.bennyDice)]),
        // Spotter: tracked from the weights minigame (StoryHooks).
        // Hymnal
        InteractionDef("side.moss.hymnal", .npc(.moss), .hymnal, "Give Moss his hymnal", when: .all([.questActive(.sMossHymnal), .has(.hymnal)]),
                       reply: [.hymnal, .music, .heart], priority: 8, [
                        .take(.hymnal, 1), .set(.hymnalReturned), .peer(.moss, 10), .favor(.moss, 1), .caption("Moss: 'This little light…' Thank you, friend."),
                       ]),
        // Portrait
        InteractionDef("side.fitz.consent", .npc(.fitz), .question, "Ask if Kenji may draw your son", when: .questStage(.sKenjiPortrait, 0), reply: [.drawing, .photo, .thumbsUp],
                       priority: 8, [.set(.fitzConsent), .peer(.fitz, 3), .caption("Fitz: …Yeah. Tell him the kid has my ears. Poor kid.")]),
        InteractionDef("side.kenji.pencils", .npc(.kenji), .pencil, "Give Kenji the colored pencils", when: .all([.questStage(.sKenjiPortrait, 1), .has(.pencils)]),
                       reply: [.pencil, .drawing, .heart], priority: 8, [
                        .take(.pencils, 1), .set(.kenjiPortraitDone), .peer(.kenji, 6), .peer(.fitz, 15),
                        .caption("Kenji works for an hour. Fitz looks at it for longer than that."),
                       ]),
        // Antenna
        InteractionDef("side.static.wire", .npc(.staticFell), .wire, "Give Static the copper wire", when: .all([.questActive(.sStaticAntenna), .has(.copperWire), .notFlag(.staticAntennaDone)]),
                       reply: [.wire, .radio, .happy], priority: 8, [
                        .take(.copperWire, 1), .set(.staticAntennaDone), .favor(.staticFell, 1), .peer(.staticFell, 8),
                        .caption("Static: Listen. Hear that? That's the city. Clean."),
                       ]),
        // Ada's count
        InteractionDef("side.ada.count", .npc(.ada), .list, "Help count the supply cabinet", when: .all([.questStage(.sAdaCount, 0), .dailyOnce("ada.count")]),
                       reply: [.list, .box], priority: 8, [
                        .markDaily("ada.count"),
                        .minigame(.supplyMatch, key: "ada.count", pass: 0.5, onPass: [.set(.adaCountDone), .choice(.adaDecision)], onFail: [.caption("Ada: Close. Again tomorrow.")]),
                       ]),
        // Photo
        InteractionDef("side.fitz.photo", .npc(.fitz), .photo, "Give Fitz the photo", when: .all([.questActive(.sFitzPhoto), .has(.photo)]), reply: [.photo, .heart],
                       priority: 8, [.take(.photo, 1), .set(.fitzPhotoFound), .peer(.fitz, 15), .caption("Fitz: …Thanks. He's ten next month.")]),
        // Dinner rush
        InteractionDef("side.rosa.rush", .npc(.rosa), .meal, "Work the dinner rush", when: .all([.questActive(.sRosaRush), .activity([.dinner]), .outfit(.kitchenWhites), .dailyOnce("rosa.rush")]),
                       reply: [.meal, .clock], priority: 9, [
                        .markDaily("rosa.rush"),
                        .minigame(.kitchenLine, key: "rosa.rush", pass: 0.5, onPass: [.set(.rosaRushDone), .favor(.rosa, 1), .peer(.rosa, 8), .give(.snack, 1)],
                                  onFail: [.caption("Rosa: We survived. Next Friday, faster.")]),
                       ]),
        InteractionDef("side.rosa.whites", .npc(.rosa), .shirt, "Ask what to wear for the rush", when: .all([.questActive(.sRosaRush), .not(.outfit(.kitchenWhites))]),
                       reply: [.shirt, .meal], priority: 4, [.caption("Rosa: Whites. Hair net. If you don't have whites, ask me nicely or ask the laundry.")]),
        // Harlan
        InteractionDef("side.harlan", .npc(.harlan), .angry, "Deal with Harlan", when: .all([.questActive(.sHarlanDebt), .notFlag(.harlanDebtSettled)]), reply: [.angry, .coin],
                       priority: 9, [.choice(.harlanDemand)]),
        // Drain
        InteractionDef("side.drain", .object("fpod.shower1"), .water, "Fish in the drain", when: .all([.questStage(.sMouseDrain, 0), .dailyOnce("drain")]), priority: 9, [
            .markDaily("drain"),
            .minigame(.drain, key: "mouse.drain", pass: 0.5, onPass: [.give(.mapScrapB, 1), .give(.note, 1)], onFail: [.caption("The hook slips. Tomorrow.")]),
        ]),
        InteractionDef("side.mouse.note", .npc(.mouse), .note, "Give Mouse her note", when: .all([.questStage(.sMouseDrain, 1), .has(.note)]), reply: [.note, .quiet, .heart],
                       priority: 9, [.take(.note, 1), .set(.drainNoteReturned), .favor(.mouse, 1), .peer(.mouse, 8), .caption("Mouse: You didn't read it. I can tell. Keep the map.")]),
        // Abe
        InteractionDef("side.abe.ask", .npc(.abe), .question, "Ask how he wants the help", when: .questStage(.sAbeRide, 0), reply: [.wheelchair, .question, .happy], priority: 8, [
            .set(.abeAsked), .peer(.abe, 3), .caption("Abe: Slow on the turns. I do the doors myself — I like doing the doors."),
        ]),
        InteractionDef("side.abe.push", .npc(.abe), .wheelchair, "Push Abe's chair to visiting", when: .all([.questStage(.sAbeRide, 1), .activity([.visiting, .afternoon]), .vehicle(nil)]),
                       reply: [.wheelchair, .thumbsUp], priority: 9, [.set(.abeRiding), .vehicle(.wheelchair)]),
        // Garden
        InteractionDef("side.garden", .object("garden.2"), .seed, "Tend the beds", when: .all([.questActive(.sGarden), .activity([.rec, .work, .afternoon])]), priority: 8, [
            .minigame(.garden, key: "garden.quest", pass: 0.5, onPass: [.set(.gardenPlanted), .give(.tomatoes, 3), .peer(.lou, 3)], onFail: []),
        ]),
        // Overdue
        InteractionDef("side.book.fitz", .npc(.fitz), .book, "Ask about the overdue library book", when: .questStage(.sLostBook, 0), reply: [.book, .tools], priority: 8, [
            .set(.lostBookFound), .caption("Fitz: 'Small Engine Repair'? Under my mattress. I was going to fix the TV."),
        ]),
        InteractionDef("side.book.return", .npc(.abernathy), .book, "Return 'Small Engine Repair'", when: .questStage(.sLostBook, 1), reply: [.book, .check], priority: 8, [
            .set(.lostBookReturned), .set(.libraryCardIssued), .staff(.abernathy, 3), .caption("Abernathy: Three weeks. Hm. Here — a library card. Don't make me regret it."),
        ]),
        // Laundry mixup
        InteractionDef("side.laundry.sort", .object("cartbay.laundrycart"), .laundry, "Sort Dutch's bundle", when: .questStage(.sLaundryMixup, 0), priority: 9, [
            .set(.laundryMixupFound), .choice(.uniformDecision),
        ]),
        // Buffer
        InteractionDef("side.buffer", .npc(.haskins), .buffer, "Borrow the floor buffer", when: .all([.questActive(.sBuffer), .vehicle(nil), .notFlag(.bufferDone)]),
                       reply: [.buffer, .stop], priority: 8, [.vehicle(.floorBuffer), .caption("Haskins: Twenty seconds of buffing, zero people on the floor. Go.")]),
        // Double charge
        InteractionDef("side.charge.form", .npc(.pruitt), .form, "Ask for a grievance form", when: .all([.questActive(.sCommissaryError), .not(.has(.grievanceForm))]),
                       reply: [.form], priority: 6, [.give(.grievanceForm, 1)]),
        InteractionDef("side.charge.file", .npc(.pruitt), .coin, "File a billing correction", when: .all([.questActive(.sCommissaryError), .has(.grievanceForm)]),
                       reply: [.form, .stamp, .coin], priority: 8, [
                        .take(.grievanceForm, 1), .set(.commissaryRefunded), .credits(3, "Refund: duplicate charge"), .staff(.pruitt, 2),
                        .caption("Pruitt: Duplicate line item. Refunded. See? Forms work."),
                       ]),
        // Haskins' card
        InteractionDef("side.card.dutch", .npc(.dutch), .pencil, "Sign Haskins' card", when: .all([.questStage(.sHaskinsCard, 1), .notFlag(.haskinsCardDutch)]), reply: [.pencil, .happy],
                       priority: 7, [.set(.haskinsCardDutch)]),
        InteractionDef("side.card.rosa", .npc(.rosa), .pencil, "Sign Haskins' card", when: .all([.questStage(.sHaskinsCard, 1), .notFlag(.haskinsCardRosa)]), reply: [.pencil, .heart],
                       priority: 7, [.set(.haskinsCardRosa)]),
        InteractionDef("side.card.moss", .npc(.moss), .pencil, "Sign Haskins' card", when: .all([.questStage(.sHaskinsCard, 1), .notFlag(.haskinsCardMoss)]), reply: [.pencil, .music],
                       priority: 7, [.set(.haskinsCardMoss)]),
        InteractionDef("side.card.give", .npc(.haskins), .heart, "Give Haskins the card", when: .all([.questStage(.sHaskinsCard, 2), .has(.drawing)]), reply: [.heart, .quiet],
                       priority: 9, [
                        .take(.drawing, 1), .set(.haskinsCardGiven), .staff(.haskins, 8), .trust(3, "Kindness noted"),
                        .caption("Haskins looks at the card for a long time. \"…Count's at six. Don't be late.\" She's smiling."),
                       ]),
        // Strick's search
        InteractionDef("side.strick.bell", .npc(.bell), .candle, "Tell Chaplain Bell what you saw", when: .questStage(.sStrickSearch, 0), reply: [.candle, .form, .eye],
                       priority: 9, [
                        .set(.strickSearchWitnessed), .set(.strickDocumented), .set(.complaintOpened), .staff(.bell, 4), .doc(.restraintAftermath),
                       ]),
        InteractionDef("side.strick.kenji", .npc(.kenji), .heart, "Check on Kenji", when: .questStage(.sStrickSearch, 1), reply: [.quiet, .heart], priority: 9, [
            .set(.strickReported), .peer(.kenji, 10), .caption("Kenji: I'm okay. I'm drawing it. All of it. Bell has copies."),
        ]),
        // Gurney
        InteractionDef("side.gurney", .object("infirmary.ramp"), .gurney, "Take the gurney down the ramp", when: .all([.questActive(.sGurneyRun), .dailyOnce("gurney")]), priority: 9, [
            .markDaily("gurney"),
            .minigame(.gurney, key: "gurney.run", pass: 0.5, onPass: [.set(.gurneyRunDone), .credits(3, "Supply run"), .staff(.okonjo, 3)],
                      onFail: [.caption("Okonjo: …Slower. Tomorrow.")]),
        ]),
        // Nadia
        InteractionDef("side.nadia.list", .npc(.pruitt), .heart, "Put Nadia on your visitor list", when: .questStage(.sVisitorDay, 0), reply: [.form, .heart, .stamp], priority: 8, [
            .set(.sisterVisitScheduled),
            .appointment(id: "nadia.visit", dayOffset: 1, start: 840, end: 930, title: "Visit: Nadia", icon: .heart, spot: "visit.t2.in", npc: .nadia, quest: .sVisitorDay),
            .caption("Pruitt: Merritt, Nadia. Two Ts. Tomorrow afternoon."),
        ]),
        // Card night
        InteractionDef("side.cards", .npc(.dutch), .cards, "Play crazy eights", when: .all([.questActive(.sCardNight), free]), reply: [.cards, .happy], priority: 8, [
            .minigame(.crazyEights, key: "card.night", pass: 0.75, onPass: [.set(.cardNightWon), .set(.cardNightPlayed), .favor(.dutch, 1)],
                      onFail: [.set(.cardNightPlayed), .give(.coffee, 1), .caption("Dutch: Benny cheats even when he isn't dealing. Coffee's on me.")]),
        ]),
        // Isolation letter
        InteractionDef("side.iso.take", .npc(.ada), .letter, "Take the letter for isolation", when: .all([.questStage(.sIsolationLetter, 0)]), reply: [.letter, .gown], priority: 8, [
            .give(.letter, 1), .set(.isolationLetterHave),
        ]),
        InteractionDef("side.iso.deliver", .object("isolation.bed"), .letter, "Leave the letter", when: .all([.questStage(.sIsolationLetter, 1), .has(.letter), .outfit(.ppe)]),
                       priority: 9, [
                        .take(.letter, 1), .set(.isolationLetterDelivered), .peer(.ada, 10), .trust(2, "Delivered mail"),
                        .caption("A hand reaches out from under the blanket. \"…Mail?\""),
                       ]),
        // Filing
        InteractionDef("side.filing", .npc(.pruitt), .form, "Help with the filing", when: .all([.questActive(.sClerkFiling), .dailyOnce("filing")]), reply: [.form, .list], priority: 8, [
            .markDaily("filing"),
            .minigame(.filing, key: "clerk.filing", pass: 0.5, onPass: [.set(.clerkFilingDone), .credits(4, "Filing help"), .staff(.pruitt, 4)], onFail: []),
        ]),
        // Cart derby
        InteractionDef("side.derby", .object("cartbay.janitorcart"), .cart, "Race a lap", when: .all([.questActive(.sCartDerby), .weekend, .activity([.afternoon, .visiting, .freeTime])]),
                       priority: 9, [
                        .minigame(.cartDrive, key: "cart.derby", pass: 0.5, onPass: [.set(.cartDerbyDone), .peer(.abe, 5), .peer(.dutch, 2)], onFail: []),
                       ]),
        // Mail call
        InteractionDef("side.mail", .object("corridor.mailbox"), .envelope, "Sort the mail", when: .all([.questActive(.sMailRound), .dailyOnce("mail")]), priority: 9, [
            .markDaily("mail"),
            .minigame(.mailSort, key: "mail.round", pass: 0.5,
                      onPass: [.set(.mailRoundDone), .set(.mailLetterFound), .set(.lawyerNumberKnown), .give(.lawyerCard, 1), .doc(.lawyerLetter)], onFail: []),
        ]),
        // Dominoes: leisure with Dutch.
        InteractionDef("play.dominoes", .npc(.dutch), .domino, "Play dominoes", when: .all([free, .zone("fpod.dayroom")]), reply: [.domino, .happy], priority: 2, [
            .minigame(.dominoes, key: "dominoes.{day}", pass: 0.75, onPass: [.peer(.dutch, 3)], onFail: [.peer(.dutch, 1)]),
        ]),
    ]
}

enum SideChoices {
    static let list: [ChoiceDef] = [
        ChoiceDef(id: .bennyDice, title: "Loaded", icon: .dice,
                  prompt: "Benny rolls a six. Then another. The dice hit the table heavy on one side.", speaker: .benny, options: [
                    ChoiceOption(.exclaim, "Call it out at the table", "Everyone gets their snacks back. Benny doesn't forget.", [
                        .set(.bennyDiceExposed), .peer(.benny, -10), .peer(.dutch, 3), .peer(.rosa, 3), .give(.snack, 1),
                    ]),
                    ChoiceOption(.quiet, "Take Benny aside: stop, or I tell", "The game gets honest. Benny respects it, grudgingly.", [
                        .set(.bennyDiceExposed), .set(.bennyTalkedPrivately), .peer(.benny, 2),
                    ]),
                    ChoiceOption(.coin, "Say nothing — for a cut", "One cigarette now, more later. You know what you are.", risky: true, [
                        .set(.bennyDiceKept), .give(.cigarettes, 1), .favor(.benny, 1), .peer(.benny, 5),
                    ]),
                  ]),
        ChoiceDef(id: .harlanDemand, title: "Harlan", icon: .angry,
                  prompt: "Harlan leans over the table. \"You owe me. Everybody owes me. Pay up or I make your week loud.\"", speaker: .harlan, options: [
                    ChoiceOption(.cigarette, "Pay him two cigarettes", "It ends today. It might start again.", when: .has(.cigarettes, 2), [
                        .take(.cigarettes, 2), .set(.harlanPaid), .set(.harlanDebtSettled), .peer(.harlan, 3),
                    ]),
                    ChoiceOption(.person, "Glance over at Lou", "Lou looks back. Harlan finds somewhere else to be.", when: .flag(.louProtection), [
                        .set(.harlanDebtSettled), .peer(.harlan, -3),
                    ]),
                    ChoiceOption(.radio, "Give him back his radio", "Square, by Harlan's math.", when: .hasOwned(.radio, .harlan), [
                        .returnOwned(.radio, .harlan), .set(.radioReturnedToHarlan), .clear(.harlanRadioAngry), .set(.harlanDebtSettled), .peer(.harlan, 8),
                    ]),
                    ChoiceOption(.badge, "Tell Lt. Gaines", "Gaines handles it. Harlan's yellow watch is public; so is who talked.", [
                        .set(.harlanReported), .set(.harlanDebtSettled), .trust(3, "Reported a threat"), .peer(.harlan, -10), .peer(.benny, -3), .staff(.gaines, 3),
                    ]),
                  ]),
        ChoiceDef(id: .uniformDecision, title: "Navy in the wash", icon: .shirt,
                  prompt: "Folded inside Dutch's whites: a navy officer's shirt, name tape picked off.", speaker: nil, options: [
                    ChoiceOption(.badge, "Return it to Mr. Feld", "Feld locks up staff laundry and thanks you, gruffly.", [
                        .set(.coUniformReturned), .staff(.feld, 4), .trust(2, "Returned a uniform"),
                    ]),
                    ChoiceOption(.shirt, "Keep it", "A navy shirt opens doors — until someone looks closely.", risky: true, [
                        .set(.coUniformKept), .give(.coUniform, 1),
                    ]),
                    ChoiceOption(.people, "Hand it to Dutch to deal with", "Dutch returns it through his own channels.", [
                        .set(.coUniformReturned), .peer(.dutch, 3),
                    ]),
                  ]),
        ChoiceDef(id: .reedDecision, title: "Night desk", icon: .zzz,
                  prompt: "Through the station glass: CO Reed, chin on his chest, asleep. Lt. Gaines rounds at midnight.", speaker: nil, options: [
                    ChoiceOption(.hand, "Tap the glass before Gaines comes", "Reed jolts awake, sees you, nods. He'll remember.", [
                        .set(.reedCovered), .staff(.reed, 10),
                    ]),
                    ChoiceOption(.badge, "Tell Lt. Gaines", "Procedure. Gaines notes your name. Reed notes it too.", [
                        .set(.reedReported), .trust(4, "Reported sleeping post"), .staff(.reed, -10), .staff(.gaines, 4),
                    ]),
                    ChoiceOption(.zzz, "Let him sleep", "Not your shift.", [.set(.reedCovered)]),
                  ]),
        ChoiceDef(id: .adaDecision, title: "A miscount", icon: .list,
                  prompt: "Forty on the sheet. Thirty-two in the box. Ada, quietly: \"The dish pit. Their hands crack.\"", speaker: .ada, options: [
                    ChoiceOption(.badge, "Report the count to Okonjo", "The sheet is right again. Ada stops talking to you for a while.", [
                        .set(.adaMiscountReported), .staff(.okonjo, 3), .trust(3, "Accurate count"), .peer(.ada, -6),
                    ]),
                    ChoiceOption(.check, "Let the sheet say forty", "The dish pit keeps its gloves.", risky: true, [
                        .set(.adaMiscountCovered), .peer(.ada, 8), .favor(.ada, 1), .peer(.rosa, 3),
                    ]),
                    ChoiceOption(.question, "Ask Ada to tell Okonjo herself", "She does — and asks for a glove order for the kitchen.", when: .peer(.ada, 10), [
                        .set(.adaMiscountReported), .peer(.ada, 3), .staff(.okonjo, 2),
                    ]),
                  ]),
    ]
}
