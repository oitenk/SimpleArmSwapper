# Changelog

## 3.0.2

Fixed a crash when leaving a ripperdoc after changing cyberware or styles. Leaving the chair sent the mod several "set the arm styles" requests within a second, while the game was still rebuilding V, and the mod handled each one on its own. Requests that arrive close together now join up, and the styles are set once, a few seconds after things have settled.

NEW! Mods that paint their own arm colours can now hear when Simple Arm Swapper sets the colours (after a swap, a save load, the Glamdoc, a ripperdoc or the Projectile Launch System), together with the arm type, so they can put theirs back on top. Details for mod authors are in the README.

## 3.0.1

The Nexus download now includes Simple Arm Swapper Native, the small plugin that lets every arm type keep its Glamdoc style. It was missing from the 3.0.0 file on Nexus, so arms outside the first arm slot (often the Projectile Launch System) showed their plain look. Update and your styles show on all your arms. Thank you to the player who reported it and helped track it down!

## 3.0.0

NEW! Glamdoc styles now show on all your arm cyberware, in every arm slot. The game does the styling itself now, through a small plugin that comes with the mod.

Style nails (the coloured fingernails that come with a Glamdoc style) now show on Mantis Blades in every arm slot.

With nail items that hide part of the Monowire (such as luvwich's manicures), the Monowire now shows its full style in every arm slot.

Styles from other mods, such as Split Cyberarm Styles, now stay on when you swap arms, load a save or change your top.

Long sleeves now change the style of all your arm cyberware, not only the arms you hold.

The mod is much smaller and lighter.

Codeware is now required.

## 2.7.1

Hopefully fixed the game crashing when you swap arms quickly. Thank you to everyone who reported it and sent logs, they made this possible. The cause: every time you swapped, the mod asked the game to change your arm style while your arms were still coming out, and pressing fast stacked those requests until the game tripped over them. Now each arm type's style is set once, when a save loads, when you leave the Glamdoc, and after a ripperdoc visit, and a swap only changes the colours. Swaps are lighter as a result too.

Hopefully fixed a crash when flipping through arm tabs quickly in the Glamdoc. Same reason as above: each tab rebuilds the preview character, and new tabs were arriving before the last preview was ready. A tab now waits for the previous preview, then shows the last tab you picked, so you can click as fast as you like.

Swap presses now wait until your arms are fully out before the next swap goes through. You won't notice it at normal speed. It just stops a burst of presses from piling up.

Mods that recolour the Monowire's wires (such as qtuna's Monowire palette) now keep their colours when a Glamdoc style is applied. Before, the style swapped their wires back to its own.

