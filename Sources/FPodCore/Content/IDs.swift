import Foundation

// Stable content identifiers. Raw values are persisted in saves — never rename
// a raw value; add new cases instead.

public enum ItemID: String, Codable, CaseIterable {
    // Food & everyday
    case snack, peanutButter, coffee, soap, tomatoes, sugar, earplugs, batteries
    // Informal currency & contraband
    case cigarettes, pillToken, hooch, phone, charger, dice, tattooDevice, weaponToken, note
    // Media & leisure
    case radio, brokenRadio, headphones, book, hollowBook, workbook, lawBook, chessSet, cards, pencils, drawing, hymnal, glasses, photo
    // Tools, keys & props
    case janitorKey, utilityKey, recordsKey, screwdriver, copperWire, fenceTool, clipboard, mop, tray, laundryBag, deliveryBox, visitorBadge
    // Maps
    case mapScrapA, mapScrapB, mapScrapC, tunnelMap
    // Papers
    case requestForm, recordsRequest, grievanceForm, visitForm, letter, chartCopy, courtDocket, transportLog, witnessStatement
    case supportLetter, housingLetter, clinicReferral, jobLead, petition, lawyerCard
    // Outfits (carried folded; worn via outfit slot)
    case tanScrubs, maintenanceJumpsuit, whiteCoat, coUniform, visitorClothes, kitchenWhites, laundryWhites, ppeGown, chaplainShirt
}

public enum NPCID: String, Codable, CaseIterable {
    // Peers (patient-prisoners)
    case dutch, marisol, benny, theo, lou, moss, kenji, staticFell, ada, fitz, rosa, harlan, mouse, abe
    // Staff
    case haskins, reed, strick, cole, varga, sato, okonjo, pruitt, gaines, bell, feld, odell, abernathy, nico, tran
    // Visitors / outside
    case calloway, nadia
}

public enum JobID: String, Codable, CaseIterable {
    case kitchen, laundry, janitorial, library, infirmary, workshop, grounds
}

public enum MinigameID: String, Codable, CaseIterable {
    // Jobs
    case mop, kitchenLine, laundrySort, libraryShelve, supplyMatch, sewing, garden
    // Leisure
    case basketball, weights, chess, dominoes, crazyEights, horseshoes, art
    // Special
    case drain, gurney, cartDrive, filing, mailSort
    case vanDrive
}

public enum QuestID: String, Codable, CaseIterable {
    // Main arc
    case m01Intake, m02Ally, m03Work, m04Radio, m05Cellmate, m06Lawyer, m07Contradiction, m08Records
    case m09Theo, m10Review, m11Plan, m12Release, m12Advocacy, m12Escape
    // Side quests
    case sDutchLetters, sBennyDice, sTheoChess, sLouSpotter, sMossHymnal, sKenjiPortrait, sStaticAntenna
    case sAdaCount, sFitzPhoto, sRosaRush, sHarlanDebt, sMouseDrain, sAbeRide, sGarden, sLostBook
    case sLaundryMixup, sBuffer, sCommissaryError, sHaskinsCard, sReedNap, sStrickSearch, sGurneyRun
    case sVisitorDay, sHorseshoes, sCardNight, sIsolationLetter, sClerkFiling, sCartDerby, sMailRound
}

