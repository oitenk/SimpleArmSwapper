# Simple Arm Swapper

A Cyberpunk 2077 mod for swapping between multiple sets of arm cyberware on the fly, without visiting a Ripperdoc.

Current version: **2.0.1**

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

- [Cyberware-EX](https://github.com/psiberx/cp2077-cyberware-ex), for more than one arm cyberware slot
- [Mod Settings](https://github.com/jackhumbert/mod_settings)
- [redscript](https://github.com/jac3km4/redscript) and [RED4ext](https://github.com/WopsS/RED4ext), which the mods above already need

Optional: The Flesh Is Weak adds even more cyberware slots on top of Cyberware-EX, and works with this mod.

With only one arm cyberware equipped, the game behaves exactly as it does without the mod.

## Installation

Copy `SimpleArmSwapper.reds` into `r6/scripts` in your Cyberpunk 2077 folder.

## Changelog

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
