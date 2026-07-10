# How To Play

Last updated: 2026-04-29

This file is the simple version.
Think of it as "potato knowledge".

## What This Game Is

You control Bubble Boy in a 2D game.

The game has:

- 1 gameplay mode
- 3 forms
- normal attacks
- mana attacks

## Gameplay Mode

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

## Current Keyboard Controls

### Movement

- Move/swim up: `W`
- Move left: `A`
- Move/swim down: `S`
- Move right: `D`
- Jump: `Space`
- Dash: `Shift`

### Combat

- Normal attack: `C`
- Parry/defense: `V`

### Form Change

- Normal form: `1`
- Bubble form: `2`
- Super form: `3`

Important:

- form change only works if the form is unlocked

### Power Wheel

- Hold power wheel: `R`
- Point up: `I`
- Point left: `J`
- Point down: `K`
- Point right: `L`
- Pause: `Tab`

### PlayStation

- Move: left analog stick
- Jump: Cross
- Attack: Square
- Parry: Triangle
- Dash: Circle
- Bubble: R1
- Super: L1
- Normal: L2
- Hold power wheel: R2
- Select wheel power: right analog stick
- Pause: Options

### Xbox

- Move: left analog stick
- Jump: A
- Attack: X
- Parry: Y
- Dash: B
- Bubble: RB
- Super: LB
- Normal: LT
- Hold power wheel: RT
- Select wheel power: right analog stick
- Pause: Menu/Start

## Ultimate And Special Powers

Ultimate and special powers are selected through the power wheel instead of dedicated default shortcuts.

## What To Remember In Potato Mode

- The game uses metroidvania mode
- Only unlocked forms can be used
- Normal attack = basic hit
- Super attack = spends some mana
- Ultimate attack = spends all mana
- Ultimate currently uses `T` by default
- Death sends the player back to the last checkpoint
