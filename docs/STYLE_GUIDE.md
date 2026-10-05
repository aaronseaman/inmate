# Style guide

## Look: flat paper-cut

- Shapes: rounded, matte, two or three tonal areas per object, a tiny soft offset shadow
  (`Drawing.shadowOffset` ≈ 1.2, 1.8 pt, blur 1.6). No gloss, bevels, gradients, heavy outlines
  or textures.
- Grid: 1 tile = 1 world unit (30 pt at default zoom). Props snap to tiles; everything renders as
  vectors at device resolution.
- Figures: small articulated paper dolls — head, body, two arms, two legs, hair, optional prop.
  Adult proportions; posture and silhouette tell people apart before color does. Abe is always
  drawn seated in his wheelchair.
- Rooms read as illustrated floor plans: warm off-white walls, cool pale floors, sparse
  furniture, generous negative space. Foreground walls stay low so people stay visible.

## Palette (`Util/Color.swift`)

| Token | Hex | Use |
|---|---|---|
| ivory | #F2EEE5 | Paper, cards, walls |
| blueGray | #CBD7DB | Floors, inactive fills |
| slate | #536871 | Secondary ink, metal |
| navy | #344956 | Primary buttons, staff uniforms |
| tan | #C5AC83 | Scrubs, wood accents |
| turquoise | #74B7B4 | Positive progress, safe accents |
| ochre | #D4AD5C | Highlights, objectives |
| coral | #C97C6A | Danger accents only |
| status green/yellow/red | #6FA77F / #D9B44A / #C2665A | Small status badges, always paired with an icon and a word |

Separate floors, walls, doors, people and props by value and silhouette, not hue alone.

## Interface

- Paper cards: soft corners, thin separators, one bold title, generous spacing.
- Touch targets ≥ 44 pt (`UIBuilder.touchTarget`). Respect the safe area. The left-handed setting
  mirrors the action cluster.
- Icons come from `Presentation/Icon.swift` and share the world's cut-paper shapes. Every
  color-coded state also has a shape or a word.
- One prominent objective at a time; everything else lives in the journal.
- Minigames: header (left), timer or progress (right), play area, big tappable controls. Each
  explains its taps on the intro card and offers assist mode when enabled.

## Sound

- Music: oddly upbeat acoustic guitar and whistling by day; quieter night and tense search
  variants; a finale theme. Music ducks during searches, seclusion and restraint scenes — they are
  never scored as comedy.
- Staff and peers speak in mumbles (pitch per character), never voiced lines.
- Effects are short and practical: buzzer, intercom chime, keys, doors, cart wheels, TV, laundry,
  steps.

## Writing

- Tone: darkly comic, humane, specific. Satirize bureaucracy and arbitrary rules, never patients.
- In-world speech is pictograms; captions are short and optional. Documents, the journal and
  choices may use plain sentences.
- Labels in charts are records, which may be wrong. Never let a diagnosis drive a mechanic.
- Choices have situational consequences — no virtue meter. Reporting, covering and staying out
  each cost something.
- Searches, seclusion and restraint are shown as a door, a stretch of time and an aftermath. No
  procedures, no doses, no weapon making, no real security details.
- Names are invented. Institutions are fictional.

## Content rules for authors

- IDs are stable: never rename a raw value; add a new case.
- Every item needs a source and a use (`ContentAudit`); every outfit two routes; every major quest
  two approaches; every critical item a recovery path.
- New minigames implement `Minigame` (including `botTap`) so the contract tests cover them.
