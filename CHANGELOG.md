# Changelog

## 2.2

- Updated for Cyberpunk 2077 2.5. Checked against the 2.5 game scripts with the redscript version that ships for it.
- Mod Settings is now optional. Without it the mod runs with the default behaviour (the weapon wheel starts on the next arms in line). With it, the option works as before.

Nothing about how swapping works was changed in this release. The Mod Settings option returns to its default once after updating, so set it again if you had turned it off. If the game's scripts fail to load after the 2.5 update, make sure every script mod you use, including this one's requirements, has a version for 2.5.

## 2.1

- The script now declares a module, so other mods can detect Simple Arm Swapper.
- No changes to how the mod behaves. The Mod Settings option may return to its default once after updating.

## 2.0.1

- Internal tidying up. No changes to how the mod behaves.

## 2.0

- Added weapon wheel support: the cyberware slot cycles through all equipped arm cyberware and bare fists.
- Added arm memory: drawing arms recalls the last used set instead of always the first slot.
- The "4" key now only cycles while arms are already drawn; otherwise it draws the last used set.
- Added a Mod Settings option for whether the wheel starts on the next arms or the ones in hand.
- Fixed Gorilla Arms appearing twice in the wheel rotation, which stopped it cycling in one direction.
- Mod Settings is now required.

## 1.0

- Initial release: cycle equipped arm cyberware with the "4" key.
