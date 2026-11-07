# One or Many — Style Guide: Sticker Arcade

Version 1.0 · 2026-11-07 · Companion to [SPEC.md](SPEC.md)

Mocks: https://claude.ai/artifact/5UwHVdcfnZCDZAdkEB65VF (page "A · Sticker arcade")

---

## 1. The idea in one paragraph

Everything looks like a sticker: flat bright fills, a thick dark-ink outline, and a hard offset shadow with no blur. A chunky display face is used for big moments (scores, titles, the words on the answer buttons). A reading-friendly face is used for everything she has to read. Two mascots carry the core rule of the game: **Solo** (one orange blob) always lives on the left and means *one*. **The Crew** (three blue blobs) always lives on the right and means *many*.

### Rules that keep it consistent

1. **Orange = one = left. Blue = many = right.** Never use orange or blue for anything else that could be confused with a side (no blue "OK" buttons, no orange warnings).
2. **Every object is a sticker:** fill + 3 pt ink outline + hard shadow. Text, icons and decoration are not stickers.
3. **One loud thing per screen.** The card during play, the score on the summary, the mission on home. Everything else is quieter.
4. **Sentences are never stylized.** Plain Lexend, high contrast, generous size. The game is about reading them fast.
5. **Timed modes go dark** (Night palette). She should feel the switch from learning to pressure before reading anything.

---

## 2. Color

### 2.1 Day palette (Journey, Daily 20, Fix-it, menus)

| Token | Hex | Use |
|---|---|---|
| `ground` | `#EFE7FF` | Screen background |
| `groundDot` | `#D9CBFA` | 1.5 pt dot grid on the ground, 22 pt spacing |
| `ink` | `#1B0F3B` | Outlines, hard shadows, primary text, primary dark buttons |
| `inkMuted` | `#5A4C80` | Labels, secondary text (6.4:1 on ground) |
| `surface` | `#FFFFFF` | Cards, tiles, tab bar |
| `one` | `#FF7A1F` | Singular side: left button, Solo, progress fill, Journey accents |
| `oneText` | `#C2410C` | Singular word written on white/tint (orange text needs this darker shade) |
| `oneTint` | `#FFF1E6` | Card fill when the answer was "one" / hint boxes |
| `many` | `#2457E8` | Plural side: right button (white text), MANY stamp, plural word on white |
| `manyLight` | `#5B8CFF` | The Crew's main blob, "Many" in the logo |
| `manyPale` | `#8FB0FF` | The Crew's side blobs |
| `manyTint` | `#EAF0FF` | Card fill while leaning right |
| `marker` | `#FFE14D` | Subject highlight, stars, streak ×2 chip, Sprint tile |
| `pop` | `#FF4FA3` | Streak / fire / celebration, Daily mission card |
| `good` | `#3DDC97` | Speed-bonus bar, correct points, Fix-it tile, mastered |
| `goodText` | `#1B7A4F` | Positive text on white ("0.5s under par") |
| `bad` | `#FF5A4E` | Miss: card shadow, "You picked" pill, −25 |

Text on fills: `ink` on `one`, `marker`, `pop`, `good`, `bad`, `surface`, `ground`. White on `many` and `ink` only.

### 2.2 Night palette (Shot Clock, Sprint 60, Boss)

| Token | Hex | Use |
|---|---|---|
| `nightGround` | `#1B0F3B` | Background |
| `nightDot` | `#33235F` | Dot grid |
| `nightSurface` | `#2E1F5A` | Back card, track of timer bar |
| `nightText` | `#FFFFFF` | Text, outlines of HUD controls |
| `nightMuted` | `#C9BEF0` | Labels |
| `nightDim` | `#6E5FA0` | Empty hearts, borders of inactive chips |

The play card stays white with ink outline. Button shadows become white (`4 pt`), so they still read as stickers on dark. In the last 30% of a card's clock: the timer turns `bad`, and the screen gets a 6 pt inset `bad` border + soft inner glow.

### 2.3 Streak tint

At ×2 and above the ground switches to `#FFE9F4` with dots `#FFC4E1`, labels `#6B3557`, and a 9 pt inset `pop` frame. At ×3 add a second inset frame in `marker`. Returns to day palette when the streak breaks.

---

## 3. Typography

| Role | Font | Size / weight | Notes |
|---|---|---|---|
| Hero (summary score, "STREAK 10!") | Bagel Fat One | 54–58 pt | Sticker text (see below) |
| Screen title, logo | Bagel Fat One | 34–44 pt | Sticker text on hero moments only |
| Card title, tile number | Bagel Fat One | 20–26 pt | Plain ink |
| Answer word on buttons | Bagel Fat One | 30 pt | |
| HUD numbers | Bagel Fat One | 26 pt | Tabular look comes from the face |
| **Sentence on card** | **Lexend** | **26–28 pt, Medium (500)** | Line height 1.4; supports Dynamic Type up to XXL, never below 22 pt |
| Blank / filled word | Lexend | same size, ExtraBold (800) | Underline 3–4 pt in side color |
| Body / explanations | Lexend | 14–16 pt, SemiBold (600) | |
| Labels (SCORE, CARD, ONE, MANY) | Lexend | 10–12 pt, ExtraBold, tracking +1.2 | Uppercase |

