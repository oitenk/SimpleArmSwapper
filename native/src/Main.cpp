// Simple Arm Swapper Native: lets the game style every arm cyberware type itself.
//
// Each arm style switcher (mantis, monowire, strongarms, launcher) claims a list of customization slots. When the
// game checks which of the switcher's options matches the pieces currently selected in those slots (0x142D8E118),
// the shared "nails_color" slot often holds another arm type's painted nails. Then no option matches, the switcher
// goes inactive, and that arm type ignores its Glamdoc style. While this one function runs for an arm switcher, the
// trailing "nails_color" entries of its slot list are hidden (the list's size is lowered and restored right after),
// so only the switcher's own slots decide the match.
//
// Game 2.50 only (RED4ext does not load it on other versions). If anything looks different from 2.50, the plugin
// does nothing and the game and Simple Arm Swapper behave as without it.
// Background: _archive\notes-native-arm-styling-re.md, sections 13-21.

#include <RED4ext/RED4ext.hpp>

#include <Windows.h>

#include <cstdint>
#include <cstring>
#include <mutex>

namespace
{
const RED4ext::v1::Sdk* gSdk = nullptr;
RED4ext::v1::PluginHandle gHandle = nullptr;

constexpr int32_t kVersion = 100; // 1.0.0, returned to scripts

// Address-file hash of the switcher match function and its first bytes in game 2.50 (exe 3.0.88.46235)
constexpr uint32_t kMatchHash = 4096686598u;
constexpr uint8_t kMatchBytes[16] = {0x48, 0x8B, 0xC4, 0x48, 0x89, 0x58, 0x18, 0x4C,
                                     0x89, 0x48, 0x20, 0x89, 0x50, 0x10, 0x48, 0x89};

// Addresses the SDK itself resolves to register the script function. Checked up front, because the SDK ends the
// game when one is missing.
constexpr uint32_t kSdkHashes[] = {
    RED4ext::Detail::AddressHashes::CRTTISystem_Get,        RED4ext::Detail::AddressHashes::CGlobalFunction_ctor,
    RED4ext::Detail::AddressHashes::Memory_Vault,           RED4ext::Detail::AddressHashes::Memory_Vault_Alloc,
    RED4ext::Detail::AddressHashes::Memory_Vault_AllocAligned, RED4ext::Detail::AddressHashes::Memory_Vault_Free,
    RED4ext::Detail::AddressHashes::Memory_Vault_Unk1,      RED4ext::Detail::AddressHashes::Memory_PoolStorage_OOM,
};

// Switcher definition layout (game 2.50): name at +0x40, slot names DynArray<CName> at +0xC0 (data pointer,
// capacity at +0xC8, size at +0xCC), options DynArray at +0xD0 (size at +0xDC).
constexpr size_t kDefName = 0x40;
constexpr size_t kDefSlotsData = 0xC0;
constexpr size_t kDefSlotsCapacity = 0xC8;
constexpr size_t kDefSlotsSize = 0xCC;
// The handle passed in points at the switcher option; its definition pointer is at +0x40
constexpr size_t kOptionDef = 0x40;
constexpr uint32_t kMaxSlots = 64;

struct RawHandle
{
    void* instance;
    void* refCount;
};

using SwitcherMatch_t = uint32_t (*)(void* aSystem, uint64_t aType, RawHandle* aEntry, uint64_t a4, uint64_t a5,
                                     uint64_t a6);
using ResolveAddress_t = uintptr_t (*)(uint32_t);

SwitcherMatch_t gMatchOrig = nullptr;
void* gMatchTarget = nullptr;
bool gHooked = false;
bool gRegister = false; // register the script function (only once the hook is in)

uint64_t gNails = 0;
uint64_t gArmSwitchers[4] = {0, 0, 0, 0};

// One call at a time edits a slot list. Recursive, in case the game ever matches again from inside the call.
std::recursive_mutex gMatchMutex;

// Only read through values that look like heap or image pointers. Bad reads are not caught safely in the game
// process (another crash handler sees them first), so this check is what keeps reads safe.
bool Plausible(uint64_t aValue)
{
    return aValue >= 0x10000ull && aValue < 0x00007FFFFFFF0000ull && (aValue & 7) == 0;
}

bool ReadU64(uint64_t aAddress, uint64_t* aOut)
{
    if (!Plausible(aAddress))
    {
        return false;
    }
    std::memcpy(aOut, reinterpret_cast<const void*>(aAddress), sizeof(uint64_t));
    return true;
}

bool IsArmSwitcher(uint64_t aName)
{
    for (auto hash : gArmSwitchers)
    {
        if (hash == aName)
        {
            return true;
        }
    }
    return false;
}

// The arm switcher definition behind this option, or 0 for anything else
uint64_t ArmSwitcherDefinition(RawHandle* aEntry)
{
    uint64_t option = 0;
    uint64_t definition = 0;
    uint64_t name = 0;
    if (!ReadU64(reinterpret_cast<uint64_t>(aEntry), &option) || !ReadU64(option + kOptionDef, &definition) ||
        !ReadU64(definition + kDefName, &name) || !IsArmSwitcher(name))
    {
        return 0;
    }
    return definition;
}

// Simple Arm Swapper finds this plugin, and tidies the pieces the native styling leaves behind, through Codeware.
// Without Codeware the fix stays off, so the game never gets native styling without that tidying.
bool CodewareLoaded()
{
    static const bool loaded = GetModuleHandleW(L"Codeware.dll") != nullptr;
    return loaded;
}

uint32_t SwitcherMatchDetour(void* aSystem, uint64_t aType, RawHandle* aEntry, uint64_t a4, uint64_t a5, uint64_t a6)
{
    if (!CodewareLoaded())
    {
        return gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    }
    uint64_t definition = ArmSwitcherDefinition(aEntry);
    if (definition == 0)
    {
        return gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    }

    std::scoped_lock lock(gMatchMutex);

    uint64_t data = 0;
    uint64_t sizes = 0;
    if (!ReadU64(definition + kDefSlotsData, &data) || !ReadU64(definition + kDefSlotsCapacity, &sizes) ||
        !Plausible(data))
    {
        return gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    }
    auto capacity = static_cast<uint32_t>(sizes & 0xFFFFFFFFull);
    auto count = static_cast<uint32_t>(sizes >> 32);
    if (count == 0 || count > kMaxSlots || capacity < count)
    {
        return gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    }

    // Count the "nails_color" entries at the end of the list
    uint32_t trailing = 0;
    while (trailing < count)
    {
        uint64_t slot = 0;
        if (!ReadU64(data + static_cast<uint64_t>(count - 1 - trailing) * 8, &slot) || slot != gNails)
        {
            break;
        }
        ++trailing;
    }
    // Nothing to hide, or nothing would be left to match
    if (trailing == 0 || trailing >= count)
    {
        return gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    }

    auto* sizeField = reinterpret_cast<volatile uint32_t*>(definition + kDefSlotsSize);
    *sizeField = count - trailing;
    uint32_t result = gMatchOrig(aSystem, aType, aEntry, a4, a5, a6);
    *sizeField = count;
    return result;
}

// Script function: SimpleArmSwapperNativeVersion() -> Int32. Only registered while the fix is in place.
void NativeVersionFunc(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, int32_t* aOut, int64_t a4)
{
    RED4EXT_UNUSED_PARAMETER(aContext);
    RED4EXT_UNUSED_PARAMETER(a4);
    aFrame->code++; // skip ParamEnd
    if (aOut)
    {
        *aOut = (gHooked && CodewareLoaded()) ? kVersion : 0;
    }
}

void RegisterTypes()
{
}

void PostRegisterTypes()
{
    if (!gRegister)
    {
        return;
    }
    auto rtti = RED4ext::CRTTISystem::Get();
    if (!rtti)
    {
        return;
    }
    auto func = RED4ext::CGlobalFunction::Create("SimpleArmSwapperNativeVersion", "SimpleArmSwapperNativeVersion",
                                                 &NativeVersionFunc);
    if (!func)
    {
        return;
    }
    func->flags = {.isNative = true, .isStatic = true};
    func->SetReturnType("Int32");
    rtti->RegisterFunction(func);
}

void Install()
{
    gNails = RED4ext::CName("nails_color").hash;
    gArmSwitchers[0] = RED4ext::CName("mantis").hash;
    gArmSwitchers[1] = RED4ext::CName("monowire").hash;
    gArmSwitchers[2] = RED4ext::CName("strongarms").hash;
    gArmSwitchers[3] = RED4ext::CName("launcher").hash;

    HMODULE red4ext = GetModuleHandleW(L"RED4ext.dll");
    auto resolve =
        red4ext ? reinterpret_cast<ResolveAddress_t>(GetProcAddress(red4ext, "RED4ext_ResolveAddress")) : nullptr;
    if (!resolve)
    {
        gSdk->logger->Error(gHandle, "RED4ext's address resolver was not found. Staying off; the game is unchanged.");
        return;
    }

    for (auto hash : kSdkHashes)
    {
        if (resolve(hash) == 0)
        {
            gSdk->logger->ErrorF(gHandle, "Game address %u not found. Staying off; the game is unchanged.", hash);
            return;
        }
    }

    uintptr_t match = resolve(kMatchHash);
    if (match == 0)
    {
        gSdk->logger->Error(gHandle, "Arm switcher match not found in this game version. Staying off.");
        return;
    }
    if (std::memcmp(reinterpret_cast<const void*>(match), kMatchBytes, sizeof(kMatchBytes)) != 0)
    {
        gSdk->logger->Error(gHandle, "Arm switcher match differs from game 2.50. Staying off; the game is unchanged.");
        return;
    }

    gMatchTarget = reinterpret_cast<void*>(match);
    gHooked = gSdk->hooking->Attach(gHandle, gMatchTarget, reinterpret_cast<void*>(&SwitcherMatchDetour),
                                    reinterpret_cast<void**>(&gMatchOrig));
    if (!gHooked)
    {
        gSdk->logger->Error(gHandle, "Could not hook the arm switcher match. Staying off; the game is unchanged.");
        return;
    }

    gRegister = true;
    auto rtti = RED4ext::CRTTISystem::Get();
    rtti->AddRegisterCallback(RegisterTypes);
    rtti->AddPostRegisterCallback(PostRegisterTypes);
    gSdk->logger->Info(gHandle, "Ready: arm style switchers ignore the shared nails slot when matching.");
}

void Uninstall()
{
    if (gHooked)
    {
        gSdk->hooking->Detach(gHandle, gMatchTarget);
        gHooked = false;
    }
}
} // namespace

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle aHandle, RED4ext::v1::EMainReason aReason,
                                        const RED4ext::v1::Sdk* aSdk)
{
    switch (aReason)
    {
    case RED4ext::v1::EMainReason::Load:
        gHandle = aHandle;
        gSdk = aSdk;
        Install();
        break;
    case RED4ext::v1::EMainReason::Unload:
        Uninstall();
        break;
    }
    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* aInfo)
{
    aInfo->name = L"SimpleArmSwapperNative";
    aInfo->author = L"oitenk";
    aInfo->version = RED4EXT_V1_SEMVER(1, 0, 0);
    // Only game 2.50: RED4ext won't load it on any other version
    aInfo->runtime = RED4EXT_V1_RUNTIME_VERSION_2_50;
    aInfo->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
