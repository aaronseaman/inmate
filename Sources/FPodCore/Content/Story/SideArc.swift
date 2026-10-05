import Foundation

// Side errands: small stories about the people on the pod. Each one leans on a
// system (a job, an outfit, a minigame, a favor) and changes something afterward.

enum SideArc {
    static func q(_ id: QuestID, _ title: String, icon: Icon, giver: NPCID?, location: String, summary: String, prereq: Cond, autoStart: Bool = false,
                  stages: [StageDef], reward: String, change: String) -> QuestDef {
        QuestDef(id, .side, title, icon: icon, giver: giver, location: location, summary: summary, prerequisite: prereq, autoStart: autoStart,
                 stages: stages, reward: reward, worldChange: change, failure: "Errands wait for you; nothing here closes for good.")
    }

    static let quests: [QuestDef] = [
        q(.sDutchLetters, "Small print", icon: .glasses, giver: .dutch, location: "Sewing room · Dutch's bench",
          summary: "Dutch's daughter writes every week. His reading glasses broke a month ago.", prereq: .all([.peer(.dutch, 8), .dayAtLeast(3)]), stages: [
            StageDef("Find Dutch a pair of reading glasses", icon: .glasses, completeWhen: .has(.glasses),
                     approaches: ["The notions shelf in the sewing room collects lost glasses.", "Ask around — someone always has a spare."]),
            StageDef("Give Dutch the glasses", icon: .heart, marker: .npc(.dutch), completeWhen: .flag(.dutchGlassesFound)),
            StageDef("Sit with him while he reads", icon: .letter, marker: .npc(.dutch), completeWhen: .flag(.dutchLetterRead)),
          ], reward: "Coffee, and Dutch's trust.", change: "Dutch reads his letters aloud at the bench now."),
        q(.sBennyDice, "Loaded", icon: .dice, giver: .benny, location: "Dayroom tables",
          summary: "Benny's dice game never seems to lose.", prereq: .dayAtLeast(3), stages: [
            StageDef("Play a round of dice with Benny (free time)", icon: .dice, marker: .npc(.benny), completeWhen: .any([.flag(.bennyDiceExposed), .flag(.bennyDiceKept)])),
          ], reward: "Depends what you do with what you saw.", change: "Either the game gets honest or you get a cut."),
        q(.sTheoChess, "Theo's opening", icon: .chess, giver: .theo, location: "Dayroom",
          summary: "Theo plays everyone. Nobody beats him. He'd like someone to.", prereq: .dayAtLeast(3), stages: [
            StageDef("Beat Theo at chess (free time, dayroom)", icon: .chess, marker: .npc(.theo), completeWhen: .flag(.theoBeaten),
                     approaches: ["Assist mode counts — he'd rather lose to you than to nobody."]),
          ], reward: "Theo owes you a favor.", change: "Theo starts teaching openings at the dayroom table."),
        q(.sLouSpotter, "Spotter", icon: .dumbbell, giver: .lou, location: "Rec yard",
          summary: "Lou wants a spotter who shows up. Three days running.", prereq: .any([.flag(.allyLou), .peer(.lou, 10)]), stages: [
            StageDef("Lift with Lou on three different days", icon: .dumbbell, marker: .object("yard.weights1"), completeWhen: .stat("lou.spot", 3)),
          ], reward: "Lou watches your back.", change: "Nobody leans on you in the yard."),
        q(.sMossHymnal, "The missing hymnal", icon: .hymnal, giver: .moss, location: "Chapel",
          summary: "Moss's hymnal walked off. He suspects the vestry shelf, where he isn't allowed.", prereq: .dayAtLeast(3), stages: [
            StageDef("Find Moss's hymnal", icon: .search, marker: .object("chapel.hymnals"), completeWhen: .has(.hymnal),
                     approaches: ["The chapel vestry shelf. A chaplain's helper shirt makes it look like your business."]),
            StageDef("Give it back to Moss", icon: .heart, marker: .npc(.moss), completeWhen: .flag(.hymnalReturned)),
          ], reward: "Moss's favor — and a voice for your petition.", change: "Moss sings on Sundays again."),
        q(.sKenjiPortrait, "A portrait, with permission", icon: .drawing, giver: .kenji, location: "Your cell · Kenji",
          summary: "Kenji wants to draw Fitz's son from the photo. He never draws a real person without their say-so.", prereq: .flag(.fitzPhotoFound), stages: [
            StageDef("Ask Fitz if Kenji may draw his son", icon: .question, marker: .npc(.fitz), completeWhen: .flag(.fitzConsent)),
            StageDef("Bring Kenji colored pencils", icon: .pencil, marker: .npc(.kenji), completeWhen: .flag(.kenjiPortraitDone),
                     approaches: ["Commissary, 3 credits.", "The sewing-room notions shelf."]),
          ], reward: "Fitz cries a little. Don't mention it.", change: "The drawing hangs over the bottom bunk."),
        q(.sStaticAntenna, "Antenna", icon: .wire, giver: .staticFell, location: "Workshop · Static",
          summary: "Static's antenna needs copper. The workshop scrap crate has copper. Feld counts the crate.", prereq: .questActive(.m04Radio), stages: [
            StageDef("Get a length of copper wire", icon: .wire, completeWhen: .has(.copperWire),
                     approaches: ["Workshop scrap crate (counted).", "Ask Feld for offcuts once he trusts you."]),
            StageDef("Give it to Static", icon: .radio, marker: .npc(.staticFell), completeWhen: .flag(.staticAntennaDone)),
          ], reward: "Static's favor; better reception.", change: "Static's radio picks up the legal-aid hour clean."),
        q(.sAdaCount, "Ada's count", icon: .list, giver: .ada, location: "Infirmary",
          summary: "Ada keeps the infirmary supply count by heart. Lately the numbers don't add up.", prereq: .all([.dayAtLeast(4), .peer(.ada, 5)]), stages: [
            StageDef("Help Ada count the supply cabinet", icon: .list, marker: .npc(.ada), completeWhen: .flag(.adaCountDone)),
            StageDef("Decide what to do about the miscount", icon: .question, completeWhen: .any([.flag(.adaMiscountReported), .flag(.adaMiscountCovered)])),
          ], reward: "Ada's respect, or Okonjo's.", change: "Either the dish pit gets a glove order or it keeps its secret."),
        q(.sFitzPhoto, "The photo", icon: .photo, giver: .fitz, location: "Laundry alcove",
          summary: "Fitz lost the photo of his son. He thinks it went into the wash in a shirt pocket.", prereq: .all([.dayAtLeast(3), .peer(.fitz, 2)]), stages: [
            StageDef("Look through the laundry alcove hampers", icon: .laundry, marker: .object("fpod.hamper2"), completeWhen: .has(.photo)),
            StageDef("Give Fitz the photo", icon: .heart, marker: .npc(.fitz), completeWhen: .flag(.fitzPhotoFound)),
          ], reward: "Fitz stops borrowing your soap. Mostly.", change: "The photo goes back on the wall."),
        q(.sRosaRush, "Dinner rush", icon: .meal, giver: .rosa, location: "Serving line",
          summary: "Friday dinner, two cooks short. Rosa needs hands — in whites.", prereq: .all([.dayAtLeast(3), .peer(.rosa, 8)]), stages: [
            StageDef("At dinner, in kitchen whites, help Rosa on the line", icon: .meal, marker: .npc(.rosa), completeWhen: .flag(.rosaRushDone),
                     approaches: ["Kitchen whites: the kitchen job, Rosa's spares, or the laundry rack."]),
          ], reward: "Rosa's favor and a second dessert.", change: "The line moves faster when you're on it."),
        q(.sHarlanDebt, "What Harlan says you owe", icon: .angry, giver: .harlan, location: "Dayroom",
          summary: "Harlan has decided you owe him. He's loud about it.", prereq: .any([.flag(.harlanRadioAngry), .dayAtLeast(7)]), autoStart: true, stages: [
            StageDef("Deal with Harlan", icon: .angry, marker: .npc(.harlan), completeWhen: .flag(.harlanDebtSettled),
                     approaches: ["Pay him off.", "Lou's protection makes him think twice.", "Tell Lt. Gaines.", "If you took his radio: give it back."]),
          ], reward: "Peace, of some kind.", change: "Harlan finds someone else to shout at."),
        q(.sMouseDrain, "Down the drain", icon: .water, giver: .mouse, location: "Showers",
          summary: "Mouse dropped a folded paper down the shower drain. She wants the note; you can keep the map scrap wrapped in it.", prereq: .any([.questActive(.m12Escape), .peer(.mouse, 10)]), stages: [
            StageDef("Fish it out of the shower drain", icon: .water, marker: .object("fpod.shower1"), completeWhen: .has(.mapScrapB)),
            StageDef("Give Mouse her note", icon: .note, marker: .npc(.mouse), completeWhen: .flag(.drainNoteReturned)),
          ], reward: "A map scrap and Mouse's favor.", change: "Mouse leaves you notes now."),
        q(.sAbeRide, "The long way to visiting", icon: .wheelchair, giver: .abe, location: "Dayroom → visiting room",
          summary: "Abe's grandson visits on the weekend. The visiting room is a long way in a chair.", prereq: .all([.dayAtLeast(3), .peer(.abe, 3)]), stages: [
            StageDef("Ask Abe how he wants the help", icon: .question, marker: .npc(.abe), completeWhen: .flag(.abeAsked)),
            StageDef("Visiting hours: push Abe's chair to the visiting room", icon: .wheelchair, marker: .zone("admin.visiting"), completeWhen: .flag(.abeRideDone),
                     approaches: ["Weekends, visiting block. Go at Abe's pace."]),
          ], reward: "Abe's bus-route sketch — with the service tunnels on it.", change: "Abe saves you a seat at visiting."),
        q(.sGarden, "Tomatoes", icon: .tomato, giver: .lou, location: "Garden beds (yard)",
          summary: "The yard garden beds need hands. Tomatoes are currency.", prereq: .dayAtLeast(3), stages: [
            StageDef("Tend the garden beds during rec", icon: .seed, marker: .object("garden.2"), completeWhen: .flag(.gardenPlanted)),
          ], reward: "Tomatoes every morning in the pantry.", change: "The yard smells like leaves."),
        q(.sLostBook, "Overdue", icon: .book, giver: .abernathy, location: "Library · your cell",
          summary: "A library book is three weeks overdue, checked out to cell F-3. It isn't yours.", prereq: .dayAtLeast(3), stages: [
            StageDef("Find the overdue book", icon: .search, marker: .npc(.fitz), completeWhen: .flag(.lostBookFound)),
            StageDef("Return it to Ms. Abernathy", icon: .book, marker: .npc(.abernathy), completeWhen: .flag(.lostBookReturned)),
          ], reward: "A library card — the law library opens to you.", change: "Abernathy nods at you. Abernathy does not nod."),
        q(.sLaundryMixup, "Navy in the wash", icon: .shirt, giver: .dutch, location: "Cart bay",
          summary: "Dutch's whites came back with a navy officer's shirt folded in. Somebody will miss it.", prereq: .dayAtLeast(4), stages: [
            StageDef("Sort Dutch's bundle at the cart bay laundry cart", icon: .laundry, marker: .object("cartbay.laundrycart"), completeWhen: .flag(.laundryMixupFound)),
            StageDef("Decide what happens to the uniform", icon: .question, completeWhen: .any([.flag(.coUniformReturned), .flag(.coUniformKept)])),
          ], reward: "Feld's gratitude, or a navy shirt.", change: "Either staff laundry gets a lock or you own a costume."),
        q(.sBuffer, "Inspection", icon: .buffer, giver: .haskins, location: "Dayroom",
          summary: "Inspection Friday. Haskins wants the dayroom floor buffed — without anyone getting knocked down.", prereq: .dayAtLeast(4), stages: [
            StageDef("Buff the dayroom floor (20 seconds, no collisions)", icon: .buffer, marker: .zone("fpod.dayroom"), completeWhen: .flag(.bufferDone),
                     approaches: ["Haskins lends the buffer from the closet. It's loud. People move. Mostly."]),
          ], reward: "5 credits and Haskins' approval.", change: "The dayroom shines. Strick slips on it once."),
        q(.sCommissaryError, "Double charge", icon: .coin, giver: .pruitt, location: "Records desk",
          summary: "Your commissary statement shows the same snack cakes twice.", prereq: .all([.flag(.commissaryUnlocked), .dayAtLeast(3), .stat("purchases", 1)]), autoStart: true, stages: [
            StageDef("File a correction with Ms. Pruitt (grievance form)", icon: .form, marker: .npc(.pruitt), completeWhen: .flag(.commissaryRefunded),
                     approaches: ["Grievance forms: Ms. Pruitt keeps blanks.", "Check the ledger in your journal: it's right there."]),
          ], reward: "Your 3 credits back, and a lesson in forms.", change: "You know how grievances work."),
        q(.sHaskinsCard, "Card for Haskins", icon: .drawing, giver: .moss, location: "Pod",
          summary: "It's Haskins' birthday. Moss wants a card from the pod — drawn by Kenji, signed by three.", prereq: .dayAtLeast(4), stages: [
            StageDef("Get a drawing for the card", icon: .drawing, completeWhen: .has(.drawing), approaches: ["Kenji, art therapy, or a trade."]),
            StageDef("Collect signatures: Dutch, Rosa, Moss", icon: .pencil,
                     completeWhen: .all([.flag(.haskinsCardDutch), .flag(.haskinsCardRosa), .flag(.haskinsCardMoss)])),
            StageDef("Give Haskins the card", icon: .heart, marker: .npc(.haskins), completeWhen: .flag(.haskinsCardGiven)),
          ], reward: "Haskins is, briefly, speechless.", change: "Haskins counts a little gentler."),
        q(.sReedNap, "Night desk", icon: .zzz, giver: .reed, location: "Officer station",
          summary: "CO Reed is asleep at the night desk. Lt. Gaines does rounds at midnight.", prereq: .all([.dayAtLeast(4), .activity([.settle, .freeTime]), .minuteBetween(1230, 1290)]),
          autoStart: true, stages: [
            StageDef("Decide what to do about CO Reed", icon: .question, marker: .npc(.reed), completeWhen: .any([.flag(.reedCovered), .flag(.reedReported)])),
          ], reward: "Reed's gratitude, or Gaines' attention.", change: "The night shift remembers."),
        q(.sStrickSearch, "What Strick calls a search", icon: .search, giver: .bell, location: "Cell F-4 · chapel",
          summary: "You saw what Strick did in Kenji's cell, and where Kenji was taken after.", prereq: .flag(.kenjiRestrained), autoStart: true, stages: [
            StageDef("Tell Chaplain Bell what you saw", icon: .candle, marker: .npc(.bell), completeWhen: .flag(.strickSearchWitnessed)),
            StageDef("Check on Kenji", icon: .heart, marker: .npc(.kenji), completeWhen: .flag(.strickReported)),
          ], reward: "Bell's notes go into the record.", change: "The advocacy path opens."),
        q(.sGurneyRun, "Ramp run", icon: .gurney, giver: .okonjo, location: "Infirmary ramp",
          summary: "Okonjo needs a supply gurney taken down the ramp to the lower corridor. Carefully.", prereq: .all([.dayAtLeast(4), .any([.job(.infirmary), .peer(.ada, 10)])]), stages: [
            StageDef("Take the supply gurney down the infirmary ramp", icon: .gurney, marker: .object("infirmary.ramp"), completeWhen: .flag(.gurneyRunDone)),
          ], reward: "3 credits and Okonjo's trust.", change: "Okonjo asks for you by name."),
        q(.sVisitorDay, "Nadia", icon: .heart, giver: nil, location: "Visiting room",
          summary: "Your sister wants to visit. She's bringing a letter from her landlord — and pictures of Biscuit.", prereq: .any([.flag(.phoneListApproved), .dayAtLeast(6)]), autoStart: true, stages: [
            StageDef("Put Nadia on your visitor list (Ms. Pruitt)", icon: .form, marker: .npc(.pruitt), completeWhen: .flag(.sisterVisitScheduled)),
            StageDef("See Nadia in the visiting room", icon: .heart, marker: .spot("visit.t2.in"), completeWhen: .flag(.visitorDayDone),
                     approaches: ["Your appointment opens the way. Visitor clothes are optional, and Nadia notices."]),
          ], reward: "A housing letter and a photo of Biscuit.", change: "Nadia is part of your plan."),
        q(.sHorseshoes, "Abe's mark", icon: .horseshoe, giver: .abe, location: "Rec yard pits",
          summary: "Abe has thrown horseshoes on every lawn from here to the coast. Beat his mark.", prereq: .dayAtLeast(3), stages: [
            StageDef("Beat Abe's mark at horseshoes (rec)", icon: .horseshoe, marker: .object("yard.shoes1"), completeWhen: .flag(.horseshoeWon)),
          ], reward: "Abe's favor.", change: "Abe tells the story of the 1998 county fair. Twice."),
        q(.sCardNight, "Card night", icon: .cards, giver: .dutch, location: "Dayroom",
          summary: "Card night at Dutch's table: crazy eights, house rules, no betting unless you want to.", prereq: .dayAtLeast(4), stages: [
            StageDef("Play crazy eights with Dutch (free time)", icon: .cards, marker: .npc(.dutch), completeWhen: .flag(.cardNightPlayed)),
          ], reward: "Dutch's favor if you win; coffee either way.", change: "You have a seat at card night."),
        q(.sIsolationLetter, "Mail for isolation", icon: .letter, giver: .ada, location: "Infirmary · isolation",
          summary: "The patient in isolation hasn't had mail in weeks. Ada has a letter for them and no way in.", prereq: .any([.flag(.ppeRouteKnown), .job(.infirmary)]), stages: [
            StageDef("Get the letter from Ada", icon: .letter, marker: .npc(.ada), completeWhen: .flag(.isolationLetterHave)),
            StageDef("Deliver it through the anteroom, in a yellow gown", icon: .gown, marker: .object("isolation.bed"), completeWhen: .flag(.isolationLetterDelivered),
                     approaches: ["PPE gowns: the anteroom shelf, or Okonjo if you're an orderly."]),
          ], reward: "Ada's trust.", change: "The isolation room gets mail."),
        q(.sClerkFiling, "The backlog", icon: .form, giver: .pruitt, location: "Records desk",
          summary: "Ms. Pruitt's filing backlog is three cabinets deep. She'd never ask. She's asking.", prereq: .all([.dayAtLeast(4), .staff(.pruitt, 3)]), stages: [
            StageDef("File folders at the records desk", icon: .form, marker: .object("clerk.files1"), completeWhen: .flag(.clerkFilingDone)),
          ], reward: "4 credits; your requests jump the queue.", change: "Records requests come back the same day."),
        q(.sCartDerby, "Cart derby", icon: .cart, giver: .abe, location: "Cart bay (weekend)",
          summary: "Weekend afternoons, the cart bay becomes a racetrack. Abe keeps the times.", prereq: .all([.dayAtLeast(5), .peer(.abe, 5)]), stages: [
            StageDef("Race a lap at the cart bay (weekend afternoon)", icon: .cart, marker: .object("cartbay.janitorcart"), completeWhen: .flag(.cartDerbyDone)),
          ], reward: "Bragging rights and Abe's stopwatch grin.", change: "Your lap time goes on the cart bay wall."),
        q(.sMailRound, "Mail call", icon: .envelope, giver: .haskins, location: "Corridor mailbox",
          summary: "Haskins needs help sorting the pod's mail. One envelope has your name on it.", prereq: .dayAtLeast(4), stages: [
            StageDef("Sort the mail at the corridor mailbox", icon: .envelope, marker: .object("corridor.mailbox"), completeWhen: .flag(.mailRoundDone)),
          ], reward: "A letter from Calloway's office.", change: "You know where the mail stops."),
    ]

