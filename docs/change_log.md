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
