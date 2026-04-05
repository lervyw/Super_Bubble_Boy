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
- Combat, combos, defense, special attack
- Damage, invincibility, death, respawn
- Stomp logic per form
- HUD interaction

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
- Dies and frees itself from scene

Important note:

- `scripts/level_1.gd` expects a `boss_defeated` signal on the boss, but the current boss script reviewed does not define or emit that signal.

### Common Enemy

Scene:

- `res://Cenas/slime.tscn`

Script:

- `res://scripts/slime.gd`

Observed responsibilities:

- Simple chase AI
- Jump/walk/fly modes
- Timed melee hitbox
- Hurtbox damage intake
- Death on stomp or direct attack

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