Manicures and the Monowire: some manicure items (such as luvwich's) hide a small part of the Monowire's arms to make room for their nails. On the plain Monowire that part is the fingernails, but on many Monowire styles it's part of the arm itself. With both the manicure and the style changing the same arm parts at once, the game could crash. So when you wear one of those manicures, a Monowire outside the first arm slot keeps its plain arm shape, with its style's colours and wires. In the first arm slot, the game styles the Monowire itself, so it shows its style there. Take the manicure off and the style comes back. I know people love their nails, and I'd rather give you a slightly plainer Monowire than a crash. I'm still looking for a way to have both.

Arm pieces are now restyled with fewer reloads, which also makes swapping lighter.

Debug Logging now keeps up to 20000 lines per session, so a log covers a whole play session if you send me one.

## 2.7.0

NEW! Four arm cyberware slots without Cyberware-EX. With TweakXL installed, V gets four arm slots, one for each arm type, free from the start, in new and existing saves. Install arms in them at any ripperdoc. Cyberware-EX is no longer needed; if it is installed, it keeps managing the arm slots as before.

Fixed cosmetic arms and hands (such as KiasuBurger's) coming off under Gorilla Arms. They share Equipment-EX's fingernail slots with nail items; now only nail items are hidden under Gorilla Arms.

Fixed Mantis Blades and Monowire showing through cosmetic arms (such as KiasuBurger's), drawn and put away. Arm parts that another mod's item hides now stay hidden when Simple Arm Swapper applies a style. This also keeps nail items from mods like luvwich's manicures looking right on the Monowire.

Fixed female V's upper arms going missing on the photo mode and inventory characters with Mantis Blades put away, when the arm pieces come from another mod (such as Split Cyberarm Styles). The upper arms are now only swapped out when the game provides its photo mode upper arms to take their place.

Better compatibility with mods that add their own looks to arm cyberware meshes (such as Night City Glamdoc Colors). Simple Arm Swapper no longer changes those looks back to the plain style look, so their finishes stay on V's arms.

## 2.6.1

Fixed cosmetic arms and hands (such as KiasuBurger's) coming off under Gorilla Arms. They share Equipment-EX's fingernail slots with nail items; now only nail items are hidden under Gorilla Arms.

Fixed Mantis Blades and Monowire showing through cosmetic arms (such as KiasuBurger's), drawn and put away. Arm parts that another mod's item hides now stay hidden when Simple Arm Swapper applies a style. This also keeps nail items from mods like luvwich's manicures looking right on the Monowire.

Fixed female V's upper arms going missing on the photo mode and inventory characters with Mantis Blades put away, when the arm pieces come from another mod (such as Split Cyberarm Styles). The upper arms are now only swapped out when the game provides its photo mode upper arms to take their place.

Better compatibility with mods that add their own looks to arm cyberware meshes (such as Night City Glamdoc Colors). Simple Arm Swapper no longer changes those looks back to the plain style look, so their finishes stay on V's arms.

## 2.6.0

NEW! Projectile Launch System styles beside melee arms. The launcher keeps a Glamdoc style and colours of its own, even with Mantis Blades, Monowire or Gorilla Arms equipped. Open its tab in the Glamdoc to preview, buy and apply launcher styles without switching your melee arms. When fired, it shows its style and colours. The game holds one colour set for all arm cyberware, so melee arms on screen share the launcher's colours while it is out, and get their own back when it is put away. Needs Codeware.

NEW! Nail items worn in Equipment-EX's fingernail slots are hidden while V wears Gorilla Arms, drawn or put away, as the Gorilla Arms cover V's hands. They come back with any other arms. This can be turned off in Mod Settings.

Fixed V's put-away arms after firing the Projectile Launch System. They could come back as the arms in the first arm slot, without their style, instead of the arms used last.

## 2.5.0

NEW! Controller swap button. With arms drawn, tap D-pad Left to swap to the next arms, like the 4 key on keyboard. Holding D-pad Left still opens the pocket radio. The button can be changed in Mod Settings. Needs Input Loader; without it, everything works as before.

## 2.4.3

Fixed holstered Mantis Blade hands showing several styles on top of each other, as patches of different colours. Old copies of the hands kept coming back each time the blades were drawn and put away, more so after changing styles. A save reload cleared it; now it no longer builds up.

## 2.4.2

Fixed the Barghest Glamdoc style on Mantis Blades. On MaxTac-based Mantis Blades the mod replaced the Barghest look with the plain Mantis Blades, leaving bare arms, plain blades or a single styled hand, and in a later arm slot Mantis Blades showed their plain look. They now wear the Barghest look in any slot, in hand and put away, for both body types.

V's nail colour no longer shows on the chrome hands of the Barghest Mantis Blades.

Fixed the Barghest Glamdoc style on the Monowire when it sits in a later arm slot. It showed the plain Monowire; it now wears the Barghest look in hand, put away and in third person, for both body types.

Arm pieces that a style leaves out now come back when you switch to a style that uses them.

Fixed some styled arm pieces showing grey instead of V's skin tone (most visible on Kang Tao Mantis Blades put away). They now wear V's own skin tone, as the game shows them, for every skin tone.

Known base game issue: Kang Tao Mantis Blades show their colours when drawn but not when put away. This happens without Simple Arm Swapper too.

## 2.4.1

Possible fix for V's hair and beard showing in first person view with a weapon drawn. With Glamdoc Style Per Arm Type on, the mod switched off the MaxTac look of MaxTac-based Mantis Blades while a save was still loading, which could leave V's hair showing. It now waits a few seconds after a save loads. If you draw those blades in the first seconds after loading, they may show their MaxTac look briefly before your style returns. Every setup is different, so if you still see hair or a beard in first person, please let me know.

Fixed a light flicker on the left arm of styled Mantis Blades when drawing them. V's skin tone now stays on the left upper arm.

Debug Logging now also records V's head, hair and beard pieces, to help track down visual problems like this one.

## 2.4

Glamdoc styles now show on every melee arm you have equipped, not only on the arms in the first arm slot. Mantis Blades and Monowire in any slot wear their own style and colours in hand, put away, in photo mode, on the inventory screen and in the Glamdoc preview, for both body types. This part needs Codeware. Without it, arms outside the first slot show their plain look, as before.

MaxTac Mantis Blades, and arm cyberware built on them, now show their Glamdoc style in any slot, and go back to their MaxTac look when the style is removed, without leftover hands or nails. Swapping between MaxTac and regular Mantis Blades keeps each one's own look, and the MaxTac look no longer carries over to other arms.

Arms keep their style on motorcycles and in cars, in both camera views.

The holster key now draws your last used arms from any arm slot, instead of another weapon.

NEW! Bare fists show the arm cyberware you used last, the same way as when you put your arms away.

NEW! The Glamdoc preview shows the style you are previewing for every arm type, and follows each style as you pick it.

Pressing "4" to swap arms no longer unequips a quickhack slotted into the Monowire.

Changing or reordering cyberware at a ripperdoc no longer clears the saved style of arms that stay installed, or leaves overlapping arm parts.

Fixed styles on another arm type's Glamdoc tab sometimes not being selectable, when switching tabs while previewing a style or right after buying one.

Gorilla Arms keep being styled by the game itself, in any slot.

## 2.3.1

Projectile Launch System: it still works alongside multiple cyberarms, and fires as normal next to any of them. Its Glamdoc styles do not work while melee arms are also equipped: it shows its default look when fired, then V's arms go back to their own style. This is because the game holds one cyberarm style at a time. A Projectile Launch System on its own can be styled as in the base game.

NEW! Style every melee arm type in one Glamdoc visit. With more than one equipped, the Glamdoc's arm type tabs switch V to those arms, and the preview, current style and colours follow.

NEW! With more than one melee arm type equipped, buying a style keeps the Glamdoc open so the other arms can be styled too. The F key reads "Buy and apply (F again to close)": press it once to buy, and again to apply and close.

NEW! Buying a style or switching arm type locks in what you have done so far, so leaving with Back only undoes changes made after that.

NEW! Debug Logging option in Mod Settings, under Troubleshooting. Off by default.

NEW! The mod's on-screen text can be translated. It goes through Codeware's localization system when Codeware is installed, with English as the fallback.

Arm types you have never styled now show their plain look, instead of taking on another type's style, colours or a white finish.

Arms that come into V's hand always wear their own style, including when the game draws them again by itself after a menu closes.

Fixed two sets of arms showing after closing the Glamdoc with arms drawn.

Fixed some styles you already owned being applied switched off, which hid them and ignored their colours.

## 2.3

NEW! Third-person arms: while your arms are put away, the inventory, vehicles and mirrors show the arm cyberware you used last, instead of always the arms in the first slot.

NEW! Glamdoc styles per arm type: the Glamdoc can now style every arm cyberware type you have equipped, not only the one in the first slot. It opens on your last used arms, and its type tabs switch the preview to your other arms.

NEW! Each arm type keeps its own style and colours, saved with your game. Switching arms with the "4" key or the weapon wheel puts the matching style back.

NEW! Two Mod Settings options to turn these off: "Show Last Used Arms When Holstered" and "Glamdoc Style Per Arm Type". Both are on by default.

The style you already had is kept for its arm type. Arm types you have never styled look exactly as before.

## 2.2

Updated for Cyberpunk 2077 2.5. Checked against the 2.5 game scripts with the redscript version that ships for it.

Mod Settings is now optional. Without it the mod runs with the default behaviour (the weapon wheel starts on the next arms in line). With it, the option works as before.

Nothing about how swapping works was changed in this release. The Mod Settings option returns to its default once after updating, so set it again if you had turned it off. If the game's scripts fail to load after the 2.5 update, make sure every script mod you use, including this one's requirements, has a version for 2.5.

## 2.1

NEW! The script now declares a module, so other mods can detect Simple Arm Swapper.

No changes to how the mod behaves. The Mod Settings option may return to its default once after updating.

## 2.0.1

Internal tidying up. No changes to how the mod behaves.

## 2.0

NEW! Weapon wheel support: the cyberware slot cycles through all equipped arm cyberware and bare fists.

NEW! Arm memory: drawing arms recalls the last used set instead of always the first slot.

The "4" key now only cycles while arms are already drawn; otherwise it draws the last used set.

NEW! A Mod Settings option for whether the wheel starts on the next arms or the ones in hand.

Fixed Gorilla Arms appearing twice in the wheel rotation, which stopped it cycling in one direction.

Mod Settings is now required.

## 1.0

Initial release: cycle equipped arm cyberware with the "4" key.
