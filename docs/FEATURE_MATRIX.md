# Feature matrix

Every requested mechanic, where it lives, how it was verified, and what remains.
Status: ✅ implemented and verified by automated tests or snapshots · ◐ implemented with a stated gap ·
✕ not done. "Verified" means Linux simulation tests (84 XCTests) and rendered snapshots; **no item has been run
on an iPhone or in the iOS Simulator** (see `KNOWN_LIMITATIONS.md`).

Abbreviations: `Sim/` = `Sources/FPodCore/Sim`, `Content/`, `Minigames/`, `Presentation/` likewise;
test names refer to `Tests/FPodCoreTests`.

## 1 · Platform and process

| Requirement | Status | Implementation | Verification / limitation |
|---|---|---|---|
| iPhone landscape, Swift + SpriteKit | ◐ | `iOS/FPod` (SpriteKit scene, CG rasterizer, AVAudioEngine) + generated `FPod.xcodeproj` | Type-checked on Linux against stub SDK modules only (`tools/ios-typecheck`). **Not built with Xcode, not run on Simulator/device.** |
| Small SwiftUI overlays | ◐ | Deliberately not used: all UI is the core display list (testable on Linux) + a UIKit VoiceOver overlay | Deviation documented here; behavior identical across tests and device. |
| Simulator keyboard controls | ✅ | `GameScene.keyDown` (WASD/arrows, E, R, C, I, M, J, Esc, F1) | Type-checked only. |
| Simulation independent of SpriteKit | ✅ | `FPodCore` has no UI framework imports | 77 XCTests run headless. |
| Milestones, regressions, checklist | ✅ | M1 → M4 with this matrix | Full suite green at each milestone. |
| Tap-only (user request) replaces floating joystick | ✅ | Tap-to-walk with A*, double-tap run, context button, Run/Sneak toggles (`Presentation/Input.swift`, `HUD.swift`) | Snapshots; keyboard movement kept for development. |

## 2 · Premise and tone

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Disputed chart, labels as records, never stat modifiers | ✅ | `Content/Docs.swift` (chart with disputed/evidence marks); no diagnosis enters any formula | Code review: diagnoses appear only in documents. |
| Non-graphic interventions (search, seclusion, restraint, watch) | ✅ | `Sim/Transition.swift` (capture/seclusion cards, player placed in the seclusion room), `StoryScenes.restraint` (door, time, aftermath only) | `StoryTests`, `RecoveryTests.testSevereIncidentDoesNotBlockTheStory` |
| No doses, procedures, weapon making, real security details | ✅ | Abstract tokens (`pillToken`, `weaponToken`, `fenceTool`), invented campus | Content review (`Content/Story/ItemStories.swift`). |
| Money can't buy legal outcomes | ✅ | Credits only buy goods/privileges (`Sim/Game+Inventory.swift`); legal milestones are story flags | `StoryTests` |
| Medication: situational, with request-to-discuss | ✅ | `Day1Choices.medPass` + `SystemChoices.medTalk` (appointment with Dr. Sato) | Daily reset of the med choice; `testHonestFullDay`. |

## 3 · Core experience

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Small dilemmas (count vs errand, wages vs theft, peer vs staff, disguise vs long route, agreement vs challenge) | ✅ | Count guard, job risk choices (7), favors, outfit routes, cellmate/records/Theo choices | `SystemsTests`, `StoryTests` |
| Loop obligation → opportunity → plan → act → consequence → recover → unlock | ✅ | Schedule + interactions + capture/recovery + tiers/flags | `testHonestFullDay`, ending paths |
| Every main quest changes a relationship, route, resource or fact | ✅ | `QuestDef.worldChange` + effects in `Content/Story/MainArc.swift` | Content review |
| Complete first day teaching systems one at a time | ✅ | `m01Intake`, `m02Ally` | `DayOneTests.testHonestFullDay` |

