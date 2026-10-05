import Foundation

/// Every pictogram in the game. Drawn as flat cut-paper shapes by `IconArt`.
public enum Icon: String, Codable, CaseIterable {
    // Interface
    case walk, run, sneak, hand, bag, map, journal, gear, close, back, check, cross, plus, minus
    case clock, bell, eye, question, exclaim, lock, key, badge, star, heart, coin, favor, trust
    case energy, info, play, pause, save, sound, music, voice, captions, leftHand, cone, motion
    case moon, sun, arrowRight, arrowLeft, arrowUp, arrowDown, swap, thumbsUp, thumbsDown, zzz
    case angry, sad, happy, quiet, beckon, stop, gavel, briefcase, stethoscope, house, dog, door
    case search, hide, stash, change, chair, flag, target, list, person, people, cellDoor, camera, tv
    // Activities
    case count, pills, meal, work, group, ball, visit, phone, book, candle, shower, laundry, mop, bed
    // Items
    case snack, jar, cup, cigarette, token, bottle, charger, radio, headphones, workbook, letter, note
    case tools, wire, shard, needle, dice, chess, cards, pencil, drawing, hymnal, glasses, photo
    case clipboard, tray, sack, box, mapScrap, form, stamp, envelope, tomato, sugar, soap, battery
    case earplug, shirt, coat, gown, cap, cutter, card
    // Minigame / leisure
    case domino, horseshoe, dumbbell, palette, seed, water, weed, stake, sheet, plate, pan, cart, wheelchair, buffer, gurney, van
}
