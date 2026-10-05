import Foundation

// Main arc, chapters 3–12. Every stage has at least two approaches; nothing that
// matters is a single dexterity check (assist mode passes any minigame).

enum MainArc {
    static let quests: [QuestDef] = [
        QuestDef(.m03Work, .main, "Work, for credit", icon: .work, giver: .haskins, location: "Job board, dayroom",
                 summary: "Credits buy soap, coffee and phone time. Work is how you get them — and how staff start to see you.",
                 prerequisite: .questDone(.m02Ally), autoStart: true, stages: [
                    StageDef("Get a work assignment", icon: .work, marker: .object("fpod.board"), completeWhen: .hasJob,
                             approaches: ["Read the job board in the dayroom.", "Ask a supervisor for a tryout.", "An ally can vouch for you.",
                                          "CO Haskins always needs someone on the mop."]),
                    StageDef("Work a full shift at your station", icon: .clock, completeWhen: .flag(.firstShiftWorked),
                             approaches: ["Shifts run 08:00–11:00 and 13:00–15:00. Tap your station to start."]),
                    StageDef("Open a commissary account", icon: .coin, marker: .npc(.pruitt),
                             completeWhen: .any([.flag(.commissaryUnlocked), .trustTier(2)]),
                             approaches: ["Take a request form from the board and give it to Ms. Pruitt at the records desk.",
                                          "Or keep your nose clean until trust tier 2."]),
                 ], reward: "Wages (6–12 credits a shift) and a commissary account.", worldChange: "Supervisors start greeting you by name.",
                 failure: "A missed shift only costs that shift."),

        QuestDef(.m04Radio, .main, "Something to listen to", icon: .radio, giver: .staticFell, location: "Commissary · donation box · F-5",
                 summary: "Static swears the legal-aid hour on 104.5 reads out public defender numbers every night. You need a radio.",
                 prerequisite: .all([.questDone(.m02Ally), .dayAtLeast(3)]), autoStart: true, stages: [
                    StageDef("Get a radio", icon: .radio, completeWhen: .has(.radio),
                             onComplete: [.ifThen(.hasOwned(.radio, .harlan),
                                                  [.set(.radioStolen), .set(.harlanRadioAngry), .bubble(.harlan, [.angry, .radio])], [])],
                             approaches: ["Buy one at the commissary: 35 credits, a special order.",
                                          "The donation box in the sewing room has a broken radio. Static fixes things for a favor.",
                                          "Harlan keeps his in the F-5 locker. Taking it will cost you."],
                             recovery: "Radios are claimable property at the records desk if confiscated."),
                    StageDef("Catch the legal-aid hour: listen in your cell after 21:00", icon: .moon, marker: .zone("fpod.cell3"),
                             completeWhen: .flag(.radioListened), approaches: ["Tap your bunk after 21:00 with the radio on you."]),
                 ], reward: "News, music, and a phone number.", worldChange: "If the radio was Harlan's, Harlan knows.",
                 failure: "Lost radios can be reclaimed or replaced."),

        QuestDef(.m05Cellmate, .main, "Bottom bunk diplomacy", icon: .bed, giver: .fitz, location: "Cell F-3",
                 summary: "Fitz borrows your soap, your snacks, your sleep. Nobody else is going to fix it.",
                 prerequisite: .all([.questDone(.m02Ally), .dayAtLeast(3)]), autoStart: true, stages: [
                    StageDef("Talk to Fitz about the borrowing", icon: .voice, marker: .npc(.fitz), completeWhen: .flag(.fitzTalked)),
                    StageDef("Settle it", icon: .heart, completeWhen: .flag(.fitzBoundaryResolved),
                             approaches: ["Agreement: split the shelf and trade him earplugs for the snoring.",
                                          "Mediation: Tech Cole sits you both down at group.",
                                          "A cell swap from CO Haskins (trust tier 2)."]),
                 ], reward: "A quieter cell — maybe a friend.", worldChange: "Fitz's photo of his son goes back on the wall.",
                 failure: "Arguments cool off by morning; you can try again."),

        QuestDef(.m06Lawyer, .main, "Ruth Calloway, Esq.", icon: .briefcase, giver: .marisol, location: "Library · phone · visiting room",
                 summary: "You have a public defender with forty other clients. Make yourself the one with documents.",
                 prerequisite: .all([.questDone(.m02Ally), .dayAtLeast(3)]), autoStart: true, stages: [
                    StageDef("Find your lawyer's number", icon: .search, completeWhen: .flag(.lawyerNumberKnown),
                             approaches: ["The law library keeps a directory — ask Ms. Abernathy.", "The radio's legal-aid hour reads it out.",
                                          "Marisol knows every public defender by first name."]),
                    StageDef("Get on the phone list — or find another phone", icon: .phone, marker: .npc(.pruitt),
                             completeWhen: .any([.flag(.phoneListApproved), .flag(.usedContrabandPhone), .flag(.calledLawyer)]),
                             approaches: ["Phone-list form from the board → Ms. Pruitt. Approved the next morning.",
                                          "Benny has a phone nobody admits exists. Risky."]),
                    StageDef("Call Ruth Calloway from the dayroom phone (free time)", icon: .phone, marker: .object("fpod.phone"),
                             completeWhen: .flag(.calledLawyer)),
                    StageDef("Meet Calloway in the visiting room", icon: .briefcase, marker: .spot("visit.t1.in"), completeWhen: .flag(.lawyerMet),
                             approaches: ["Your appointment opens the way to admin. Missed it? She reschedules."]),
                 ], reward: "The court docket — dates, in writing.", worldChange: "Calloway answers your calls now.",
                 failure: "Missed visits are rescheduled, never lost."),

        QuestDef(.m07Contradiction, .main, "Three-fourteen", icon: .search, giver: .calloway, location: "Your chart · the docket",
                 summary: "Somewhere between the chart and the docket, the story stops adding up.",
                 prerequisite: .questDone(.m06Lawyer), autoStart: true, stages: [
                    StageDef("Compare the docket with your chart", icon: .search, completeWhen: .flag(.contradictionFound),
                             approaches: ["Carry both papers and lay them out on your bunk or a library table.",
                                          "Marisol reads dockets for fun — ask her to look."],
                             recovery: "Lost a paper? Cole reprints the chart; Calloway resends the docket."),
                    StageDef("Tell someone who can act on it", icon: .voice, completeWhen: .flag(.contradictionReported),
                             approaches: ["Dr. Sato, in her office.", "Tech Cole, who passes it on.", "Calloway, by phone."]),
                 ], reward: "A crack in the record.", worldChange: "Dr. Sato starts reading your chart twice.",
                 failure: "Wrong guesses cost nothing. Look again."),

        QuestDef(.m08Records, .main, "The transport log", icon: .form, giver: .sato, location: "Records desk · records room",
                 summary: "If the transferring facility logged the wrong patient, the 03/14 transport log will show it.",
                 prerequisite: .questDone(.m07Contradiction), autoStart: true, stages: [
                    StageDef("Get the 03/14 transport log", icon: .form, marker: .npc(.pruitt), completeWhen: .has(.transportLog),
                             approaches: ["Authorized: a records request form to Ms. Pruitt; ready the next day.",
                                          "Ask Calloway (phone) to subpoena it — slower, airtight.",
                                          "Or into the records room yourself: night, a white coat, or the ceiling space. Risky."],
                             recovery: "Confiscated? Ms. Pruitt can reissue an authorized copy."),
                    StageDef("Read the transport log", icon: .eye, completeWhen: .docRead(.transportLog), onComplete: [.set(.transportLogRead)],
                             approaches: ["Open it from your bag."]),
                    StageDef("Bring the log to Dr. Sato", icon: .stethoscope, marker: .npc(.sato), completeWhen: .flag(.chartCorrected)),
                 ], reward: "A corrected chart.", worldChange: "The 03/14 'assault' leaves your record.",
                 failure: "Caught in the records room? The authorized request still works."),

        QuestDef(.m09Theo, .main, "Theo's word", icon: .chess, giver: .theo, location: "Dayroom",
                 summary: "You saw what happened to Theo. Your word could help him — and cost you.",
                 prerequisite: .all([.questDone(.m06Lawyer), .dayAtLeast(5)]), autoStart: true, stages: [
                    StageDef("Something is happening in the dayroom during free time", icon: .exclaim, marker: .zone("fpod.dayroom"),
                             completeWhen: .flag(.theoAccused), approaches: ["Be in the dayroom in the evening."]),
                    StageDef("Decide what to do about what you saw", icon: .people, marker: .npc(.moss),
                             completeWhen: .any([.flag(.theoTestified), .flag(.theoHelped), .flag(.theoStayedOut)]),
                             approaches: ["Write a witness statement for Ms. Pruitt — Strick will notice.", "Tell Chaplain Bell; she documents what she's told.",
                                          "Stay out of it."]),
                    StageDef("See how it lands", icon: .clock, completeWhen: .flag(.theoResolved), approaches: ["Sleep on it."]),
                 ], reward: "Theo's chess set — or his silence.", worldChange: "Peers remember who spoke up.",
                 failure: "Every choice here has a cost. None ends the game."),

        QuestDef(.m10Review, .main, "Competency review", icon: .gavel, giver: .sato, location: "Hearing room",
                 summary: "Understand the roles, understand the charges, be able to tell your side. Then face the panel.",
                 prerequisite: .questDone(.m08Records), autoStart: true, stages: [
                    StageDef("Prepare: roles, charges, and telling your side", icon: .list,
                             completeWhen: .all([.flag(.reviewPrepRoles), .flag(.reviewPrepCharges), .flag(.reviewPrepCommunication)]),
                             onComplete: [.set(.reviewPrepped), .set(.reviewScheduled),
                                          .appointment(id: "review.hearing", dayOffset: 1, start: 600, end: 690, title: "Competency review", icon: .gavel,
                                                       spot: "hearing.self", npc: .sato, quest: .m10Review)],
                             approaches: ["Roles: the courtroom guide in the library (Ms. Abernathy).",
                                          "Charges: Calloway by phone, or Marisol.", "Telling your side: practice with Tech Cole at group."]),
                    StageDef("Attend your review in the hearing room", icon: .gavel, marker: .spot("hearing.self"), completeWhen: .flag(.reviewPassed),
                             approaches: ["Chaplain Bell lends clothes for hearings if you ask.", "Deferred? Fix what the panel names and they'll see you again."]),
                 ], reward: "Found competent — the case can move.", worldChange: "Discharge planning opens.",
                 failure: "A deferral says what's missing and books a new date."),

        QuestDef(.m11Plan, .main, "A place to go", icon: .house, giver: .sato, location: "Phone · visiting room · offices",
                 summary: "Release needs a plan: someone to call, somewhere to live, help waiting, and two signatures.",
                 prerequisite: .all([.questDone(.m10Review), .trustTier(5)]), autoStart: true, stages: [
                    StageDef("Contact: call your sister Nadia", icon: .heart, marker: .object("fpod.phone"), completeWhen: .flag(.planContact),
                             approaches: ["Phone list needed (Ms. Pruitt).", "Or see her on visiting day."]),
                    StageDef("Destination: get a housing letter", icon: .house, completeWhen: .has(.housingLetter), onComplete: [.set(.planDestination)],
                             approaches: ["Nadia's landlord can write one — visiting day.", "Chaplain Bell knows a transitional house."]),
                    StageDef("Supports: a clinic referral and a job lead", icon: .stethoscope,
                             completeWhen: .all([.has(.clinicReferral), .has(.jobLead)]), onComplete: [.set(.planSupports)],
                             approaches: ["Dr. Sato writes clinic referrals.", "Your supervisor writes a job lead after three shifts."]),
                    StageDef("Approval: Dr. Sato signs; Calloway files", icon: .stamp,
                             completeWhen: .all([.flag(.planApprovedSato), .flag(.planApprovedCalloway)]), onComplete: [.set(.planComplete)],
                             approaches: ["Bring the letters to Dr. Sato.", "Then call Calloway."]),
                 ], reward: "A plan with your name on it.", worldChange: "The release hearing goes on the calendar.",
                 failure: "Missing pieces just wait for you."),

        QuestDef(.m12Release, .main, "Conditional release", icon: .sun, giver: .calloway, location: "Hearing room",
                 summary: "The plan is filed. One more hearing.",
                 prerequisite: .questDone(.m11Plan), autoStart: true, stages: [
                    StageDef("Be ready for the release hearing (tomorrow, 10:00)", icon: .gavel, completeWhen: .flag(.preFinaleSaved),
                             onComplete: [],
                             approaches: ["A save is made before the hearing so you can see other endings."]),
                    StageDef("Attend the release hearing", icon: .gavel, marker: .spot("hearing.self"), completeWhen: .flag(.endingRelease)),
                 ], reward: "Ending: Conditional Release.", worldChange: "—", failure: "—"),

        QuestDef(.m12Advocacy, .main, "A better placement", icon: .people, giver: .bell, location: "Records desk · dayroom · admin",
                 summary: "What happens on F-Pod is written down by the people who do it. Write it down yourselves.",
                 prerequisite: .all([.questDone(.m09Theo), .any([.flag(.strickDocumented), .flag(.theoTestified), .flag(.complaintOpened), .flag(.strickSearchWitnessed)])]),
                 stages: [
                    StageDef("File a grievance with Ms. Pruitt", icon: .form, marker: .npc(.pruitt), completeWhen: .flag(.grievanceFiled),
                             approaches: ["Grievance forms: Ms. Pruitt, or Marisol's favor.", "Chaplain Bell will attach her notes."]),
                    StageDef("Gather signatures: five peers on Marisol's petition", icon: .people,
                             completeWhen: .countFlags([.signedDutch, .signedMarisol, .signedMoss, .signedTheo, .signedKenji, .signedAda, .signedLou, .signedRosa, .signedAbe], 5),
                             onComplete: [.set(.petitionSigned)],
                             approaches: ["Each peer signs for their own reasons — and some want something first."]),
                    StageDef("Meet the Administrator", icon: .briefcase, marker: .spot("admin.chair"), completeWhen: .flag(.endingAdvocacy),
                             approaches: ["Chaplain Bell sets the meeting. A save is made before it."]),
                 ], reward: "Ending: A Better Placement.", worldChange: "—", failure: "Grievances can be refiled."),

        QuestDef(.m12Escape, .main, "Through the trees", icon: .map, giver: .mouse, location: "Tunnels · culvert · woods",
                 summary: "Mouse says the tunnels go under the fence. It is a fiction, and it has a price.",
                 prerequisite: .all([.flag(.tunnelHatchKnown), .dayAtLeast(6)]), stages: [
                    StageDef("Put the tunnel map together (three scraps → Mouse)", icon: .mapScrap, marker: .npc(.mouse), completeWhen: .has(.tunnelMap),
                             approaches: ["Mouse has one scrap; the shower drain and Abe hold the others.", "Static can sketch the pump room from memory."]),
                    StageDef("Get the utility key for the hatches", icon: .key, completeWhen: .has(.utilityKey),
                             approaches: ["Static can cut a copy from Nico's — he needs copper wire.", "Nico's key hangs in the pump room. Risky."]),
                    StageDef("Find a way through the outer fence", icon: .tools, completeWhen: .has(.fenceTool),
                             approaches: ["The groundskeepers' tool box by the lawn shed has a panel lifter.", "Lou has seen where they leave it."]),
                    StageDef("After lights out: tunnels → culvert → the tree line", icon: .moon, marker: .spot("escape.exit"),
                             completeWhen: .flag(.endingEscape),
                             approaches: ["Maintenance gray blends into the tunnels.", "The K-9 road is quiet when you noted it would be.",
                                          "A save is made when you go into the tunnels."]),
                 ], reward: "Ending: Through the Trees.", worldChange: "—", failure: "Caught? It's an incident, not a game over."),
    ]
}

