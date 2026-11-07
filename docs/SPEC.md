# One or Many — Game Spec

Version 1.0 · 2026-11-07 · Mechanics only (visual design is a separate doc)

Working title: **One or Many**. Platform: iPhone (iOS 18+), SwiftUI, fully on-device.

Design review page (prototype + wireframes): https://claude.ai/artifact/AJKcvQSoMMNkKCzNzX8UWR
Look & feel mocks: https://claude.ai/artifact/5UwHVdcfnZCDZAdkEB65VF (chosen direction: page "A · Sticker arcade")
Visual style guide: [STYLE.md](STYLE.md)

---

## 1. Purpose

The player is a 7th grader, a non-native English speaker, who knows singular/plural agreement rules when she has time to think but makes mistakes while speaking ("the cars is stopped"). The game trains the *reflex*: deciding instantly whether a subject is one thing or many and producing the matching form.

Success looks like: accuracy above 90% on all patterns **and** median answer time at or below par, sustained over weeks.

### Design pillars

1. **One is always left, many is always right.** The singular form is always the left option and the plural form is always the right option, in every mode.
2. **Speed always counts.** Every correct answer is worth more when it's fast. Timed modes add a hard clock.
3. **Fix it with your hands.** After a miss she performs the correct swipe (in learning modes).
4. **Misses come back.** Spaced repetition via the Fix-it pile.
5. **Track patterns, not just scores.** Every sentence is tagged with the grammar pattern it tests.

---

## 2. Glossary

| Term | Meaning |
|---|---|
| Card | One sentence with one blank and two options |
| Item | A sentence in the content bank (a card is an item being shown) |
| Pattern | The grammar pattern an item tests (e.g. `words-in-the-way`) |
| Par | Expected answer time for a card, based on its length |
| Reaction time | Time from card shown to her decisive move (see §4.3) |
| Round | A fixed set of cards (Journey, Daily 20, Boss) |
| Run | An open-ended game (Shot Clock, Sprint 60) |
| Fix-it pile | Spaced-repetition queue of missed items |

---

## 3. Core loop

1. A card appears with a sentence containing one blank (`___`).
2. Two option buttons sit under the card: **left = singular form** (label "one"), **right = plural form** (label "many").
3. She answers by swiping the card left/right, tapping an option button, or (simulator/iPad keyboard) pressing ← / →.
4. Feedback (§6), points (§5), next card.

### 3.1 Card kinds

| Kind | Blank is | Example | Left / Right |
|---|---|---|---|
| `verb` | the verb | The cars ___ stopped at the light. | is / are |
| `noun` | the noun | I have two ___ in my backpack. | book / books |

For verb cards, "singular" means the form that agrees with a singular subject (`walks`, `has`, `does`, `was`, `is`), even though the plural form is often the shorter word. The "one"/"many" labels under each button must always be visible.

---

## 4. Card interaction

### 4.1 Swipe

- Card follows the finger horizontally; rotation = `dx / 18` degrees.
- Past **18 pt** horizontal: the card "leans" toward that side — tinted with that side's color, and the blank shows a ghost preview of that side's word.
- Release past **80 pt**: commit to that side. Otherwise spring back to center (no answer).
- Committed correct: card flies off in the swipe direction (~280 ms).
- Committed wrong: card springs back to center and shakes (§6.2).

### 4.2 Tap / keys

Tapping an option button commits immediately. Keyboard ← / → equivalent.

### 4.3 Timing (important)

- `shownAt` = when the card's enter animation completes (≈190 ms after it starts). Input before that is ignored.
- **First decisive move** = the first time drag `|dx| > 18 pt`, recording its side and timestamp.
- **Reaction time** for a commit on side S:
  - If the first decisive move was toward S → `firstMove.t − shownAt`.
  - Otherwise (she started toward the other side, or tapped) → `commit.t − shownAt`. If there was a first move toward the other side, set `changedMind = true`.
- All times stored in milliseconds; displayed in seconds with one decimal.

---

## 5. Scoring

### 5.1 Formulas

```
words       = number of whitespace-separated tokens in the sentence, counting "___"
par (s)     = 0.8 + 0.25 × words
speedBonus  = round(50 × clamp((2·par − t) / (1.5·par), 0, 1))
              // full 50 when t ≤ par/2, 0 when t ≥ 2·par, linear between
multiplier  = streak ≥ 20 → 3 | ≥ 10 → 2 | ≥ 5 → 1.5 | else 1
              // streak counts the current correct answer
correct     = round((50 + speedBonus) × multiplier)
wrong       = −25, streak := 0
timeout     = treated as wrong (Shot Clock, Boss)
roundScore  = max(0, roundScore + points)  // never negative
```

### 5.2 Reference values (par = 2.55 s, 7 words)

