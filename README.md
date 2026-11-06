# Simple Arm Swapper

A Cyberpunk 2077 mod for swapping between multiple sets of arm cyberware on the fly, without visiting a Ripperdoc.

Current version: **2.6.1**, for Cyberpunk 2077 2.5.

## Features

- **Swap with the "4" key.** With arms drawn, press 4 to step to the next set of equipped arm cyberware.
- **Swap with the weapon wheel.** The wheel's cyberware slot cycles through every equipped arm cyberware and bare fists, in both directions, using the wheel's previous/next keys. Select the slot to draw what it shows.
- **Swap with a controller button.** With arms drawn, tap D-pad Left to step to the next set of arm cyberware. Holding D-pad Left still opens the pocket radio. The button can be changed in Mod Settings. Needs Input Loader.
- **Arm memory.** Drawing your arms brings back the set you used last, not whatever is in the first slot. This carries across saves.
- **Gorilla Arms function like vanilla.** They take the place of bare fists, so the wheel offers Gorilla Arms rather than a separate fists entry while they are installed.
- **Third-person arms.** While your arms are put away, and while you fight with bare fists, the inventory, vehicles and mirrors show the arm cyberware you used last.
- **Glamdoc styles per arm type.** The Glamdoc can style every arm cyberware type you have equipped, in one visit. Each type keeps its own style and colours, saved with your game, and switching arms puts the matching style back.
- **Styles on every arm slot.** Mantis Blades and Monowire wear their style in any arm slot: in hand, put away, in photo mode, on the inventory screen and in the Glamdoc preview. This includes the MaxTac Mantis Blades and arms built on them. Needs Codeware.
- **Projectile Launch System styles beside melee arms.** The launcher keeps its own Glamdoc style and colours next to Mantis Blades, Monowire or Gorilla Arms, and shows them when fired. Needs Codeware.
- **Nail items under Gorilla Arms.** Nails worn in Equipment-EX's fingernail slots are hidden while V wears Gorilla Arms, which cover V's hands, and come back with other arms.

## Styling several arm types in the Glamdoc

1. Open the Glamdoc. It opens on the arms you used last.
2. Pick a style and colours, then press **F** to buy and apply it. With more than one melee arm type equipped, the menu stays open.
3. Use the arm type tabs at the top (Mantis Blades, Monowire, Gorilla Arms) to switch to your other arms. V switches to those arms, and the preview follows. The Projectile Launch System tab styles the launcher while V keeps her melee arms; the preview shows the launcher.
4. Style those too, then press **F** again to apply and close.

Buying a style or switching arm type locks in what you have done so far, so leaving with Back only undoes changes made after that.

## Known limitations

- **If an arm looks off,** for example right after removing a style or changing cyberware at a ripperdoc, save and reload once. That clears most visual hiccups. If it doesn't, please report it with a screenshot (and a log with Debug Logging on, if you can).
- **Painted nails.** Most Mantis Blade and Monowire styles paint V's fingernails, which replaces V's own nails as in the base game. The painted nails can be missing on Mantis Blades outside the first arm slot. If you plan to remove arm cyberware that has such a style, remove its Glamdoc style first: otherwise the nail choice in the character editor can stay locked after the arms are gone. If that has already happened, installing the same arms again, removing their style in the Glamdoc and then removing the arms should free the nail choice.
- **Launcher colours.** The game holds one colour set for all arm cyberware. While the Projectile Launch System is out, melee arms on screen share its colours; they get their own back when it is put away.

## Mod Settings options

With [Mod Settings](https://github.com/jackhumbert/mod_settings) installed, these appear under "Simple Arm Swapper". Without it, the defaults apply.

- **Weapon Wheel Shows Next Arms** (on by default): while arms are drawn, the wheel's cyberware slot starts on the next arms in line, so selecting it swaps right away. Off: it starts on the arms you are holding.
- **Show Last Used Arms When Holstered** (on by default): third-person views show your last used arms while they are put away. Off: the game and your other mods decide.
- **Glamdoc Style Per Arm Type** (on by default): the Glamdoc styles each arm type separately and switching arms puts the matching style back. Off: styling works as in the base game.
- **Hide Nail Items Under Gorilla Arms** (on by default): nail items in Equipment-EX's fingernail slots are hidden while V wears Gorilla Arms. Off: they always show.
- **Controller Swap Button** (D-pad Left by default): the controller button that swaps arms when tapped. Needs Input Loader.
- **Debug Logging** (off by default, under Troubleshooting): writes what the mod does with arms and styles to the Cyber Engine Tweaks game log. Leave it off unless asked for a log.

Empty arm slots are skipped, and arm cyberware that is not a melee weapon (such as the Projectile Launch System) is left out of the rotation.

## Requirements

- [Cyberware-EX](https://github.com/psiberx/cp2077-cyberware-ex)
- Any mod that adds more arm cyberware slots. Cyberware-EX does not add arm slots on its own, and you need at least two. This includes Cyberware-EX slot configurations that unlock an extra arm slot: Simple Arm Swapper works as the arm swapper for those.
- [redscript](https://github.com/jac3km4/redscript) and [RED4ext](https://github.com/WopsS/RED4ext), which the mods above already need

Optional:

- [Codeware](https://github.com/psiberx/cp2077-codeware) - shows Glamdoc styles on Mantis Blades and Monowire outside the first arm slot and on the Projectile Launch System beside melee arms, and lets the mod's text be translated. Without it those arms show their plain look.
- [Mod Settings](https://github.com/jackhumbert/mod_settings) - adds the options above to the in-game Mod Settings menu. Without it the defaults apply.
- [Input Loader](https://github.com/jackhumbert/cyberpunk2077-input-loader) - adds the controller swap button. Without it, swapping works with the 4 key and the weapon wheel as before.
- [Equipment-EX](https://github.com/psiberx/cp2077-equipment-ex) - only if you wear nail items in its fingernail slots; the mod hides them under Gorilla Arms. Nothing changes without it.

With only one arm cyberware equipped, the game behaves exactly as it does without the mod.

## Installation

Install the release zip with a mod manager such as Vortex, or copy its `r6` folder into your Cyberpunk 2077 folder. The scripts end up here:

```
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapperStyleData.reds
Cyberpunk 2077/r6/input/SimpleArmSwapper.xml
```

If you are updating from 1.x, delete the old `r6/scripts/SimpleArmSwapper.reds` first. Having both copies installed will stop the game's scripts from compiling.

## Translating

The mod's on-screen text goes through Codeware's localization system, with English as the fallback. To add a language, copy `SimpleArmSwapperLanguageEnglish` at the bottom of the script into a new class, translate the second string of each line, and return it for your language from `SimpleArmSwapperLocalizationProvider.GetPackage`. Without Codeware the English text is used. The Mod Settings page is in English only.

## For mod authors

Other scripts can check that Simple Arm Swapper is installed with `@if(ModuleExists("SimpleArmSwapperMod"))`. The module also provides `Version()`, which returns the version as a string.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

Released under the [MIT License](LICENSE).
