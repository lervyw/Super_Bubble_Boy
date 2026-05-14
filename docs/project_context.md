# Project Context

Last reviewed: 2026-04-29

## Overview

This repository is a Godot 2D game project for `Super Bubble Boy`.
The current playable foundation appears to be concentrated in `Cenas/level1.tscn`.

The game now uses a single gameplay paradigm:

- Metroidvania

The legacy `GameMode` enum still exists in `scripts/player.gd` for compatibility with older scripts/scenes, but runtime gameplay should behave as metroidvania only.

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
- Legacy game mode enum kept for compatibility
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
- Mana and mana attacks are always available by gameplay rules

Current mode/form rules:

- The player starts and stays in metroidvania behavior
- Locked forms still cannot be selected
- Checkpoints no longer change gameplay mode

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
- The title menus use a framed dark pixel-art layout with the existing animated title/background assets
- The config screen exposes Master, Music, and SFX volume sliders
- The controls menu now includes a dedicated `Ultimate` rebind button for `ultimate_attack`
- The controls menu also exposes left, right, crouch, dash, and pause rebinding entries
- Control rebinding supports keyboard, joypad buttons, analog axes, and Xbox/PS4 trigger axes (`LT/L2`, `RT/R2`)
- Saved joypad bindings are normalized to any controller device so Xbox/PS4 mappings survive controller reconnect/order changes
- Title button signal wiring was aligned with the current script method names to avoid broken presses at runtime

## Android / Mobile Controls

- `scripts/level_1.gd` can create `scripts/mobile_controls.gd` at runtime through the `Mobile Controls` export group
- The overlay appears automatically on Android/iOS/touchscreen devices when `mobile_controls_enabled` is true
- `mobile_controls_show_on_desktop` can be enabled in the Inspector to test the touch overlay on desktop
- The mobile layout uses a left virtual touch wheel for movement/crouch and right thumb buttons for jump, attack, dash, power menu, and Normal/Bubble/Super transforms
- When the power menu is held open, the same touch wheel switches from movement to HUD-wheel direction selection and does not move the player until the power menu closes
- The mobile overlay also exposes `PAUSE`

## Display Settings

- Internal pixel-art viewport remains `420x280`
- The game window opens at `1260x840`, an integer 3x scale
- Stretch mode is `canvas_items` with aspect `expand`, so widescreen/mobile displays fill the screen without distorting the pixel-art viewport

## Camera Framing

- The active player camera is `player/Camera` in `Cenas/player.tscn`
- `scripts/player.gd` configures camera smoothing, drag margins, a modest horizontal look-ahead, and a vertical offset that keeps the player slightly below center for metroidvania-style framing
- Level-specific camera limits are still the safest way to prevent widescreen from revealing unfinished/offstage map areas
- Attack, special attack, defense, transform, and power-wheel states keep vertical gravity active; they only stop horizontal movement.

## Level Timer

- The timer HUD scene is `res://Cenas/Timer.tscn`
- Timer logic lives in `res://scripts/timer.gd`
- The default timer value in the timer script is still `180.0` seconds
- The active per-level control is now on the root level script `res://scripts/level_1.gd`:
  `level_timer_enabled`, `level_time_limit`, and `timer_node`
- `level1` and `level2` currently enable the timer with `level_time_limit = 180.0`
- When time reaches zero, the timer calls the player's timeout death flow. Death now respawns the player at the last checkpoint instead of using platform lives or the Continue scene.

## Current Combat Notes

- Slime enemies can now be configured in the Inspector to attack either by direct contact/pounce or by timed hitbox attack
- Slime flying is still selected through the existing `move_mode = FLY` option
- Slimes target the player through the `jogador` group and use `player_hurtbox` for hitbox damage resolution
- Slime facing now has a horizontal dead zone through `turn_horizontal_threshold`, so the enemy does not rapidly flip when the player is almost directly above it
- Player stomp areas are now tagged separately from normal attack areas so enemies do not die from accidental side collisions
- Boss animation flow is now script-driven using the available `idle`, `walk`, and `attack` animations
- Boss facing also uses `turn_horizontal_threshold`, so it does not rapidly flip when the player is almost directly above it
- Fatal boss and slime damage both use the same checkpoint respawn flow
- `default` is treated as placeholder data for boss/slime sprite sheets and is no longer the intended runtime animation for their gameplay states
- Attack hitboxes now turn off before the end of the animation, but the enemy remains in the attack state until the full attack animation duration has completed
- The player scene now uses clearer area names:
  `HurtboxArea`, `AttackHitbox`, `StompHitboxNormal`, `StompHitboxBubble`, `StompHitboxSuper`
- Enemy hurtboxes now look for the player's real attack hitbox group (`player_attack`) for attack damage instead of treating every `killer` area the same way
- Slime and boss now use a dedicated `AttackReceiver` area for button-based attack damage
- Stomps are handled separately through the top `Hurtbox` area
- Boss stomp no longer kills instantly; it applies damage and the boss only dies when health reaches zero
- Slimes now have simple separation logic to reduce overlapping stacks
- Player attack windows are now controlled only by `scripts/player.gd`; `scripts/textura_2.gd` no longer re-enables attack areas every animation frame
- Player no longer takes damage just by touching slime/boss bodies; damage should now come from explicit enemy attack behavior
- Boss and slime hitbox attacks now play their wind-up animation first and only open the damaging hitbox at the end of the animation
- Fatal enemy hits now put the player through `hurt` then the form-specific `death` animation and then respawn the player at the last checkpoint with HP/mana restored
- Platform lives and the Continue scene are no longer part of the player death flow
- Bosses are excluded from the player's generic stomp instant-kill path; stomps now chip boss health instead
- `Cenas/Final_Credits.tscn` now uses the real `res://scripts/final_credits.gd` script resource, avoiding the boss-defeat scene-change script error

## Level 1 Test Setup

- `res://Cenas/level1.tscn` now has explicit enemy test setup:
- Boss uses scripted `idle`, `walk`, and `attack` animation names
- Slimes in the current level1 test setup use explicit hitbox attacks instead of touch/contact damage
- One slime is set to `FLY` movement mode for quick testing
