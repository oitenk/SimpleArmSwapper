@echo off
rem Builds SimpleArmSwapperNative.dll with Visual Studio 2026's compiler and puts it in the mod's
rem red4ext\plugins\SimpleArmSwapperNative folder. Uses the RED4ext SDK as headers only (no CMake).
rem SDK location: set RED4EXT_SDK, or it defaults to the clone in _archive\arm-style-probe\deps.
setlocal
set "VS=C:\Program Files\Microsoft Visual Studio\18\Community"
call "%VS%\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
cd /d "%~dp0"
if "%RED4EXT_SDK%"=="" set "RED4EXT_SDK=%~dp0..\_archive\arm-style-probe\deps\RED4ext.SDK"
if not exist build mkdir build
cl /nologo /std:c++20 /O2 /Zi /MT /EHsc /W4 /DWIN32_LEAN_AND_MEAN /DNOMINMAX ^
   /I "%RED4EXT_SDK%\include" ^
   src\Main.cpp /Fobuild\ /Fdbuild\ /LD /Febuild\SimpleArmSwapperNative.dll ^
   /link user32.lib /DEBUG /INCREMENTAL:NO /OPT:REF /OPT:ICF /PDB:build\SimpleArmSwapperNative.pdb || exit /b 1
if not exist ..\red4ext\plugins\SimpleArmSwapperNative mkdir ..\red4ext\plugins\SimpleArmSwapperNative
copy /y build\SimpleArmSwapperNative.dll ..\red4ext\plugins\SimpleArmSwapperNative\ >nul || exit /b 1
echo Built red4ext\plugins\SimpleArmSwapperNative\SimpleArmSwapperNative.dll
