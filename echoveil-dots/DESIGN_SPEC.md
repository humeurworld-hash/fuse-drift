# EchoVeil: Mourk Weave — design spec

The shared contract between design work and the Godot build. Design against
these numbers and a mockup maps 1:1 onto the game with no reinterpretation.

Anything in here is what the code currently does. When a design changes a
value, change it here too — this file is the source of truth we both read.

---

## 1. Canvas

| | |
|---|---|
| Design size | **720 × 1280 px, portrait** |
| Aspect | 9:16 |
| Godot stretch | `canvas_items`, aspect `expand` |
| Orientation | portrait, locked |

**Design at exactly 720 × 1280.** Every number below is in those units, and
they are 1:1 with Godot pixels — no scale factor.

If a design tool defaults to a phone preset (e.g. 390 × 844 CSS points),
multiply every value by **1.846** to convert, or just set the artboard to
720 × 1280 to avoid it entirely.

Because the stretch mode is `expand`, taller phones get **extra height, not
scaling**. So:

- Anchor the HUD to the **top**, the hint line to the **bottom**.
- The board is positioned as a **fraction of height** (see §4), not a fixed y.
- Keep anything critical out of the top 60 px and bottom 90 px (notch / home
  indicator on real devices).

---

## 2. Palette

Copy these exactly — the crystal art is lit to match them.

| Token | Hex | Use |
|---|---|---|
| `BG` | `#080D17` | page background, panel base |
| `GOLD` | `#E6D166` | titles, moves counter, cleared state, primary accent |
| `VEIL` | `#6B7594` | veiled/shrouded pieces, locked state |
| Ember | `#FF4D73` | hue 0 — anger |
| Sorrow | `#4D9EFF` | hue 1 — sadness |
| Verdant | `#5CEB7A` | hue 2 — calm |
| Radiance | `#FADB59` | hue 3 — joy |
| Umbral | `#B86BFF` | hue 4 — fear |

Supporting greys currently in use:

| Hex | Use |
|---|---|
| `#EBEDF7` | primary text |
| `#8C94B3` | secondary text (captions, "THREAD n") |
| `#6B7594` | tertiary text (bottom hint) |
| `#121B2B` | button fill |
| `#0D141F` | panel fill |

Warden (Canvas drone) red: body `#1A1C26`, edge/eye `#FF4D42`.

---

## 3. Type

There is no custom font yet — everything is Godot's default. **If the design
picks a typeface, say so and I'll add it**; otherwise assume a clean geometric
sans.

| Role | Size | Colour |
|---|---|---|
| Screen title | 40 | GOLD |
| Menu title | 92 | GOLD |
| Moves counter | 64 | GOLD |
| Shape/alert banner | 40–44 | hue-tinted |
| Level intro note | 24 | GOLD |
| Button label | 26–40 | GOLD or `#99A3C2` |
| Caption ("MOVES") | 20 | `#8C94B3` |
| Bottom hint | 20 | `#6B7594` |
| Goal chip count | 26 | white, or `#5CEB7A` when met |

---

## 4. Game screen (current layout)

All y values from the top of a 720 × 1280 canvas.

| Element | Position | Size |
|---|---|---|
| Back chevron | x 20, y 24 | ~64 × 60 |
| "THREAD n" | centred, y 36 | 26 pt |
| Moves number | centred, y 78 | 64 pt |
| "MOVES" caption | centred, y 152 | 20 pt |
| Goal chip row | centred, y 200 | each chip 76 × 96 |
| **Board origin** | centred, **y = height × 0.33** (≈422) | centre of top-left cell |
| Board | 6 × 6 grid, **cell pitch 104** | 520 × 520 span, ≈600 with art bleed |
| Piece art | 108 × 108 | touch radius ~46 |
| Level note banner | centred, board bottom + 78 | 24 pt, 44 px side margins |
| Shape banner | centred, board top − 96 | 40 pt |
| Bottom hint | centred, y = height − 70 | 20 pt |

**Board maths:** cell pitch 104, so 6 columns span `5 × 104 = 520`, centred →
left column centre at x 100, right at x 620. Rows run from y ≈ 422 to ≈ 942.

Free space worth designing into: **y 250–420** (between chips and board) and
**y 1000–1200** (below board, above hint).

---

## 5. Level select — "The Descent"

Vertically scrolling; content is taller than the screen.

| | |
|---|---|
| Content height | `180 + 210 + 190 × (levels − 1)` — 3990 for 20 levels |
| Stop spacing | 190 vertical |
| Stop horizontal sway | ±150 from centre (sine) |
| Stop radius | 42 (hit area 84 × 84) |
| Cave wall inset | 90–150 from each edge |
| Top scrim | 88 tall, `BG` at 88% |
| Bottom scrim | 110 tall, `BG` at 88% |

Read bottom-to-top: level 1 at the bottom (surface), highest level at the top
(deepest). Three stop states: **cleared** (gold ring), **open** (white pulsing
ring), **locked** (dark, thin grey ring).

---

## 6. What to hand back

Ranked by how cleanly I can consume it:

1. **A published artifact URL** — best. I fetch it and read the real HTML/CSS,
   so I get exact hex values, spacing and sizes with nothing lost.
2. **The HTML/CSS pasted in chat** — same fidelity, no fetch needed.
3. **A screenshot plus a values list** — fine for layout intent; include the
   numbers that matter (positions, sizes, hex) since I can't measure a PNG
   precisely.
4. **A screenshot alone** — I can match the look but will have to guess
   spacing, and we'll iterate more.

Whatever the form, the useful unit is: *element → position → size → colour*,
in 720 × 1280 units.

## 7. Known gaps a design could fix

Honest list of what's laid out by feel rather than designed:

- The HUD stack (title / moves / chips) is evenly spaced by eye, not to a grid.
- Goal chips are a plain row; with 4+ chips plus a drone chip they crowd.
- Win/lose is a centred stack on a dim scrim — functional, unstyled.
- The main menu is a centred column with a shard row; it has no real layout.
- No custom font anywhere.
- Empty space at y 250–420 and below the board is unused.
