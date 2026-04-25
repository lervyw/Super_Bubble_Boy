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

## 2026-04-05

### Enemy animation timing and level1 test wiring

- Updated `scripts/slime.gd` to use explicit `idle`, `walk`, `attack`, and `death` animation names instead of relying on `default`
- Added a non-looping `attack` animation to `Cenas/slime.tscn`
- Updated `scripts/boss.gd` so attack state waits for the full attack animation duration before leaving the attack state
- Changed `Cenas/boss.tscn` attack animation to non-looping so the full attack can complete cleanly
- Cleaned broken slime instance overrides from `Cenas/level1.tscn` that were pointing hitbox/hurtbox paths at a different slime node
- Added explicit level1 test overrides so the scene now contains examples of hitbox slime, contact slime, and flying slime behavior

## 2026-04-05

### Player attack hitbox clarity and enemy damage fix

- Renamed the player collision areas in `Cenas/player.tscn` so the real attack and stomp areas are easier to distinguish
- Moved the player attack hitbox upward so button attacks overlap slime and boss hurtboxes correctly
- Updated `scripts/player.gd` default attack-area paths to the renamed `AttackHitbox`
- Tightened `scripts/slime.gd` and `scripts/boss.gd` hurtbox filtering so attack damage comes from the player's actual attack hitbox instead of generic `killer` areas

## 2026-04-05

### Dedicated attack receiver and slime separation

- Added a new `AttackReceiver` area to both `Cenas/slime.tscn` and `Cenas/boss.tscn`
- Split enemy damage handling so button attacks hit `AttackReceiver` while stomps hit the existing top `Hurtbox`
- Kept slime stomp as an instant kill because the slime is the small enemy
- Changed boss stomp behavior so it deals damage instead of killing instantly; boss death now still depends on total health reaching zero
- Added simple slime-to-slime separation in `scripts/slime.gd` so groups of slimes stop collapsing into a single overlapping stack

## 2026-04-05

### Level 1 scene sync

- Updated `Cenas/level1.tscn` so the current level scene explicitly uses the latest boss/slime animation-name overrides
- Kept the scene's current manual placements while syncing the enemy test configuration in place

## 2026-04-05

### Simplified attack windows and no touch-damage in level1

- Simplified player attack activation so the player's attack hitbox is only opened by `scripts/player.gd` during explicit attack windows
- Removed the sprite-controller logic that was reactivating player attack areas every frame during attack animations
- Removed simple body-touch damage from slime/boss contact on the player side; damage should now come from explicit enemy attack logic
- Updated `Cenas/level1.tscn` so the slime test setup no longer uses contact-attack mode by default

### Enemy attack hitbox facing

- Updated `scripts/boss.gd` and `scripts/slime.gd` so hitbox-based attacks mirror their `AttackHitbox` collision toward the player's horizontal position
- Preserved the boss's existing scene offset as the base attack reach and derived a forward offset for slimes when their hitbox was centered in the scene

### Enemy wind-up and player death restart flow

- Updated `scripts/boss.gd` and `scripts/slime.gd` so hitbox attacks now wait through the attack animation wind-up and only enable the hitbox at the end of the animation
- Added a dedicated `HURT` state in `scripts/player.gd` and `scripts/textura_2.gd` so the player now shows the hurt animation before the death animation
- Changed fatal player hits to restart the current level from the beginning instead of sending the player to continue/checkpoint flow

### Scene sync for combat changes

- Kept the scene-side hitbox and placement adjustments in `Cenas/player.tscn`, `Cenas/boss.tscn`, `Cenas/slime.tscn`, and `Cenas/level1.tscn`
- Restored `boss` and `slime` scene preview animations to `idle` so runtime startup state matches gameplay expectations
- Corrected the slime scene so `attack` remains the non-looping attack animation and `death` remains its separate animation resource

### Platform lives vs metroidvania health

- Restored platform-mode life consumption so fatal hits now decrement `GameManager` lives before the death sequence
- Kept metroidvania-mode fatal hits tied to the player's HP reaching zero
- Platform mode now goes to continue only when the last life is consumed; otherwise it still reloads the current level after the hurt/death sequence

### Boss stomp damage rule

- Updated `scripts/player.gd` so stomping a boss no longer routes through the generic instant-kill stomp branch
- Boss stomps now apply a small configurable damage amount instead, while normal stompable enemies can still die from stomps

### Boss damage flush and credits-scene script fix

- Updated `scripts/boss.gd` so boss hitbox disabling during damage uses deferred collision-state changes, avoiding the physics query flush error on stomp/hit
- Fixed `Cenas/Final_Credits.tscn` to reference `res://scripts/final_credits.gd` as a real script ext_resource instead of a broken generic resource path

## 2026-04-25

### Title menu layout and resolution pass

- Reworked `Cenas/Title.tscn` main/config/controls menus into a darker framed pixel-art layout with wider, consistent buttons and stronger hover/focus states
- Added a Master volume slider to the title config menu and fixed `scripts/ConfigManager.gd` so the built-in `Master` audio bus can be controlled through the saved lowercase `master` setting
- Added missing control rebinding entries for left, right, crouch, dash, and pause while preserving the existing attack/form/combo/ultimate rebinding flow
- Updated `scripts/title.gd` so the title menu initializes slider values from saved config and shows a small prompt when waiting for a new input
- Changed the project window settings to open at 1260x840 while keeping the internal 420x280 pixel-art viewport and preserving aspect ratio with `stretch/aspect="keep"`

### Verification notes

- No local Godot executable was available in the shell, so validation was limited to static inspection and diff review