// MARK: - Interactions

enum MainArcInteractions {
    static let list: [InteractionDef] = work + radio + cellmate + lawyer + contradiction + records + theo + review + plan + advocacy + escape

    static let work: [InteractionDef] = []

    static let radio: [InteractionDef] = [
        InteractionDef("radio.listen", .kind(.bunk), .radio, "Listen to the radio", when: .all([.has(.radio), .inOwnCell, .minuteBetween(1260, 1440)]), priority: 6, [
            .ifThen(.notFlag(.radioListened), [
                .set(.radioListened), .set(.lawyerNumberKnown), .give(.lawyerCard, 1),
                .caption("Radio: \"…public defender's office, collect calls weekdays. Ask for Ms. Calloway's desk.\""),
            ], [.caption("Radio: soul hour. Moss would approve.")]),
            .energy(5), .sound(.tvMumble),
            .ifThen(.has(.headphones), [.peer(.fitz, 1)], [.peer(.fitz, -1), .bubble(.fitz, [.zzz, .angry])]),
        ]),
        InteractionDef("radio.return", .npc(.harlan), .radio, "Give Harlan back his radio", when: .hasOwned(.radio, .harlan), reply: [.radio, .stop, .thumbsUp], priority: 7, [
            .returnOwned(.radio, .harlan), .set(.radioReturnedToHarlan), .clear(.harlanRadioAngry), .peer(.harlan, 8),
            .caption("Harlan: …Fine. We're square. Don't touch my stuff again."),
        ]),
    ]