## 4 · Controls, camera, interface

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| High top-down camera, smooth follow | ✅ | `Sim/Game+Camera.swift` | Snapshots |
| Contextual interact, run, sneak, inventory, map | ✅ | `Presentation/HUD.swift` | Snapshots (`pod`, `cart`) |
| Interaction radius 1.25 tiles, proximity + facing, no trading through doors | ✅ | `Game.interactRadius`, `canInteract` line check | `DayOneTests`, `WorldTests` |
| Touch targets ≥ 44 pt, safe areas, left-handed, reduced motion, audio sliders, icon explanations | ✅ | `UIBuilder.touchTarget`, `Viewport.safeRect`, Settings | Snapshot `lefty`; touch not verified on device. |
| HUD: schedule/countdown, objective, compact suspicion, collapsible status | ✅ | `HUD.swift` | Snapshots |
| Pictogram speech, mumbles, optional captions | ✅ | Bubbles + `Audio/SFXBank.mumble`, captions setting | `AudioTests.testMumblesVaryByPitch` |
| Map: discovered rooms, obligation, quest, requirements; no hidden passages | ✅ | `Menus.buildMap`, `knownZones`, hatches gated by discovery flags | `WorldTests.testTunnelsReachableOnlyThroughHatches`, snapshot `map` |
| Control legend; color never alone | ✅ | Help sheet; watch badge = color + word; item legality badges | Snapshot `help` |

## 5 · Time and schedule

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| 1 sim-minute per second, configurable; pauses in menus/choices/minigames | ✅ | `Settings.clockRate`, `Game.isPaused` | `SimTests.testMinigamePausesClock` |
| Weekday schedule per spec, weekend variant, story-day overrides | ✅ | `Content/Schedule.swift` (06:00 count … 22:00 lights out; weekend brunch/chapel/visiting) | `testWeekdayScheduleMatchesSpec` |
| Count warning + 2-minute grace; repeated misses escalate | ✅ | `Sim/Game+Schedule.swift`, `applyConsequence` | `testMissedCountHasGraceThenLateReturn` |
| Doors and patrols follow schedule | ✅ | `AccessRule.schedule`, NPC posts per activity | `testScheduleDoorsAndDisguiseNeverOpensLocks` |
| Appointments override assignments | ✅ | Appointment doors scoped to their route; staging of the other party | `testAppointmentOpensItsWayNotEverything`, ending paths |
| Minigames can't silently cause a missed count | ✅ | `countGuardMessage` blocks starting within 4 minutes of count | `testCountGuardBlocksMinigamesNearCount` |
| Sleep advances to morning | ✅ | `Scenes.sleep` → `startNewDay` | All multi-day tests |

## 6 · World

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| All 10 districts with the listed spaces | ✅ | `Content/Campus.swift` (91 zones, 358 objects) | `WorldTests.testMapBuildsWithoutProblems`; snapshots per district |
| Visible doors, collision, labels, LOS blockers, hiding places | ✅ | `MapBuilder` auto-walls, 76 doors, 41 hide spots | `testDoorsConnectWalkableTiles`, `testWallsBlockVision` |
| Secure doors state what they need; costumes never open locks | ✅ | `doorRequirement`; outfits affect suspicion only | `testScheduleDoorsAndDisguiseNeverOpensLocks` |

## 7 · Stealth and staff AI

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Speeds 2.5 / 1.4 / 4.2; CO 7 t/65°, tech 4.5 t/110°; cameras 8 t/70° fixed or sweeping | ✅ | `Game+Player.swift`, `Characters.swift`, `MapBuilder` (some cameras override range for room size) | `testMovementAndVisionValues` |
| Occluded vision, noise at its source through doors, last-known search | ✅ | `World/Sight.swift`, `Game+Perception.swift` | `testWallsBlockStaffVision`, `testNoiseIsInvestigatedAtItsSource`, `testNoisePropagationRespectsWallsAndDoors`, `testPursuitFallsBackToLastKnownAndInspectsHidingSpots` |
| State machine routine → notice → question → investigate → pursue → escort → resume | ✅ | `NPCMode`, `Game+NPC.swift` | `testPursuitFallsBackToLastKnownAndInspectsHidingSpots`, `testWitnessedTheftLeadsToSearchAndConfiscation` |
| Suspicion 0–100 stages, local + unit alert, reaction delay; allowed presence builds none | ✅ | `Game+Perception.swift` | `testAllowedPresenceIsNotSuspicious`, pursuit and theft tests |
| Cameras feed suspicion when watched; record when not | ✅ | `updateCameras`: Lt. Gaines on duty → live; otherwise footage reviewed next morning | `testNightFootageIsReviewedInTheMorning` |
| Hiding places with capacity, discovery risk, visible inspection | ✅ | `Content/Places.swift`, `enterHide`, inspect mode | `testHiddenPlayerIsInvisible`, pursuit test |
| Normalizing actions reduce unconfirmed suspicion only | ◐ | Station/prop plausibility in perception (`Observation.normalizing`); witnessed theft is remembered | Theft memory tested (`testWitnessedTheftLeadsToSearchAndConfiscation`); normalizing decay has no dedicated test. |

