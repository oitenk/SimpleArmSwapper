# Changelog

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