    static let cellmate: [InteractionDef] = [
        InteractionDef("fitz.talk", .npc(.fitz), .voice, "Talk about the borrowing", when: .all([.questStage(.m05Cellmate, 0)]), reply: [.bed, .question], priority: 9, [
            .set(.fitzTalked), .choice(.cellmateRoute),
        ]),
        InteractionDef("fitz.talkAgain", .npc(.fitz), .voice, "Bring up the cell again", when: .all([.questStage(.m05Cellmate, 1), .not(.any([.flag(.cellAgreement), .flag(.cellMediated)]))]),
                       reply: [.bed, .question], priority: 8, [.choice(.cellmateRoute)]),
    ]

    static let lawyer: [InteractionDef] = [
        InteractionDef("lib.directory", .npc(.abernathy), .book, "Look up the public defender's office", when: .notFlag(.lawyerNumberKnown), reply: [.book, .phone],
                       priority: 6, [
                        .set(.lawyerNumberKnown), .give(.lawyerCard, 1), .staff(.abernathy, 1),
                        .caption("Abernathy: Calloway, Ruth. Public Defender, Unit B. Write it down — properly."),
                       ]),
        InteractionDef("marisol.lawyer", .npc(.marisol), .briefcase, "Ask who your lawyer is", when: .all([.notFlag(.lawyerNumberKnown), .any([.flag(.allyMarisol), .peer(.marisol, 10)])]),
                       reply: [.briefcase, .phone, .happy], priority: 6, [
                        .set(.lawyerNumberKnown), .give(.lawyerCard, 1), .caption("Marisol: Calloway. Good one. Overworked. Call before noon."),
                       ]),
        InteractionDef("board.phoneform", .kind(.noticeBoard), .phone, "Take a phone list form",
                       when: .all([.not(.has(.visitForm)), .notFlag(.phoneListApproved), .notFlag(.phoneListPending)]), priority: 2, [.give(.visitForm, 1)]),
        InteractionDef("pruitt.phonelist", .npc(.pruitt), .phone, "Submit your phone list",
                       when: .all([.has(.visitForm), .any([.has(.lawyerCard), .flag(.lawyerNumberKnown)]), .notFlag(.phoneListPending), .notFlag(.phoneListApproved)]),
                       reply: [.form, .stamp, .clock], priority: 7, [
                        .take(.visitForm, 1), .set(.phoneListPending), .staff(.pruitt, 1),
                        .caption("Pruitt: Lists post tomorrow at count. Your sister and your lawyer, yes? Both spelled right. Good."),
                       ]),
        InteractionDef("benny.phone", .npc(.benny), .phone, "Ask about the phone", when: .all([.flag(.lawyerNumberKnown), .notFlag(.calledLawyer), .notFlag(.phoneListApproved)]),
                       reply: [.phone, .quiet, .coin], priority: 5, [.choice(.contrabandPhone)]),
    ]