| Case | Points |
|---|---|
| Correct, 1.1 s, streak 1 | 100 |
| Correct, 2.55 s, streak 1 | 83 |
| Correct, 4.0 s, streak 1 | 64 |
| Correct, 6.0 s, streak 1 | 50 |
| Correct, 1.1 s, streak 12 | 200 |
| Wrong | −25 |

These are the unit-test cases for the scoring module.

### 5.3 Stars (Journey and Daily 20 rounds)

| Stars | Requirement |
|---|---|
| ★ | accuracy ≥ 80% |
| ★★ | accuracy ≥ 90% |
| ★★★ | accuracy ≥ 95% **and** speed index ≤ 1.00 |

`speed index = median(t / par)` over correct answers in the round.

The round summary always states what the next star requires.

---

## 6. Feedback

### 6.1 Correct

- Blank fills with the chosen word in that side's color; card flies off.
- Floating `+points` near the top; success haptic (light impact).
- Next card after ~330 ms.

### 6.2 Wrong

- Error haptic (notification `.error`). Card returns to center and shakes.
- Blank shows the **correct** word (success color).
- The item's `subject` span is highlighted (marker style).
- Feedback box: "You picked "<word>"" (or "Time's up") + the item's `why` line.
- **Journey, Daily 20, Fix-it:** enters *correction* state. The correct option button pulses; she must swipe/tap the correct side to continue. Wrong-side attempts shake and are ignored. Correction time is not scored or recorded as a reaction time.
- **Shot Clock, Sprint 60, Boss:** feedback shows for 1.5 s, then the next card.

### 6.3 Audio

- No speech: sentences are text only (decided 2026-11-07; synthetic voices sound robotic and add nothing).
- Optional sound effects per answer (visual design doc).

---

## 7. Levels and progression

### 7.1 Levels

| # | Name | Patterns (tags) | Max words | Boss clock |
|---|---|---|---|---|
| 1 | One or many | `basic-be`, `number-words`, `this-these` | 8 | 5.0 s |
| 2 | The -s flip | `present-s`, `has-have`, `do-does`, `was-were` | 8 | 4.6 s |
| 3 | Irregular plurals | `irregular-plural` | 8 | 4.2 s |
| 4 | Each, every, both | `indefinite-pronoun`, `each-every`, `both-few-several` | 11 | 3.8 s |
| 5 | Words in the way | `words-in-the-way` (of-/with-/who- phrases) | 11 | 3.4 s |
| 6 | Uncountables | `uncountable` (incl. noun cards like advice/advices) | 11 | 3.0 s |
| 7 | There is & questions | `there-be`, `question-inversion` | 14 | 2.6 s |
| 8 | Tricky ones | `compound-and`, `one-of`, `amounts`, `gerund-subject`, `pair-nouns`, `ics-nouns` | 14 | 2.2 s |

Boss clock = `5.0 − 0.4 × (level − 1)` seconds.

### 7.2 Structure

- Each level: **4 practice rounds** (Journey, 20 cards) + **1 Boss round**.
- A practice round "counts" when it earns ★★ or better. Rounds are replayable for more stars.
- When all 4 practice rounds count, the Boss unlocks.
- **Boss:** 15 cards from the level, fixed per-card clock (Boss clock + long-sentence extra, §8.3, no shrinking). Fails on the 3rd miss (max 2 misses). Passing unlocks the next level.
- Level 1 round 1 is unlocked at first launch.

### 7.3 Card selection for a Journey round (level L)

- Level 1: 20 cards from level 1.
- Level ≥ 2: 14 cards from level L, 6 review cards. Review = due Fix-it items first, then random items from levels < L, weighted toward patterns with the lowest accuracy over the last 14 days.
- No item repeats within a round, except a missed item re-inserted 3 cards later (once per round). The re-inserted card counts toward the 20.
- Never the same item twice in a row.

---

## 8. Game modes

| Mode | Clock | Ends | Correction swipe | Leaderboard |
|---|---|---|---|---|
| Journey | none (bonus drains) | 20 cards | yes | stars |
| Boss | fixed per card | 15 cards or 3rd miss | no | pass/fail |
| Shot Clock | per card, shrinking | 3 lives lost | no | score |
| Sprint 60 | 60 s total | clock = 0 | no | correct count |
| Daily 20 | none (bonus drains) | 20 cards | yes | day streak |
| Fix-it | none (time recorded) | no due items | yes | — |

### 8.1 Journey
See §7.

### 8.2 Daily 20
- One per calendar day per profile (can be replayed, but only the first completion counts for the day streak).
- Mix: 10 from current Journey level, up to 5 due Fix-it items, rest review from earlier levels.
- Completing it extends the **day streak**.

