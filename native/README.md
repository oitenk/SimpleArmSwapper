# Simple Arm Swapper Native (source)

A RED4ext plugin for Cyberpunk 2077 2.50 that lets the game style every arm cyberware type itself.

It hooks one game function, the arm style switcher match (address-file hash 4096686598). For the arm switchers
(`mantis`, `monowire`, `strongarms`, `launcher`) it hides the trailing `nails_color` entries of the switcher's slot
list for that one call, so the shared nails slot no longer makes a switcher go inactive. It also registers the script
function `SimpleArmSwapperNativeVersion() -> Int32`, which Simple Arm Swapper reads through Codeware's reflection.

Safety: the address is resolved through RED4ext (a missing address turns the plugin off, it never ends the game), the
function's first bytes are checked against game 2.50, pointers are range-checked before every read, nothing is called
on unknown objects, and RED4ext only loads the plugin on game 2.50. The fix stays off without Codeware.

Build: `build.bat` (Visual Studio 2026, MSVC directly, RED4ext SDK headers only; set `RED4EXT_SDK` to the SDK folder).
The DLL is copied to `red4ext\plugins\SimpleArmSwapperNative\`.
