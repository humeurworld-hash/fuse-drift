# EchoVeil: Mourk Weave

A Two Dots-style connect-the-dots puzzle set in the world of EchoVeil, where
emotion crystallises into Mourk. Companion game to *Fuse: Mourk Run* (the main
project in this repository) — this is a fully separate, self-contained Godot
project.

## How to play

- **Weave a thread**: drag through orthogonally adjacent motes of the same hue.
- **Release** with 2+ motes woven to gather them (costs one move).
- **Close a loop** (weave back onto a mote already in your thread) and release
  to gather **every** mote of that hue on the board.
- **Veiled motes** (grey shrouds) can't be woven. Gather a mote next to a veil
  to lift it and free the mote underneath.
- Meet every hue goal (and lift every veil) before your moves run out.

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
