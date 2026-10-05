# Simple Arm Swapper

A Cyberpunk 2077 mod for swapping between multiple sets of arm cyberware on the fly, without visiting a Ripperdoc.

Current version: **2.1**

## Features

- **Swap with the "4" key.** With arms drawn, press 4 to step to the next set of equipped arm cyberware.
- **Swap with the weapon wheel.** The wheel's cyberware slot cycles through every equipped arm cyberware and bare fists, in both directions, using the wheel's previous/next keys. Select the slot to draw what it shows.
- **Arm memory.** Drawing your arms brings back the set you used last, not whatever is in the first slot. This carries across saves.
- **Gorilla Arms function like vanilla.** They take the place of bare fists, so the wheel offers Gorilla Arms rather than a separate fists entry while they are installed.
- **Mod Settings option.** "Weapon Wheel Shows Next Arms" chooses what the wheel's cyberware slot starts on while arms are drawn:
  - On (default): the next arms in line, so selecting the slot swaps right away.
  - Off: the arms you are holding, and you cycle from there.

Empty arm slots are skipped, and arm cyberware that is not a melee weapon (such as the Projectile Launch System) is left out of the rotation.

## Requirements

- [Cyberware-EX](https://github.com/psiberx/cp2077-cyberware-ex)
- Any mod that adds more arm cyberware slots. Cyberware-EX does not add arm slots on its own, and you need at least two. This includes Cyberware-EX slot configurations that unlock an extra arm slot: Simple Arm Swapper works as the arm swapper for those.
- [Mod Settings](https://github.com/jackhumbert/mod_settings)
- [redscript](https://github.com/jac3km4/redscript) and [RED4ext](https://github.com/WopsS/RED4ext), which the mods above already need

With only one arm cyberware equipped, the game behaves exactly as it does without the mod.

## Installation

Create a `simple_arm_swapper` folder inside `r6/scripts` in your Cyberpunk 2077 folder and copy `SimpleArmSwapper.reds` into it:

```
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
```

If you are updating from an older version, delete the old `r6/scripts/SimpleArmSwapper.reds` first. Having both copies installed will stop the game's scripts from compiling.

## For mod authors

Other scripts can check that Simple Arm Swapper is installed with `@if(ModuleExists("SimpleArmSwapperMod"))`. The module also provides `Version()`, which returns the version as a string.

## Changelog

### 2.1

- The script now declares a module, so other mods can detect Simple Arm Swapper.
- No changes to how the mod behaves. The Mod Settings option may return to its default once after updating.

### 2.0.1

- Internal tidying up. No changes to how the mod behaves.

### 2.0

- Added weapon wheel support: the cyberware slot cycles through all equipped arm cyberware and bare fists.
- Added arm memory: drawing arms recalls the last used set instead of always the first slot.
- The "4" key now only cycles while arms are already drawn; otherwise it draws the last used set.
- Added a Mod Settings option for whether the wheel starts on the next arms or the ones in hand.
- Fixed Gorilla Arms appearing twice in the wheel rotation, which stopped it cycling in one direction.
- Mod Settings is now required.

### 1.0

- Initial release: cycle equipped arm cyberware with the "4" key.