    static let contradiction: [InteractionDef] = [
        InteractionDef("papers.bunk", .kind(.bunk), .search, "Lay out your papers", when: .all([.has(.chartCopy), .has(.courtDocket), .notFlag(.contradictionFound), .inOwnCell]),
                       priority: 7, [.choice(.compareDocs)]),
        InteractionDef("papers.library", .object("library.table1"), .search, "Lay out your papers", when: .all([.has(.chartCopy), .has(.courtDocket), .notFlag(.contradictionFound)]),
                       priority: 7, [.choice(.compareDocs)]),
        InteractionDef("papers.marisol", .npc(.marisol), .search, "Ask Marisol to read both papers",
                       when: .all([.has(.chartCopy), .has(.courtDocket), .notFlag(.contradictionFound), .any([.flag(.allyMarisol), .peer(.marisol, 15)])]),
                       reply: [.search, .clock, .exclaim], priority: 8, [
                        .set(.contradictionFound), .peer(.marisol, 3),
                        .caption("Marisol: Three-fourteen, nine-forty, 'assault on staff.' Three-fourteen, nine o'clock, you're in County Court. Can't be both."),
                        .doc(.chartAnnotated),
                       ]),
        InteractionDef("tell.sato", .npc(.sato), .voice, "Show Dr. Sato the dates", when: .all([.flag(.contradictionFound), .notFlag(.contradictionReported)]),
                       reply: [.clipboard, .eye, .question], priority: 8, [
                        .set(.contradictionReported), .staff(.sato, 4), .trust(3, "Raised a records error"),
                        .caption("Sato: If the transferring facility logged the wrong patient, their transport log will show it. Get me that log."),
                       ]),
        InteractionDef("tell.cole", .npc(.cole), .voice, "Show Cole the dates", when: .all([.flag(.contradictionFound), .notFlag(.contradictionReported)]),
                       reply: [.clipboard, .heart], priority: 7, [
                        .set(.contradictionReported), .staff(.cole, 3),
                        .caption("Cole: I'll put it in front of Dr. Sato. You'll need the records to make it stick."),
                       ]),
    ]