**Sticker text**: fill color + 2–3 pt `ink` stroke + 3–4 pt hard `ink` shadow down-right. Use only for hero text.

Both fonts are SIL Open Font License; bundle the `.ttf` files in the app.

---

## 4. Shape, depth and spacing

| Thing | Value |
|---|---|
| Outline | 3 pt `ink` (2.5 pt on small dots/bars, 2 pt on pills inside cards) |
| Hard shadow | offset only, no blur: 3 pt (chips, small buttons), 4 pt (buttons, tiles), 5 pt (home cards), 7 pt (play card) |
| Shadow color | `ink` by default; the play card's shadow takes the state color: `many` when leaning right, `one` when leaning left, `bad` on a miss |
| Corner radius | play card 28, home cards 22–26, tiles/buttons 20–22, small buttons 16, chips/pills full |
| Screen gutter | 18 pt left/right |
| Vertical rhythm | 10–16 pt between blocks; 12 pt between the two answer buttons |
| Answer buttons | 80 pt tall, full half-width; minimum touch target 44 pt everywhere |
| Background | dot grid on every full screen (day and night) |

**Pressed state** for any sticker button: move down-right by the shadow offset and drop the shadow (it "presses into the page"). 80 ms.

---

## 5. Components

### 5.1 HUD (play screens)
`[pause 42 pt circle] [SCORE + number] [streak chip] [CARD n/20 | LIVES | TIME]`, then a 12 pt round progress bar (`surface` track, `one` fill, ink outline).

Streak chip states:

| Streak | Look |
|---|---|
| 0 (after a miss) | `surface`, 3 pt **dashed** `inkMuted` border, "×1 · 0" in `inkMuted` |
| 1–4 | `surface` chip, "×1 · n" |
| 5–9 | `pop` chip with flame icon, "×1.5 · n" |
| 10–19 | `marker` chip, pink flame, scaled 1.12 |
| 20+ | `marker` chip with `pop` 3 pt shadow, scaled 1.2, flame flickers |

### 5.2 Play card
- `surface`, 3 pt ink outline, radius 28, 7 pt hard shadow, 22 pt padding.
- Speed-bonus bar at the top (10 pt, `good` fill draining on `#D3DCF8` track) with "+n" label. Shot Clock replaces it with the timer bar.
- Sentence centered, vertically centered.
- Small pattern pill at the bottom ("Level 5 · Words in the way").
- **Lean left / right** (past 18 pt): fill becomes `oneTint` / `manyTint`, shadow takes the side color, a stamp fades in top-left: Bagel 30 pt, 4 pt border, `-14°`, reading **ONE** (`oneText`) or **MANY** (`many`). The blank shows a ghost of that side's word with a dashed underline.
- A second card sits behind it, `-3°`, scale 0.95.

### 5.3 Answer buttons
Left: `one` fill, ink text, "←", word (Bagel 30) over "ONE" label. Right: `many` fill, white text, word over "MANY", "→". While leaning, the leaned-to button lifts (−3 pt, scale 1.04, 6 pt shadow) and the other drops to 55% opacity. In correction state the correct button pulses (scale 1 → 1.04, 0.9 s) with two outline rings in `one`/`many`, and the other drops to 35%.

### 5.4 Miss feedback (inside the card)
- `bad` pill with ✕ icon: `You picked "are"` (or `Time's up`).
- The subject gets the highlighter: `marker` fill, 2.5 pt ink ring, radius 8.
- Correct word filled in its side color with a solid underline.
- Hint box: `oneTint` (or `manyTint`), lightbulb icon, one sentence from the item's `why`.
- Solo or the Crew (whichever side is correct) appears below the card with a speech bubble: `Now swipe it to "is" ←`.

### 5.5 Home cards and tiles
- **Mission card** (Daily 20): `pop` fill, 5 pt shadow, sticker-text title, ink "Play" button with `marker` play icon.
- **Journey card**: white, level label, Bagel title, 4 round dots (filled `one` / empty white) + crown "Boss", round orange arrow button.
- **Mode tiles** (3 across): Shot Clock = `ink` fill with `pop` shadow (previews night mode), Sprint 60 = `marker`, Fix-it = `good`.

### 5.6 Tab bar
White, 3 pt ink top border, 86 pt tall incl. home indicator. Active tab is an `one` sticker pill; others are `inkMuted` text + icon.

### 5.7 Stars
Five-point star, `marker` fill, 6 pt ink stroke (in a 100 pt box). Earned stars tilt −12° / 0° (raised) / +12°. Unearned: white fill, dashed `#8A7DB5` outline.

---

## 6. Mascots