## 8 · Watch, privileges, recovery

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Separate suspicion / alert / watch / trust / peers / legal | ✅ | Distinct state in `GameState` | — |
| Yellow: reduced movement, no commissary, closer scrutiny | ◐ | Free time confined to the pod (doors), commissary closed, suspicion ×1.15 | `testYellowWatchKeepsFreeTimeInThePod`. "Closer rounds" is the suspicion multiplier, not extra patrol routes. |
| Red: constant observer, no yard, limited privacy | ✅ | Observer follows (`followPlayer`), yard doors closed, no private changing | Perception + access code; observer staffing is day-shift only (Cole/Varga). |
| Seclusion: non-graphic, time skip, review, recovery task | ✅ | Capture card → player placed in seclusion room → 4 h skip → SR-2 doc → 72 h watch | `RecoveryTests.testSevereIncidentDoesNotBlockTheStory` |
| Restraint-chair event only in authored abuse scene | ✅ | `StoryScenes.restraint` (Strick/Kenji), leads to complaint path | `StoryTests` reach; content review |
| 72-hour watch with remaining time, review conditions, early review, never blocks content | ✅ | Group + clean count + shift → Sato review choice; natural expiry | `testSeventyTwoHourWatchHasAnEarlyReviewAndAnEnd` |
| Capture: witnessed reason, only searched places, confiscation, recovery objective, no recapture loop | ✅ | `Game+Capture.swift` | `testWitnessedTheftLeadsToSearchAndConfiscation`, `testSearchOnlyLosesSearchedContainers`, `testNoImmediateRecaptureAfterRecovery` |

## 9 · Disguises and access

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| 9 outfits with role plausibility per zone class and hours | ✅ | `Outfit.plausibleIn`, `disguisePlausible` | `testDisguiseGivesPlausibilityButFamiliarStaffRecognize`, `testDisguiseErrandIsolationLetter` |
| Condition 0–100, prop bonus, familiar-staff recognition | ◐ | Condition drops when running, restored by washing; props raise plausibility; recognition at close range | No authored stain/tear events beyond running. |
| 2.5 s change in private places; watched change is suspicious; red watch removes privacy | ✅ | `beginChange`, `privateForChanging` | `testChangingInViewIsSuspicious`, `testRedWatchRemovesPrivacy`, `testMovementAndVisionValues` |
| Every disguise has ≥ 2 routes and a quest use | ✅ | Jobs, favors, trades, supply racks, choices (`Content/Systems.swift`) | `testEveryOutfitHasTwoRoutes`. Quest uses: kitchen whites (Dinner rush), PPE (Mail for isolation), CO (Navy in the wash), visitor (review hearing, Nadia), chaplain (hymnal), white coat & maintenance (records/escape routes), laundry whites (cart ride). |
| Stash points incl. bunks, laundry bins, stacks, donation box; independent discovery | ✅ | 58 stash containers; cell searches and common-area sweeps roll each container's own odds | `testSearchOnlyLosesSearchedContainers`; sweep in `Systems.sweepCommonStashes` |

