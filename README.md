# Simple Arm Swapper

A Cyberpunk 2077 mod for swapping between multiple sets of arm cyberware on the fly, without visiting a Ripperdoc.

Current version: **3.0.2**, for Cyberpunk 2077 2.5.

## Features

- **Four arm cyberware slots.** With TweakXL installed, V gets four arm cyberware slots, one for each arm type, free from the start. Install arms in them at any ripperdoc. If Cyberware-EX is installed, it manages the arm slots instead.
- **Swap with the "4" key.** With arms drawn, press 4 to step to the next set of equipped arm cyberware.
- **Swap with the weapon wheel.** The wheel's cyberware slot cycles through every equipped arm cyberware and bare fists, in both directions, using the wheel's previous/next keys. Select the slot to draw what it shows.
- **Swap with a controller button.** With arms drawn, tap D-pad Left to step to the next set of arm cyberware. Holding D-pad Left still opens the pocket radio. The button can be changed in Mod Settings. Needs Input Loader.
- **Arm memory.** Drawing your arms brings back the set you used last, not whatever is in the first slot. This carries across saves.
- **Gorilla Arms function like vanilla.** They take the place of bare fists, so the wheel offers Gorilla Arms rather than a separate fists entry while they are installed.
- **Third-person arms.** While your arms are put away, and while you fight with bare fists, the inventory, vehicles and mirrors show the arm cyberware you used last.
- **Glamdoc styles per arm type.** The Glamdoc can style every arm cyberware type you have equipped, in one visit. Each type keeps its own style and colours, saved with your game, and switching arms puts the matching style back.
- **Styles on every arm slot.** Mantis Blades, Monowire, Gorilla Arms and the Projectile Launch System wear their style in any arm slot: in hand, put away, in photo mode, on the inventory screen and in the Glamdoc preview, the style's own fingernails included. The game styles them itself, through the small plugin that comes with the mod (Simple Arm Swapper Native, see below). This includes the MaxTac Mantis Blades and arms built on them.
- **Projectile Launch System styles beside melee arms.** The launcher keeps its own Glamdoc style and colours next to Mantis Blades, Monowire or Gorilla Arms, and shows them when fired.
- **Nail items under Gorilla Arms.** Nails worn in Equipment-EX's fingernail slots are hidden while V wears Gorilla Arms, which cover V's hands, and come back with other arms.

## Styling several arm types in the Glamdoc

1. Open the Glamdoc. It opens on the arms you used last.
2. Pick a style and colours, then press **F** to buy and apply it. With more than one melee arm type equipped, the menu stays open.
3. Use the arm type tabs at the top (Mantis Blades, Monowire, Gorilla Arms) to switch to your other arms. V switches to those arms, and the preview follows. The Projectile Launch System tab styles the launcher while V keeps her melee arms; the preview shows the launcher.
4. Style those too, then press **F** again to apply and close.

Buying a style or switching arm type locks in what you have done so far, so leaving with Back only undoes changes made after that.

## Known limitations