/// Story/world flags. Persisted by raw value.
public enum Flag: String, Codable, CaseIterable {
    // Intake / tutorial
    case claimedBunk, readChart, firstCountDone, metDutch, firstTrade, medDiscussRequested, tookMeds
    case jobTrialDone, mouseErrandOffered, mouseNoteFetched, mouseErrandReported, firstHide
    // Allies
    case allyMarisol, allyLou, allyDutch
    // Work
    case workAssigned, rosaVouched
    // Radio
    case radioBought, radioRepaired, radioStolen, staticHelped, radioReturnedToHarlan
    // Cellmate
    case fitzTalked, cellAgreement, cellMediated, cellSwapped, fitzBoundaryResolved
    // Lawyer
    case lawyerNumberKnown, phoneListApproved, calledLawyer, usedContrabandPhone, lawyerVisitScheduled, lawyerMet
    // Contradiction
    case gotCourtDocket, gotChartCopy, contradictionFound
    // Records
    case recordsRequested, recordsApproved, recordsTaken, transportLogHave, recordsCaught
    // Theo
    case theoAccused, theoHelped, theoTestified, theoStayedOut, theoCleared
    // Review
    case reviewPrepRoles, reviewPrepCharges, reviewPrepCommunication, reviewPrepped, reviewHeld, reviewPassed, reviewDeferred
    // Discharge plan
    case planContact, planDestination, planSupports, planApprovedSato, planApprovedCalloway, planComplete
    // Advocacy
    case grievanceFiled, strickDocumented, petitionSigned, advocacyMeeting
    // Escape
    case tunnelHatchKnown, culvertKnown, vanScheduleKnown, escapeReady, escapeStarted, perimeterReached
    // Endings
    case endingRelease, endingAdvocacy, endingEscape, gameFinished, preFinaleSaved
    // Side quests and misc world changes
    case dutchGlassesFound, bennyDiceExposed, lousSpotterDone, hymnalReturned, kenjiPortraitDone
    case adaMiscountReported, adaMiscountCovered, fitzPhotoFound, harlanDebtSettled, gardenPlanted
    case lostBookReturned, coUniformReturned, coUniformKept, commissaryRefunded, haskinsCardGiven
    case reedCovered, reedReported, strickSearchWitnessed, visitorDayDone, mailRoundDone
    case libraryCardIssued, phoneUnlocked, commissaryUnlocked, kitchenWhitesIssued, laundryWhitesIssued
    case maintenanceIssued, chaplainShirtLent, whiteCoatFound, ppeRouteKnown, isolationLetterDelivered
    case clerkFilingDone, cartDerbyDone, abeRideDone, gurneyRunDone, horseshoeWon, cardNightWon
    case restraintEventSeen, seclusionEventSeen, complaintOpened, watch72Assigned, watch72Reviewed
    case lockdownActive, harlanThreat, weaponSurrendered, hoochDumped, staticAntennaDone
    case tutorialMove, tutorialInteract, tutorialSneak, tutorialHide, tutorialCount, tutorialSchedule, tutorialStatus
    case medDeclined, mouseErrandDeclined, firstEveningCount, trialGood, trialDone
    // Systems: job risk choices, favors, routine
    case closetHatchReported, closetHatchKept, sugarSkimmed, sugarRefused, rackSpareTaken, rackReported
    case libraryNoteCarried, libraryNoteRefused, copperTaken, copperDeclined, copperOffcuts, k9Noted, k9Waved
    case favorDutchVouch, favorMouseHatch, favorLouCover, favorMarisolPapers, favorAdaRoute, favorMossShirt
    case favorAbeRoutes, favorStaticRadio, favorKenjiDrawing, favorRosaVouch, louProtection
    case medAdjusted, medRefusedInformed, commissaryRequested, jobChoiceKitchen, jobChoiceLaundry
    case jobChoiceJanitorial, jobChoiceLibrary, jobChoiceInfirmary, jobChoiceWorkshop, jobChoiceGrounds
    case tryoutKitchen, tryoutLaundry, tryoutLibrary, tryoutInfirmary, tryoutWorkshop, tryoutGrounds
    // Main arc beats
    case firstShiftWorked, radioListened, contradictionReported, chartCorrected, phoneListPending, subpoenaRequested
    case reviewScheduled, transportLogRead, recordsHonest, recordsLied, finaleChosen, lockdownSeen, theoEventSeen
    case harlanRadioAngry, reviewQuizPassed, nadiaCalled, clinicReferralGiven, jobLeadGiven, housingFromNadia, housingFromBell
    case mapAssembled, utilityKeyCopied, escapeNight, grievanceStrick, administratorMet
    // Petition signatures
    case signedDutch, signedMarisol, signedMoss, signedTheo, signedKenji, signedAda, signedLou, signedRosa, signedAbe
    // Side arc beats
    case bufferDone, fitzConsent, haskinsCardDutch, haskinsCardRosa, haskinsCardMoss, harlanPaid, harlanReported
    case bennyDiceKept, kenjiRestrained, sisterVisitScheduled, isolationLetterHave, lostBookFound, mailLetterFound
    case dutchLetterRead, gardenTended, commissaryErrorSeen, strickReported, abeAsked, theoBeaten, cardNightPlayed
    case staticAntennaWire, adaCountDone, rosaRushDone, laundryMixupFound
    case theoResolved, strickRetaliation, hearingDressed, reviewAttempted, escapeKeyStolen
    case drainNoteReturned, abeRiding, bennyTalkedPrivately
}