    static let records: [InteractionDef] = [
        InteractionDef("pruitt.recordsform", .npc(.pruitt), .form, "Ask for a records request form",
                       when: .all([.questActive(.m08Records), .not(.has(.recordsRequest)), .notFlag(.recordsRequested), .not(.has(.transportLog))]), reply: [.form, .pencil], priority: 5, [
                        .give(.recordsRequest, 1), .caption("Pruitt: Blue ink. Facility name, date, document type. 'Transport log' is two words."),
                       ]),
        InteractionDef("pruitt.records", .npc(.pruitt), .form, "Submit the records request", when: .all([.has(.recordsRequest), .notFlag(.recordsRequested)]),
                       reply: [.form, .stamp, .clock], priority: 8, [
                        .take(.recordsRequest, 1), .set(.recordsRequested), .staff(.pruitt, 2),
                        .appointment(id: "pruitt.records", dayOffset: 1, start: 780, end: 900, title: "Records pickup (Ms. Pruitt)", icon: .form, spot: "clerk.client", npc: .pruitt, quest: .m08Records),
                        .caption("Pruitt: Correctly filled. Tomorrow afternoon."),
                       ]),
        InteractionDef("pruitt.collect", .npc(.pruitt), .form, "Collect your records", when: .all([.flag(.recordsApproved), .not(.has(.transportLog)), .notFlag(.chartCorrected)]),
                       reply: [.form, .check], priority: 8, [
                        .give(.transportLog, 1), .set(.transportLogHave), .caption("Pruitt: One transport log, certified copy. Sign here."),
                       ]),
        InteractionDef("records.search", .object("records.cab2"), .search, "Search the 03/14 transfer files",
                       when: .all([.questActive(.m08Records), .not(.has(.transportLog)), .notFlag(.chartCorrected)]), risky: true, witnessed: .theft, priority: 8, [
                        .give(.transportLog, 1), .set(.recordsTaken), .sound(.paper),
                       ]),
        InteractionDef("sato.log", .npc(.sato), .form, "Give Dr. Sato the transport log", when: .all([.has(.transportLog), .flag(.transportLogRead), .notFlag(.chartCorrected)]),
                       reply: [.form, .eye, .check], priority: 9, [
                        .ifThen(.flag(.recordsTaken), [.choice(.recordsHonesty)], [
                            .set(.chartCorrected), .staff(.sato, 8), .trust(8, "Chart corrected"),
                            .caption("Sato: 'Merrit, Joel. 40471-F.' Not you. I'm correcting your chart today."),
                        ]),
                       ]),
    ]

    static let theo: [InteractionDef] = [
        InteractionDef("theo.decide.moss", .npc(.moss), .people, "Talk about what happened to Theo", when: .questStage(.m09Theo, 1), reply: [.chess, .sad, .question], priority: 9, [
            .choice(.theoDecision),
        ]),
        InteractionDef("theo.decide.theo", .npc(.theo), .people, "Talk to Theo", when: .questStage(.m09Theo, 1), reply: [.sad, .quiet], priority: 9, [
            .choice(.theoDecision),
        ]),
    ]

