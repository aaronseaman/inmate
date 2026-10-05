import Foundation

/// Factories for every minigame beyond the mop.
enum MinigameCatalog {
    static let all: [MinigameID: (MinigameConfig) -> Minigame] = [
        .kitchenLine: { KitchenLineGame($0) },
        .laundrySort: { LaundrySortGame($0) },
        .libraryShelve: { LibraryShelveGame($0) },
        .supplyMatch: { SupplyMatchGame($0) },
        .sewing: { SewingGame($0) },
        .garden: { GardenGame($0) },
        .basketball: { BasketballGame($0) },
        .horseshoes: { HorseshoesGame($0) },
        .weights: { WeightsGame($0) },
        .art: { ArtGame($0) },
        .chess: { ChessGame($0) },
        .dominoes: { DominoesGame($0) },
        .crazyEights: { CrazyEightsGame($0) },
        .drain: { DrainGame($0) },
        .gurney: { GurneyGame($0) },
        .cartDrive: { CartDriveGame($0) },
        .vanDrive: { CartDriveGame($0, van: true) },
        .filing: { FilingGame($0) },
        .mailSort: { MailSortGame($0) },
    ]
}