    /// Side quests a person offers when you tap them (prerequisite met, not started).
    static let starters: [InteractionDef] = quests.compactMap { def in
        guard !def.autoStart, let giver = def.giver else { return nil }
        var effects: [Effect] = [.startQuest(def.id)]
        effects += onStart[def.id] ?? []
        return InteractionDef("side.start.\(def.id.rawValue)", .npc(giver), def.icon, "\(Cast.def(giver).short): \(def.title)",
                              when: .questAvailable(def.id), reply: [def.icon, .question], priority: 3, effects)
    }

    /// Setup when an errand begins (props placed in the world, captions).
    static let onStart: [QuestID: [Effect]] = [
        .sDutchLetters: [.caption("Dutch: Can't read my own kid's handwriting. Glasses broke. Don't make a thing of it.")],
        .sFitzPhoto: [.putInStash("fpod.hamper2", .photo, 1), .caption("Fitz: It was in my shirt pocket. If the wash ate it…")],
        .sMossHymnal: [.caption("Moss: Somebody shelved it with the vestry books. I'm not allowed back there.")],
        .sLostBook: [.caption("Abernathy: 'Small Engine Repair.' Checked out to F-3. Three weeks.")],
        .sMouseDrain: [.caption("Mouse: Shower one. Folded paper. Don't read the note. Do keep the map.")],
        .sAbeRide: [.caption("Abe: My grandson comes Saturday. The hallway's long. Ask me first, though.")],
        .sHaskinsCard: [.caption("Moss: Fifty-one tomorrow. She'll pretend she hates it.")],
        .sCardNight: [.caption("Dutch: Crazy eights. Eights are wild. Benny is not allowed to deal.")],
        .sIsolationLetter: [.caption("Ada: The anteroom has gowns. Gown on, gown off. Nobody stops a delivery.")],
        .sClerkFiling: [.caption("Pruitt: Alphabetical. By last name. People get this wrong. Constantly.")],
        .sCartDerby: [.caption("Abe: Three gates. Don't clip the cones. Record's forty seconds.")],
        .sMailRound: [.caption("Haskins: Pod numbers on the front. Legal mail gets logged. Don't read anything.")],
        .sTheoChess: [.caption("Theo: Nobody beats me. I'd like somebody to. Not in a sad way.")],
        .sLouSpotter: [.caption("Lou: Three days. Show up three days.")],
        .sStaticAntenna: [.caption("Static: Copper. Thin gauge. The workshop's got a whole coil.")],
        .sAdaCount: [.caption("Ada: Help me count. Then tell me I'm not crazy.")],
        .sRosaRush: [.caption("Rosa: Friday. Dinner. Whites. Don't be late.")],
        .sGarden: [.caption("Lou: Beds by the bleachers. Water, weeds, stakes. Tomatoes don't lie.")],
        .sLaundryMixup: [.caption("Dutch: Navy shirt in my whites. Someone at the cart bay mixed the bags.")],
        .sBuffer: [.caption("Haskins: Inspection. Buffer's in the closet. Don't hit anyone.")],
        .sGurneyRun: [.caption("Okonjo: Gurney down the ramp. Slowly. I mean it.")],
        .sHorseshoes: [.caption("Abe: Six shoes. Beat my mark.")],
        .sBennyDice: [.caption("Benny: Dice. Friendly stakes. Very friendly.")],
        .sKenjiPortrait: [.caption("Kenji: The kid in Fitz's photo. Only if Fitz says yes.")],
    ]
}
