# EchoVeil: Mourk Weave

A Two Dots-style connect-the-dots puzzle set in the world of EchoVeil, where
emotion crystallises into Mourk. Companion game to *Fuse: Mourk Run* (the main
project in this repository) — this is a fully separate, self-contained Godot
project.

## How to play

- **Weave a thread**: drag between neighbouring shards of the same hue —
  **in any of the 8 directions**, diagonals included.
- **Release** with 2+ shards woven to gather them (costs one move).
- **Close a loop** (weave back onto a shard already in your thread) and release
  to gather **every** shard of that hue on the board. A loop needs at least 4
  distinct shards, so a diagonal triangle won't do it.
- Meet every hue goal (and lift every veil) before your moves run out.

## Mechanics, thread by thread

Rather than dropping everything at once, each idea arrives on its own thread
with a one-line note, then stays.

| From | Mechanic | What it does |
|---|---|---|
| 1 | **Weaving & loops** | The base game, in all 8 directions. |
| 4 | **Resonant shards** | Prismatic crystals ringed in every hue. Weave *through* one and your thread may **change hue and keep going** — the move that turns "find the biggest blob" into route-planning. The thread is drawn per-segment, so you watch the colour change at the resonance. Chain 8+ shards and a new resonance condenses on the board. |
| 5 | **Veils** | Grey, drained shards that can't be woven. Gather beside one to lift its veil. |
| 7 | **Echo shards** | Carry a countdown badge. Each move ticks it down; at zero the Loops rewind every neighbouring shard to a random hue. Gather one before it fires for a **bonus move**. |

## Why it doesn't look like a match-3

The skeleton of Two Dots and Bejeweled is nearly identical; presentation is
what separates them. Deliberate choices here:

- **No sockets.** Shards hang in the veil — they drift, sway, and breathe.
  A circle behind each piece, even a faint one, reads instantly as a slot.
  For the same reason the hue aura is stacked soft rings drawn *behind* the
  crystal, never over it.
- **Each hue has its own silhouette.** The art is one crystal cluster, so
  every emotion gets a signature tilt, scale and handedness (`HUE_FORM`).
  Five recolours of one shape is the jewel-game tell.
- **The thread is the hero.** While weaving, shards that can't join fall back
  into the veil, so the eye follows the line rather than scanning a wall of
  gems — and the thread is drawn per-segment so a hue switch is visible.

## The five hues

| Hue | Emotion | Colour |
|---|---|---|
| Ember | anger | red |
| Sorrow | sadness | blue |
| Verdant | calm | green |
| Radiance | joy | gold |
| Umbral | fear | purple |

## Running it

Open this folder (`echoveil-dots/`) as a project in Godot 4.6+ and press Play.
Portrait 720×1280, mobile renderer (GL Compatibility) — same setup as the main
project. The game pieces use the Mourk shard crystal art shared with
*Fuse: Mourk Run* (`assets/shards/`); everything else is drawn in code.

## Structure

- `scenes/` — thin `.tscn` shells (Menu, LevelSelect, Game); all UI is built in code
- `scripts/global.gd` — autoload `G`: palette, level definitions, save data
- `scripts/game.gd` — board, weaving input, loop detection, gravity/refill, HUD
- `scripts/dot.gd` — a single Mourk mote (procedural glow, veil state)
- `scripts/motes.gd` — ambient drifting-mote background layer
- `scripts/ui_helpers.gd` — shared styled labels/buttons/panels

Progress (unlocked threads) is saved to `user://mourk_weave.cfg`.

## Smoke test

A headless test drives the board logic (fill, veils, weave, loop clear,
gravity/refill) and exits non-zero on failure:

```sh
godot --headless --path . res://TestSmoke.tscn
```