## 10 · Inventory and economy

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Carry 6 bulk, pocket 2, sock 1, hollow book 1; world containers separate | ✅ | `Inventory`, `StashDef` | `testParkingReturnsOverflowToTheBay`, `testSearchOnlyLosesSearchedContainers` |
| Every item has a purpose (source and use) | ✅ | Content tables + `ContentAudit.codePaths` | `testEveryItemHasASourceAndAUse`, `fpod-tool items` |
| Credits, barter, named favors (spendable) | ✅ | Ledger; fixed-quote trades; favor interactions (`SystemInteractions.favors`) | `testFavorsAreEarnedAndSpent` |
| Start 8 cr; wages 6–12; spec prices | ✅ | `Items.swift`, `Jobs.swift` | `testShiftThroughGamePaysOnceAndFeedsPerformance` |
| Daily limits; upkeep; no runaway wealth or circular profit | ✅ | 20 cr/day small purchases + 1 special order; radio batteries; trades never give more value | `testRadioIsBuyableDespiteDailyCap`, `testTradeIsAtomicAndQuoteFrozen` |
| Atomic ledger; no duplication through reopening/scenes | ✅ | Frozen quotes with nonce; reward keys | `testRewardAppliesOnce`, `testTradeIsAtomicAndQuoteFrozen` |
| Recovery from zero credits | ✅ | Jobs/tryouts never cost credits | `testRecoveryPossibleAtZeroCredits` |

## 11 · Jobs and minigames

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| 7 jobs: unlock, schedule, supervisor, task, pay, performance, access, risk/trust choice | ✅ | `Content/Jobs.swift`, tryouts + applications, `SystemChoices` job choices on 2nd shift | `testEveryJobIsReachableThroughATryout`, `testJobRiskChoiceArrivesOnSecondShift` |
| Job minigames: mop route, tray line, laundry sort, shelving (Dewey decimals), supply match, sewing timing, garden | ✅ | `Minigames/*` | `MinigameTests` (idle ends low, bot passes on all difficulties and two screen sizes, random taps safe, renders finite) |
| Leisure: basketball aim/power, weights rhythm, chess (full legal moves + AI), dominoes, crazy eights, horseshoes, art composition + sales; betting bounded and optional | ✅ | `BasketballGame`, `WeightsGame`, `ChessEngine/ChessGame`, `DominoesGame`, `CrazyEightsGame`, `HorseshoesGame`, `ArtGame`; bet on hoop (3 cr, daily) | `ChessTests` (perft incl. Kiwipete), `testContestBotIsCompetitive` |
| Special: drain, gurney ramp, cart driving, clerk filing, mail sorting | ✅ | `DrainGame`, `GurneyGame`, `CartDriveGame`, `FilingGame`, `MailSortGame` | `MinigameTests` |
| Shared contract: explain, play, score, reward once, exit safely; 20–60 s; assist mode | ✅ | `MinigameSession`, intro/result screens, reward keys | `testShiftThroughGamePaysOnceAndFeedsPerformance` |

## 12 · Vehicles

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Janitor cart (slow, capacity, route access) | ✅ | `Vehicle.janitorCart` (+4 bulk), permitted zone classes, Park button | `testJanitorialAfterTrialAndCartAccess`, `testCartsStayOutOfCellsAndOffices` |
| Laundry cart (large capacity, hiding, reduced control when concealed) | ✅ | +8 bulk; hide inside; concealed ride wheeled by Dutch with a lid-check risk | `testConcealedLaundryCartRide`, `testParkingReturnsOverflowToTheBay` |
| Wheelchair (authored segment, no stealth bonus, not a gag) | ✅ | Abe is always drawn seated in his chair; "ask first" then push him to visiting | Side errand "The long way to visiting" |
| Floor buffer (fast, noisy, collisions → incidents) | ✅ | Noise 7, bump + stumble + witnessed `equipmentCollision` | Inspection errand |
| Transport van (supervised driving) | ✅ | Supervised supply run at trust tier 4 (`vanDrive`) | `testSupervisedVanRunNeedsTierFour` |
| Gurney ramp minigame | ✅ | `GurneyGame`, errand "Ramp run" | `MinigameTests` |

## 13 · Characters, quests, story

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| ≥ 12 peers, ≥ 8 staff with routines, trust, wants, boundaries | ✅ | 14 peers, 15 staff, 2 visitors (`Content/Characters.swift`) | `testNamedCast` |
| 12 main quests with ≥ 2 approaches each | ✅ | `Content/Story/MainArc.swift` (m01–m12; m12 has three finales) | `testQuestCounts`, ending paths |
| ≥ 24 side quests | ✅ | 29 errands (`Content/Story/SideArc.swift`) | `testQuestCounts` (every errand can start) |
| Quest data: prerequisites, giver, location, objectives, approaches, recovery, rewards, world change | ✅ | `QuestDef`, `StageDef` | Journal snapshots |
| Critical items recoverable | ✅ | Chart reprint, docket resend, authorized records copy, key recut, map redraw, hints on loss | `RecoveryTests` |