- **If an arm looks off,** for example right after removing a style or changing cyberware at a ripperdoc, save and reload once. That clears most visual hiccups. If it doesn't, please report it with a screenshot (and a log with Debug Logging on, if you can).
- **Style nails.** Many Mantis Blade and Monowire styles come with their own coloured fingernails, which replace V's own nails as in the base game. If you plan to remove arm cyberware that has such a style, remove its Glamdoc style first: otherwise the nail choice in the character editor can stay locked after the arms are gone. If that has already happened, installing the same arms again, removing their style in the Glamdoc and then removing the arms should free the nail choice.
- **Removing the mod or adding Cyberware-EX later.** Remove arms from the second, third and fourth arm slots at a ripperdoc first. Without the extra slots, cyberware left in them can go missing from V's equipment.
- **Manicures and the Monowire.** Some manicure items (such as luvwich's) hide part of the Monowire's arms to make room for their nails. On the plain Monowire that part is the fingernails, but on some styles (such as Mox) it includes a plate on the arm, which then doesn't show. Take the manicure off for the full style.
- **Game updates.** Simple Arm Swapper Native only runs on the game version it was made for (Cyberpunk 2077 2.5). After a game update, arms outside the first arm slot (and the launcher beside melee arms) show their plain look until the plugin is updated. Swapping and everything else keep working.
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

- [redscript](https://github.com/jac3km4/redscript) and [RED4ext](https://github.com/WopsS/RED4ext)
- [Codeware](https://github.com/psiberx/cp2077-codeware) - needed for Glamdoc styles on every arm slot (Simple Arm Swapper Native is found through it) and for the mod's translations
- [TweakXL](https://github.com/psiberx/cp2077-tweak-xl) - adds the extra arm slots. Without it you need another mod that adds arm slots.

Cyberware-EX is no longer needed. If you use it, Simple Arm Swapper adds no slots of its own and leaves the arm slots to Cyberware-EX: you then need a Cyberware-EX mode or slot configuration with at least two arm slots, as before. Arm slots added by other mods count towards the four, so slots are never added twice.

Optional:

- [Mod Settings](https://github.com/jackhumbert/mod_settings) - adds the options above to the in-game Mod Settings menu. Without it the defaults apply.
- [Input Loader](https://github.com/jackhumbert/cyberpunk2077-input-loader) - adds the controller swap button. Without it, swapping works with the 4 key and the weapon wheel as before.
- [Equipment-EX](https://github.com/psiberx/cp2077-equipment-ex) - only if you wear nail items in its fingernail slots; the mod hides them under Gorilla Arms. Nothing changes without it.

With only one arm cyberware equipped, the game behaves exactly as it does without the mod.

## Simple Arm Swapper Native

The zip includes a small RED4ext plugin, `SimpleArmSwapperNative.dll`. Without it, the game only shows a Glamdoc style on one type of arm cyberware at a time. The reason: every arm style also chooses the coloured fingernails that come with it, and all arm types share those fingernails. When the game checks whether a style fits, the fingernails of another arm type's style made the check fail, so the game skipped that style. The plugin makes the game leave the fingernails out of that one check. That is all it changes.

With the plugin, the mod no longer restyles arm pieces itself; it only tidies away pieces of other arm types that the game leaves on V after a style change. The plugin only works on Cyberpunk 2077 2.5 (RED4ext does not load it on other versions) and only with Codeware installed. If anything about the game looks different from what it expects, it stays off and the game behaves as without it: arms outside the first arm slot show their plain look. Its source is in the `native` folder of this repository.

## Installation

Install the release zip with a mod manager such as Vortex, or copy its `r6` and `red4ext` folders into your Cyberpunk 2077 folder. The files end up here:

```
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
Cyberpunk 2077/r6/scripts/simple_arm_swapper/SimpleArmSwapperArmSlots.reds
Cyberpunk 2077/r6/input/SimpleArmSwapper.xml
Cyberpunk 2077/red4ext/plugins/SimpleArmSwapperNative/SimpleArmSwapperNative.dll
```

If you install by hand over 2.7.1 or older, you can delete `r6/scripts/simple_arm_swapper/SimpleArmSwapperStyleData.reds`; 3.0.0 no longer uses it (left in place it does no harm). Mod managers remove it for you.

If you are updating from 1.x, delete the old `r6/scripts/SimpleArmSwapper.reds` first. Having both copies installed will stop the game's scripts from compiling.

## Translating

The mod's on-screen text goes through Codeware's localization system, with English as the fallback. To add a language, copy `SimpleArmSwapperLanguageEnglish` at the bottom of the script into a new class, translate the second string of each line, and return it for your language from `SimpleArmSwapperLocalizationProvider.GetPackage`. Without Codeware the English text is used. The Mod Settings page is in English only.

## For mod authors

Other scripts can check that Simple Arm Swapper is installed with `@if(ModuleExists("SimpleArmSwapperMod"))`. The module also provides `Version()`, which returns the version as a string.

Mods that paint their own arm colours: to keep each arm type's style and colours, Simple Arm Swapper sets the arm colours itself with `CyberwareCustomizationSystem.SetCustomizationParameters` (after a swap, about 12 seconds after a save loads, after the Glamdoc closes, when V's top changes, and when the Projectile Launch System is drawn or put away). Right after each of these it calls `CyberwareCustomizationSystem.ArmSwapperColoursPainted(why: CName, armsType: Int32)`, so your mod can paint its colours again. From CET: `ObserveAfter('CyberwareCustomizationSystem', 'ArmSwapperColoursPainted', function(self, why, armsType) ... end)`; from redscript, wrap the method. `why` is one of `load`, `swap`, `noStyle`, `glamdocClosed`, `topChanged`, `styleChanged`, `launcherOut`, `launcherAway` or `styleKept`. `armsType` is the arm cyberware the colours are for, so a mod can keep colours per arm type: `0` Projectile Launch System (while it is out), `1` Mantis Blades, `2` Monowire, `3` Gorilla Arms, `-1` none. Since 3.0.0 the game styles the arms itself and the style piece table is gone; `ArmSwapperStylePiece`, `ArmSwapperStylePieceNew` and `SimpleArmSwapperStyleMemory.ArmSwapperStylePieces()` are kept so mods built against older versions still compile, but the table is always empty.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits

I built it with Claude (the AI).

## License

Released under the [MIT License](LICENSE).