    static let review: [InteractionDef] = [
        InteractionDef("review.roles", .npc(.abernathy), .book, "Ask for the courtroom guide", when: .all([.questStage(.m10Review, 0), .notFlag(.reviewPrepRoles)]),
                       reply: [.book, .gavel], priority: 8, [.choice(.courtQuiz)]),
        InteractionDef("review.charges.marisol", .npc(.marisol), .gavel, "Go over your charges", when: .all([.questStage(.m10Review, 0), .notFlag(.reviewPrepCharges)]),
                       reply: [.gavel, .form, .clock], priority: 8, [
                        .set(.reviewPrepCharges),
                        .caption("Marisol: Obstruction — you didn't move when told. Assault — pending, and it's the 03/14 thing. With the log, that one's weak."),
                       ]),
        InteractionDef("review.practice", .npc(.cole), .voice, "Practice telling your side", when: .all([.questStage(.m10Review, 0), .notFlag(.reviewPrepCommunication)]),
                       reply: [.voice, .heart, .thumbsUp], priority: 8, [
                        .set(.reviewPrepCommunication), .trust(2, "Prepared for review"),
                        .caption("You say it out loud: the dates, the name, the log. The third time, your voice stops shaking."),
                       ]),
    ]

    static let plan: [InteractionDef] = [
        InteractionDef("plan.referral", .npc(.sato), .stethoscope, "Ask for a clinic referral", when: .all([.questActive(.m11Plan), .not(.has(.clinicReferral))]),
                       reply: [.stethoscope, .form], priority: 7, [
                        .give(.clinicReferral, 1), .set(.clinicReferralGiven), .caption("Sato: Harbor Street clinic. They take walk-ins Tuesdays. Go."),
                       ]),
        InteractionDef("plan.house.bell", .npc(.bell), .house, "Ask about a transitional house", when: .all([.questActive(.m11Plan), .not(.has(.housingLetter))]),
                       reply: [.house, .heart], priority: 6, [
                        .give(.housingLetter, 1), .set(.housingFromBell), .caption("Bell: Saint Brendan's. Six beds, a curfew, good soup. I'll write them."),
                       ]),
        InteractionDef("plan.sign", .npc(.sato), .stamp, "Ask Dr. Sato to sign your plan",
                       when: .all([.questStage(.m11Plan, 3), .has(.housingLetter), .has(.clinicReferral), .has(.jobLead), .flag(.planContact), .notFlag(.planApprovedSato)]),
                       reply: [.stamp, .check, .happy], priority: 9, [
                        .set(.planApprovedSato), .doc(.dischargePlan), .caption("Sato: Contact, housing, clinic, work. Signed. Call your lawyer."),
                       ]),
    ] + JobID.allCases.map { j in
        let d = Jobs.def(j)
        return InteractionDef("plan.lead.\(j.rawValue)", .npc(d.supervisor), .work, "Ask for a reference",
                              when: .all([.questActive(.m11Plan), .job(j), .shiftsWorked(3), .not(.has(.jobLead))]), reply: [.work, .form, .thumbsUp], priority: 7, [
                                .give(.jobLead, 1), .set(.jobLeadGiven), .caption("\(Cast.def(d.supervisor).short): You showed up. That's what I'll write."),
                              ])
    }

    static let advocacy: [InteractionDef] = [
        InteractionDef("adv.start", .npc(.bell), .people, "Ask what can actually change here", when: .questAvailable(.m12Advocacy), reply: [.people, .form, .candle], priority: 8, [
            .startQuest(.m12Advocacy), .give(.petition, 1),
            .caption("Bell: Paper. Signatures. The administrator reads what's signed. Start with a grievance; Marisol has a petition."),
        ]),
        InteractionDef("adv.form", .npc(.pruitt), .form, "Ask for a grievance form", when: .all([.questActive(.m12Advocacy), .not(.has(.grievanceForm)), .notFlag(.grievanceFiled)]),
                       reply: [.form, .stamp], priority: 6, [.give(.grievanceForm, 1)]),
        InteractionDef("adv.file", .npc(.pruitt), .form, "File your grievance", when: .all([.questActive(.m12Advocacy), .has(.grievanceForm), .notFlag(.grievanceFiled)]),
                       reply: [.form, .stamp, .check], priority: 8, [
                        .take(.grievanceForm, 1), .set(.grievanceFiled), .set(.grievanceStrick), .staff(.pruitt, 2), .doc(.grievanceCopy),
                        .caption("Pruitt: Filed and stamped. You get a copy. They have to answer in writing."),
                       ]),
        InteractionDef("adv.meet", .npc(.bell), .briefcase, "Ask Bell to set the meeting", when: .all([.questStage(.m12Advocacy, 2), .notFlag(.administratorMet)]),
                       reply: [.briefcase, .clock], priority: 9, [
                        .savePreFinale,
                        .appointment(id: "admin.meeting", dayOffset: 0, start: 840, end: 960, title: "Meeting with the Administrator", icon: .briefcase, spot: "admin.chair", npc: .bell, quest: .m12Advocacy),
                        .caption("Bell: This afternoon. I'll be there. Bring the petition."),
                       ]),
    ] + [(NPCID.dutch, Flag.signedDutch, Cond.always, "Dutch: For the ones who can't write it."),
         (.marisol, .signedMarisol, .always, "Marisol: My name goes first. I wrote it."),
         (.moss, .signedMoss, .flag(.hymnalReturned), "Moss: You brought back my hymnal. Here's my hand."),
         (.theo, .signedTheo, .any([.flag(.theoTestified), .flag(.theoHelped)]), "Theo: You stood up. Okay."),
         (.kenji, .signedKenji, .flag(.kenjiPortraitDone), "Kenji: I'll sign it in ink."),
         (.ada, .signedAda, .peer(.ada, 15), "Ada: I was a nurse. I know what a record is worth."),
         (.lou, .signedLou, .flag(.allyLou), "Lou: Show up, sign up."),
         (.rosa, .signedRosa, .peer(.rosa, 15), "Rosa: For the line."),
         (.abe, .signedAbe, .flag(.abeRideDone), "Abe: The 14 never stopped running because someone complained. Still."),
    ].map { (npc, flag, cond, line) in
        InteractionDef("adv.sign.\(npc.rawValue)", .npc(npc), .pencil, "Ask to sign the petition",
                       when: .all([.questStage(.m12Advocacy, 1), .has(.petition), .notFlag(flag), cond]), reply: [.pencil, .thumbsUp], priority: 8, [
                        .set(flag), .peer(npc, 2), .caption(line),
                       ])
    }