public enum ItemSize: Int, Codable, Comparable {
    case tiny = 0, small = 1, medium = 2, large = 3
    public static func < (a: ItemSize, b: ItemSize) -> Bool { a.rawValue < b.rawValue }
    public var bulk: Int {
        switch self {
        case .tiny: return 1
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        }
    }
    public var title: String {
        switch self {
        case .tiny: return "Tiny"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

public enum Legality: Int, Codable, Comparable {
    case legal = 0        // allowed
    case restricted = 1   // allowed only with a job/permission; otherwise confiscated
    case contraband = 2   // prohibited
    case dangerous = 3    // prohibited, severe incident if found
    public static func < (a: Legality, b: Legality) -> Bool { a.rawValue < b.rawValue }
    public var title: String {
        switch self {
        case .legal: return "Allowed"
        case .restricted: return "Restricted"
        case .contraband: return "Contraband"
        case .dangerous: return "Dangerous"
        }
    }
}

/// Clothing roles. Tan scrubs are the default.
public enum Outfit: String, Codable, CaseIterable {
    case tanScrubs, maintenance, whiteCoat, co, visitor, kitchenWhites, laundryWhites, ppe, chaplain

    public var item: ItemID {
        switch self {
        case .tanScrubs: return .tanScrubs
        case .maintenance: return .maintenanceJumpsuit
        case .whiteCoat: return .whiteCoat
        case .co: return .coUniform
        case .visitor: return .visitorClothes
        case .kitchenWhites: return .kitchenWhites
        case .laundryWhites: return .laundryWhites
        case .ppe: return .ppeGown
        case .chaplain: return .chaplainShirt
        }
    }
    public static func from(item: ItemID) -> Outfit? { Outfit.allCases.first { $0.item == item } }

    public var title: String {
        switch self {
        case .tanScrubs: return "Tan scrubs"
        case .maintenance: return "Gray maintenance jumpsuit"
        case .whiteCoat: return "White coat"
        case .co: return "Navy CO uniform"
        case .visitor: return "Visitor clothes"
        case .kitchenWhites: return "Kitchen whites"
        case .laundryWhites: return "Laundry whites"
        case .ppe: return "Yellow PPE gown"
        case .chaplain: return "Chaplain black shirt"
        }
    }
    public var color: RGBA {
        switch self {
        case .tanScrubs: return Palette.tan
        case .maintenance: return RGBA(hex: 0x8C969A)
        case .whiteCoat: return RGBA(hex: 0xF7F5F0)
        case .co: return Palette.navy
        case .visitor: return RGBA(hex: 0x7C9CB4)
        case .kitchenWhites: return RGBA(hex: 0xF0EEE8)
        case .laundryWhites: return RGBA(hex: 0xE9EEF0)
        case .ppe: return RGBA(hex: 0xE5C65A)
        case .chaplain: return RGBA(hex: 0x2F3236)
        }
    }
    public var pants: RGBA {
        switch self {
        case .tanScrubs: return Palette.tan.darker(0.12)
        case .maintenance: return RGBA(hex: 0x7C878B)
        case .whiteCoat: return Palette.slate
        case .co: return Palette.navy.darker(0.2)
        case .visitor: return RGBA(hex: 0x4E5A66)
        case .kitchenWhites: return RGBA(hex: 0x5A6670)
        case .laundryWhites: return RGBA(hex: 0xD3DADD)
        case .ppe: return RGBA(hex: 0x5A6670)
        case .chaplain: return RGBA(hex: 0x3C4046)
        }
    }
    /// Zone classes in which this outfit is a plausible role.
    public var plausibleIn: Set<ZoneClass> {
        switch self {
        case .tanScrubs: return [.home, .ownCell, .dining, .yard, .program, .transit]
        case .maintenance: return [.closet, .service, .transit, .work, .home]
        case .whiteCoat: return [.medical, .records, .transit, .adminPublic]
        case .co: return [.staffOnly, .transit, .home, .dining, .yard]
        case .visitor: return [.adminPublic]
        case .kitchenWhites: return [.dining, .work, .transit]
        case .laundryWhites: return [.work, .transit, .service]
        case .ppe: return [.isolation, .medical, .restricted]
        case .chaplain: return [.program, .transit, .restricted]
        }
    }
    /// How strongly familiar staff scrutinize this role at close range (0..1).
    public var inspectionRisk: Double {
        switch self {
        case .tanScrubs: return 0
        case .maintenance: return 0.35
        case .whiteCoat: return 0.5
        case .co: return 0.9
        case .visitor: return 0.55
        case .kitchenWhites: return 0.25
        case .laundryWhites: return 0.25
        case .ppe: return 0.3
        case .chaplain: return 0.45
        }
    }
    /// Prop that makes this role more plausible when carried.
    public var supportingProps: [ItemID] {
        switch self {
        case .tanScrubs: return []
        case .maintenance: return [.mop, .screwdriver]
        case .whiteCoat: return [.clipboard]
        case .co: return [.clipboard]
        case .visitor: return [.visitorBadge]
        case .kitchenWhites: return [.tray]
        case .laundryWhites: return [.laundryBag, .deliveryBox]
        case .ppe: return [.deliveryBox]
        case .chaplain: return [.hymnal]
        }
    }
}
