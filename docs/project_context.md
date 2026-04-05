# Project Context

Last reviewed: 2026-04-05

## Overview

This repository is a Godot 2D game project for `Super Bubble Boy`.
The current playable foundation appears to be concentrated in `Cenas/level1.tscn`.

The game concept described by the user is a hybrid that switches between:

- Platformer
- Metroidvania

The player logic already contains an explicit `GameMode` enum with:

- `PLATAFORMA`
- `METROIDVANIA`

## Main Level 1 Wiring

Scene: `res://Cenas/level1.tscn`

Level controller:

- `res://scripts/level_1.gd`

Important configured references in `level1`:

- `player = NodePath("player")`
- `stats = NodePath("player/Stats")`
- `boss_node = NodePath("boss")`
- `next_scene = res://Cenas/Final_Credits.tscn`

Main instantiated gameplay elements currently present in `level1`:

- Player
- Boss
- Multiple slime enemies
- Checkpoints
- Water areas
- Exit object (`saida`)
- Background/parallax

## Gameplay Scripts Read

### Player

Scene:

- `res://Cenas/player.tscn`

Main script:

- `res://scripts/player.gd`

Observed responsibilities:

- Character movement and state machine
- Form switching: `NORMAL`, `BUBBLE`, `SUPER`
- Hybrid game mode enum
- Combat, combos, defense, passive/active/ultimate attack foundations
- Damage, invincibility, mana, death, respawn
- Stomp logic per form
- HUD interaction

Current attack foundation in `scripts/player.gd`:

- Normal attacks keep using the existing attack flow
- Passive attacks now have a timer/config foundation
- Active super attacks now support configurable slot arrays:
  `name`, `cooldown`, `mana_cost`, `damage`, `area_path`
- Ultimate attack now has its own cooldown/damage foundation and consumes all mana
- Mana usage can be enabled/disabled independently from mana attacks in platform mode

Current mode/form rules:

- Forms can only be changed in `METROIDVANIA`
- Locked forms still cannot be selected
- Platform mode can optionally disable mana and/or mana-based attacks
- Platform mode currently forces the player back to `NORMAL` form when enabled

Important groups and combat nodes:

- Root scene instance in `level1` is in group `player`
- Attack area is in group `killer`
- Multiple stomper areas are in group `killer`
- Internal collision nodes also use group `player`

### Boss

Scene:

- `res://Cenas/boss.tscn`

Script:

- `res://scripts/boss.gd`

Observed responsibilities:

- Chases player with configurable movement mode
- Performs timed hitbox attack
- Receives damage through hurtbox
- Emits `boss_defeated` on death and frees itself from scene

Important note:

- `scripts/level_1.gd` expects a `boss_defeated` signal on the boss. This has now been aligned in `scripts/boss.gd`.

### Common Enemy

Scene:

- `res://Cenas/slime.tscn`

Script:

- `res://scripts/slime.gd`

Observed responsibilities:

- Simple chase AI
- Jump/walk/fly modes
- Configurable attack mode per slime:
  `CONTACT` or `HITBOX`
- Hurtbox damage intake
- Death only from valid player attack hitboxes or valid stomp checks

## Git Baseline

HEAD at review time:

- `ebf76ab` `sistema de ataques e habilidades`

Recent history before new work:

- `ebf76ab` `sistema de ataques e habilidades`
- `f13ad99` `sistema de menu de ataques`
- `2c00be8` `sistema de animacoes novo`

## Working Rules For Future Changes

- Track each meaningful change in `docs/change_log.md`
- Create a git commit after each coherent task so the user can roll back safely
- Avoid touching the untracked empty `.codex` file unless the user asks

## Player-Facing Docs

- `docs/how_to_play.md` now exists as the simple player manual
- Current ultimate status: `ultimate_attack` is now present in `project.godot` and can be rebound from `Title.tscn`

## Title / Config Menu

- `res://Cenas/Title.tscn` is the first screen shown by the game
- `res://scripts/title.gd` controls the main menu, config menu, and input rebinding menu
- The controls menu now includes a dedicated `Ultimate` rebind button for `ultimate_attack`
- Title button signal wiring was aligned with the current script method names to avoid broken presses at runtime

## Current Combat Notes

- Slime enemies can now be configured in the Inspector to attack either by direct contact/pounce or by timed hitbox attack
- Slime flying is still selected through the existing `move_mode = FLY` option
- Player stomp areas are now tagged separately from normal attack areas so enemies do not die from accidental side collisions
- Boss animation flow is now script-driven using the available `idle`, `walk`, and `attack` animations