    static let escape: [InteractionDef] = [
        InteractionDef("esc.start", .npc(.mouse), .map, "Ask Mouse about the tunnels", when: .questAvailable(.m12Escape), reply: [.map, .quiet, .eye], priority: 6, [
            .startQuest(.m12Escape), .give(.mapScrapA, 1),
            .caption("Mouse: One scrap's mine. The drain ate another. Abe remembers the rest. It's a long way under the fence."),
        ]),
        InteractionDef("esc.map", .npc(.mouse), .mapScrap, "Ask Mouse to put the map together",
                       when: .all([.has(.mapScrapA), .has(.mapScrapB), .has(.mapScrapC), .not(.has(.tunnelMap))]), reply: [.map, .check], priority: 9, [
                        .take(.mapScrapA, 1), .take(.mapScrapB, 1), .take(.mapScrapC, 1), .give(.tunnelMap, 1), .set(.mapAssembled), .set(.culvertKnown),
                        .caption("Mouse: Trunk line, pump room, culvert. The culvert grate's rusted through."),
                       ]),
        InteractionDef("esc.redraw", .npc(.mouse), .map, "Ask Mouse to redraw the map", when: .all([.flag(.mapAssembled), .not(.has(.tunnelMap)), .questActive(.m12Escape)]),
                       reply: [.map, .pencil, .quiet], priority: 8, [.give(.tunnelMap, 1), .caption("Mouse: I remember every turn. Don't lose it twice.")]),
        InteractionDef("esc.static.map", .npc(.staticFell), .mapScrap, "Ask Static to sketch the pump room",
                       when: .all([.questActive(.m12Escape), .not(.has(.mapScrapC)), .not(.has(.tunnelMap)), .favor(.staticFell, 1)]), reply: [.mapScrap, .wire], priority: 6, [
                        .favor(.staticFell, -1), .give(.mapScrapC, 1), .caption("Static: Pump room's here. Water goes out the culvert. So could you. Not that I said so."),
                       ]),
        InteractionDef("esc.key.static", .npc(.staticFell), .key, "Ask Static to cut a key copy",
                       when: .all([.questActive(.m12Escape), .has(.copperWire), .not(.has(.utilityKey))]), reply: [.key, .wire, .quiet], priority: 7, [
                        .take(.copperWire, 1), .give(.utilityKey, 1), .set(.utilityKeyCopied),
                        .caption("Static: Nico's key, from memory and a little copper. Don't tell me what it's for."),
                       ]),
        InteractionDef("esc.key.steal", .object("pump.tools"), .key, "Take Nico's utility key", when: .all([.questActive(.m12Escape), .not(.has(.utilityKey))]),
                       risky: true, witnessed: .theft, priority: 6, [.give(.utilityKey, 1), .set(.escapeKeyStolen)]),
    ]
}

// MARK: - Choices