### 8.3 Shot Clock
- Starting level = her current Journey level (selectable down to 1).
- Per-card limit: `max(1.2, bossClock(level) × 0.92^floor(correctSoFar / 5)) + 0.2 × max(0, words − 8)` seconds.
- Timer bar on the card; turns warning color below 30% remaining.
- Timeout or wrong = lose a life (3 lives). Run ends at 0 lives.
- Cards drawn 70% from the selected level, 30% from earlier levels.
- Scoring as §5. Leaderboard on score; also record cards survived and the fastest limit reached.

### 8.4 Sprint 60
- 60 s global clock; no per-card limit. Each wrong answer subtracts 3 s.
- Cards from her current level and below (70/30).
- Leaderboard on **correct answers**; score also recorded.
- If the clock hits 0 mid-card, that card is discarded (not recorded).

### 8.5 Fix-it pile (spaced repetition)

Each missed item enters box 1. Boxes:

| Box | Due |
|---|---|
| 1 | immediately (next Fix-it session; also re-inserted 3 cards later in the current round) |
| 2 | next calendar day |
| 3 | 3 days later |
| 4 | 7 days later |

Transitions on each answer of that item, in **any** mode:
- Correct and `t ≤ par` → up one box (from box 4 → **mastered**, leaves the pile).
- Correct but `t > par` → stays in its box; due date resets to the box's interval.
- Wrong → box 1.

Fix-it mode presents all due items (shuffled), no time limit, correction swipe on misses. Home shows the count of due items.

**Mastered** (for stats) is separate: an item is mastered after 3 consecutive correct answers under par, across any modes. A wrong answer resets that count.


---

## 9. Profiles, scoreboard, parent corner

### 9.1 Profiles
- Up to 4 local profiles (name + avatar). No accounts, no network.
- All progress, stats and Fix-it state are per profile.

### 9.2 Scoreboard
- Tabs: Shot Clock, Sprint 60, Boss.
- **Family** section: each profile's best for that mode.
- **Your top runs**: top 10 for the active profile, with date, level, and cards answered.
- New personal best → celebration on the summary screen.

### 9.3 Parent corner (behind a 4-digit PIN set on first entry)
- **Needs work:** the 3 patterns with the lowest accuracy (last 30 days, min 10 answers), with speed index.
- **Most missed:** top 10 items by miss count (last 30 days).
- **Add a sentence I heard:** text field with `___`, both option words, which is correct, optional subject and reason, level (defaults to the level of the chosen pattern), pattern. Custom items are tagged `custom` and mixed into rounds of their level and into Daily 20 (max 3 per Daily 20).
- **Settings:** sound/haptics on/off, daily goal, pattern on/off toggles (off = excluded from rounds), reset profile progress (confirm with PIN).

---

## 10. Stats

### 10.1 Stored per answer (`AnswerEvent`)

| Field | Type | Notes |
|---|---|---|
| id | UUID | |
| at | Date | |
| profileId | UUID | |
| mode | enum | journey, boss, shot, sprint, daily, fixit |
| level | Int | level the round/run was played at |
| itemId | String | |
| pattern | String | copied from the item for fast queries |
| chose | enum? | one / many / nil on timeout |
| correct | Bool | |
| timeout | Bool | |
| reactionMs | Int | |
| parMs | Int | |
| limitMs | Int? | Shot Clock / Boss only |
| changedMind | Bool | |
| sessionId | UUID | round or run |

Also stored: `Session` (mode, level, start/end, score, stars, accuracy, median time, best streak, passed for Boss), `FixItEntry` (itemId, box, dueAt, consecutiveFastCorrect), `LevelProgress` (level, round stars ×4, bossPassed), `Profile`, `CustomItem`.

### 10.2 Displayed (her Stats tab)
- Range selector: 7 days / 30 days / All.
- Accuracy trend (weekly points; daily in the 7-day view).
- Median answer time trend (correct answers only).
- By pattern, weakest first: accuracy bar + speed index.
- Practice calendar (days with ≥ 1 completed session) and current day streak.
- Totals: cards answered, items mastered, best streak ever.

### 10.3 Definitions
- **Accuracy** = correct ÷ answered (timeouts count as answered).
- **Median time** = median reactionMs on correct answers.
- **Speed index** = median(reactionMs / parMs) on correct answers. 1.00 = par.
- **Second-guess rate** = changedMind ÷ answered (parent corner only).

---

## 11. Content

### 11.1 Item schema (`items.json`, bundled)

```json
{
  "id": "L5-014",
  "level": 5,
  "pattern": "words-in-the-way",
  "kind": "verb",
  "text": "The box of chocolates ___ on the table.",
  "options": { "one": "is", "many": "are" },
  "answer": "one",
  "subject": "The box",
  "why": "The subject is the box, not the chocolates."
}
```

