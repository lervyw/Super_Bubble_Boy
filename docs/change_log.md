# Change Log

## 2026-04-05

### Baseline documentation

- Read the repository structure and identified the current gameplay foundation around `Cenas/level1.tscn`
- Reviewed the main scripts for the level controller, player, slime enemy, and boss
- Added `docs/project_context.md` to preserve working context between edits
- Added this log file to track future changes in chronological order

### Initial observations

- `scripts/player.gd` already models both platformer and metroidvania modes through `GameMode`
- `scripts/level_1.gd` expects a `boss_defeated` signal, but `scripts/boss.gd` currently does not expose that signal in the reviewed version
- `scripts/inimigo.gd` is currently empty

### Pending

- Wait for the next gameplay or scene change request from the user
- Commit each requested change in isolated git commits where practical

## 2026-04-05

### Player combat and mana foundation

- Extended `scripts/player.gd` so the player now has a formal combat foundation for:
  normal attacks, passive attacks, active super attacks, and an ultimate attack
- Added mana-aware mode rules:
  metroidvania always supports mana, while platform mode can independently enable mana and mana-based attacks
- Restricted form switching to metroidvania mode and preserved the unlocked-form gate
- Forced the player back to `NORMAL` form when platform mode is enabled so platform sections cannot continue in transformed forms by accident
- Preserved normal attack flow while making active super attacks configurable through exported arrays for name, cooldown, mana cost, damage, and area path
- Added an ultimate attack foundation that uses a separate cooldown and consumes all mana

### Stats, HUD, checkpoint, and respawn compatibility

- Extended `scripts/stats.gd` with mana, mana regen, mana refill helpers, and a `mana_changed` signal
- Updated `scripts/hud.gd`, `Cenas/hud_panel.gd`, and `Cenas/hud.tscn` so the HUD can show mana and visually disable the special-attack menu entry when mana attacks are unavailable
- Updated `Cenas/checkpoint.gd`, `scripts/level_1.gd`, and `scripts/GameManager.gd` so checkpoints and respawns can refill mana alongside health

### Enemy and boss compatibility

- Updated `scripts/slime.gd` and `scripts/boss.gd` to read attack damage from the attacking hitbox metadata instead of using a fixed damage value for every player attack
- Added the missing `boss_defeated` signal emission to `scripts/boss.gd` so level transitions can react correctly when the boss dies

### Verification notes

- A local Godot binary was not available in the workspace shell, so I could not run a headless engine parse/test pass
- Verification was limited to static inspection and diff review

## 2026-04-05

### Player manual

- Added `docs/how_to_play.md` with a simple manual in plain language
- Documented the currently confirmed keyboard controls from `project.godot`
- Documented that the ultimate attack currently has no usable command because the input action is not bound and the player script keeps direct ultimate input disabled by default

## 2026-04-05

### Ultimate input mapping in title menu

- Added an `Ultimate` button to the controls menu in `Cenas/Title.tscn`
- Updated `scripts/title.gd` so `ultimate_attack` can be rebound and its current key is shown in the menu
- Enabled direct ultimate input by default in `scripts/player.gd`, so the new `ultimate_attack` binding is actually used in gameplay
- Fixed `Title.tscn` button signal targets so they match the methods that currently exist in `scripts/title.gd`
- Preserved the existing save/load behavior by continuing to route rebinds through `ConfigManager.rebind_action()`

## 2026-04-05

### Slime attack and stomp fix

- Reworked `scripts/slime.gd` so each slime can now attack through a new Inspector-configurable `attack_mode`
- Supported slime attack modes:
  `CONTACT` for direct pounce/contact damage and `HITBOX` for boss-style timed attack hitboxes
- Kept flying configurable through the existing `move_mode = FLY`
- Fixed enemy hurtbox filtering so slimes no longer die from accidental side collisions with the player; now they only die from valid player attacks or valid stomps

### Boss animation use

- Reworked `scripts/boss.gd` to drive the boss sprite with the available `idle`, `walk`, and `attack` animations based on behavior
- Updated `Cenas/boss.tscn` so the boss no longer starts in attack animation by default