enum MainArcChoices {
    static let list: [ChoiceDef] = [
        ChoiceDef(id: .cellmateRoute, title: "Bottom bunk diplomacy", icon: .bed,
                  prompt: "Fitz shrugs. \"Your soap was right there. And I can't help the snoring. What do you want, a treaty?\"",
                  speaker: .fitz, options: [
                    ChoiceOption(.swap, "A treaty: split the shelf, earplugs for the snoring", "You'll need foam earplugs (commissary, 1 credit) to seal it.", [
                        .set(.cellAgreement), .peer(.fitz, 3), .caption("Fitz: Left shelf's yours. Bring me earplugs and I'll even stop humming."),
                    ]),
                    ChoiceOption(.group, "Ask Tech Cole to mediate", "Cole books you both for a sit-down tomorrow afternoon.", [
                        .appointment(id: "cole.mediate", dayOffset: 1, start: 840, end: 900, title: "Mediation with Fitz (Tech Cole)", icon: .group, spot: "group.lead", npc: .cole, quest: .m05Cellmate),
                        .caption("Fitz: A meeting. About soap. Fine."),
                    ]),
                    ChoiceOption(.cellDoor, "Request a cell swap", "CO Haskins moves you to F-9. Fitz takes it personally.", when: .trustTier(2), [
                        .cellAssign(9), .set(.cellSwapped), .set(.fitzBoundaryResolved), .peer(.fitz, -5), .staff(.haskins, 1),
                    ]),
                    ChoiceOption(.quiet, "Let it go for now", "Nothing changes. You can bring it up again.", [.peer(.fitz, 1)]),
                  ]),
        ChoiceDef(id: .contrabandPhone, title: "Benny's phone", icon: .phone,
                  prompt: "Benny pats a pocket. \"Five minutes, two cigarettes. If anyone in a uniform looks this way, you were never here.\"",
                  speaker: .benny, options: [
                    ChoiceOption(.cigarette, "Two cigarettes, five minutes", "Call Calloway now. If staff see the phone, it's contraband.", when: .has(.cigarettes, 2), risky: true, [
                        .take(.cigarettes, 2), .peer(.benny, 3),
                        .ifThen(.unobserved, [.set(.usedContrabandPhone), .call(.calloway)],
                                [.incident(.contraband, witness: .haskins), .caption("A uniform turns your way. Benny's phone vanishes; you're the one holding nothing but trouble.")]),
                    ]),
                    ChoiceOption(.cross, "Not worth it", "Pruitt's phone list is slow but legal.", []),
                  ]),
        ChoiceDef(id: .compareDocs, title: "Two papers", icon: .search,
                  prompt: "The chart on the left, the court docket on the right. Which entries can't both be true?",
                  speaker: nil, options: [
                    ChoiceOption(.calendarIcon, "Arrest 03/02 · transfer 03/21", "Nineteen days apart. Slow, but not impossible.", [.caption("Slow paperwork isn't a lie. Look again.")]),
                    ChoiceOption(.clock, "03/14 09:40 'assault on staff' · 03/14 09:00 your County Court hearing",
                                 "You can't hit someone in one building while a judge watches you in another.", [
                        .set(.contradictionFound), .doc(.chartAnnotated), .sound(.success),
                    ]),
                    ChoiceOption(.person, "The name on the incident: MERRIT, J.", "One T. Your name has two.", [
                        .set(.contradictionFound), .doc(.chartAnnotated), .sound(.success),
                    ]),
                    ChoiceOption(.moon, "'Insomnia' · 'requests medication discussion'", "Both true. Not the problem.", [.caption("Both of those are you. Look again.")]),
                  ]),
        ChoiceDef(id: .recordsHonesty, title: "Where did this come from?", icon: .form,
                  prompt: "Dr. Sato turns the transport log over. No certification stamp. \"How did you get this?\"",
                  speaker: .sato, options: [
                    ChoiceOption(.voice, "Tell her the truth", "She requests a certified copy officially and corrects the chart. It goes in your incident file too.", [
                        .set(.recordsHonest), .set(.chartCorrected), .staff(.sato, 4), .trust(-2, "Records room"),
                        .caption("Sato: I'll request the certified copy myself. Don't do that again — and thank you for telling me."),
                    ]),
                    ChoiceOption(.briefcase, "Say Calloway sent it", "It works today. Records have long memories.", risky: true, [
                        .set(.recordsLied), .set(.chartCorrected), .staff(.sato, 2),
                    ]),
                  ]),
        ChoiceDef(id: .theoDecision, title: "Theo's word", icon: .chess,
                  prompt: "Strick wrote Theo up for 'assault on staff.' You saw it: Strick swept the chess set off the table and Theo yelled. Theo's on a 72-hour watch.",
                  speaker: .moss, options: [
                    ChoiceOption(.form, "Write a witness statement for Ms. Pruitt", "It clears Theo. Strick will make your week harder — and that's documented too.", risky: true, [
                        .set(.theoTestified), .set(.strickDocumented), .set(.strickRetaliation), .give(.witnessStatement, 1), .peer(.theo, 15), .peer(.moss, 5),
                        .staff(.strick, -20), .staff(.bell, 3),
                    ]),
                    ChoiceOption(.candle, "Tell Chaplain Bell", "She documents what she's told. Quieter, slower.", [
                        .set(.theoHelped), .staff(.bell, 4), .peer(.theo, 6),
                    ]),
                    ChoiceOption(.quiet, "Stay out of it", "Your week stays easy. Theo's doesn't.", [
                        .set(.theoStayedOut), .peer(.theo, -10), .peer(.moss, -5),
                    ]),
                  ]),
        ChoiceDef(id: .courtQuiz, title: "The courtroom guide", icon: .gavel,
                  prompt: "Ms. Abernathy taps a diagram of a hearing room. \"Pop quiz. Who decides whether you're competent to stand trial?\"",
                  speaker: .abernathy, options: [
                    ChoiceOption(.gavel, "The judge", "Correct. The evaluator reports; the judge decides.", [
                        .set(.reviewPrepRoles), .set(.reviewQuizPassed), .staff(.abernathy, 2),
                        .caption("Abernathy: The judge. Dr. Sato reports, your lawyer argues, the prosecutor argues back. Due Friday."),
                    ]),
                    ChoiceOption(.stethoscope, "Dr. Sato", "She evaluates and writes a report — the judge decides.", [.caption("Abernathy: Close. She reports. Who rules? Try again.")]),
                    ChoiceOption(.briefcase, "The prosecutor", "They argue; they don't decide.", [.caption("Abernathy: They argue. They don't decide. Try again.")]),
                  ]),
    ]
}

extension Icon {
    static var calendarIcon: Icon { .clock }
}
