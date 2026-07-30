# EchoVeil: Mourk Weave

A Two Dots-style connect-the-dots puzzle set in the world of EchoVeil, where
emotion crystallises into Mourk. Companion game to *Fuse: Mourk Run* (the main
project in this repository) — this is a fully separate, self-contained Godot
project.

## How to play

- **Weave a thread**: drag through orthogonally adjacent shards of the same hue.
- **Release** with 2+ shards woven to gather them (costs one move).
- **Close a loop** (weave back onto a shard already in your thread) and release
  to gather **every** shard of that hue on the board.
- Meet every hue goal (and lift every veil) before your moves run out.

## Mechanics, thread by thread

Rather than dropping everything at once, each idea arrives on its own thread
with a one-line note, then stays.

| From | Mechanic | What it does |
|---|---|---|
| 1 | **Weaving & loops** | The base game. |
| 2 | **Exposure** | Every shard gathered draws Canvas attention; closing a loop spikes it hard. Fill the meter and the Canvas sweeps the board, shrouding 3 shards. Loops are powerful *and* loud — that tension is the core of the game. |
| 4 | **Resonant shards** | Prismatic crystals ringed in every hue. They join a thread of **any** colour, so they bridge two runs that could never connect. Fuse's resonance, on the board. |
| 5 | **Veils** | Grey, drained shards that can't be woven. Gather beside one to lift its veil. |
| 7 | **Echo shards** | Carry a countdown badge. Each move ticks it down; at zero the Loops rewind every neighbouring shard to a random hue. Gather one before it fires for a **bonus move**. |

Note that shards the Canvas shrouds mid-level are obstacles, not goals — they
don't raise the veil counter. Otherwise a heavy-scoring run could push the
target out of reach faster than you could chase it.

## The five hues

| Hue | Emotion | Colour |
|---|---|---|
| Ember | anger | orange |
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