| | Solo | The Crew |
|---|---|---|
| Means | ONE, singular, left | MANY, plural, right |
| Body | One round blob, `one` | Three blobs: center `manyLight`, sides `manyPale` |
| Outline | 4 pt ink (in a 64 pt box) | 4 pt ink |
| Face | Two dot eyes, smile | Each blob has eyes; center one has the mouth |

**Expressions:** neutral smile · cheering (arms up, happy closed eyes, open mouth) · unsure (flat mouth, faded 35%) · pointing (speech bubble, used in correction).

**Behavior:**
- During a drag, the mascot of the leaned-to side pops in from that screen edge (rotated toward the card); the other one fades to 35% at the opposite edge.
- On a correct answer the right mascot cheers for ~600 ms.
- In correction, the mascot of the correct side points at its button.
- Solo never appears on the right, and the Crew never on the left.

Source shapes: see the inline SVGs in the mock files (`Main.dc.html`, `Streak.dc.html`). Ship them as vector assets (PDF/SVG in the asset catalog, "Preserve Vector Data"), one file per expression.

---

## 7. Icons
Inline, rounded stroke icons: 2.2–3.2 pt stroke, round caps and joins, ink by default. Icons that sit on a colored sticker can take a fill (flame = `pop`, crown/star = `marker`, wrench = white). No emoji anywhere.

---

## 8. Motion

| Moment | Motion |
|---|---|
| Card follows finger | 1:1 translation, rotation `dx / 18`°, no lag |
| Lean (18 pt) | stamp + tint fade in over the next 60 pt of drag; mascot slides in 150 ms |
| Release under 80 pt | spring back (response 0.3, damping 0.7) |
| Correct commit | fly out in swipe direction, 280 ms ease-in, +18° rotation; next card enters 180 ms ease-out from y +14 pt, scale 0.97 |
| Points pop | rises 30 pt and fades over 700 ms; `good` for positive, `bad` for −25 |
| Miss | card returns (200 ms) then shakes ±10 pt over 380 ms; subject highlighter "draws" left to right in 250 ms |
| Streak tier up (5, 10, 20) | burst + headline scale-in (0 → 1.1 → 1, 350 ms), confetti for 900 ms; play continues underneath, input is never blocked |
| Shot Clock last 30% | timer bar turns `bad`, pulses at 2 Hz; inset glow fades in |

**Reduce Motion**: no rotation or fly-out (cards cross-fade), no confetti, no pulsing; streak tier-up is a static banner for 900 ms.

---

## 9. Haptics and sound

| Event | Haptic | Sound (if on) |
|---|---|---|
| Crossing the lean threshold | selection tick | — |
| Correct | light impact | short "pop", pitch rises with streak tier |
| Wrong / timeout | `.error` notification | soft low "thud" |
| Streak tier up | `.success` notification | short fanfare |
| Last second of Shot Clock | light tick each 250 ms | tick |
| New personal best | `.success` | fanfare |

Sound effects respect the silent switch. The game has no speech: sentences are text only.

---

## 10. Accessibility
- All text pairs listed in §2.1 meet 4.5:1; `inkMuted` labels 6.4:1 on `ground`.
- Sides differ in lightness (orange vs. blue) **and** carry text labels ONE / MANY, so the game works without color.
- Sentences support Dynamic Type (22–34 pt); the card grows, and buttons stay at the bottom.
- VoiceOver: buttons read `"is, one"` / `"are, many"`; the card reads the sentence with "blank" for `___`; correct/miss is announced.
- Every swipe has a tap equivalent (the buttons), so swiping is never required.

---

## 11. SwiftUI implementation notes
- Define tokens once: `extension Color { static let ink = Color(hex: 0x1B0F3B) ... }` plus a `Palette` (day / night) injected through the environment, so timed modes swap palettes in one place.
- **Hard shadow**: don't use `.shadow` (it blurs). Use a `background` of the same shape filled with the shadow color and offset by `(x, y)`. Wrap it in a `StickerStyle` view modifier: `fill`, `stroke 3`, `shadowOffset`, `shadowColor`, `cornerRadius`.
- **Sticker text** (stroke + hard shadow): SwiftUI has no text stroke; draw the text 8 times offset by the stroke width in ink, then the fill on top, then the offset shadow copy behind. Only for hero text, so cost is fine.
- **Dot grid**: a `Canvas` that draws circles every 22 pt; draw it once as the screen background.
- **Card drag**: `DragGesture(minimumDistance: 0)` on the card; record the first-move timestamp at |dx| > 18 pt (SPEC §4.3) using `CACurrentMediaTime()`.
- Fonts: register Bagel Fat One and Lexend (variable or static 500/600/700/800) in `Info.plist` under `UIAppFonts`; use `Font.custom(_:size:relativeTo:)` so sentences scale with Dynamic Type.

---

## 12. Screens mocked in this style
Home · Journey mid-swipe · Correct with streak ×2 · Miss and correction · Shot Clock (night) · Round summary · Journey map · Stats · Scores · Parent corner · Boss intro (night).
