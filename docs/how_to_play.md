# How To Play

Last updated: 2026-04-05

This file is the simple version.
Think of it as "potato knowledge".

## What This Game Is

You control Bubble Boy in a 2D game.

The game has:

- 2 gameplay modes
- 3 forms
- normal attacks
- mana attacks

## The 2 Gameplay Modes

### Platformer Mode

This is the simpler mode.

Main idea:

- jump
- move
- attack
- survive

Important:

- You cannot change forms here
- The game can be set to disable mana here
- The game can also be set to disable mana attacks here
- When this mode is activated, the player goes back to Normal form

### Metroidvania Mode

This is the more complete mode.

Main idea:

- you can use health
- you can use mana
- you can change forms if those forms are unlocked
- you can use special mana attacks

## The 3 Forms

### Normal

The default form.

### Bubble

A special form.
You can only use it if:

- it was unlocked
- you are in Metroidvania mode

### Super

A stronger form.
You can only use it if:

- it was unlocked
- you are in Metroidvania mode

## Attacks

The player now has 4 attack types in the code.

### 1. Normal Attack

This is the regular hit.
It already existed before.

Use it when:

- you want the basic attack
- you do not want to spend mana

### 2. Passive Attack

This is the "auto attack" foundation.

Simple idea:

- it can happen by itself
- it can happen after some time
- later more conditions can be added

Right now:

- the foundation exists
- it can be configured
- it is not yet a full final gameplay system

### 3. Active Super Attack

This is the strong attack that spends mana.

Simple idea:

- it uses mana
- it has cooldown
- it can do different damage
- it can use different hit areas

The code now supports multiple super attacks with separate settings for:

- attack name
- cooldown
- mana cost
- damage
- attack area path

### 4. Ultimate Attack

This is the biggest attack.

Simple idea:

- it has cooldown
- it does big damage
- it uses all mana

Important:

- the ultimate system exists in code
- but it does not have a usable input command yet

## Mana

Mana is the blue energy for strong attacks.

Simple rules:

- active super attacks spend some mana
- the ultimate spends all mana
- mana regenerates after a short wait
- checkpoints can refill mana
- respawn/checkpoint systems can refill mana too

## Health And Mana Refill

Checkpoints now can restore:

- health
- mana

Respawn can also restore:

- health
- mana

## Current Keyboard Controls Found In The Project

These are the controls I could confirm from `project.godot`.

### Movement

- Move left: `H`
- Move right: `L`
- Jump: `J`
- Crouch: `K`
- Dash: `D`

### Combat

- Normal attack: `C`

### Form Change

- Bubble form: `X`
- Super form: `Z`
- Back to normal form: `N`

Important:

- form change only works in Metroidvania mode
- form change only works if the form is unlocked

### Radial / Quick Form Input

- Hold form select: `1`

This is used by the quick form selection logic.

## What Is The Ultimate Attack Command?

Short answer:

- there is no command yet

Why:

- the player script has the ultimate attack code
- but `allow_ultimate_input` is off by default
- and `project.godot` does not have an `ultimate_attack` input action yet

So if you try to use it now:

- nothing will happen

## What To Remember In Potato Mode

- Platformer mode = simple mode
- Metroidvania mode = full mode
- Only Metroidvania can change forms
- Only unlocked forms can be used
- Normal attack = basic hit
- Super attack = spends some mana
- Ultimate attack = spends all mana
- Ultimate button does not exist yet
