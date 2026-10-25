# Simple Arm Swapper

A Cyberpunk 2077 mod for swapping between multiple sets of arm cyberware on the fly, without visiting a Ripperdoc.

Current version: **2.3**, for Cyberpunk 2077 2.5.

## Features

- **Swap with the "4" key.** With arms drawn, press 4 to step to the next set of equipped arm cyberware.
- **Swap with the weapon wheel.** The wheel's cyberware slot cycles through every equipped arm cyberware and bare fists, in both directions, using the wheel's previous/next keys. Select the slot to draw what it shows.
- **Arm memory.** Drawing your arms brings back the set you used last, not whatever is in the first slot. This carries across saves.
- **Gorilla Arms function like vanilla.** They take the place of bare fists, so the wheel offers Gorilla Arms rather than a separate fists entry while they are installed.
- **Third-person arms.** While your arms are put away, the inventory, vehicles and mirrors show the arm cyberware you used last.
- **Glamdoc styles per arm type.** The Glamdoc can style every arm cyberware type you have equipped, not only the one in the first slot. Each type keeps its own style and colours, saved with your game, and switching arms puts the matching style back.

## Mod Settings options

With [Mod Settings](https://github.com/jackhumbert/mod_settings) installed, these appear under "Simple Arm Swapper". Without it, the defaults apply.

- **Weapon Wheel Shows Next Arms** (on by default): while arms are drawn, the wheel's cyberware slot starts on the next arms in line, so selecting it swaps right away. Off: it starts on the arms you are holding.
- **Show Last Used Arms When Holstered** (on by default): third-person views show your last used arms while they are put away. Off: the game and your other mods decide.
- **Glamdoc Style Per Arm Type** (on by default): the Glamdoc styles each arm type separately and switching arms puts the matching style back. Off: styling works as in the base game.

Empty arm slots are skipped, and arm cyberware that is not a melee weapon (such as the Projectile Launch System) is left out of the rotation.

## Requirements

- [Cyberware-EX](https://github.com/psiberx/cp2077-cyberware-ex)
- Any mod that adds more arm cyberware slots. Cyberware-EX does not add arm slots on its own, and you need at least two. This includes Cyberware-EX slot configurations that unlock an extra arm slot: Simple Arm Swapper works as the arm swapper for those.
- [redscript](https://github.com/jac3km4/redscript) and [RED4ext](https://github.com/WopsS/RED4ext), which the mods above already need

Optional:

- [Mod Settings](https://github.com/jackhumbert/mod_settings) - adds the options above to the in-game Mod Settings menu. Without it the defaults apply.

With only one arm cyberware equipped, the game behaves exactly as it does without the mod.

## Installation

Install the release zip with a mod manager such as Vortex, or copy its `r6` folder into your Cyberpunk 2077 folder. The script ends up here:

```
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
```

If you are updating from 1.x, delete the old `r6/scripts/SimpleArmSwapper.reds` first. Having both copies installed will stop the game's scripts from compiling.

## For mod authors

Other scripts can check that Simple Arm Swapper is installed with `@if(ModuleExists("SimpleArmSwapperMod"))`. The module also provides `Version()`, which returns the version as a string.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

Released under the [MIT License](LICENSE).