## 14 · Progression and endings

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Trust tiers 1–5 unlock eligibility; daily farming cap; one mistake never drops a tier | ✅ | Tier 2 commissary/jobs, 3 senior pay, 4 yard in free time + van run, 5 discharge planning; corrected chart lifts floor to 3, competency to 5 | `testTrustTierHysteresisAndDailyCap`, `testSupervisedVanRunNeedsTierFour`, `testReleasePath` |
| Three endings, each a playable final quest with distinct epilogue | ✅ | `m12Release`, `m12Advocacy`, `m12Escape`; `Endings.epilogue` | `testReleasePath`, `testAdvocacyPath`, `testEscapePath` |
| Pre-finale save and post-ending continuation | ✅ | `.savePreFinale` before each finale; ending screen: load pre-finale / keep exploring / new game | Ending paths assert the save; iOS load path type-checked only. |

## 15 · Art and audio

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Flat paper-cut style, spec palette, soft offset shadows, vector forms | ✅ | `Presentation/Art/*` | Snapshots (`out/*.png`) |
| Articulated figures; walk/sneak/run/idle/interact/carry/caught | ✅ | `FigureArt`, `appendFigure` poses | Snapshots |
| Recognizable furniture, district variation, paper-card menus | ✅ | `PropArt`, `ChunkArt` | `testAllEffectsRenderCleanly`, snapshots |
| Music: upbeat guitar/whistle + night/search variants; effects list; mumbles; ducking; spatialized threats | ✅ | `Audio/Music.swift`, `SFXBank.swift`, pan/volume by distance | `AudioTests`; rendered WAVs. **Not heard through AVAudioEngine on a device.** |
| Distribution rights for all assets | ✅ | Everything generated in code; see `LICENSES.md` | — |

## 16 · Architecture, persistence, performance

| Requirement | Status | Implementation | Verification |
|---|---|---|---|
| Data-driven content, stable IDs, separated modules, small event layer | ✅ | `Content/`, `GameEvent` | — |
| Saves: everything persisted, versioned, validated, autosave, backup | ✅ | `Persistence/SaveSystem.swift`, `GameScene` autosave (4 s cooldown, safe moments) | `testSaveLoadRoundTrip`, `PersistenceTests` |
| Old saves load after new fields | ✅ | Post-v1 fields optional | `testOlderSaveWithoutNewOptionalFieldsLoads` |
| Mid-minigame save never pays twice | ✅ | Minigames aren't saved; reward keys | `testRewardAppliesOnce` |
| A* navigation; perception at 10 Hz; 60 FPS rendering | ✅ | `World/Navigation.swift`, perception timer 0.1 s, texture cache + async chunk raster | `PerformanceTests`: 1.3 ms/frame for update + display list (Linux, debug). **Not profiled on iPhone.** |

## 17 · Definition of done

| Requirement | Status | Notes |
|---|---|---|
| Boundary tests listed in the spec | ✅ | Walls/vision, noise source, disguises vs locks, hidden spaces, pursuit evidence, schedules across saves, count grace, minigame pause, rewards once, searched containers only, watch expiry, zero-credit recovery, endings after mistakes — all have tests named above. |
| Scenario checks: honest day, disguise errand, witnessed theft + search, critical item confiscation, 72 h watch recovery, all ending gates | ✅ | `testHonestFullDay`, `testDisguiseErrandIsolationLetter`, `testWitnessedTheftLeadsToSearchAndConfiscation`, `testEscapeKitConfiscatedThenRecovered`, `testSeventyTwoHourWatchHasAnEarlyReviewAndAnEnd`, three ending paths |
| Each minigame implements its actual rules | ✅ | Chess perft, dominoes/crazy-eights legal-move logic, per-game scoring; `MinigameTests` |
| Touch tested on device/simulator | ✕ | No iOS SDK in this environment. |
| Developer menu (clock, teleport, quest states, outfit condition, suspicion, watch, credits, seeded scenarios), not in release UI | ✅ | `Sim/DevMenu.swift`, paged; shown only in debug builds |
| Run/build instructions, controls, license inventory, feature matrix, checks, limitations | ✅ | `README.md`, `docs/` |