- `text` contains exactly one `___`.
- `subject` is a substring of `text` (or empty when the cue is the blank word itself, e.g. uncountable noun cards). Validation fails the build otherwise.
- `why` ≤ 70 characters, plain words a 12-year-old understands.

### 11.2 Volume
At least 40 items per level at launch (≥ 320 total), with every pattern tag in a level represented by ≥ 6 items. Items are drafted with an LLM and hand-reviewed.

### 11.3 Writing rules
- Exactly one defensible answer in standard **American English**.
- Exclude disputed cases: `none is/are`, `data is/are`, collective nouns (`team`, `family`, `class`) except in Level 8 with the US singular, `there's` + plural.
- Everyday vocabulary: school, friends, family, sports, food, phones, pets.
- Word limits per level (§7.1). Levels 1–3 vocabulary at about a 4th-grade reading level, so reading speed isn't the bottleneck.
- Both options must be real forms, except `uncountable` noun cards, where the wrong option is the typical learner error (advices, furnitures, informations).
- Balance: in every level, 40–60% of items have `answer: "many"`.

---

## 12. Screens and navigation

Tab bar: **Play · Stats · Scores**. Parent corner is reached from a gear icon on Play (PIN-gated).

| Screen | Contents |
|---|---|
| Play (home) | greeting + day streak; Daily 20 card (primary); Journey "continue" card (level, round, progress); tiles for Shot Clock (best), Sprint 60 (best), Fix-it (due count) |
| Level map | 8 levels; done/current/locked; per-level star totals; current level shows 4 round dots + Boss |
| Round intro | mode, level, one-line rules, Start |
| Countdown | 3-2-1 (≈450 ms each) |
| Game | HUD (score, multiplier+streak, mode-specific right slot: cards left / lives / seconds), card, two option buttons |
| Summary | stars (if applicable), score, accuracy, median time, speed index, best streak, mode-specific stats, "next star" hint, items added to Fix-it, Again / Next |
| Stats | §10.2 |
| Scores | §9.2 |
| Parent corner | §9.3 |
| Profile picker | on launch when > 1 profile |

Game can be paused (pause button in HUD): the card is hidden while paused; the current card's reaction time is discarded and the card is re-shown on resume (Shot Clock limit restarts; Sprint clock pauses).

---

## 13. Technical notes

- **SwiftUI**, iOS 18+, iPhone portrait only (iPad runs scaled).
- **SwiftData** for all persisted models (§10.1). No network, no analytics, no accounts.
- **Swift Charts** for stats.
- **Core Haptics / UIFeedbackGenerator** for haptics.
- Timing uses `CACurrentMediaTime()` (monotonic), not wall-clock.
- Content in `items.json` validated by a unit test (schema, single blank, subject substring, level word limits, answer balance).
- Pure, unit-tested `Scoring` module: par, speed bonus, multiplier, stars, Shot Clock limit, Fix-it box transitions.
- Game Center: out of scope for v1.

### Constants (single source of truth)

| Constant | Value |
|---|---|
| parBase / parPerWord | 0.8 s / 0.25 s |
| basePoints / maxSpeedBonus / wrongPenalty | 50 / 50 / −25 |
| multiplier thresholds | 5 → 1.5, 10 → 2, 20 → 3 |
| leanThreshold / commitThreshold | 18 pt / 80 pt |
| enterDelay | 190 ms |
| roundLength (Journey, Daily) / bossLength | 20 / 15 |
| bossMaxMisses | 2 |
| bossClock(level) | 5.0 − 0.4 × (level − 1) s |
| shotShrink / shotEvery / shotFloor | ×0.92 / 5 correct / 1.2 s |
| longSentenceExtra | 0.2 s per word over 8 |
| shotLives | 3 |
| sprintDuration / sprintMissPenalty | 60 s / 3 s |
| timedFeedbackDuration | 1.5 s |
| reinsertGap | 3 cards |
| reviewShare (Journey L ≥ 2) | 6 of 20 |
| Fix-it intervals | 0, 1, 3, 7 days |
| masteryStreak | 3 correct under par |

---

## 14. Decisions taken

These were open in the review and are settled with the recommended option:

1. Fixed sides (singular left, plural right) in all modes.
2. Wrong answer: −25 and streak reset; round score floors at 0.
3. Correction swipe required in Journey, Daily 20 and Fix-it; skipped in timed modes.
4. Clock numbers fixed as in §13; retune after ~2 weeks of real data.
5. No audio: no read-aloud and no Listen mode. Text only.
6. Up to 4 local profiles; nothing online.
7. Parent corner with "add a sentence I heard" in v1.
8. 20-card rounds; daily goal = Daily 20 + one other mode.

## 15. Out of scope for v1

Any spoken audio (read-aloud, Listen mode), speech recognition ("say it" mode), Game Center, iCloud sync, iPad-specific layout, British English variant, content beyond the 8 levels.
