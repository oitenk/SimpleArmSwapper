// r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
// Simple Arm Swapper v3.1.0

// Other mods can detect this one with @if(ModuleExists("SimpleArmSwapperMod"))
module SimpleArmSwapperMod

@if(ModuleExists("Codeware.Localization"))
import Codeware.Localization.*

@if(ModuleExists("EquipmentEx"))
import EquipmentEx.OutfitSystem

public func Version() -> String = "3.1.0"

// Which version of a Glamdoc style V's arms wear: the one for short or for long sleeves
enum ArmSwapperSleeveVersion {
    Automatic = 0,
    AlwaysShort = 1,
    AlwaysLong = 2
}

// Options shown in the Mod Settings menu. Mod Settings is optional: when it is installed it
// writes the saved choice into this class's default values (at startup and whenever the
// option changes), so a freshly created instance always holds the current setting. Without
// Mod Settings the defaults below are used.
public class SimpleArmSwapperSettings {

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Weapon Wheel Shows Next Arms")
    @runtimeProperty("ModSettings.description", "While arm cyberware is drawn, the weapon wheel's cyberware slot starts on the next arms in line, so selecting it swaps right away. Turn off to have it start on the arms you are holding.")
    public let wheelShowsNextArms: Bool = true;

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Show Last Used Arms When Holstered")
    @runtimeProperty("ModSettings.description", "While your arms are put away, show the arm cyberware you used last in third person: the inventory, vehicles and mirrors. Turn off to leave this to the game and your other mods.")
    public let showLastUsedArmsHolstered: Bool = true;

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Glamdoc Style Per Arm Type")
    @runtimeProperty("ModSettings.description", "Let the Glamdoc style every arm cyberware type you have equipped, and keep a separate style for each type. Switching arms puts the matching style back. Turn off to leave styling to the game.")
    public let stylePerArmType: Bool = true;

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Hide Nail Items Under Gorilla Arms")
    @runtimeProperty("ModSettings.description", "Gorilla Arms cover V's hands, so nail items worn in Equipment-EX's fingernail slots are hidden while V wears them, drawn or put away. Turn off to always show them.")
    public let hideNailItemsUnderGorillaArms: Bool = true;

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Sleeve Version Of Styles")
    @runtimeProperty("ModSettings.description", "Some Glamdoc styles have a shorter version that fits under long sleeves. Automatic picks it from the top V wears, including the clothes of an active Equipment-EX outfit. Clothes from mods are not always marked as long-sleeved: pick Always Short or Always Long to decide yourself.")
    @runtimeProperty("ModSettings.displayValues.Automatic", "Automatic")
    @runtimeProperty("ModSettings.displayValues.AlwaysShort", "Always Short")
    @runtimeProperty("ModSettings.displayValues.AlwaysLong", "Always Long")
    public let sleeveVersion: ArmSwapperSleeveVersion = ArmSwapperSleeveVersion.Automatic;

    // The name must match overridableUI in r6/input/SimpleArmSwapper.xml
    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Controller Swap Button")
    @runtimeProperty("ModSettings.description", "With arms drawn, tap this controller button to swap to the next arms. Holding it does what the button normally does on hold. Needs Input Loader.")
    public let armSwapPadButton: EInputKey = EInputKey.IK_Pad_DigitLeft;

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.category", "Troubleshooting")
    @runtimeProperty("ModSettings.displayName", "Debug Logging")
    @runtimeProperty("ModSettings.description", "Writes what the mod does with arms and Glamdoc styles to the Cyber Engine Tweaks game log (up to 20000 lines per session). Leave off unless asked for a log.")
    public let debugLogging: Bool = false;
}

// --- Debug log (off by default) ---

@addField(PlayerPuppet)
public let m_armSwapperLogLines: Int32;

public func ArmSwapperLog(game: GameInstance, message: String) {
    if !(new SimpleArmSwapperSettings()).debugLogging { return; }
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) || player.m_armSwapperLogLines >= 20000 { return; }
    player.m_armSwapperLogLines += 1;
    FTLog("[SimpleArmSwapper] " + message);
}

public func ArmSwapperName(item: ItemID) -> String {
    if !ItemID.IsValid(item) { return "none"; }
    return TDBID.ToStringDEBUG(ItemID.GetTDBID(item));
}

public func ArmSwapperSlotName(owner: ref<GameObject>, slot: TweakDBID) -> String {
    if !IsDefined(owner) { return "no-owner"; }
    let itemObject: ref<ItemObject> = GameInstance.GetTransactionSystem(owner.GetGame()).GetItemInSlot(owner, slot);
    if !IsDefined(itemObject) { return "empty"; }
    return ArmSwapperName(itemObject.GetItemID());
}

public func ArmSwapperStyleDataText(data: CyberwareCustomizationPersistentData) -> String {
    return "style=" + ArmSwapperName(data.customizationItemID) + " switcher=" + NameToString(data.switcherName)
        + "/" + IntToString(Cast<Int32>(data.switcherIndex)) + " enabled=" + BoolToString(data.enabled)
        + " colours=" + IntToString(Cast<Int32>(data.primaryColorIndex)) + "," + IntToString(Cast<Int32>(data.secondaryColorIndex))
        + " maxTac=" + BoolToString(data.hasMaxTacApperanceEquipped)
        + " brand=" + (TDBID.IsValid(data.brandDataID) ? TDBID.ToStringDEBUG(data.brandDataID) : "none");
}

// A colour as the game will paint it, for the log
public func ArmSwapperColorText(c: Color) -> String {
    return IntToString(Cast<Int32>(c.Red)) + "/" + IntToString(Cast<Int32>(c.Green)) + "/" + IntToString(Cast<Int32>(c.Blue));
}

// Every arm cyberware slot in order, with the active one marked
public func ArmSwapperArmSlotsText(player: ref<GameObject>) -> String {
    if !IsDefined(player) { return "no player"; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return "no equipment data"; }
    let areaIndex: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex < 0 { return "no arm area"; }
    let area: SEquipArea = eqData.m_equipment.equipAreas[areaIndex];
    let text: String = "arm slots (active " + IntToString(area.activeIndex) + "):";
    let i: Int32 = 0;
    while i < ArraySize(area.equipSlots) {
        text += " " + IntToString(i) + "=" + ArmSwapperName(area.equipSlots[i].itemID);
        i += 1;
    }
    return text;
}

// One line describing V's arms: active arms, what is in hand, the arm slot and the style slot
public func ArmSwapperArmsState(player: ref<GameObject>) -> String {
    if !IsDefined(player) { return "no player"; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return "no equipment data"; }
    return "active=" + ArmSwapperName(eqData.GetActiveMeleeWare())
        + " hand=" + ArmSwapperSlotName(player, t"AttachmentSlots.WeaponRight")
        + " armSlot=" + ArmSwapperSlotName(player, t"AttachmentSlots.RightArm")
        + " styleSlot=" + ArmSwapperName(eqData.GetActiveItem(gamedataEquipmentArea.ArmsCWStyle));
}

// Controller swap button (the CycleArmCyberware action from r6/input/SimpleArmSwapper.xml,
// which needs Input Loader). A tap swaps; a hold is left to the button's own hold action.
public class ArmSwapperPadListener {
    public let player: wref<PlayerPuppet>;
    private let heldLong: Bool;

    protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
        if !Equals(ListenerAction.GetName(action), n"CycleArmCyberware") { return false; }
        let actionType: gameinputActionType = ListenerAction.GetType(action);

        if Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
            this.heldLong = false;
        } else if Equals(actionType, gameinputActionType.BUTTON_HOLD_COMPLETE) {
            this.heldLong = true;
        } else if Equals(actionType, gameinputActionType.BUTTON_RELEASED) && !this.heldLong {
            let player: ref<PlayerPuppet> = this.player;
            if !IsDefined(player) { return false; }
            ArmSwapperLog(player.GetGame(), "controller swap button tapped");
            let swapper: ref<SimpleArmSwapper> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"SimpleArmSwapperMod.SimpleArmSwapper") as SimpleArmSwapper;
            if IsDefined(swapper) {
                swapper.SwapToNextArms(player);
            }
        }
        return false;
    }
}

// Mod Settings (optional) tells the mod when one of its options changes
@if(ModuleExists("ModSettingsModule"))
public func ArmSwapperListenToSettings(listener: ref<IScriptable>, listen: Bool) {
    if listen {
        ModSettings.RegisterListenerToModifications(listener);
    } else {
        ModSettings.UnregisterListenerToModifications(listener);
    }
}

@if(!ModuleExists("ModSettingsModule"))
public func ArmSwapperListenToSettings(listener: ref<IScriptable>, listen: Bool) {}

public class SimpleArmSwapper extends ScriptableSystem {

    private let m_padListener: ref<ArmSwapperPadListener>;

    private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
        let player: ref<PlayerPuppet> = request.owner as PlayerPuppet;
        if !IsDefined(player) { return; }
        this.m_padListener = new ArmSwapperPadListener();
        this.m_padListener.player = player;
        player.RegisterInputListener(this.m_padListener, n"CycleArmCyberware");
    }

    private func OnAttach() -> Void {
        ArmSwapperListenToSettings(this, true);
    }

    private func OnDetach() -> Void {
        ArmSwapperListenToSettings(this, false);
    }

    // Mod Settings calls this when an option was changed and applied. A new Sleeve Version shows
    // right away: every arm type's style is set again for it.
    public cb func OnModVariableChangeAccepted(groupPath: CName, varName: CName) -> Void {
        if !Equals(varName, n"sleeveVersion") || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
        let game: GameInstance = this.GetGameInstance();
        ArmSwapperLog(game, "Sleeve Version changed in Mod Settings, setting the arm styles again");
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) { system.ArmSwapperSetAllSwitchersLater("top changed", 0.5); }
    }

    // Returns every equipped arm cyberware carrying the 'Meleeware' tag, in slot order
    public func GetMeleewareItems(player: ref<GameObject>) -> array<ItemID> {
        let meleewareItems: array<ItemID>;
        if !IsDefined(player) { return meleewareItems; }

        let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if !IsDefined(eqData) { return meleewareItems; }

        let areaIndex: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
        if areaIndex < 0 { return meleewareItems; }

        // Read the slots directly: the game's own slot count skips slots it considers locked,
        // which hides the extra arm slots added by Cyberware-EX
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
        let equipArea: SEquipArea = eqData.m_equipment.equipAreas[areaIndex];
        let i: Int32 = 0;

        while i < ArraySize(equipArea.equipSlots) {
            let item: ItemID = equipArea.equipSlots[i].itemID;
            if ItemID.IsValid(item) && !ArrayContains(meleewareItems, item) {
                let itemData: ref<gameItemData> = ts.GetItemData(player, item);
                if IsDefined(itemData) && itemData.HasTag(n"Meleeware") {
                    ArrayPush(meleewareItems, item);
                }
            }
            i += 1;
        }

        return meleewareItems;
    }

    public func SwapToNextArms(player: ref<PlayerPuppet>) {
        if !IsDefined(player) { return; }

        let eqSystem: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
        let eqData: ref<EquipmentSystemPlayerData> = eqSystem.GetPlayerData(player);
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());

        let areaIndex: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
        if areaIndex < 0 { return; }

        let equipArea: SEquipArea = eqData.m_equipment.equipAreas[areaIndex];
        let totalSlots: Int32 = ArraySize(equipArea.equipSlots);
        if totalSlots <= 0 { return; }

        let meleewareItems: array<ItemID>;
        let slotIndices: array<Int32>;
        let i: Int32 = 0;

        // Collect unique items with the 'Meleeware' tag and track their exact slot indices
        while i < totalSlots {
            let item: ItemID = equipArea.equipSlots[i].itemID;
            if ItemID.IsValid(item) {
                let itemData: ref<gameItemData> = ts.GetItemData(player, item);
                if IsDefined(itemData) && itemData.HasTag(n"Meleeware") {
                    // Prevent pushing exact duplicate IDs if the inventory glitches
                    if !ArrayContains(meleewareItems, item) {
                        ArrayPush(meleewareItems, item);
                        ArrayPush(slotIndices, i);
                    }
                }
            }
            i += 1;
        }

        let count: Int32 = ArraySize(meleewareItems);
        let heldObject: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
        ArmSwapperLog(player.GetGame(), "4 key: " + IntToString(count) + " melee arms, held=" + (IsDefined(heldObject) ? ArmSwapperName(heldObject.GetItemID()) : "empty")
            + ", " + ArmSwapperArmSlotsText(player) + ". " + ArmSwapperArmsState(player));
        if count < 1 { return; }

        // A swap restyles the arms while they load in. Pressing again before they are in hand
        // stacked those restyles and could freeze or crash the game, so wait for them
        let now: Float = ArmSwapperNow(player.GetGame());
        if player.m_armSwapperSwapSince > 0.0 && now - player.m_armSwapperSwapSince < 1.5 {
            ArmSwapperLog(player.GetGame(), "4 key ignored: the last swap is still settling ("
                + FloatToStringPrec(now - player.m_armSwapperSwapSince, 2) + "s)");
            return;
        }
        // The arms are in hand, but their first styling passes are still running
        if now < player.m_armSwapperSettledAt {
            ArmSwapperLog(player.GetGame(), "4 key ignored: the last swap's arms are still being styled");
            return;
        }

        // Only cycle while arms are already out. Otherwise the game draws the
        // remembered arms on its own (see the GetActiveMeleeWare wrap below)
        let holdingArms: Bool = IsDefined(heldObject) && ArrayContains(meleewareItems, heldObject.GetItemID());
        if !holdingArms {
            // The game draws the arms from this press: wait for them too
            player.m_armSwapperSwapSince = now;
            player.m_armSwapperSwapGen += 1;
            return;
        }
        if count <= 1 { return; }

        // Without an active weapon the game is still busy with the last draw. Swapping then only
        // changed the active arms without drawing them, and let the next press through at once.
        let activeWeapon: ItemID = eqData.GetSlotActiveWeapon();
        if !ItemID.IsValid(activeWeapon) {
            ArmSwapperLog(player.GetGame(), "4 key ignored: the game is still drawing the arms");
            return;
        }

        // Fetch currently active arm item
        let currentActiveID: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.ArmsCW);
        let currentIndex: Int32 = -1;
        i = 0;

        while i < count {
            if meleewareItems[i] == currentActiveID {
                currentIndex = i;
                break;
            }
            i += 1;
        }

        if currentIndex < 0 {
            currentIndex = 0;
        }

        // Cycle to the next item safely using modulo
        let nextIndex: Int32 = (currentIndex + 1) % count;
        let nextArmsID: ItemID = meleewareItems[nextIndex];
        let targetSlotIndex: Int32 = slotIndices[nextIndex];
        ArmSwapperLog(player.GetGame(), "4 key: from " + ArmSwapperName(currentActiveID) + " to " + ArmSwapperName(nextArmsID) + " (slot " + IntToString(targetSlotIndex) + ")");

        // The next arms are already installed in their slot, so only mark them as the active arms.
        // Equipping them again re-installs the cyberware, which can drop parts slotted into it
        // (such as a quickhack on the Monowire).
        eqData.ArmSwapperMakeActiveArms(nextArmsID);

        // Draw them, and take no further swap until they are in hand
        player.m_armSwapperSwapSince = now;
        player.m_armSwapperSwapGen += 1;
        eqData.DrawItem(nextArmsID, gameEquipAnimationType.Default);
    }
}

// The game looks items up in an equipment area through a list that leaves out slots it counts as
// locked, which includes the extra arm slots added by Cyberware-EX. Drawing the last used weapon
// (the holster key) therefore missed arms in those slots and drew an older weapon instead. Arms
// in any arm slot are found here.
@wrapMethod(EquipmentSystemPlayerData)
public final func FindItemInEquipArea(item: ItemID, area: gamedataEquipmentArea) -> ItemID {
    let found: ItemID = wrappedMethod(item, area);
    if ItemID.IsValid(found) || !ItemID.IsValid(item) || NotEquals(area, gamedataEquipmentArea.ArmsCW) { return found; }
    let areaIndex: Int32 = this.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex < 0 { return found; }
    let i: Int32 = 0;
    while i < ArraySize(this.m_equipment.equipAreas[areaIndex].equipSlots) {
        if this.m_equipment.equipAreas[areaIndex].equipSlots[i].itemID == item {
            return item;
        }
        i += 1;
    }
    return found;
}

// Arm memory: the game treats the first arm cyberware it finds as "the" meleeware, so
// drawing arms always fell back to slot 1. Answer with the last used arms instead,
// which the equipment system already tracks as the active slot of the arms area.
@wrapMethod(EquipmentSystemPlayerData)
public final const func GetActiveMeleeWare() -> ItemID {
    let areaIndex: Int32 = this.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex >= 0 {
        let equipArea: SEquipArea = this.m_equipment.equipAreas[areaIndex];
        let activeIndex: Int32 = equipArea.activeIndex;
        if activeIndex >= 0 && activeIndex < ArraySize(equipArea.equipSlots) {
            let itemID: ItemID = equipArea.equipSlots[activeIndex].itemID;
            if ItemID.IsValid(itemID) && TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID)).TagsContains(n"Meleeware") {
                return itemID;
            }
        }
        // Firing the Projectile Launch System makes its slot the active one. The melee arms are
        // still the ones used last (the game would answer with the first arms in the list, which
        // then came back put away with another arm type's style)
        let lastMelee: ItemID = this.m_lastUsedStruct.lastUsedMelee;
        if ItemID.IsValid(lastMelee) && TweakDBInterface.GetItemRecord(ItemID.GetTDBID(lastMelee)).TagsContains(n"Meleeware") {
            let i: Int32 = 0;
            while i < ArraySize(equipArea.equipSlots) {
                if equipArea.equipSlots[i].itemID == lastMelee {
                    return lastMelee;
                }
                i += 1;
            }
        }
    }

    return wrappedMethod();
}

// Holstered arms: while arm cyberware is put away, the player wears a "holstered" version of
// one set of arms, which is what third-person views show (inventory, vehicles, mirrors).
// The game picks the active arms for this, but a mod may pick a fixed slot instead.

// The holstered item to show for the arms used last, or ItemID.None() when the game should
// decide as usual (setting off, arms or a launcher out, nothing to show).
@addMethod(EquipmentSystemPlayerData)
public static func GetArmSwapperHolsteredArms(player: ref<PlayerPuppet>, out lastUsedArms: ItemID) -> ItemID {
    if !IsDefined(player) || player.IsJohnnyReplacer() { return ItemID.None(); }
    if !(new SimpleArmSwapperSettings()).showLastUsedArmsHolstered { return ItemID.None(); }

    let equipmentData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(equipmentData) { return ItemID.None(); }

    lastUsedArms = equipmentData.GetActiveMeleeWare();
    if !ItemID.IsValid(lastUsedArms) { return ItemID.None(); }

    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let rightHand: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
    if IsDefined(rightHand) && TweakDBInterface.GetItemRecord(ItemID.GetTDBID(rightHand.GetItemID())).TagsContains(n"Meleeware") { return ItemID.None(); }
    let leftHand: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponLeft");
    if IsDefined(leftHand) && TweakDBInterface.GetItemRecord(ItemID.GetTDBID(leftHand.GetItemID())).TagsContains(n"ProjectileLauncher") { return ItemID.None(); }

    let armsRecord: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(lastUsedArms));
    if !IsDefined(armsRecord) || !IsDefined(armsRecord.HolsteredItem()) { return ItemID.None(); }
    return ItemID.CreateQuery(armsRecord.HolsteredItem().GetID());
}

// Arms landed in V's hand, by any route: a swap, the weapon wheel, or the game drawing them
// again by itself after a menu closes. Those arms become the active arms and wear their own
// Glamdoc style, so the arms in hand and the style always match.
@addMethod(EquipmentSystemPlayerData)
public static func ArmSwapperArmsInHand(player: ref<PlayerPuppet>, arms: ItemID) {
    if !IsDefined(player) || !ItemID.IsValid(arms) { return; }
    // The Projectile Launch System comes out beside the melee arms already on V. The game
    // holds one cyberarm style at a time, and switching it under arms that are on screen
    // leaves broken arm visuals, so the launcher never changes the style.
    if ArmSwapperArmsType(arms) == 0 { return; }
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(arms));
    if !IsDefined(record) || !record.TagsContains(n"Meleeware") { return; }
    // A swap that was settling is done: the next swap press is taken again
    // A swap that was settling has its arms in hand. The next swap waits for their first styling
    // passes too (see ArmSwapperStylePiecesSoon: 0.05 and 0.25 s after they attach).
    if player.m_armSwapperSwapSince > 0.0 {
        let settledNow: Float = ArmSwapperNow(player.GetGame());
        ArmSwapperLog(player.GetGame(), "swap arms in hand after " + FloatToStringPrec(settledNow - player.m_armSwapperSwapSince, 2) + "s");
        player.m_armSwapperSwapSince = 0.0;
        player.m_armSwapperSettledAt = settledNow + 0.3;
    }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return; }
    if !(eqData.GetActiveMeleeWare() == arms) {
        eqData.ArmSwapperMakeActiveArms(arms);
    }
    // The holster key draws the last used weapon. The game only records arms as last used when
    // they are tagged as a melee weapon, which some arm cyberware is not (the MaxTac Mantis
    // Blades, and arms built on them), so the key then drew an older weapon. Record them here.
    let lastUsed: SLastUsedWeapon = eqData.m_lastUsedStruct;
    if !(lastUsed.lastUsedWeapon == arms) {
        ArmSwapperLog(player.GetGame(), "last used weapon set to " + ArmSwapperName(arms) + " (was " + ArmSwapperName(lastUsed.lastUsedWeapon)
            + ", melee weapon tag: " + BoolToString(record.TagsContains(n"MeleeWeapon")) + ")");
        lastUsed.lastUsedMelee = arms;
        lastUsed.lastUsedWeapon = arms;
        lastUsed.lastUsedHeavy = ItemID.None();
        eqData.m_lastUsedStruct = lastUsed;
    }
    // With arms in hand the holstered arms come off, as the base game does. Checking the hand
    // a moment too early can leave them on, showing two sets of arms after a menu closes.
    if ItemID.IsValid(eqData.GetActiveItem(gamedataEquipmentArea.RightArm)) {
        let rightArmArea: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.RightArm);
        if rightArmArea >= 0 {
            eqData.UnequipItem(rightArmArea, 0, true);
            ArmSwapperLog(player.GetGame(), "holstered arms taken off, arms are in hand");
        }
    }
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        system.ArmSwapperApplyStyleFor(arms);
    }
    ArmSwapperProbeSoon(player, arms);
    ArmSwapperLog(player.GetGame(), "arms in hand: " + ArmSwapperName(arms) + ". " + ArmSwapperArmsState(player));
}

// Plain fists, not arm cyberware that takes the fists' place (Gorilla Arms)
public func ArmSwapperIsBareFists(item: ItemID) -> Bool {
    if !ItemID.IsValid(item) || NotEquals(EquipmentSystem.GetEquipAreaType(item), gamedataEquipmentArea.BaseFists) { return false; }
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
    return IsDefined(record) && !record.TagsContains(n"Meleeware");
}

// When the arms used last should be shown, equip their holstered version once in place of
// the original, so the arm slot is never swapped twice in a row. In every other case the
// original runs unchanged.
@wrapMethod(EquipmentSystemPlayerData)
public final static func UpdateArmSlot(owner: ref<gamePuppet>, itemToDraw: ItemID, equipHolsteredItem: Bool) {
    let player: ref<PlayerPuppet> = owner as PlayerPuppet;
    let lastUsedArms: ItemID;
    let holsteredArms: ItemID;
    // Only step in when the game asks for holstered arms to be shown, never when it asks
    // for them to be taken off (for example while Gorilla Arms force a door open)
    // Drawing bare fists also brings holstered arms out, whatever the game asks for
    let drawingFists: Bool = ArmSwapperIsBareFists(itemToDraw);
    if equipHolsteredItem || drawingFists {
        holsteredArms = EquipmentSystemPlayerData.GetArmSwapperHolsteredArms(player, lastUsedArms);
    }
    if IsDefined(player) {
        ArmSwapperLog(player.GetGame(), "arm slot update for " + ArmSwapperName(itemToDraw) + ": holstered asked=" + BoolToString(equipHolsteredItem)
            + " fists=" + BoolToString(drawingFists) + " ours=" + ArmSwapperName(holsteredArms));
        ArmSwapperLogNextDraw(player);
    }
    if !ItemID.IsValid(holsteredArms) {
        wrappedMethod(owner, itemToDraw, equipHolsteredItem);
        if !equipHolsteredItem {
            EquipmentSystemPlayerData.ArmSwapperArmsInHand(player, itemToDraw);
        }
        return;
    }

    let equipmentData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());

    // Already showing these arms
    if ts.HasItemInSlot(player, t"AttachmentSlots.RightArm", holsteredArms)
        || ItemID.GetTDBID(equipmentData.GetActiveItem(gamedataEquipmentArea.RightArm)) == ItemID.GetTDBID(holsteredArms) {
        return;
    }

    if !ts.HasItem(player, holsteredArms) {
        ts.GiveItem(player, holsteredArms, 1);
    }
    EquipmentSystemPlayerData.ForceQualityAndDuplicateStatsShard(player, lastUsedArms, holsteredArms);
    equipmentData.EquipItem(holsteredArms, false, false);
    ArmSwapperLog(player.GetGame(), "holstered arms set to " + ArmSwapperName(holsteredArms) + " for " + ArmSwapperName(lastUsedArms));
    ArmSwapperCheckHeadSoon(player, "holstered arms set");
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionName: CName = ListenerAction.GetName(action);
    let actionType: gameinputActionType = ListenerAction.GetType(action);

    if Equals(actionName, n"WeaponSlot4") && Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
        // Debug: the swap key also records V's head pieces as they are right now
        ArmSwapperCheckHead(this, "swap key", true);
        let swapper: ref<SimpleArmSwapper> = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"SimpleArmSwapperMod.SimpleArmSwapper") as SimpleArmSwapper;
        if IsDefined(swapper) {
            swapper.SwapToNextArms(this);
        }
    }

    return wrappedMethod(action, consumer);
}

// ---------------------------------------------------------------------------
// Weapon wheel support
// The wheel's cyberware slot normally only toggles between one arm cyberware
// and bare fists. With several Meleeware equipped it cycles through all of
// them (plus fists) instead, and selecting the slot draws the shown item.
// ---------------------------------------------------------------------------

// What the cyberware slot is showing while the wheel is open
@addField(RadialWheelController)
private let m_armSwapperSelected: ItemID;

@addMethod(RadialWheelController)
private func GetArmSwapper() -> ref<SimpleArmSwapper> {
    return GameInstance.GetScriptableSystemsContainer(this.GetPlayer().GetGame()).Get(n"SimpleArmSwapperMod.SimpleArmSwapper") as SimpleArmSwapper;
}

// Every Meleeware followed by bare fists (when fists are a separate item). Empty when there is nothing extra to cycle,
// in which case the vanilla wheel behaviour is left untouched.
@addMethod(RadialWheelController)
private func GetArmSwapperRing() -> array<ItemID> {
    let ring: array<ItemID>;
    let player: ref<GameObject> = this.GetPlayer();
    if !IsDefined(player) { return ring; }

    let swapper: ref<SimpleArmSwapper> = this.GetArmSwapper();
    if !IsDefined(swapper) { return ring; }

    ring = swapper.GetMeleewareItems(player);
    if ArraySize(ring) <= 1 {
        ArrayClear(ring);
        return ring;
    }

    // Gorilla Arms take over the fists slot, so the "fists" item is then one of the arms
    // already in the ring. Adding it twice would trap the cycling on that entry.
    let fists: array<ItemID> = EquipmentSystem.GetItemsInArea(player, gamedataEquipmentArea.BaseFists);
    if ArraySize(fists) > 0 && ItemID.IsValid(fists[0]) && !ArrayContains(ring, fists[0]) {
        ArrayPush(ring, fists[0]);
    }

    return ring;
}

@addMethod(RadialWheelController)
private func GetArmSwapperHeldItem() -> ItemID {
    let player: ref<GameObject> = this.GetPlayer();
    let heldObject: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
    if IsDefined(heldObject) {
        return heldObject.GetItemID();
    }
    return ItemID.None();
}

// The item before or after the given one, wrapping around the ring
@addMethod(RadialWheelController)
private func GetArmSwapperNeighbour(ring: array<ItemID>, from: ItemID, next: Bool) -> ItemID {
    let count: Int32 = ArraySize(ring);
    let index: Int32 = next ? -1 : 0;
    let i: Int32 = 0;

    while i < count {
        if ring[i] == from {
            index = i;
            break;
        }
        i += 1;
    }

    if next {
        return ring[(index + 1) % count];
    }
    return ring[(index + count - 1) % count];
}

@addMethod(RadialWheelController)
private func SetupArmSwapperSlot(slot: ref<CyclableRadialSlot>, itemID: ItemID) {
    let controller: ref<InventoryItemDisplayController> = this.GetController(slot);
    if !IsDefined(controller) || !ItemID.IsValid(itemID) { return; }

    let baseFists: InventoryItemData = this.GetBaseFists();
    if itemID == InventoryItemData.GetID(baseFists) {
        controller.Setup(baseFists);
    } else {
        controller.Setup(this.inventoryManager.GetItemDataFromIDInLoadout(itemID));
    }
}

// Decides what the cyberware slot shows
@wrapMethod(RadialWheelController)
private final func RefreshCyberware() -> Void {
    wrappedMethod();

    let ring: array<ItemID> = this.GetArmSwapperRing();
    if ArraySize(ring) == 0 { return; }

    let slot: ref<CyclableRadialSlot> = this.radialWeapons[6] as CyclableRadialSlot;

    // A refresh while the wheel is already open must not undo what the player cycled to
    if !this.isActive || !ArrayContains(ring, this.m_armSwapperSelected) {
        let lastUsed: ItemID = EquipmentSystem.GetData(this.GetPlayer()).GetActiveItem(gamedataEquipmentArea.ArmsCW);
        let held: ItemID = this.GetArmSwapperHeldItem();

        if !ArrayContains(ring, lastUsed) {
            lastUsed = ring[0];
        }

        if ArrayContains(ring, held) && TweakDBInterface.GetItemRecord(ItemID.GetTDBID(held)).TagsContains(n"Meleeware") {
            // Arms are out: offer the next one in line, or the ones in hand, depending on the setting
            if (new SimpleArmSwapperSettings()).wheelShowsNextArms {
                this.m_armSwapperSelected = this.GetArmSwapperNeighbour(ring, held, true);
            } else {
                this.m_armSwapperSelected = held;
            }
        } else {
            // Fists, a weapon or nothing in hand: offer the last used arms
            this.m_armSwapperSelected = lastUsed;
        }
    }

    this.SetupArmSwapperSlot(slot, this.m_armSwapperSelected);
}

@wrapMethod(RadialWheelController)
private final func CanPlayerCycleCyberware() -> Bool {
    if ArraySize(this.GetArmSwapperRing()) > 0 {
        return true;
    }
    return wrappedMethod();
}

// The game switches cycling off for the cyberware slot while arms or fists are in hand,
// and again after drawing from it. Switch it back on whenever that slot is highlighted.
@wrapMethod(RadialWheelController)
private final func SetActiveSlot(newActiveSlot: ref<WeaponRadialSlot>) -> Bool {
    let changed: Bool = wrappedMethod(newActiveSlot);

    let slot: ref<CyclableRadialSlot> = this.radialWeapons[6] as CyclableRadialSlot;
    if IsDefined(slot) && this.activeSlot == slot && !slot.CanCycle() && ArraySize(this.GetArmSwapperRing()) > 0 {
        slot.SetCanCycle(true);
        if this.GetRootWidget().IsVisible() {
            this.UpdateInputHints();
        }
    }

    return changed;
}

// Handles the previous/next keys for the cyberware slot directly, so cycling never
// depends on the game's own "can this slot cycle" state
@wrapMethod(RadialWheelController)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionName: CName = ListenerAction.GetName(action);
    let isCycleAction: Bool = Equals(actionName, n"UI_PreviousAbility") || Equals(actionName, n"UI_NextAbility");

    if this.isActive && isCycleAction && Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_PRESSED) {
        let slot: ref<CyclableRadialSlot> = this.radialWeapons[6] as CyclableRadialSlot;
        let ring: array<ItemID> = this.GetArmSwapperRing();

        if IsDefined(slot) && this.activeSlot == slot && ArraySize(ring) > 0 {
            let next: Bool = Equals(actionName, n"UI_NextAbility");

            this.m_armSwapperSelected = this.GetArmSwapperNeighbour(ring, this.GetItemID(slot), next);
            this.SetupArmSwapperSlot(slot, this.m_armSwapperSelected);

            this.PlayLibraryAnimation(n"cycle_hotkey");
            this.cyclingActionRegistered = actionName;
            slot.CycleStart(next);
            this.UpdateActiveTooltip();
            return false;
        }
    }

    return wrappedMethod(action, consumer);
}

// ---------------------------------------------------------------------------
// Glamdoc styles per arm type
// The Glamdoc only works on the arms in the first arm slot, and the game remembers a
// single style. With several arm types equipped, the Glamdoc can style each of them,
// every type keeps its own style, and switching arms puts the matching style back.
// ---------------------------------------------------------------------------

// Arm type numbers as the Glamdoc counts them: 0 Projectile Launch System,
// 1 Mantis Blades, 2 Monowire, 3 Gorilla Arms. -1 for anything else.
public func ArmSwapperArmsType(armsItem: ItemID) -> Int32 {
    if !ItemID.IsValid(armsItem) { return -1; }
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(armsItem));
    if !IsDefined(record) || !IsDefined(record.ItemType()) { return -1; }
    let itemType: gamedataItemType = record.ItemType().Type();
    if Equals(itemType, gamedataItemType.Cyb_Launcher) { return 0; }
    if Equals(itemType, gamedataItemType.Cyb_MantisBlades) { return 1; }
    if Equals(itemType, gamedataItemType.Cyb_NanoWires) { return 2; }
    if Equals(itemType, gamedataItemType.Cyb_StrongArms) { return 3; }
    return -1;
}

// The arm type a Glamdoc style is made for, read from the same tags the Glamdoc uses
public func ArmSwapperStyleType(styleItem: ItemID) -> Int32 {
    if !ItemID.IsValid(styleItem) { return -1; }
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(styleItem));
    if !IsDefined(record) { return -1; }
    if record.TagsContains(n"ProjectileLauncher") { return 0; }
    if record.TagsContains(n"MantisBlades") { return 1; }
    if record.TagsContains(n"NanoWires") { return 2; }
    if record.TagsContains(n"StrongArms") { return 3; }
    return -1;
}

// First equipped arm cyberware of the given type, in slot order
public func ArmSwapperEquippedArmsOfType(player: ref<GameObject>, armsType: Int32) -> ItemID {
    if !IsDefined(player) || armsType < 0 { return ItemID.None(); }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return ItemID.None(); }
    let areaIndex: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex < 0 { return ItemID.None(); }
    let equipArea: SEquipArea = eqData.m_equipment.equipAreas[areaIndex];
    let i: Int32 = 0;
    while i < ArraySize(equipArea.equipSlots) {
        let item: ItemID = equipArea.equipSlots[i].itemID;
        if ArmSwapperArmsType(item) == armsType {
            return item;
        }
        i += 1;
    }
    return ItemID.None();
}

// Puts the given Glamdoc style item in the style slot, or empties it for None. The game hides
// V's plain arms while a style item is equipped, so the slot has to match the active arms.
@addMethod(EquipmentSystemPlayerData)
public func ArmSwapperSyncStyleItem(styleItem: ItemID) {
    let areaIndex: Int32 = this.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCWStyle);
    if areaIndex < 0 || ArraySize(this.m_equipment.equipAreas[areaIndex].equipSlots) == 0 { return; }
    let current: ItemID = this.m_equipment.equipAreas[areaIndex].equipSlots[0].itemID;
    let questSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.m_owner.GetGame());
    if ItemID.IsValid(styleItem) {
        if current == styleItem { return; }
        if !GameInstance.GetTransactionSystem(this.m_owner.GetGame()).HasItem(this.m_owner, styleItem) { return; }
        this.EquipItem(styleItem, false, false);
        questSystem.SetFact(n"glam_equipped", 1);
    } else {
        if !ItemID.IsValid(current) { return; }
        this.UnequipItem(areaIndex, 0);
        questSystem.SetFact(n"glam_equipped", 0);
    }
}

// Remembers one Glamdoc style per arm type, in the save. An entry without a style item
// means the style was taken off for that type.
public class SimpleArmSwapperStyleMemory extends ScriptableSystem {

    private persistent let m_known: array<Bool>;
    private persistent let m_styleItem: array<ItemID>;
    private persistent let m_switcherName: array<CName>;
    private persistent let m_enabled: array<Bool>;
    private persistent let m_primaryColor: array<Int32>;
    private persistent let m_secondaryColor: array<Int32>;
    // The switcher option the game saved with the style (-1: not known). Usually the style item's own
    // option; another mod can pick a different one (Split Cyberarm Styles' left/right pairs).
    private persistent let m_switcherIndex: array<Int32>;

    // True while the Glamdoc menu is open. Styles are only put back once it closes.
    public let glamdocOpen: Bool;
    // The open Glamdoc, so its preview character can be styled the moment its arms arrive
    public let glamdoc: wref<GlamDocGameController>;

    public static func Get(game: GameInstance) -> ref<SimpleArmSwapperStyleMemory> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"SimpleArmSwapperMod.SimpleArmSwapperStyleMemory") as SimpleArmSwapperStyleMemory;
    }

    private func EnsureEntries() {
        while ArraySize(this.m_known) < 4 {
            ArrayPush(this.m_known, false);
        }
        while ArraySize(this.m_styleItem) < 4 {
            ArrayPush(this.m_styleItem, ItemID.None());
        }
        while ArraySize(this.m_switcherName) < 4 {
            ArrayPush(this.m_switcherName, n"None");
        }
        while ArraySize(this.m_enabled) < 4 {
            ArrayPush(this.m_enabled, false);
        }
        while ArraySize(this.m_primaryColor) < 4 {
            ArrayPush(this.m_primaryColor, 0);
        }
        while ArraySize(this.m_switcherIndex) < 4 {
            ArrayPush(this.m_switcherIndex, -1);
        }
        while ArraySize(this.m_secondaryColor) < 4 {
            ArrayPush(this.m_secondaryColor, 0);
        }
    }

    public func HasStyle(armsType: Int32) -> Bool {
        this.EnsureEntries();
        return armsType >= 0 && armsType < 4 && this.m_known[armsType];
    }

    public func Remember(armsType: Int32, styleItem: ItemID, switcherName: CName, enabled: Bool, primaryColor: Int32, secondaryColor: Int32) {
        if armsType < 0 || armsType >= 4 { return; }
        this.EnsureEntries();
        this.m_known[armsType] = true;
        this.m_styleItem[armsType] = styleItem;
        this.m_switcherName[armsType] = switcherName;
        this.m_enabled[armsType] = enabled;
        this.m_primaryColor[armsType] = primaryColor;
        this.m_secondaryColor[armsType] = secondaryColor;
        this.m_switcherIndex[armsType] = -1;
    }

    public func RememberSwitcherIndex(armsType: Int32, index: Int32) {
        if armsType < 0 || armsType >= 4 { return; }
        this.EnsureEntries();
        this.m_switcherIndex[armsType] = index;
    }

    public func GetSwitcherIndex(armsType: Int32) -> Int32 {
        this.EnsureEntries();
        return armsType >= 0 && armsType < 4 ? this.m_switcherIndex[armsType] : -1;
    }

    // The arm type whose remembered style uses this switcher, or -1
    public func FindTypeBySwitcher(switcherName: CName) -> Int32 {
        this.EnsureEntries();
        let i: Int32 = 0;
        while i < 4 {
            if this.m_known[i] && Equals(this.m_switcherName[i], switcherName) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    public func GetStyleItem(armsType: Int32) -> ItemID { this.EnsureEntries(); return this.m_styleItem[armsType]; }

    // The name of the arm type's appearance switcher: learned from any style seen for that
    // type, otherwise the game's own names for the melee types, confirmed in game
    public func GetKnownSwitcherName(armsType: Int32) -> CName {
        this.EnsureEntries();
        if armsType >= 0 && armsType < 4 && this.m_known[armsType] && NotEquals(this.m_switcherName[armsType], n"None") {
            return this.m_switcherName[armsType];
        }
        if armsType == 1 { return n"mantis"; }
        if armsType == 2 { return n"monowire"; }
        if armsType == 3 { return n"strongarms"; }
        return n"None";
    }
    public func GetSwitcherName(armsType: Int32) -> CName { this.EnsureEntries(); return this.m_switcherName[armsType]; }
    public func IsEnabled(armsType: Int32) -> Bool { this.EnsureEntries(); return this.m_enabled[armsType]; }
    public func GetPrimaryColor(armsType: Int32) -> Int32 { this.EnsureEntries(); return this.m_primaryColor[armsType]; }
    public func GetSecondaryColor(armsType: Int32) -> Int32 { this.EnsureEntries(); return this.m_secondaryColor[armsType]; }

    // Copy taken when the Glamdoc opens, so discarding its changes can put every type back
    private let m_snapKnown: array<Bool>;
    private let m_snapStyleItem: array<ItemID>;
    private let m_snapSwitcherName: array<CName>;
    private let m_snapEnabled: array<Bool>;
    private let m_snapPrimaryColor: array<Int32>;
    private let m_snapSecondaryColor: array<Int32>;
    private let m_snapSwitcherIndex: array<Int32>;

    public func TakeSnapshot() {
        this.EnsureEntries();
        this.m_snapKnown = this.m_known;
        this.m_snapStyleItem = this.m_styleItem;
        this.m_snapSwitcherName = this.m_switcherName;
        this.m_snapEnabled = this.m_enabled;
        this.m_snapPrimaryColor = this.m_primaryColor;
        this.m_snapSecondaryColor = this.m_secondaryColor;
        this.m_snapSwitcherIndex = this.m_switcherIndex;
    }

    public func RestoreSnapshot() {
        if ArraySize(this.m_snapKnown) < 4 { return; }
        this.m_known = this.m_snapKnown;
        this.m_styleItem = this.m_snapStyleItem;
        this.m_switcherName = this.m_snapSwitcherName;
        this.m_enabled = this.m_snapEnabled;
        this.m_primaryColor = this.m_snapPrimaryColor;
        this.m_secondaryColor = this.m_snapSecondaryColor;
        this.m_switcherIndex = this.m_snapSwitcherIndex;
        this.EnsureEntries();
    }

    // With native styling: pieces of other arm types switched off on V, and the arm type of each
    public let hiddenStray: array<wref<IComponent>>;
    public let hiddenStrayType: array<Int32>;
    // Whether Simple Arm Swapper Native was looked for this session, and its version (0: absent or off)
    public let nativeChecked: Bool;
    public let nativeVersion: Int32;
    // V's own nail pieces switched off under a painted-nail style
    public let hiddenNails: array<wref<IComponent>>;
    // Mantis Blade nail pieces switched off under a Mantis style
    public let hiddenBladeNails: array<wref<IComponent>>;
    // Nail items taken out of Equipment-EX's fingernail slots under Gorilla Arms, to put back
    public let hiddenNailSlots: array<TweakDBID>;
    public let hiddenNailItems: array<ItemID>;

    // Kept for other mods built against 2.7.1 and older (such as Split Cyberarm Styles), which read
    // the style piece table the mod used to paint arm pieces from. The game styles the arms itself
    // now, so the table is empty and nothing reads it here.
    private let m_stylePieces: array<ref<ArmSwapperStylePiece>>;

    public func ArmSwapperStylePieces() -> array<ref<ArmSwapperStylePiece>> {
        return this.m_stylePieces;
    }
}

// Files the style the game currently has saved under its arm type. Styles the player does
// not own are only being previewed in the Glamdoc and are skipped.
@addMethod(CyberwareCustomizationSystem)
private func ArmSwapperRememberCurrentStyle() {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if !IsDefined(memory) || !IsDefined(this.m_playerPuppet) { return; }
    let styleItem: ItemID = this.savedData.customizationItemID;
    if !ItemID.IsValid(styleItem) { return; }
    if !GameInstance.GetTransactionSystem(this.GetGameInstance()).HasItem(this.m_playerPuppet, styleItem) { return; }
    ArmSwapperLog(this.GetGameInstance(), "remember type " + IntToString(ArmSwapperStyleType(styleItem)) + ": " + ArmSwapperStyleDataText(this.savedData));
    memory.Remember(ArmSwapperStyleType(styleItem), styleItem, this.savedData.switcherName, this.savedData.enabled,
        Cast<Int32>(this.savedData.primaryColorIndex), Cast<Int32>(this.savedData.secondaryColorIndex));
    memory.RememberSwitcherIndex(ArmSwapperStyleType(styleItem), Cast<Int32>(this.savedData.switcherIndex));
}

// Arm cyberware tagged for the MaxTac look (the MaxTac Mantis Blades, and arms from other mods
// built on them) shows the MaxTac look while it has no Glamdoc style; a style replaces it. The
// game only checks that again when the holstered Mantis Blades appear, which is enough when arms
// can only be changed at a Ripperdoc. After swapping to other arms the MaxTac look would stay on
// and their styles and colours would not show, so the check is repeated whenever the arms change.
// styled: the arms about to be shown have a style switched on.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperRefreshMaxTacLook(styled: Bool) {
    if !IsDefined(this.m_playerPuppet) { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.m_playerPuppet);
    // The game's check reads the active arms' record, so it needs arms to look at
    if !IsDefined(eqData) || !IsDefined(TweakDBInterface.GetItemRecord(ItemID.GetTDBID(eqData.GetActiveItem(gamedataEquipmentArea.ArmsCW)))) { return; }
    let before: Bool = this.savedData.hasMaxTacApperanceEquipped;
    let active: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.ArmsCW);
    let gameTest: Bool = this.ShouldApplyMaxTacApperance();
    ArmSwapperLog(this.GetGameInstance(), "MaxTac check for " + ArmSwapperName(active) + ": game test " + BoolToString(gameTest)
        + ", styled " + BoolToString(styled) + ", flag " + BoolToString(before) + ", tags " + ArmSwapperTagsText(active));
    // Only Mantis Blades have a MaxTac look; calling the game's MaxTac functions for other arms would
    // apply the Mantis Blade pieces again while those arms come out.
    if ArmSwapperArmsType(active) != 1 {
        // Outside the Glamdoc no style switch goes out on a swap, so the flag stays as it is: the
        // MaxTac look only touches the Mantis Blades' own pieces, and keeping it set means swapping
        // back to the blades needs no MaxTac switch either. The Glamdoc's tabs do send style
        // switches (through the MaxTac version while the flag is set), so there it is cleared;
        // leaving the Glamdoc sets the MaxTac look again with the other switchers.
        let tabsMemory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
        if !(IsDefined(tabsMemory) && tabsMemory.glamdocOpen) { return; }
        if before {
            this.savedData.hasMaxTacApperanceEquipped = false;
            ArmSwapperLog(this.GetGameInstance(), "MaxTac flag cleared for " + ArmSwapperName(active));
        }
        return;
    }
    // The game's own test for MaxTac arms; a style on them shows the style, not the MaxTac look
    let wantMaxTac: Bool = gameTest && !styled;
    if wantMaxTac && !before {
        this.SetMaxTacApperance();
    }
    if !wantMaxTac && before {
        this.RemoveMaxTacApperance();
    }
    if NotEquals(before, this.savedData.hasMaxTacApperanceEquipped) {
        // Put the arms' style back through the matching version
        this.RestoreCyberwareCustomization(true);
        ArmSwapperCheckHeadSoon(this.m_playerPuppet as PlayerPuppet, "after MaxTac look change");
        ArmSwapperLog(this.GetGameInstance(), "MaxTac look " + (this.savedData.hasMaxTacApperanceEquipped ? "on" : "off")
            + " for " + ArmSwapperName(eqData.GetActiveItem(gamedataEquipmentArea.ArmsCW)));
    }
}

// Debug: an item's tags, to tell MaxTac-based arms apart
public func ArmSwapperTagsText(item: ItemID) -> String {
    let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item));
    if !IsDefined(record) { return "none"; }
    let text: String = "";
    for tag in record.Tags() {
        text += NameToString(tag) + " ";
    }
    return text;
}

// When V attached (a save loading), in engine time
@addField(PlayerPuppet)
public let m_armSwapperAttachTime: Float;

// When the last arm swap started, in engine time, until its arms are in hand (0 = none settling)
@addField(PlayerPuppet)
public let m_armSwapperSwapSince: Float;

// Until when the last swap's arms are still being styled, in engine time
@addField(PlayerPuppet)
public let m_armSwapperSettledAt: Float;

// Counts the swaps started with the swap key or button. Styling passes queued for V's arms
// drop out once a newer swap has started, so they never work on arms on their way out.
@addField(PlayerPuppet)
public let m_armSwapperSwapGen: Int32;

public func ArmSwapperNow(game: GameInstance) -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(game));
}

// The game repeats its MaxTac check whenever the holstered Mantis Blades appear (mounting a bike,
// for one), which switches the MaxTac look back on over a style. Apply the style rule again
// straight after, and tidy the arms V is wearing.
// The game also runs this check while a save is still loading. Switching the look off at that
// point re-applies V's customization too early, which left V's hair showing in first person
// with a weapon drawn. During the first moments after a load the switch waits a little.
@wrapMethod(CyberwareCustomizationSystem)
private final func OnPotentiallyRefreshMaxTacApperance(request: ref<PotentiallyRefreshMaxTacApperanceRequest>) {
    let before: Bool = this.savedData.hasMaxTacApperanceEquipped;
    wrappedMethod(request);
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    if !IsDefined(player) { return; }
    let game: GameInstance = this.GetGameInstance();
    // In the Glamdoc the rule applies at once, before the menu reads the style
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) && memory.glamdocOpen {
        this.ArmSwapperMaxTacOverStyle(before);
        return;
    }
    // Elsewhere it waits a moment: the holstered blades appear while the game is still rebuilding V
    // (getting on a bike, for one), and switching the style in the middle of that could crash the
    // game. Checks that come in meanwhile share the one waiting callback.
    let delay: Float = ArmSwapperNow(game) - player.m_armSwapperAttachTime < 30.0 ? 10.0 : 1.0;
    ArmSwapperLog(game, "MaxTac check by the game (flag " + BoolToString(before) + " -> "
        + BoolToString(this.savedData.hasMaxTacApperanceEquipped) + "); applying the style rule in " + FloatToStringPrec(delay, 0) + " s");
    player.m_armSwapperMaxTacGen += 1;
    let callback: ref<ArmSwapperMaxTacLaterCallback> = new ArmSwapperMaxTacLaterCallback();
    callback.player = player;
    callback.before = before;
    callback.gen = player.m_armSwapperMaxTacGen;
    GameInstance.GetDelaySystem(game).DelayCallback(callback, delay, false);
}

// Only the newest waiting MaxTac style rule runs
@addField(PlayerPuppet)
public let m_armSwapperMaxTacGen: Int32;

public class ArmSwapperMaxTacLaterCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let before: Bool;
    public let gen: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) || this.gen != player.m_armSwapperMaxTacGen { return; }
        // A swap is still bringing its arms out: once more, a moment later
        let now: Float = ArmSwapperNow(player.GetGame());
        if (player.m_armSwapperSwapSince > 0.0 && now - player.m_armSwapperSwapSince < 1.5) || now < player.m_armSwapperSettledAt {
            GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(this, 0.5, false);
            return;
        }
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) {
            system.ArmSwapperMaxTacOverStyle(this.before);
            ArmSwapperCheckHeadSoon(player, "after the MaxTac style rule");
        }
    }
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperMaxTacOverStyle(before: Bool) {
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !IsDefined(this.m_playerPuppet) { return; }
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(player) || !IsDefined(eqData) { return; }
    let arms: ItemID = eqData.GetActiveMeleeWare();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    let armsType: Int32 = ArmSwapperArmsType(arms);
    if !IsDefined(memory) || armsType < 0 || armsType > 3 || !memory.HasStyle(armsType) || !memory.IsEnabled(armsType) { return; }
    if !this.savedData.hasMaxTacApperanceEquipped { return; }
    ArmSwapperLog(this.GetGameInstance(), "game switched the MaxTac look on (was " + BoolToString(before) + ") over the style of " + ArmSwapperName(arms) + "; switching it off");
    this.ArmSwapperRefreshMaxTacLook(true);
    ArmSwapperTidyWornNow(player, "MaxTac look switched off");
}

// The game's own test for MaxTac-based arms (the MaxTac Mantis Blades and modded arms built on
// them), for the active arms
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperArmsAreMaxTac() -> Bool {
    return this.ShouldApplyMaxTacApperance();
}

// Shows the given arms with their own style: the one remembered for their type, or no
// style if that type has never been styled, rather than another type's style. While the
// Glamdoc is open this only happens when the menu itself asks for it.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperApplyStyleFor(armsItem: ItemID, opt fromGlamdoc: Bool) {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    // Whether these arms will wear a style: their remembered one, or with styles per arm type
    // off, the game's current one
    let styled: Bool = ItemID.IsValid(this.savedData.customizationItemID) && this.savedData.enabled;
    if (new SimpleArmSwapperSettings()).stylePerArmType && IsDefined(memory) {
        let ownType: Int32 = ArmSwapperArmsType(armsItem);
        styled = false;
        if ownType >= 0 && ownType < 4 && memory.HasStyle(ownType) {
            styled = memory.IsEnabled(ownType) && ItemID.IsValid(memory.GetStyleItem(ownType));
        }
    }
    // The MaxTac look belongs to the melee arms; the launcher's style says nothing about it
    if ArmSwapperArmsType(armsItem) != 0 {
        this.ArmSwapperRefreshMaxTacLook(styled);
    }
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    if !IsDefined(memory) || (memory.glamdocOpen && !fromGlamdoc) { return; }
    let armsType: Int32 = ArmSwapperArmsType(armsItem);
    if armsType < 0 { return; }
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    if !IsDefined(player) { return; }

    // Never lose the style the game has now: file it first if its type is new to us
    let currentType: Int32 = ArmSwapperStyleType(this.savedData.customizationItemID);
    if currentType >= 0 && !memory.HasStyle(currentType) {
        this.ArmSwapperRememberCurrentStyle();
    }

    let styleItem: ItemID = ItemID.None();
    let enabled: Bool = false;
    let switcherName: CName = this.savedData.switcherName;
    let switcherIndex: Int32 = 0;
    let brandDataID: TweakDBID = TDBID.None();
    let primaryColor: Uint8 = Cast<Uint8>(0);
    let secondaryColor: Uint8 = Cast<Uint8>(0);

    if memory.HasStyle(armsType) {
        styleItem = memory.GetStyleItem(armsType);
        enabled = memory.IsEnabled(armsType);
        switcherName = memory.GetSwitcherName(armsType);
        primaryColor = Cast<Uint8>(memory.GetPrimaryColor(armsType));
        secondaryColor = Cast<Uint8>(memory.GetSecondaryColor(armsType));
    } else {
        // Never styled: nothing to do if the game's current style is already for these arms
        if currentType == armsType { return; }
        // Show them plain: reset this type's own appearance switcher to its default, the way
        // removing a style does, and switch the colours off. The game keeps a switcher's last
        // setting for the rest of the session, so without the reset an earlier style's shape
        // shows without its colours (plain white). Another type's switcher is never touched:
        // changing it while these arms are active draws both sets of arms at once.
        let ownSwitcher: CName = memory.GetKnownSwitcherName(armsType);
        this.savedData.enabled = false;
        this.savedData.customizationItemID = ItemID.None();
        this.savedData.switcherName = ownSwitcher;
        this.savedData.switcherIndex = Cast<Uint32>(0);
        this.savedData.brandDataID = TDBID.None();
        this.savedData.primaryColorIndex = Cast<Uint8>(0);
        this.savedData.secondaryColorIndex = Cast<Uint8>(0);
        // Switchers are only set when the save loads and when the Glamdoc closes, never on a swap
        // (see ArmSwapperSetAllSwitchers). Glamdoc tab switches still send theirs: the game only
        // rebuilds the preview character for the new arms after a style switch.
        if fromGlamdoc && NotEquals(ownSwitcher, n"None") && !this.ArmSwapperHoldsBackSwitcher(ownSwitcher) {
            this.SetIndexForCustomizationSwitcher(ownSwitcher, Cast<Uint32>(0), true);
            this.ArmSwapperNoteSwitcherSent(ownSwitcher, 0, false);
            ArmSwapperCheckHeadSoon(player, "after style switcher reset");
        }
        let noColor: Color;
        this.ArmSwapperPaint(false, noColor, noColor, n"noStyle");
        EquipmentSystem.GetData(player).ArmSwapperSyncStyleItem(ItemID.None());
        ArmSwapperLog(this.GetGameInstance(), "apply for " + ArmSwapperName(armsItem) + ": no style of its own, switcher " + NameToString(ownSwitcher) + " reset, colours off. " + ArmSwapperArmsState(player));
        return;
    }

    if ItemID.IsValid(styleItem) {
        let record: ref<UIGlamdocCustomizationItem_Record> = TweakDBInterface.GetUIGlamdocCustomizationItemRecord(ItemID.GetTDBID(styleItem));
        if !IsDefined(record) { return; }
        switcherIndex = record.CustomizationIndex();
        let longSleevesIndex: Int32 = record.LongSleevesCustomizationIndex();
        if longSleevesIndex != -1 && EquipmentSystemPlayerData.HasLongSleeves(player) {
            switcherIndex = longSleevesIndex;
        }
        // Another mod saved a different option with this style (Split Cyberarm Styles' left/right
        // pairs): keep that one
        let savedIndex: Int32 = memory.GetSwitcherIndex(armsType);
        if savedIndex >= 0 && savedIndex != record.CustomizationIndex() && savedIndex != longSleevesIndex {
            switcherIndex = savedIndex;
        }
        if IsDefined(record.BrandHandle()) {
            brandDataID = record.BrandHandle().GetID();
        }
    } else {
        enabled = false;
    }

    // Already showing this style
    if this.savedData.customizationItemID == styleItem && Equals(this.savedData.switcherName, switcherName)
        && this.savedData.switcherIndex == Cast<Uint32>(switcherIndex) && this.savedData.brandDataID == brandDataID
        && Equals(this.savedData.enabled, enabled) && this.savedData.primaryColorIndex == primaryColor
        && this.savedData.secondaryColorIndex == secondaryColor {
        return;
    }

    this.savedData.enabled = enabled;
    this.savedData.customizationItemID = styleItem;
    this.savedData.switcherName = switcherName;
    this.savedData.switcherIndex = Cast<Uint32>(switcherIndex);
    this.savedData.brandDataID = brandDataID;
    this.savedData.primaryColorIndex = primaryColor;
    this.savedData.secondaryColorIndex = secondaryColor;
    if !fromGlamdoc {
        // Every type's switcher was set once already (ArmSwapperSetAllSwitchers), so a swap only
        // changes the colours. Sending the style switch on every swap, while the arms were still
        // changing, could crash the game.
        this.ArmSwapperPaintSaved(n"swap");
        EquipmentSystem.GetData(player).ArmSwapperSyncStyleItem(styleItem);
        ArmSwapperLog(this.GetGameInstance(), "colours for " + ArmSwapperName(armsItem) + ": " + ArmSwapperStyleDataText(this.savedData));
        return;
    }
    this.RestoreCyberwareCustomization(true);
    ArmSwapperCheckHeadSoon(player, "after style restore for " + ArmSwapperName(armsItem));
    EquipmentSystem.GetData(player).ArmSwapperSyncStyleItem(styleItem);
    ArmSwapperLog(this.GetGameInstance(), "apply for " + ArmSwapperName(armsItem) + ": " + ArmSwapperStyleDataText(this.savedData) + ". " + ArmSwapperArmsState(player));
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperApplyStyleForActiveArms(opt fromGlamdoc: Bool) {
    if !IsDefined(this.m_playerPuppet) { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.m_playerPuppet);
    if !IsDefined(eqData) { return; }
    this.ArmSwapperApplyStyleFor(eqData.GetActiveMeleeWare(), fromGlamdoc);
}

// A style was saved or taken off: file it, then make sure the arms in use show theirs
@wrapMethod(CyberwareCustomizationSystem)
private final func OnSaveAndApplyCyberwareCustomizationDataRequest(request: ref<SaveAndApplyCyberwareCustomizationDataRequest>) {
    // Applying a style the player already owns copies the on/off flag from the style saved
    // before it. After an arm type shown without a style that flag is off, and the new style
    // would be saved switched off: invisible, with its colours ignored. A real style is
    // always meant to be on; only "no style" is ever saved switched off.
    if IsDefined(request.customizationItem) && !request.enabled && (new SimpleArmSwapperSettings()).stylePerArmType {
        request.enabled = true;
    }
    wrappedMethod(request);
    if IsDefined(request.customizationItem) {
        this.ArmSwapperRememberCurrentStyle();
    } else {
        let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
        if IsDefined(memory) {
            let armsType: Int32 = memory.FindTypeBySwitcher(request.switcherName);
            ArmSwapperLog(this.GetGameInstance(), "style removed for switcher " + NameToString(request.switcherName) + " (type " + IntToString(armsType)
                + ", in Glamdoc: " + BoolToString(memory.glamdocOpen) + ")");
            // Only a style taken off in the Glamdoc is forgotten. The game also clears the style in
            // use when cyberware changes at a ripperdoc; those arms keep their remembered style.
            if armsType >= 0 && memory.glamdocOpen {
                memory.Remember(armsType, ItemID.None(), request.switcherName, false, 0, 0);
            }
        }
    }
    this.ArmSwapperApplyStyleForActiveArms();
    // A style change outside the Glamdoc (the game clears the style when cyberware changes at a
    // ripperdoc): set every type's switcher again a moment later
    let changeMemory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if IsDefined(changeMemory) && !changeMemory.glamdocOpen && (new SimpleArmSwapperSettings()).stylePerArmType {
        // (3 s: leaving a ripperdoc, the game is still rebuilding V for a moment)
        this.ArmSwapperSetAllSwitchersLater("style changed outside the Glamdoc", 3.0);
    }
}

@wrapMethod(CyberwareCustomizationSystem)
private final func OnSaveAndApplyCyberwareCustomizationColorRequest(request: ref<SaveAndApplyCyberWareCustomColorRequest>) {
    wrappedMethod(request);
    ArmSwapperLog(this.GetGameInstance(), "colour request " + IntToString(Cast<Int32>(request.primaryColorIndex)) + "," + IntToString(Cast<Int32>(request.secondaryColorIndex))
        + " painted " + ArmSwapperColorText(CyberwareCustomizationPersistentData.GetPrimaryColor(this.savedData))
        + " and " + ArmSwapperColorText(CyberwareCustomizationPersistentData.GetSecondaryColor(this.savedData))
        + ". " + ArmSwapperStyleDataText(this.savedData));
    this.ArmSwapperRememberCurrentStyle();
}

// After loading: file the style the save already had, then match the arms in use
@wrapMethod(CyberwareCustomizationSystem)
private final func PlayerAttachedCallback(playerPuppet: ref<GameObject>) {
    wrappedMethod(playerPuppet);
    let attached: ref<PlayerPuppet> = playerPuppet as PlayerPuppet;
    if IsDefined(attached) { attached.m_armSwapperAttachTime = ArmSwapperNow(attached.GetGame()); }
    this.m_armSwapperLauncherColoursOn = false;
    // A pass still waiting from before the load is dropped; the load's own pass follows below
    this.m_armSwapperSwitchersDue = 0.0;
    this.m_armSwapperSwitchersWhy = "";
    this.m_armSwapperSwitchersGen += 1;
    this.ArmSwapperForgetSwitchersSent();
    this.ArmSwapperListenForLauncher(playerPuppet);
    ArmSwapperStartHeadWatch(attached);
    this.ArmSwapperRememberCurrentStyle();
    this.ArmSwapperApplyStyleForActiveArms();
    // Set every arm type's switcher once the save has finished loading (earlier, mid-load style
    // changes brought V's hair into first person)
    if IsDefined(attached) && (new SimpleArmSwapperSettings()).stylePerArmType {
        this.ArmSwapperSetAllSwitchersLater("save loaded", 12.0);
    }
}

// One switcher pass waits at a time. Requests that come in while it waits (leaving a ripperdoc
// sends several within a second, while the game is still rebuilding V) join it and push it back,
// so the switchers are set once, after things have gone quiet. Setting them several times in a
// row while V was being rebuilt could crash the game.
@addField(CyberwareCustomizationSystem)
private let m_armSwapperSwitchersDue: Float;

@addField(CyberwareCustomizationSystem)
private let m_armSwapperSwitchersWhy: String;

// Only the newest waiting callback may run the pass; older ones see a different number and stop
@addField(CyberwareCustomizationSystem)
private let m_armSwapperSwitchersGen: Int32;

// The option each style switcher was last sent this session, and whether it went through the game's
// MaxTac version. A switcher pass only sends the switchers whose option changed: every send makes
// the game rebuild V's arms, and the fewer of those the better. Forgotten when a save loads and
// when the Glamdoc closes (its previews change switchers without passing through here).
@addField(CyberwareCustomizationSystem)
private let m_armSwapperSentName: array<CName>;

@addField(CyberwareCustomizationSystem)
private let m_armSwapperSentIndex: array<Int32>;

@addField(CyberwareCustomizationSystem)
private let m_armSwapperSentMaxTac: array<Bool>;

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperNoteSwitcherSent(switcher: CName, index: Int32, maxTac: Bool) {
    if Equals(switcher, n"None") { return; }
    let at: Int32 = ArrayFindFirst(this.m_armSwapperSentName, switcher);
    if at < 0 {
        ArrayPush(this.m_armSwapperSentName, switcher);
        ArrayPush(this.m_armSwapperSentIndex, index);
        ArrayPush(this.m_armSwapperSentMaxTac, maxTac);
    } else {
        this.m_armSwapperSentIndex[at] = index;
        this.m_armSwapperSentMaxTac[at] = maxTac;
    }
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperSwitcherAlreadySent(switcher: CName, index: Int32, maxTac: Bool) -> Bool {
    let at: Int32 = ArrayFindFirst(this.m_armSwapperSentName, switcher);
    return at >= 0 && this.m_armSwapperSentIndex[at] == index && Equals(this.m_armSwapperSentMaxTac[at], maxTac);
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperForgetSwitchersSent() {
    ArrayClear(this.m_armSwapperSentName);
    ArrayClear(this.m_armSwapperSentIndex);
    ArrayClear(this.m_armSwapperSentMaxTac);
}

// Sets every arm type's switcher after the given delay, once no swap is settling and the Glamdoc is closed
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperSetAllSwitchersLater(why: String, delay: Float) {
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    if !IsDefined(player) { return; }
    let now: Float = ArmSwapperNow(player.GetGame());
    let waiting: Bool = this.m_armSwapperSwitchersDue > 0.0;
    let due: Float = now + delay;
    if waiting && this.m_armSwapperSwitchersDue > due { due = this.m_armSwapperSwitchersDue; }
    this.m_armSwapperSwitchersDue = due;
    if !waiting || Equals(this.m_armSwapperSwitchersWhy, "") {
        this.m_armSwapperSwitchersWhy = why;
    } else if !StrContains(this.m_armSwapperSwitchersWhy, why) {
        this.m_armSwapperSwitchersWhy += " + " + why;
    }
    if waiting {
        ArmSwapperLog(player.GetGame(), "switcher pass joined (" + why + "), runs in " + FloatToStringPrec(due - now, 2) + "s");
    }
    this.m_armSwapperSwitchersGen += 1;
    let later: ref<ArmSwapperSetSwitchersCallback> = new ArmSwapperSetSwitchersCallback();
    later.system = this;
    later.gen = this.m_armSwapperSwitchersGen;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(later, due - now, false);
}

// Runs the waiting switcher pass if it is due and nothing is settling. Returns 0 when done (it ran,
// or a newer callback owns the pass), otherwise the seconds to wait before asking again.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperRunSwitchersIfDue(gen: Int32) -> Float {
    if gen != this.m_armSwapperSwitchersGen || this.m_armSwapperSwitchersDue <= 0.0 { return 0.0; }
    let player: ref<PlayerPuppet> = this.ArmSwapperPlayer();
    if !IsDefined(player) { return 0.0; }
    let left: Float = this.m_armSwapperSwitchersDue - ArmSwapperNow(player.GetGame());
    if left > 0.05 { return left; }
    // A swap still settling, or the Glamdoc open again: try a moment later
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if player.m_armSwapperSwapSince > 0.0 || (IsDefined(memory) && memory.glamdocOpen) { return 1.0; }
    let why: String = NotEquals(this.m_armSwapperSwitchersWhy, "") ? this.m_armSwapperSwitchersWhy : "save loaded";
    this.m_armSwapperSwitchersDue = 0.0;
    this.m_armSwapperSwitchersWhy = "";
    this.ArmSwapperSetAllSwitchers(why);
    return 0.0;
}

public class ArmSwapperSetSwitchersCallback extends DelayCallback {
    public let system: wref<CyberwareCustomizationSystem>;
    public let gen: Int32;

    public func Call() -> Void {
        let system: ref<CyberwareCustomizationSystem> = this.system;
        if !IsDefined(system) { return; }
        let wait: Float = system.ArmSwapperRunSwitchersIfDue(this.gen);
        let player: ref<PlayerPuppet> = system.ArmSwapperPlayer();
        if wait > 0.0 && IsDefined(player) {
            GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(this, wait, false);
        }
    }
}

// The reason passed to ArmSwapperColoursPainted for a switcher pass (several reasons when requests joined)
public func ArmSwapperSwitchersReason(why: String) -> CName {
    if StrContains(why, "save loaded") { return n"load"; }
    if StrContains(why, "glamdoc closed") { return n"glamdocClosed"; }
    if StrContains(why, "style changed") { return n"styleChanged"; }
    if StrContains(why, "top changed") { return n"topChanged"; }
    return n"styleChanged";
}

// Each arm type has a style switcher of its own in V's character customization (mantis, monowire,
// strongarms), so every equipped type's switcher is set to its remembered style once: when the save
// loads, when the Glamdoc closes, and when the game changes the style (a ripperdoc). Swaps then only
// change the colours. The type in use goes last.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperSetAllSwitchers(why: String) {
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if !IsDefined(player) || !IsDefined(memory) { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return; }
    let activeType: Int32 = ArmSwapperArmsType(eqData.GetActiveMeleeWare());
    // The sleeves these styles are set for; the arms in use follow them first
    let longSleeves: Bool = EquipmentSystemPlayerData.HasLongSleeves(player);
    player.m_armSwapperSleeves = longSleeves ? 2 : 1;
    this.ArmSwapperFollowSleeves(longSleeves);
    ArmSwapperLog(this.GetGameInstance(), "switchers (" + why + "): sleeves " + (longSleeves ? "long" : "short") + ", Sleeve Version setting "
        + IntToString(EnumInt((new SimpleArmSwapperSettings()).sleeveVersion)) + " (0 automatic, 1 always short, 2 always long)");
    // The launcher first, and only with native styling (without it, its style is kept off V beside
    // melee arms); then the melee arms. The active type goes last, so its switcher is the one the game
    // saw most recently and its painted nails are the ones on V.
    let order: array<Int32>;
    if ArmSwapperNativeStyling(this.GetGameInstance()) && memory.HasStyle(0) { ArrayPush(order, 0); }
    let t: Int32 = 1;
    while t <= 3 {
        if t != activeType { ArrayPush(order, t); }
        t += 1;
    }
    if activeType >= 1 && activeType <= 3 { ArrayPush(order, activeType); }
    // After a load and after the Glamdoc every switcher is sent; other passes (a top change, a
    // ripperdoc) only send the ones whose option changed
    if StrContains(why, "save loaded") || StrContains(why, "glamdoc closed") {
        this.ArmSwapperForgetSwitchersSent();
    }
    let skipped: Int32 = 0;
    for armsType in order {
        if ItemID.IsValid(ArmSwapperEquippedArmsOfType(player, armsType)) {
            let switcher: CName = memory.GetKnownSwitcherName(armsType);
            let index: Int32 = 0;
            if memory.HasStyle(armsType) && memory.IsEnabled(armsType) && ItemID.IsValid(memory.GetStyleItem(armsType)) {
                let record: ref<UIGlamdocCustomizationItem_Record> = TweakDBInterface.GetUIGlamdocCustomizationItemRecord(ItemID.GetTDBID(memory.GetStyleItem(armsType)));
                if IsDefined(record) {
                    index = record.CustomizationIndex();
                    if record.LongSleevesCustomizationIndex() != -1 && EquipmentSystemPlayerData.HasLongSleeves(player) {
                        index = record.LongSleevesCustomizationIndex();
                    }
                    // Another mod saved a different option with this style (Split Cyberarm Styles'
                    // left/right pairs): keep that one
                    let saved: Int32 = memory.GetSwitcherIndex(armsType);
                    if saved >= 0 && saved != record.CustomizationIndex() && saved != record.LongSleevesCustomizationIndex() {
                        index = saved;
                    }
                    // The arms in use: the option the game holds right now, which already follows long
                    // sleeves (the game re-sends it when the top changes, and other mods adjust it there)
                    if armsType == activeType && this.savedData.enabled && this.savedData.customizationItemID == memory.GetStyleItem(armsType)
                        && Equals(this.savedData.switcherName, memory.GetSwitcherName(armsType)) {
                        index = Cast<Int32>(this.savedData.switcherIndex);
                    }
                }
                if NotEquals(memory.GetSwitcherName(armsType), n"None") { switcher = memory.GetSwitcherName(armsType); }
            }
            // MaxTac-based Mantis Blades without a style wear the MaxTac look, through the game's own
            // MaxTac version of the switch
            let maxTac: Bool = false;
            if armsType == 1 && index == 0 {
                let bladeRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(ArmSwapperEquippedArmsOfType(player, 1)));
                maxTac = IsDefined(bladeRecord) && bladeRecord.TagsContains(n"SetMaxTacApperance");
            }
            // Already at this option, and for the blades the MaxTac look is as wanted: nothing to send
            let alreadySent: Bool = this.ArmSwapperSwitcherAlreadySent(switcher, index, maxTac)
                && (armsType != 1 || Equals(this.savedData.hasMaxTacApperanceEquipped, maxTac));
            if NotEquals(switcher, n"None") && alreadySent {
                skipped += 1;
            }
            if NotEquals(switcher, n"None") && !alreadySent {
                if maxTac {
                    if !this.savedData.hasMaxTacApperanceEquipped { this.SetMaxTacApperance(); }
                    this.SetIndexForCustomizationSwitcherWithMaxTacAppearance(switcher, Cast<Uint32>(index), true);
                } else {
                    if armsType == 1 && this.savedData.hasMaxTacApperanceEquipped { this.RemoveMaxTacApperance(); }
                    this.SetIndexForCustomizationSwitcher(switcher, Cast<Uint32>(index), true);
                }
                this.ArmSwapperNoteSwitcherSent(switcher, index, maxTac);
                ArmSwapperLog(this.GetGameInstance(), "switchers (" + why + "): " + NameToString(switcher) + " set to " + IntToString(index)
                    + (maxTac ? " with the MaxTac look" : ""));
            }
        }
    }
    if skipped > 0 {
        ArmSwapperLog(this.GetGameInstance(), "switchers (" + why + "): " + IntToString(skipped) + " already at their option, not sent again");
    }
    // The arms in use keep their colours
    this.ArmSwapperPaintSaved(ArmSwapperSwitchersReason(why));
    // Native styling: the style changes can leave other arm types' pieces on V, with no arms attaching
    // to tidy them away
    ArmSwapperTidyWornNow(player, "switchers set");
}

// Drawing a different set of arms puts its style back
@wrapMethod(EquipmentSystemPlayerData)
private final func DrawItem(itemToDraw: ItemID, drawAnimationType: gameEquipAnimationType) {
    wrappedMethod(itemToDraw, drawAnimationType);
    ArmSwapperLog(this.m_owner.GetGame(), "draw " + ArmSwapperName(itemToDraw) + ". " + ArmSwapperArmsState(this.m_owner));
    if ItemID.IsValid(itemToDraw) && Equals(EquipmentSystem.GetEquipAreaType(itemToDraw), gamedataEquipmentArea.BaseFists) {
        ArmSwapperProbeSoon(this.m_owner as PlayerPuppet, itemToDraw);
    }
    if !ItemID.IsValid(itemToDraw) || !TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemToDraw)).TagsContains(n"Meleeware") { return; }
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(this.m_owner.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        system.ArmSwapperApplyStyleFor(itemToDraw);
    }
}

// --- The Glamdoc menu ---
// The game can only paint the arms V has active. Picking another equipped arm type on the
// Glamdoc's tabs therefore really switches V to those arms first, then reloads the menu for
// them. Buying keeps the menu open, so every arm type can be done in one visit.

// Makes the given arm cyberware V's active arms without drawing them, the way the game
// remembers the last used arms. Returns false if they are not equipped.
@addMethod(EquipmentSystemPlayerData)
public func ArmSwapperMakeActiveArms(arms: ItemID) -> Bool {
    let areaIndex: Int32 = this.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex < 0 || !ItemID.IsValid(arms) { return false; }
    let i: Int32 = 0;
    while i < ArraySize(this.m_equipment.equipAreas[areaIndex].equipSlots) {
        if this.m_equipment.equipAreas[areaIndex].equipSlots[i].itemID == arms {
            this.m_equipment.equipAreas[areaIndex].activeIndex = i;
            return true;
        }
        i += 1;
    }
    return false;
}

// More than one arm cyberware type equipped, the Projectile Launch System included
public func ArmSwapperHasSeveralArmTypes(player: ref<GameObject>) -> Bool {
    let found: Int32 = 0;
    let armsType: Int32 = 0;
    while armsType < 4 {
        if ItemID.IsValid(ArmSwapperEquippedArmsOfType(player, armsType)) {
            found += 1;
        }
        armsType += 1;
    }
    return found > 1;
}

// The arms V had active when the menu opened, so discarding can switch back to them
@addField(GlamDocGameController)
private let m_armSwapperArmsAtOpen: ItemID;

// True while the launcher tab is open beside melee arms. The menu then works on the launcher,
// while V's active arms stay the melee arms.
@addField(GlamDocGameController)
private let m_armSwapperLauncherMode: Bool;

@addMethod(GlamDocGameController)
public func ArmSwapperInLauncherMode() -> Bool {
    return this.m_armSwapperLauncherMode;
}

// The arms the menu is working on: the launcher on its tab beside melee arms, else V's active arms
@addMethod(GlamDocGameController)
private func ArmSwapperActiveArms() -> ItemID {
    if this.m_armSwapperLauncherMode {
        let launcher: ItemID = ArmSwapperEquippedArmsOfType(this.m_player, 0);
        if ItemID.IsValid(launcher) { return launcher; }
    }
    return EquipmentSystem.GetData(this.m_player).GetActiveMeleeWare();
}

// The launcher tab shows the launcher on the preview character, not the active melee arms
@wrapMethod(GlamDocGameController)
private final func UpdatePuppetWithCyberware(itemToEquip: ItemID) {
    if this.m_armSwapperLauncherMode && (new SimpleArmSwapperSettings()).stylePerArmType {
        let launcher: ItemID = ArmSwapperEquippedArmsOfType(this.m_player, 0);
        if ItemID.IsValid(launcher) {
            ArmSwapperLog(this.m_player.GetGame(), "glamdoc preview shows the launcher instead of " + ArmSwapperName(itemToEquip));
            itemToEquip = launcher;
            // The game only puts the arms in the preview's hand while a style is on; otherwise it
            // shows the arms put away, which on this tab would be the melee arms. Without a style
            // the preview wears the launcher put away instead, as the game shows a plain launcher.
            // Launchers with no put-away version go in the hand, plain.
            if !this.DoesPlayerHaveGlamEquipped() && !ItemID.IsValid(ArmSwapperLauncherHolstered(launcher)) {
                this.m_armSwapperDressingLauncher = true;
            }
        }
    }
    wrappedMethod(itemToEquip);
    this.m_armSwapperDressingLauncher = false;
    this.ArmSwapperPreviewLauncherPutAway();
}

@addField(GlamDocGameController)
private let m_armSwapperDressingLauncher: Bool;

// The put-away (holstered) item of the launcher, if it has one
public func ArmSwapperLauncherHolstered(launcher: ItemID) -> ItemID {
    let record: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(launcher));
    if !IsDefined(record) || !IsDefined(record.HolsteredItem()) { return ItemID.None(); }
    return ItemID.CreateQuery(record.HolsteredItem().GetID());
}

// Launcher tab without a style: the preview's put-away arms are the launcher's, not the melee arms
@addMethod(GlamDocGameController)
public func ArmSwapperPreviewLauncherPutAway() {
    if !this.m_armSwapperLauncherMode || !(new SimpleArmSwapperSettings()).stylePerArmType || this.DoesPlayerHaveGlamEquipped() { return; }
    let puppet: ref<GameObject> = this.m_previewPuppet;
    if !IsDefined(puppet) { return; }
    let holstered: ItemID = ArmSwapperLauncherHolstered(ArmSwapperEquippedArmsOfType(this.m_player, 0));
    if !ItemID.IsValid(holstered) { return; }
    let current: ref<ItemObject> = this.m_transactionSystem.GetItemInSlot(puppet, t"AttachmentSlots.RightArm");
    if IsDefined(current) && ItemID.GetTDBID(current.GetItemID()) == ItemID.GetTDBID(holstered) { return; }
    this.m_transactionSystem.RemoveItemFromSlot(puppet, t"AttachmentSlots.RightArm");
    if !this.m_transactionSystem.HasItem(puppet, holstered) {
        this.m_transactionSystem.GiveItem(puppet, holstered, 1);
    }
    this.m_transactionSystem.AddItemToSlot(puppet, t"AttachmentSlots.RightArm", holstered);
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc preview wears the launcher put away: " + ArmSwapperName(holstered));
}

@wrapMethod(GlamDocGameController)
public func DoesPlayerHaveGlamEquipped() -> Bool {
    if this.m_armSwapperDressingLauncher { return true; }
    return wrappedMethod();
}

// Locks in what has been done so far in this visit: "discard changes" (Back) will only undo
// edits made after this point. Called after every purchase and every arm type switch, so
// Back never throws away a purchase or another arm type's style.
@addMethod(GlamDocGameController)
private func ArmSwapperCommitEdits() {
    let game: GameInstance = this.m_player.GetGame();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) { memory.TakeSnapshot(); }
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        this.m_styleDataWhenEnteringGlamdoc = system.GetSavedData();
    }
    let activeMelee: ItemID = EquipmentSystem.GetData(this.m_player).GetActiveMeleeWare();
    if ItemID.IsValid(activeMelee) {
        this.m_armSwapperArmsAtOpen = activeMelee;
    }
    ArmSwapperLog(game, "glamdoc edits locked in. " + ArmSwapperArmsState(this.m_player));
}

// Switches V to the given arms, shows them with their own style and reloads the menu for them
@addMethod(GlamDocGameController)
private func ArmSwapperSwitchTo(arms: ItemID) {
    let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
    ArmSwapperLog(player.GetGame(), "glamdoc switch to " + ArmSwapperName(arms) + ". Before: " + ArmSwapperArmsState(player)
        + " preview armSlot=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.RightArm")
        + " preview hand=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.WeaponRight"));
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return; }
    // The launcher never becomes the active arms: the melee arms stay V's arms
    let toLauncher: Bool = ArmSwapperArmsType(arms) == 0;
    if !toLauncher && !eqData.ArmSwapperMakeActiveArms(arms) { return; }
    // A style previewed for the previous arms does not carry over
    this.m_armSwapperPreviewItem = ItemID.None();
    // The holstered arms in third person follow along
    if !toLauncher {
        EquipmentSystemPlayerData.UpdateArmSlot(player, arms, true);
    }

    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        system.ArmSwapperApplyStyleFor(arms, true);
        let savedData: CyberwareCustomizationPersistentData = system.GetSavedData();
        this.UpdateCurrentCustomizationItem(savedData.customizationItemID);
        this.InitializeBrandData(CyberwareCustomizationPersistentData.GetBrandDataID(savedData));
        this.m_colorADefined = false;
        this.m_colorBDefined = false;
        this.ProcessPreviousCustomizationState();
    }
    this.InitializeEquippedCyberArm();
    this.DisplayInventory();
    if IsDefined(this.m_minigridController) {
        this.m_minigridController.UpdateData(gamedataEquipmentArea.ArmsCWStyle, this.m_uiInventorySystem.GetPlayerAreaItems(gamedataEquipmentArea.ArmsCWStyle));
    }

    // Rebuild the preview character from scratch, the way the menu builds it when it opens:
    // the game dresses a fresh one from V's new arms and hands it to the menu, which sets
    // it up for those arms. Editing the old one leaves the menu, the game's preview sync
    // and the previous tab's listener all changing it at once.
    // Styling still queued for the old preview character stops here
    this.m_armSwapperPreviewHidden = true;
    this.m_armSwapperPreviewRun += 1;
    this.HidePuppetPreview();
    this.ReloadPreviewPuppet(n"inventory");
    this.ArmSwapperCommitEdits();
    ArmSwapperDumpGlamdoc(this, "after tab switch", false);
    ArmSwapperLog(player.GetGame(), "glamdoc switch done. After: " + ArmSwapperArmsState(player)
        + " glamOn=" + BoolToString(this.DoesPlayerHaveGlamEquipped())
        + " previewArms=" + ArmSwapperName(this.m_currentCyberarmItem)
        + " previewSlot=" + TDBID.ToStringDEBUG(EquipmentSystem.GetPlacementSlot(this.m_currentCyberarmItem))
        + " holds " + ArmSwapperSlotName(this.m_previewPuppet, EquipmentSystem.GetPlacementSlot(this.m_currentCyberarmItem))
        + " preview left=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.WeaponLeft")
        + " preview armSlot=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.RightArm")
        + " preview hand=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.WeaponRight"));
}

@wrapMethod(GlamDocGameController)
protected cb func OnInitialize() -> Bool {
    let game: GameInstance = GetGameInstance();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) {
        memory.glamdocOpen = true;
        memory.glamdoc = this;
        // Show the arms in use with their own style before the menu reads it, and keep a
        // copy of every type's style so "discard changes" can put them all back
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) {
            system.ArmSwapperApplyStyleForActiveArms(true);
        }
        memory.TakeSnapshot();
    }
    let result: Bool = wrappedMethod();
    this.m_armSwapperArmsAtOpen = this.ArmSwapperActiveArms();
    ArmSwapperLog(game, "glamdoc opened. " + ArmSwapperArmsState(this.m_player) + " glamOn=" + BoolToString(this.DoesPlayerHaveGlamEquipped()));
    ArmSwapperLog(game, ArmSwapperArmSlotsText(this.m_player));
    ArmSwapperDumpGlamdoc(this, "opened", true);
    return result;
}

@wrapMethod(GlamDocGameController)
protected cb func OnUninitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let game: GameInstance = GetGameInstance();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) {
        memory.glamdocOpen = false;
        memory.glamdoc = null;
    }
    this.m_armSwapperLauncherMode = false;

    // The game puts V's weapons away while the menu is open and draws them again after it
    // closes; ArmSwapperArmsInHand matches the style to whatever arms come back.
    let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
    ArmSwapperLog(game, "glamdoc closed. " + ArmSwapperArmsState(player));
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        system.ArmSwapperApplyStyleForActiveArms();
        // A moment after the menu closes, once the game has drawn V's weapons again
        if (new SimpleArmSwapperSettings()).stylePerArmType {
            system.ArmSwapperSetAllSwitchersLater("glamdoc closed", 1.5);
        }
    }
    return result;
}

// Discarding puts every arm type's style back, and the arms that were active when the menu
// opened, before the menu restores its own copy of their style
@wrapMethod(GlamDocGameController)
private final func DiscardChangesAndQuitVendor() {
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc closing without applying (changes to discard: " + BoolToString(this.m_hasChangesToApply) + ")");
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
    if IsDefined(memory) { memory.RestoreSnapshot(); }
    // Back to the melee arms; the launcher was never V's active arms
    this.m_armSwapperLauncherMode = false;
    if ItemID.IsValid(this.m_armSwapperArmsAtOpen) && !(this.m_armSwapperArmsAtOpen == this.ArmSwapperActiveArms()) {
        let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
        let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if IsDefined(eqData) && eqData.ArmSwapperMakeActiveArms(this.m_armSwapperArmsAtOpen) {
            EquipmentSystemPlayerData.UpdateArmSlot(player, this.m_armSwapperArmsAtOpen, true);
        }
    }
    wrappedMethod();
}

// Styles fit the active arms, wherever they sit, not only the arms in the first slot
@wrapMethod(GlamDocGameController)
private final func CheckIfCanApply(itemData: wref<gameItemData>) -> Bool {
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !IsDefined(itemData) { return wrappedMethod(itemData); }
    let activeType: Int32 = ArmSwapperArmsType(this.ArmSwapperActiveArms());
    if activeType < 0 { return wrappedMethod(itemData); }
    let canApply: Bool = this.ItemTagToIndex(itemData) == activeType;
    ArmSwapperLog(this.m_player.GetGame(), "can apply " + ArmSwapperName(itemData.GetID()) + ": " + BoolToString(canApply)
        + " (style type " + IntToString(this.ItemTagToIndex(itemData)) + ", arms type " + IntToString(activeType) + ")");
    return canApply;
}

// The menu opens on the type of the active arms
@wrapMethod(GlamDocGameController)
private final func GetCurrentArmsWareType() -> ArmsWareType {
    if (new SimpleArmSwapperSettings()).stylePerArmType {
        let armsType: Int32 = ArmSwapperArmsType(this.ArmSwapperActiveArms());
        if armsType >= 0 {
            return IntEnum<ArmsWareType>(armsType);
        }
    }
    return wrappedMethod();
}

@wrapMethod(GlamDocGameController)
private final func InitializeEquippedCyberArm() {
    wrappedMethod();
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let arms: ItemID = this.ArmSwapperActiveArms();
    if !ItemID.IsValid(arms) { return; }
    let items: array<wref<UIInventoryItem>> = this.m_uiInventorySystem.GetPlayerAreaItems(gamedataEquipmentArea.ArmsCW);
    for item in items {
        if IsDefined(item) && item.GetID() == arms {
            this.m_equippedArmItem = item;
        }
    }
}

// Picking the tab of another equipped arm type switches V to those arms
@wrapMethod(GlamDocGameController)
protected cb func OnSelectorChange(evt: ref<GlamdocSelectorChangeEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return result; }
    if NotEquals(this.m_screenType, GlamdocScreenType.Appearance) || this.m_isInPopup { return result; }
    let tabType: Int32 = -1;
    if Equals(this.m_filterArea, ArmsWareType.Launcher) { tabType = 0; }
    if Equals(this.m_filterArea, ArmsWareType.MantisBlades) { tabType = 1; }
    if Equals(this.m_filterArea, ArmsWareType.NanoWires) { tabType = 2; }
    if Equals(this.m_filterArea, ArmsWareType.StrongArms) { tabType = 3; }
    if tabType < 0 { return result; }
    let arms: ItemID = ArmSwapperEquippedArmsOfType(this.m_player, tabType);
    // The launcher tab works on the launcher while the melee arms stay V's arms. A launcher with no
    // melee arms beside it is V's arms already, and keeps the game's behaviour.
    let toLauncher: Bool = tabType == 0;
    if toLauncher && ArmSwapperArmsType(EquipmentSystem.GetData(this.m_player).GetActiveMeleeWare()) < 1 { return result; }
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc tab " + IntToString(tabType) + " -> arms " + ArmSwapperName(arms));
    if !ItemID.IsValid(arms) { return result; }
    // The last tab switch is still building its preview character: this one waits for it, and
    // only the latest tab picked meanwhile is switched to. Switching again while V's arms and the
    // preview were still changing could crash the game.
    if ArmSwapperNow(this.m_player.GetGame()) < this.m_armSwapperTabBusyUntil {
        this.m_armSwapperTabPending = arms;
        this.m_armSwapperTabPendingLauncher = toLauncher;
        ArmSwapperLog(this.m_player.GetGame(), "glamdoc tab switch waits for the preview character");
        return result;
    }
    this.ArmSwapperTabTo(arms, toLauncher);
    return result;
}

// The tab switch itself, once no other one is still building its preview
@addMethod(GlamDocGameController)
private func ArmSwapperTabTo(arms: ItemID, toLauncher: Bool) {
    let tabType: Int32 = toLauncher ? 0 : ArmSwapperArmsType(arms);
    if NotEquals(this.m_armSwapperLauncherMode, toLauncher) || ArmSwapperArmsType(this.ArmSwapperActiveArms()) != tabType {
        // Leave a preview first. Otherwise the tab shows the other arms' styles while V keeps
        // the previous arms, and none of those styles can be picked. A style just bought is
        // kept (the menu is only waiting for the preview character); one only previewed is undone.
        if this.m_isInPreviewMode {
            let justBought: Bool = this.m_isPuppetWaitingForPreviewModeExit;
            ArmSwapperLog(this.m_player.GetGame(), "glamdoc leaving preview for the tab switch (just bought: " + BoolToString(justBought) + ")");
            this.ExitPreviewMode(justBought);
            this.m_isPuppetWaitingForPreviewModeExit = false;
            this.m_isProcessingCustomizationChange = false;
        }
        this.m_armSwapperLauncherMode = toLauncher;
        this.m_armSwapperTabBusyUntil = ArmSwapperNow(this.m_player.GetGame()) + 2.0;
        this.ArmSwapperSwitchTo(arms);
        // Should the preview never report back, a waiting tab still gets its turn
        let check: ref<ArmSwapperTabPendingCallback> = new ArmSwapperTabPendingCallback();
        check.glamdoc = this;
        GameInstance.GetDelaySystem(this.m_player.GetGame()).DelayCallback(check, 2.05, false);
    }
}

// A preview character arrived (or the wait ran out): run the tab switch that was waiting, if any
@addMethod(GlamDocGameController)
public func ArmSwapperRunPendingTab() {
    this.m_armSwapperTabBusyUntil = 0.0;
    if !ItemID.IsValid(this.m_armSwapperTabPending) { return; }
    let arms: ItemID = this.m_armSwapperTabPending;
    let toLauncher: Bool = this.m_armSwapperTabPendingLauncher;
    this.m_armSwapperTabPending = ItemID.None();
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc waiting tab switch now runs: " + ArmSwapperName(arms));
    this.ArmSwapperTabTo(arms, toLauncher);
}

public class ArmSwapperTabPendingCallback extends DelayCallback {
    public let glamdoc: wref<GlamDocGameController>;

    public func Call() -> Void {
        let glamdoc: ref<GlamDocGameController> = this.glamdoc;
        if !IsDefined(glamdoc) { return; }
        if ArmSwapperNow(GetGameInstance()) >= glamdoc.m_armSwapperTabBusyUntil {
            glamdoc.ArmSwapperRunPendingTab();
        }
    }
}

// Until when the last tab switch is building its preview character, in engine time
@addField(GlamDocGameController)
public let m_armSwapperTabBusyUntil: Float;

// The latest tab picked while another was still building its preview
@addField(GlamDocGameController)
public let m_armSwapperTabPending: ItemID;

@addField(GlamDocGameController)
public let m_armSwapperTabPendingLauncher: Bool;

// With more than one arm type equipped, buying keeps the menu open so the other arms can be
// styled too. "Apply and close" then keeps the changes; Back discards them, as in the game.
@wrapMethod(GlamDocGameController)
public func OnItemBought(itemID: ItemID, itemData: wref<gameItemData>) {
    if (new SimpleArmSwapperSettings()).stylePerArmType && ArmSwapperHasSeveralArmTypes(this.m_player) {
        this.m_isExitingMenuAfterBuy = false;
    }
    wrappedMethod(itemID, itemData);
    if (new SimpleArmSwapperSettings()).stylePerArmType && ArmSwapperHasSeveralArmTypes(this.m_player) {
        this.ArmSwapperCommitEdits();
    }
    ArmSwapperDumpGlamdoc(this, "after buying", false);
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc bought " + ArmSwapperName(itemID) + ". " + ArmSwapperArmsState(this.m_player)
        + " glamOn=" + BoolToString(this.DoesPlayerHaveGlamEquipped())
        + " preview armSlot=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.RightArm")
        + " preview hand=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.WeaponRight")
        + " preview left=" + ArmSwapperSlotName(this.m_previewPuppet, t"AttachmentSlots.WeaponLeft"));
}

// While a style is being previewed, F buys it and keeps the menu open. Say so on the
// button, so it is clear that F is pressed once to buy and again to apply and close.
@wrapMethod(GlamDocGameController)
private final func EnterPreviewMode(item: wref<UIInventoryItem>) {
    wrappedMethod(item);
    if IsDefined(item) {
        this.m_armSwapperPreviewItem = item.GetID();
        ArmSwapperDumpGlamdoc(this, "previewing", false);
        this.ArmSwapperStylePreviewSoon(item.GetID(), "previewing");
    }
    if (new SimpleArmSwapperSettings()).stylePerArmType && ArmSwapperHasSeveralArmTypes(this.m_player) {
        this.m_buttonHintsController.AddButtonHint(n"UI_Apply", SimpleArmSwapperText("SimpleArmSwapper-Glamdoc-BuyAndApply"));
    }
}

@wrapMethod(GlamDocGameController)
private final func ExitPreviewMode(opt skipRestorePreviousCyberware: Bool) {
    wrappedMethod(skipRestorePreviousCyberware);
    this.m_armSwapperPreviewItem = ItemID.None();
    this.ArmSwapperStylePreviewSoon(ItemID.None(), "preview left");
    if this.m_hasChangesToApply {
        this.m_buttonHintsController.AddButtonHint(n"UI_Apply", GetLocalizedText("Gameplay-Cyberware-PimpMyChrome-Hints-CloseApply"));
    }
}

// ---------------------------------------------------------------------------
// Text shown by the mod, registered with Codeware's localization system so it can
// be translated.
//
// To add a language, copy SimpleArmSwapperLanguageEnglish into a new class,
// translate the second string of every line and leave the first alone, then return
// the new class for that language from SimpleArmSwapperLocalizationProvider.GetPackage.
//
// Codeware is optional. Without it the English text at the bottom is used. The Mod
// Settings page is written in English only.
// ---------------------------------------------------------------------------

@if(ModuleExists("Codeware.Localization"))
public class SimpleArmSwapperLocalizationProvider extends ModLocalizationProvider {
    public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
        switch language {
            // case n"fr-fr": return new SimpleArmSwapperLanguageFrench();
            default: return new SimpleArmSwapperLanguageEnglish();
        }
    }

    public func GetFallback() -> CName {
        return n"en-us";
    }
}

@if(ModuleExists("Codeware.Localization"))
public class SimpleArmSwapperLanguageEnglish extends ModLocalizationPackage {
    protected func DefineTexts() -> Void {
        // Glamdoc: the F key's label while a style is previewed and more than one arm type is equipped
        this.Text("SimpleArmSwapper-Glamdoc-BuyAndApply", "Buy and apply (F again to close)");
    }
}

// Text in the language the game is set to
@if(ModuleExists("Codeware.Localization"))
public func SimpleArmSwapperText(key: String) -> String {
    let text: String = GetLocalizedTextByKey(StringToName(key));
    return Equals(text, "") || Equals(text, key) ? key : text;
}

// Without Codeware: the same English as SimpleArmSwapperLanguageEnglish. Keep the two in step.
@if(!ModuleExists("Codeware.Localization"))
public func SimpleArmSwapperText(key: String) -> String {
    switch key {
        case "SimpleArmSwapper-Glamdoc-BuyAndApply": return "Buy and apply (F again to close)";
    }
    return key;
}

@wrapMethod(GlamdocAttachmentSlotsScriptCallback)
private final func ShowPuppetPreviewOnceItemsVisualsAreUpdated(slot: TweakDBID, item: ItemID) {
    if slot == t"AttachmentSlots.RightArm" || slot == t"AttachmentSlots.WeaponRight" || slot == t"AttachmentSlots.WeaponLeft" {
        ArmSwapperLog(this.m_player.GetGame(), "preview slot " + TDBID.ToStringDEBUG(slot) + " got " + ArmSwapperName(item)
        + " (waiting for " + TDBID.ToStringDEBUG(this.m_slotToWaitFor) + "/" + ArmSwapperName(this.m_itemToWaitFor)
        + ", clears " + TDBID.ToStringDEBUG(this.m_slotToClear) + ")");
    }
    // Style the preview character before the game shows it, so it never appears unstyled
    if slot == t"AttachmentSlots.RightArm" || slot == t"AttachmentSlots.WeaponRight" || slot == t"AttachmentSlots.WeaponLeft" {
        let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
        if IsDefined(memory) {
            let glamdoc: ref<GlamDocGameController> = memory.glamdoc;
            if IsDefined(glamdoc) {
                glamdoc.ArmSwapperStylePreviewArrived();
            }
        }
    }
    wrappedMethod(slot, item);
    // The game can bring the melee arms back as the preview's put-away arms on the launcher tab
    if slot == t"AttachmentSlots.RightArm" {
        let tabMemory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
        if IsDefined(tabMemory) && IsDefined(tabMemory.glamdoc) {
            tabMemory.glamdoc.ArmSwapperPreviewLauncherPutAway();
        }
    }
}

// The preview character's arms just arrived: style it with whatever it should show right now
@addMethod(GlamDocGameController)
public func ArmSwapperStylePreviewArrived() {
    this.ArmSwapperStylePreviewNow(this.m_armSwapperPreviewItem, this.m_armSwapperPreviewRun, "arms arrived", false);
}

@wrapMethod(GlamDocGameController)
protected cb func OnInventoryPuppetReceived(puppet: ref<gamePuppet>) -> Bool {
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc preview character received. " + ArmSwapperArmsState(this.m_player));
    let result: Bool = wrappedMethod(puppet);
    // Previewing a style also builds a new preview character, which should show that style
    this.ArmSwapperStylePreviewSoon(this.m_armSwapperPreviewItem, "new preview");
    // A tab switch that was waiting for this preview gets its turn now
    if this.m_armSwapperTabBusyUntil > 0.0 {
        this.ArmSwapperRunPendingTab();
    }
    return result;
}

// --- Debug probe: V's arm meshes (needs Codeware; only runs with Debug Logging on) ---

public func ArmSwapperIsArmPart(name: CName) -> Bool {
    let n: String = StrLower(NameToString(name));
    return StrContains(n, "a0_") || StrContains(n, "arm") || StrContains(n, "hand") || StrContains(n, "mantis")
        || StrContains(n, "blade") || StrContains(n, "nano") || StrContains(n, "wire") || StrContains(n, "strong")
        || StrContains(n, "launcher") || StrContains(n, "cyber") || StrContains(n, "fist") || StrContains(n, "glam");
}

@if(ModuleExists("Codeware"))
public func ArmSwapperDumpMeshes(game: GameInstance, owner: ref<Entity>, label: String) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(owner) { return; }
    let comps: array<ref<IComponent>> = owner.GetComponents();
    let shown: Int32 = 0;
    for comp in comps {
        if IsDefined(comp) && ArmSwapperIsArmPart(comp.GetName()) {
            let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
            let mesh: ref<MeshComponent> = comp as MeshComponent;
            if IsDefined(skinned) {
                let meshRef: ResourceAsyncRef = skinned.mesh;
                ArmSwapperLog(game, label + " skinned " + NameToString(comp.GetName()) + " mesh=" + ResRef.ToString(ResourceAsyncRef.GetPath(meshRef)) + " app=" + NameToString(skinned.meshAppearance)
                    + " on=" + BoolToString(comp.IsEnabled()) + " mask=" + s"\(skinned.chunkMask)");
                shown += 1;
            } else {
                if IsDefined(mesh) {
                    ArmSwapperLog(game, label + " mesh " + NameToString(comp.GetName()) + " app=" + NameToString(mesh.meshAppearance)
                        + " on=" + BoolToString(comp.IsEnabled()));
                    shown += 1;
                } else {
                    ArmSwapperLog(game, label + " other " + NameToString(comp.GetName()) + " on=" + BoolToString(comp.IsEnabled()));
                }
            }
        }
    }
    ArmSwapperLog(game, label + ": " + IntToString(ArraySize(comps)) + " components, " + IntToString(shown) + " arm meshes listed");
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperDumpMeshes(game: GameInstance, owner: ref<Entity>, label: String) {}

// --- Debug probe: V's head, hair and beard pieces (needs Codeware; only runs with Debug Logging on) ---
// In first person the game hides these or keeps them for shadows only. The mod never changes them;
// this records their state next to the mod's own arm changes, so a stray head or hair piece in first
// person can be matched to what happened just before it.

@addField(PlayerPuppet)
public let m_armSwapperHeadNames: array<String>;

@addField(PlayerPuppet)
public let m_armSwapperHeadStates: array<String>;

public func ArmSwapperIsHeadPart(name: CName) -> Bool {
    let n: String = StrLower(NameToString(name));
    if StrBeginsWith(n, "a0_") { return false; }
    return StrContains(n, "head") || StrContains(n, "hair") || StrContains(n, "beard") || StrContains(n, "face")
        || StrContains(n, "shadow") || StrContains(n, "brow") || StrContains(n, "lash")
        || StrBeginsWith(n, "h0_") || StrBeginsWith(n, "h1_") || StrBeginsWith(n, "hx_") || StrBeginsWith(n, "hh_")
        || StrBeginsWith(n, "hb_") || StrBeginsWith(n, "he_") || StrBeginsWith(n, "heb_") || StrBeginsWith(n, "ht_");
}

// What a piece is attached to and skinned to, and its draw settings
@if(ModuleExists("Codeware"))
public func ArmSwapperHeadPieceBinding(comp: ref<IComponent>) -> String {
    let text: String = "";
    let placed: ref<IPlacedComponent> = comp as IPlacedComponent;
    if IsDefined(placed) {
        let parent: ref<entITransformBinding> = placed.parentTransform;
        if IsDefined(parent) {
            let hard: ref<entHardTransformBinding> = parent as entHardTransformBinding;
            text += " parent=" + NameToString(parent.bindName) + (IsDefined(hard) ? "/" + NameToString(hard.slotName) : "") + (parent.enabled ? "" : "(off)");
        } else {
            text += " parent=none";
        }
    }
    let skinTarget: ref<entISkinTargetComponent> = comp as entISkinTargetComponent;
    if IsDefined(skinTarget) {
        let skin: ref<entSkinningBinding> = skinTarget.skinning;
        text += IsDefined(skin) ? " skin=" + NameToString(skin.bindName) + (skin.enabled ? "" : "(off)") : " skin=none";
    }
    let visual: ref<IVisualComponent> = comp as IVisualComponent;
    if IsDefined(visual) {
        text += " lod=" + IntToString(Cast<Int32>(visual.forceLODLevel)) + " autoHide=" + FloatToStringPrec(visual.autoHideDistance, 1);
    }
    return text;
}

@if(ModuleExists("Codeware"))
public func ArmSwapperHeadPieceState(comp: ref<IComponent>) -> String {
    let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
    if IsDefined(skinned) {
        let meshRef: ResourceAsyncRef = skinned.mesh;
        return "skinned mesh=" + ResRef.ToString(ResourceAsyncRef.GetPath(meshRef)) + " app=" + NameToString(skinned.meshAppearance)
            + " on=" + BoolToString(comp.IsEnabled()) + " mask=" + s"\(skinned.chunkMask)"
            + " shadows=" + IntToString(EnumInt(skinned.castShadows)) + "/" + IntToString(EnumInt(skinned.castLocalShadows))
            + " visParam=" + NameToString(skinned.visibilityAnimationParam) + " planeParam=" + NameToString(skinned.renderingPlaneAnimationParam)
            + ArmSwapperHeadPieceBinding(comp);
    }
    let plain: ref<MeshComponent> = comp as MeshComponent;
    if IsDefined(plain) {
        let plainRef: ResourceAsyncRef = plain.mesh;
        return "mesh mesh=" + ResRef.ToString(ResourceAsyncRef.GetPath(plainRef)) + " app=" + NameToString(plain.meshAppearance)
            + " on=" + BoolToString(comp.IsEnabled()) + " mask=" + s"\(plain.chunkMask)"
            + " shadows=" + IntToString(EnumInt(plain.castShadows)) + "/" + IntToString(EnumInt(plain.castLocalShadows))
            + " plane=" + IntToString(EnumInt(plain.renderingPlane)) + ArmSwapperHeadPieceBinding(comp);
    }
    return "";
}

// Logs V's head, hair and beard pieces: all of them when full is set, otherwise only the ones that
// appeared, changed or went away since the last check
@if(ModuleExists("Codeware"))
public func ArmSwapperCheckHead(player: ref<PlayerPuppet>, label: String, opt full: Bool) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    let game: GameInstance = player.GetGame();
    let names: array<String>;
    let states: array<String>;
    let baseNames: array<String>;
    let changes: Int32 = 0;
    for comp in player.GetComponents() {
        if IsDefined(comp) && ArmSwapperIsHeadPart(comp.GetName()) {
            let state: String = ArmSwapperHeadPieceState(comp);
            if NotEquals(state, "") {
                let name: String = NameToString(comp.GetName());
                // Several pieces can share a name: number the copies #1, #2 and so on
                let copy: Int32 = 0;
                for seen in baseNames { if Equals(seen, name) { copy += 1; } }
                ArrayPush(baseNames, name);
                if copy > 0 { name += "#" + IntToString(copy); }
                ArrayPush(names, name);
                ArrayPush(states, state);
                let before: Int32 = -1;
                let i: Int32 = 0;
                while i < ArraySize(player.m_armSwapperHeadNames) {
                    if Equals(player.m_armSwapperHeadNames[i], name) { before = i; }
                    i += 1;
                }
                if full || before < 0 || NotEquals(player.m_armSwapperHeadStates[before], state) {
                    if changes == 0 {
                        ArmSwapperLog(game, "head check (" + label + "), in vehicle " + BoolToString(VehicleComponent.IsMountedToVehicle(game, player)));
                    }
                    changes += 1;
                    let mark: String = full ? "" : (before < 0 ? " NEW" : " CHANGED, was " + player.m_armSwapperHeadStates[before]);
                    ArmSwapperLog(game, "  head piece " + name + ": " + state + mark);
                }
            }
        }
    }
    let k: Int32 = 0;
    while k < ArraySize(player.m_armSwapperHeadNames) {
        if !ArrayContains(names, player.m_armSwapperHeadNames[k]) {
            if changes == 0 {
                ArmSwapperLog(game, "head check (" + label + "), in vehicle " + BoolToString(VehicleComponent.IsMountedToVehicle(game, player)));
            }
            changes += 1;
            ArmSwapperLog(game, "  head piece " + player.m_armSwapperHeadNames[k] + " GONE");
        }
        k += 1;
    }
    if full {
        ArmSwapperLog(game, "head check (" + label + "): " + IntToString(ArraySize(names)) + " head pieces");
    }
    player.m_armSwapperHeadNames = names;
    player.m_armSwapperHeadStates = states;
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperCheckHead(player: ref<PlayerPuppet>, label: String, opt full: Bool) {}

public class ArmSwapperHeadCheckCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let label: String;

    public func Call() -> Void {
        ArmSwapperCheckHead(this.player, this.label);
    }
}

// From the moment V attaches, checks every few seconds, so a change made by anything (the game, the
// mod or another mod) shows up in the log at about the time it happened
@addField(PlayerPuppet)
public let m_armSwapperHeadWatchRun: Int32;

@addField(PlayerPuppet)
public let m_armSwapperHeadWatchHand: ItemID;

public class ArmSwapperHeadWatchCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let run: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) || player.m_armSwapperHeadWatchRun != this.run || !(new SimpleArmSwapperSettings()).debugLogging { return; }
        // A full list whenever what V holds changes (drawn, holstered, swapped)
        let held: ItemID = ItemID.None();
        let inHand: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
        if IsDefined(inHand) { held = inHand.GetItemID(); }
        if !(held == player.m_armSwapperHeadWatchHand) {
            player.m_armSwapperHeadWatchHand = held;
            ArmSwapperCheckHead(player, "hand now " + ArmSwapperName(held), true);
        } else {
            ArmSwapperCheckHead(player, "watch");
        }
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(this, 1.0, false);
    }
}

public func ArmSwapperStartHeadWatch(player: ref<PlayerPuppet>) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    player.m_armSwapperHeadWatchRun += 1;
    ArmSwapperCheckHead(player, "V attached", true);
    let callback: ref<ArmSwapperHeadWatchCallback> = new ArmSwapperHeadWatchCallback();
    callback.player = player;
    callback.run = player.m_armSwapperHeadWatchRun;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, 1.0, false);
}

// Checks now and again a moment later, after the game has rebuilt what it rebuilds
public func ArmSwapperCheckHeadSoon(player: ref<PlayerPuppet>, label: String) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    ArmSwapperCheckHead(player, label);
    let delays: array<Float> = [0.5, 2.0, 5.0];
    for delay in delays {
        let callback: ref<ArmSwapperHeadCheckCallback> = new ArmSwapperHeadCheckCallback();
        callback.player = player;
        callback.label = label + " +" + FloatToStringPrec(delay, 1) + "s";
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

// Which arm items the item system holds in the arm attachment slots, and which one is active there
public func ArmSwapperDumpArmSlots(game: GameInstance, player: ref<PlayerPuppet>) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(game);
    let slots: array<TweakDBID> = [t"AttachmentSlots.WeaponRight", t"AttachmentSlots.WeaponLeft", t"AttachmentSlots.RightArm"];
    let names: array<String> = ["WeaponRight", "WeaponLeft", "RightArm"];
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    let areaIndex: Int32 = IsDefined(eqData) ? eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW) : -1;
    let k: Int32 = 0;
    while k < ArraySize(slots) {
        let line: String = names[k] + ": active=" + ArmSwapperName(ts.GetActiveItemInSlot(player, slots[k]))
            + " object=" + ArmSwapperSlotName(player, slots[k]) + " holds";
        if areaIndex >= 0 {
            let i: Int32 = 0;
            while i < ArraySize(eqData.m_equipment.equipAreas[areaIndex].equipSlots) {
                let item: ItemID = eqData.m_equipment.equipAreas[areaIndex].equipSlots[i].itemID;
                if ItemID.IsValid(item) {
                    line += " [" + ArmSwapperName(item) + " inSlot=" + BoolToString(ts.HasItemInSlot(player, slots[k], item))
                        + " data=" + BoolToString(ts.HasItemDataInSlot(player, slots[k], item))
                        + " canBeActive=" + BoolToString(ts.CanItemBeActiveInSlot(player, slots[k], item)) + "]";
                }
                i += 1;
            }
        }
        ArmSwapperLog(game, "slot " + line);
        k += 1;
    }
}

public class ArmSwapperProbeCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let arms: ItemID;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) { return; }
        let game: GameInstance = player.GetGame();
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) {
            ArmSwapperLog(game, "probe for " + ArmSwapperName(this.arms) + ": " + ArmSwapperStyleDataText(system.GetSavedData()) + ". " + ArmSwapperArmsState(player));
        }
        ArmSwapperDumpArmSlots(game, player);
        ArmSwapperDumpMeshes(game, player, "V");
        let inHand: ref<ItemObject> = GameInstance.GetTransactionSystem(game).GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
        if IsDefined(inHand) {
            ArmSwapperDumpMeshes(game, inHand, "hand item " + ArmSwapperName(inHand.GetItemID()));
        }
    }
}

public func ArmSwapperProbeSoon(player: ref<PlayerPuppet>, arms: ItemID) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    let callback: ref<ArmSwapperProbeCallback> = new ArmSwapperProbeCallback();
    callback.player = player;
    callback.arms = arms;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, 0.6, false);
}

// One row of the style piece table that 2.7.1 and older painted arm pieces from. Kept, with its
// constructor, for other mods that use it (see SimpleArmSwapperStyleMemory.ArmSwapperStylePieces).
public class ArmSwapperStylePiece {
    public let key: CName;
    public let comp: CName;
    public let mesh: ResRef;
    public let app: CName;
    public let keepSkin: Bool;
    public let mask: Uint64;
    public let hide: Bool;
}

public func ArmSwapperStylePieceNew(key: CName, comp: CName, mesh: ResRef, app: CName, keepSkin: Bool, mask: Uint64, hide: Bool) -> ref<ArmSwapperStylePiece> {
    let piece: ref<ArmSwapperStylePiece> = new ArmSwapperStylePiece();
    piece.key = key;
    piece.comp = comp;
    piece.mesh = mesh;
    piece.app = app;
    piece.keepSkin = keepSkin;
    piece.mask = mask;
    piece.hide = hide;
    return piece;
}

// --- Arm styles in every arm slot ---
// The game styles arm cyberware itself once Simple Arm Swapper Native is installed (see "Native
// styling" below): the mod only sets each arm type's style switcher and tidies away pieces of other
// arm types. Without the plugin, arms outside the first arm slot show their plain look.

// The style index the game would use for a style item on this player (long sleeves change it)
public func ArmSwapperStyleIndex(player: ref<PlayerPuppet>, styleItem: ItemID) -> Int32 {
    let record: ref<UIGlamdocCustomizationItem_Record> = TweakDBInterface.GetUIGlamdocCustomizationItemRecord(ItemID.GetTDBID(styleItem));
    if !IsDefined(record) { return -1; }
    let index: Int32 = record.CustomizationIndex();
    let longSleevesIndex: Int32 = record.LongSleevesCustomizationIndex();
    if longSleevesIndex != -1 && EquipmentSystemPlayerData.HasLongSleeves(player) {
        index = longSleevesIndex;
    }
    return index;
}

// Called wherever arms appear on V or on a copy of V (photo mode, inventory, Glamdoc preview). The
// game styles the arms itself; copies only get other arm types' leftover pieces tidied away (V's are
// tidied in ArmSwapperTidyWorn). Kept as one entry point so all those places stay hooked up.
@if(ModuleExists("Codeware"))
public func ArmSwapperStylePiecesOf(player: ref<PlayerPuppet>, owner: ref<Entity>, arms: ItemID, reason: String, opt view: CName, opt styleOverride: ItemID) -> Int32 {
    if !IsDefined(player) || !IsDefined(owner) || owner == player || !(new SimpleArmSwapperSettings()).stylePerArmType { return -1; }
    if !ArmSwapperNativeStyling(player.GetGame()) { return -1; }
    ArmSwapperHideStrayArms(player, owner, ArmSwapperArmsType(arms));
    return -1;
}

// Styles that keep V's own nails: the plain style and the Barghest Monowire, whose hands are V's own
public func ArmSwapperStyleKeepsOwnNails(armsType: Int32, index: Int32) -> Bool {
    // Gorilla Arms cover the hands: no own nails, as in the base game
    if armsType == 3 { return false; }
    if index <= 0 { return true; }
    // Every Mantis Blade style has chrome hands, Barghest (10, 19) included
    if armsType == 1 { return false; }
    if armsType == 2 { return index == 7; }
    return true;
}

// V's own nails go off under a painted-nail style and come back without one. The game does this
// itself, except after a style change on MaxTac-based blades, where they were left floating.
public func ArmSwapperOwnNails(player: ref<PlayerPuppet>, comps: array<ref<IComponent>>, armsType: Int32, index: Int32) {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if !IsDefined(memory) { return; }
    // The Mantis Blades' own nail pieces (in V's nail colour) belong to the plain style. Every Mantis
    // style replaces them: brand styles with an empty nail entry, Barghest with painted chrome
    // hands. They go off under a style and back on without one.
    if armsType == 1 {
        if index > 0 {
            for comp in comps {
                if IsDefined(comp) && comp.IsEnabled() {
                    let bladeNail: String = NameToString(comp.GetName());
                    if StrBeginsWith(bladeNail, "a0_003_") && StrContains(bladeNail, "mantisblade_nails") {
                        comp.Toggle(false);
                        ArrayPush(memory.hiddenBladeNails, comp);
                        ArmSwapperLog(player.GetGame(), "  Mantis nail piece " + bladeNail + " switched off under style " + IntToString(index));
                    }
                }
            }
        } else {
            if ArraySize(memory.hiddenBladeNails) > 0 {
                for bladeNailComp in memory.hiddenBladeNails {
                    let shownAgain: ref<IComponent> = bladeNailComp;
                    if IsDefined(shownAgain) { shownAgain.Toggle(true); }
                }
                ArmSwapperLog(player.GetGame(), "  Mantis nail pieces shown again");
                ArrayClear(memory.hiddenBladeNails);
            }
        }
    }
    if ArmSwapperStyleKeepsOwnNails(armsType, index) {
        if ArraySize(memory.hiddenNails) > 0 {
            for nail in memory.hiddenNails {
                let nailComp: ref<IComponent> = nail;
                if IsDefined(nailComp) { nailComp.Toggle(true); }
            }
            ArmSwapperLog(player.GetGame(), "  V's own nails shown again");
            ArrayClear(memory.hiddenNails);
        }
        return;
    }
    for comp in comps {
        if IsDefined(comp) && comp.IsEnabled() {
            let pieceName: String = NameToString(comp.GetName());
            if StrBeginsWith(pieceName, "a0_000_p") && StrContains(pieceName, "__nails_") {
                comp.Toggle(false);
                ArrayPush(memory.hiddenNails, comp);
                ArmSwapperLog(player.GetGame(), "  own nail piece " + pieceName + " switched off under a painted-nail style");
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Native styling. The RED4ext plugin Simple Arm Swapper Native, shipped with the mod, lets the game
// style every arm type itself, in every arm slot (its source and the reasoning are in the native
// folder of the repository). Found through Codeware. When the plugin is missing or stays off (another
// game version), arms outside the first arm slot keep their plain look and nothing is tidied.
// ---------------------------------------------------------------------------

@if(ModuleExists("Codeware"))
public func ArmSwapperNativeStyling(game: GameInstance) -> Bool {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if !IsDefined(memory) { return false; }
    if !memory.nativeChecked {
        memory.nativeChecked = true;
        memory.nativeVersion = 0;
        let fn: ref<ReflectionStaticFunc> = Reflection.GetGlobalFunction(n"SimpleArmSwapperNativeVersion");
        if IsDefined(fn) {
            let ok: Bool = false;
            let result: Variant = fn.Call([], ok);
            if ok { memory.nativeVersion = FromVariant<Int32>(result); }
        }
        ArmSwapperLog(game, memory.nativeVersion > 0
            ? "Simple Arm Swapper Native " + IntToString(memory.nativeVersion) + " found: the game styles every arm type itself"
            : "Simple Arm Swapper Native not active: the mod styles arm pieces itself");
    }
    return memory.nativeVersion > 0;
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperNativeStyling(game: GameInstance) -> Bool {
    return false;
}

// The arm type a piece belongs to, by its name: 0 Projectile Launch System, 1 Mantis Blades,
// 2 Monowire, 3 Gorilla Arms, -1 for anything else
public func ArmSwapperPieceArmsType(pieceName: String) -> Int32 {
    if StrBeginsWith(pieceName, "a0_006_") { return 0; }
    if StrBeginsWith(pieceName, "a0_003_") { return 1; }
    if StrBeginsWith(pieceName, "a0_002_") { return 2; }
    if StrBeginsWith(pieceName, "a0_005_") { return 3; }
    return -1;
}

// Which chunks of a mesh piece show (0: none), or false for a piece that is not a mesh
@if(ModuleExists("Codeware"))
public func ArmSwapperPieceMask(comp: ref<IComponent>, out mask: Uint64) -> Bool {
    let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
    if IsDefined(skinned) { mask = skinned.chunkMask; return true; }
    let plain: ref<MeshComponent> = comp as MeshComponent;
    if IsDefined(plain) { mask = plain.chunkMask; return true; }
    return false;
}

// A mesh piece's mesh and look, or false for a piece that is not a mesh
@if(ModuleExists("Codeware"))
public func ArmSwapperPieceLook(comp: ref<IComponent>, out mesh: ResRef, out look: CName) -> Bool {
    let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
    if IsDefined(skinned) {
        let meshRef: ResourceAsyncRef = skinned.mesh;
        mesh = ResourceAsyncRef.GetPath(meshRef);
        look = skinned.meshAppearance;
        return true;
    }
    let plain: ref<MeshComponent> = comp as MeshComponent;
    if IsDefined(plain) {
        let plainRef: ResourceAsyncRef = plain.mesh;
        mesh = ResourceAsyncRef.GetPath(plainRef);
        look = plain.meshAppearance;
        return true;
    }
    return false;
}

// Whether a piece is on and shows at least part of its mesh. The game keeps some pieces on with
// every chunk hidden (such as the inventory and photo mode upper arms), which show nothing.
@if(ModuleExists("Codeware"))
public func ArmSwapperPieceShows(comp: ref<IComponent>) -> Bool {
    if !IsDefined(comp) || !comp.IsEnabled() { return false; }
    let mask: Uint64;
    if ArmSwapperPieceMask(comp, mask) { return NotEquals(mask, 0ul); }
    return true;
}

// Whether a character's launcher pieces belong on it: it holds the launcher, or the launcher is the
// only arm cyberware V has (then its put-away arm is V's arm)
public func ArmSwapperLauncherBelongs(player: ref<PlayerPuppet>, owner: ref<Entity>, keepType: Int32) -> Bool {
    if keepType == 0 || !ArmSwapperHasMeleeArms(player) { return true; }
    let inLeft: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(owner as GameObject, t"AttachmentSlots.WeaponLeft");
    return IsDefined(inLeft) && ArmSwapperArmsType(inLeft.GetItemID()) == 0;
}

// With native styling: when an arm type's style changes while that type is shown on a character, the
// game leaves the type's earlier pieces on it, beside whatever arms come next (seen with the Monowire
// after the style calls at load, and as a stray Gorilla spike on the Glamdoc preview). Only pieces of
// the melee type worn (keepType, in hand or put away) belong on a character, plus the launcher's
// while it is out; the others are switched off. With keepType 0 (the launcher, or a character showing
// it) melee pieces are left alone. On V hidden pieces are remembered and come back with their type,
// unless the game has put a fresh copy on V meanwhile. Copies of V (Glamdoc preview, inventory, photo
// mode) are built fresh.
// The same effect within one type: each style change adds a fresh copy of that type's pieces and
// keeps the old ones, so several copies of a piece (from different styles) show at once. Only the
// newest copy of each piece stays. And with the Mantis Blades drawn, their put-away hands go until the
// blades are put away (the numbered a0_003_ma__ pieces stay: they carry the painted-nail decals).
@if(ModuleExists("Codeware"))
public func ArmSwapperHideStrayArms(player: ref<PlayerPuppet>, owner: ref<Entity>, keepType: Int32, opt drawn: Bool) {
    if !IsDefined(player) || !IsDefined(owner) || keepType < 0 || keepType > 3 { return; }
    let game: GameInstance = player.GetGame();
    let onV: Bool = owner == player;
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if onV && !IsDefined(memory) { return; }
    let launcherBelongs: Bool = ArmSwapperLauncherBelongs(player, owner, keepType);
    let comps: array<ref<IComponent>> = owner.GetComponents();
    if onV && ArraySize(memory.hiddenStray) > 0 {
        let keptComps: array<wref<IComponent>>;
        let keptTypes: array<Int32>;
        let shown: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(memory.hiddenStray) {
            let comp: ref<IComponent> = memory.hiddenStray[i];
            let compType: Int32 = i < ArraySize(memory.hiddenStrayType) ? memory.hiddenStrayType[i] : -1;
            if IsDefined(comp) {
                if (compType == keepType && keepType >= 1) || (compType == 0 && launcherBelongs)
                    || (compType == 11 && keepType == 1 && !drawn) {
                    // Old copies among them are sorted out by the copy rule below
                    comp.Toggle(true);
                    shown += 1;
                } else {
                    ArrayPush(keptComps, comp);
                    ArrayPush(keptTypes, compType);
                }
            }
            i += 1;
        }
        memory.hiddenStray = keptComps;
        memory.hiddenStrayType = keptTypes;
        if shown > 0 {
            ArmSwapperLog(game, "  " + IntToString(shown) + " hidden arm pieces shown again");
        }
    }
    let hidden: Int32 = 0;
    for comp in comps {
        if IsDefined(comp) && comp.IsEnabled() {
            let pieceType: Int32 = ArmSwapperPieceArmsType(NameToString(comp.GetName()));
            let stray: Bool = false;
            if pieceType == 0 { stray = !launcherBelongs; }
            if pieceType >= 1 { stray = keepType >= 1 && pieceType != keepType; }
            if stray {
                comp.Toggle(false);
                if onV {
                    ArrayPush(memory.hiddenStray, comp);
                    ArrayPush(memory.hiddenStrayType, pieceType);
                }
                hidden += 1;
            }
        }
    }
    if hidden > 0 {
        ArmSwapperLog(game, "  hid " + IntToString(hidden) + " pieces of other arm types on " + (onV ? "V" : "a copy of V")
            + " (arm type " + IntToString(keepType) + " worn, launcher out " + BoolToString(launcherBelongs) + ")");
    }
    // Mantis Blades drawn on V: their put-away hands go, remembered as type 11 until put away
    let putAway: Int32 = 0;
    if onV && keepType == 1 && drawn {
        for comp in comps {
            if IsDefined(comp) && comp.IsEnabled() && StrBeginsWith(NameToString(comp.GetName()), "a0_003_wa__mantisblade_holstered") {
                comp.Toggle(false);
                ArrayPush(memory.hiddenStray, comp);
                ArrayPush(memory.hiddenStrayType, 11);
                putAway += 1;
            }
        }
    }
    // Several copies of one Mantis Blade or launcher piece from different styles (another mesh or
    // look): the newest (last listed) stays. Copies with the same mesh and look are parts of one piece,
    // and copies with every chunk hidden are the game's own; both are left alone. Not the Gorilla Arms:
    // they build their photo mode arms from several same-named parts, styled and skin meshes mixed.
    let names: array<CName>;
    let meshes: array<ResRef>;
    let looks: array<CName>;
    let i: Int32 = 0;
    while i < ArraySize(comps) {
        let comp: ref<IComponent> = comps[i];
        let mesh: ResRef;
        let look: CName;
        let copyType: Int32 = ArmSwapperPieceArmsType(NameToString(comp.GetName()));
        if ArmSwapperPieceShows(comp) && (copyType == 1 || copyType == 0) && ArmSwapperPieceLook(comp, mesh, look) {
            let at: Int32 = ArrayFindFirst(names, comp.GetName());
            if at < 0 {
                ArrayPush(names, comp.GetName());
                ArrayPush(meshes, mesh);
                ArrayPush(looks, look);
            } else {
                meshes[at] = mesh;
                looks[at] = look;
            }
        }
        i += 1;
    }
    let oldCopies: Int32 = 0;
    i = 0;
    while i < ArraySize(comps) {
        let comp: ref<IComponent> = comps[i];
        let mesh: ResRef;
        let look: CName;
        if ArmSwapperPieceShows(comp) && ArmSwapperPieceLook(comp, mesh, look) {
            let at: Int32 = ArrayFindFirst(names, comp.GetName());
            if at >= 0 && (NotEquals(mesh, meshes[at]) || NotEquals(look, looks[at])) {
                comp.Toggle(false);
                oldCopies += 1;
            }
        }
        i += 1;
    }
    if putAway > 0 || oldCopies > 0 {
        ArmSwapperLog(game, "  hid " + IntToString(putAway) + " put-away Mantis pieces while drawn, " + IntToString(oldCopies)
            + " old copies of Mantis or launcher pieces on " + (onV ? "V" : "a copy of V"));
    }
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperHideStrayArms(player: ref<PlayerPuppet>, owner: ref<Entity>, keepType: Int32, opt drawn: Bool) {}

// Tidies V for the arms she wears now, over the next few seconds (native styling only)
public func ArmSwapperTidyWornNow(player: ref<PlayerPuppet>, why: String) {
    if !IsDefined(player) || !ArmSwapperNativeStyling(player.GetGame()) { return; }
    let holstered: Bool;
    let wornType: Int32 = ArmSwapperWornMeleeType(player, holstered);
    // Only the launcher out (melee arms leave the arm slot meanwhile), or the launcher alone
    if wornType < 0 && ArmSwapperLauncherBelongs(player, player, -1) && ItemID.IsValid(ArmSwapperEquippedArmsOfType(player, 0)) {
        wornType = 0;
    }
    if wornType < 0 { return; }
    ArmSwapperLog(player.GetGame(), "tidying worn arms (" + why + "), arm type " + IntToString(wornType));
    ArmSwapperTidyWornSoon(player, wornType, holstered, true);
}

// The melee arm type V wears right now, in hand or put away (-1 for none), and whether it is put away
public func ArmSwapperWornMeleeType(player: ref<PlayerPuppet>, out holstered: Bool) -> Int32 {
    holstered = false;
    if !IsDefined(player) { return -1; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let inHand: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
    if IsDefined(inHand) {
        let handType: Int32 = ArmSwapperArmsType(inHand.GetItemID());
        if handType >= 1 && handType <= 3 { return handType; }
    }
    let putAway: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.RightArm");
    if IsDefined(putAway) {
        let awayType: Int32 = ArmSwapperArmsType(ArmSwapperArmsForHolstered(player, putAway.GetItemID()));
        if awayType >= 1 && awayType <= 3 {
            holstered = true;
            return awayType;
        }
    }
    return -1;
}

// Whatever arms V now wears: other arm types' leftover pieces go (native styling), and Gorilla Arms
// and painted-nail styles hide V's own nails
@if(ModuleExists("Codeware"))
public func ArmSwapperTidyWorn(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool) {
    if !IsDefined(player) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    if ArmSwapperNativeStyling(player.GetGame()) {
        // Passes are queued for a few seconds after arms appear, and the arms can be drawn or put away
        // meanwhile: tidy for what V wears when the pass runs
        let nowHolstered: Bool;
        let nowType: Int32 = ArmSwapperWornMeleeType(player, nowHolstered);
        if nowType >= 1 {
            ArmSwapperHideStrayArms(player, player, nowType, !nowHolstered);
        } else {
            ArmSwapperHideStrayArms(player, player, armsType, !holstered);
        }
    }
    let comps: array<ref<IComponent>> = player.GetComponents();
    // V's own nails: off under Gorilla Arms and painted-nail styles, on otherwise
    let index: Int32 = 0;
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if IsDefined(memory) && armsType >= 0 && armsType < 4 && memory.HasStyle(armsType) && memory.IsEnabled(armsType)
        && ItemID.IsValid(memory.GetStyleItem(armsType)) {
        index = ArmSwapperStyleIndex(player, memory.GetStyleItem(armsType));
    }
    if armsType >= 1 && armsType <= 3 {
        ArmSwapperOwnNails(player, comps, armsType, index);
    }
    ArmSwapperCheckHead(player, "after tidying worn arms");
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperTidyWorn(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool) {}

public class ArmSwapperTidyCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let armsType: Int32;
    public let holstered: Bool;
    public let swapGen: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        // A newer swap has started: these arms are on their way out
        if !IsDefined(player) || this.swapGen != player.m_armSwapperSwapGen { return; }
        ArmSwapperTidyWorn(player, this.armsType, this.holstered);
    }
}

public func ArmSwapperTidyWornSoon(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool, opt longer: Bool) {
    if !IsDefined(player) { return; }
    ArmSwapperTidyWorn(player, armsType, holstered);
    let delays: array<Float> = [0.1, 0.4, 1.0];
    if longer {
        delays = [0.3, 1.0, 2.0, 3.5];
    }
    for delay in delays {
        let callback: ref<ArmSwapperTidyCallback> = new ArmSwapperTidyCallback();
        callback.player = player;
        callback.armsType = armsType;
        callback.holstered = holstered;
        callback.swapGen = player.m_armSwapperSwapGen;
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperStylePiecesOf(player: ref<PlayerPuppet>, owner: ref<Entity>, arms: ItemID, reason: String, opt view: CName, opt styleOverride: ItemID) -> Int32 {
    return -1;
}

// Pieces arrive over a few frames after the arms attach, so styling is tried again shortly after
public class ArmSwapperStylePiecesCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let target: wref<Entity>;
    public let arms: ItemID;
    public let reason: String;
    public let view: CName;
    // The slot and item to check before styling, so stale retries do nothing
    public let slot: TweakDBID;
    public let slotItem: ItemID;
    public let dump: Bool;
    // The swap count when this pass was queued (see m_armSwapperSwapGen)
    public let swapGen: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        let target: ref<Entity> = this.target;
        if !IsDefined(player) || !IsDefined(target) { return; }
        if target == player && this.swapGen != player.m_armSwapperSwapGen { return; }
        let inSlot: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(target as GameObject, this.slot);
        if !IsDefined(inSlot) || !(inSlot.GetItemID() == this.slotItem) { return; }
        ArmSwapperStylePiecesOf(player, target, this.arms, this.reason, this.view);
        if this.dump {
            ArmSwapperDumpMeshes(player.GetGame(), target, "styled " + NameToString(this.view));
        }
    }
}

// Styles now and again over the next moment, while the given item stays in the given slot
public func ArmSwapperStylePiecesSoon(player: ref<PlayerPuppet>, target: ref<Entity>, arms: ItemID, view: CName, slot: TweakDBID, slotItem: ItemID, opt longer: Bool) {
    // V is styled by the game and tidied in ArmSwapperTidyWorn; only copies of V are looked at here
    if !IsDefined(player) || !IsDefined(target) || target == player || ArmSwapperArmsType(arms) < 0 { return; }
    ArmSwapperStylePiecesOf(player, target, arms, "attached", view);
    let delays: array<Float> = [0.05, 0.25, 0.75];
    if longer {
        delays = [0.1, 0.5, 1.0, 2.0, 3.5];
    }
    for delay in delays {
        let callback: ref<ArmSwapperStylePiecesCallback> = new ArmSwapperStylePiecesCallback();
        callback.player = player;
        callback.target = target;
        callback.arms = arms;
        callback.view = view;
        callback.slot = slot;
        callback.slotItem = slotItem;
        callback.dump = longer ? delay > 3.0 : delay > 0.5;
        callback.swapGen = player.m_armSwapperSwapGen;
        callback.reason = NameToString(view) + " after " + FloatToStringPrec(delay, 2) + "s";
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

// Getting on or off a vehicle, or switching its camera, rebuilds V's arm pieces without the arms
// being attached again: tidy them again
public func ArmSwapperRestyleWorn(player: ref<PlayerPuppet>, why: String) {
    if !IsDefined(player) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    ArmSwapperCheckHeadSoon(player, why);
    ArmSwapperTidyWornNow(player, why);
}

// Getting on or off a vehicle rebuilds V's arm pieces without the arms being attached again
@wrapMethod(PlayerPuppet)
protected cb func OnMountingEvent(evt: ref<MountingEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    ArmSwapperRestyleWorn(this, "mounting");
    return result;
}

// Switching between first and third person camera in a vehicle rebuilds them too
@wrapMethod(VehicleComponent)
protected final func OnVehicleCameraChange(state: Bool) -> Void {
    wrappedMethod(state);
    ArmSwapperRestyleWorn(GetPlayer(GetGameInstance()), state ? "vehicle camera third person" : "vehicle camera first person");
}

@wrapMethod(PlayerPuppet)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    ArmSwapperRestyleWorn(this, "unmounting");
    return result;
}

// ---------------------------------------------------------------------------
// Long or short sleeves. Some Glamdoc styles have a second version that fits under long sleeves. The
// game picks it from the clothes in its own torso, chest and outfit slots. While an Equipment-EX
// outfit is active those clothes are hidden and V shows the outfit's clothes instead, so the game's
// answer followed clothes nobody sees. The test below answers from the outfit's torso and body slots
// then, for the game's own callers too (the Glamdoc, changing tops). Equipment-EX is optional. The
// Sleeve Version setting can fix the answer, for clothes from mods that are not marked as long-sleeved.
// ---------------------------------------------------------------------------

@if(ModuleExists("EquipmentEx"))
public func ArmSwapperOutfitActive(game: GameInstance) -> Bool {
    let outfits: ref<OutfitSystem> = OutfitSystem.GetInstance(game);
    return IsDefined(outfits) && outfits.IsActive();
}

@if(!ModuleExists("EquipmentEx"))
public func ArmSwapperOutfitActive(game: GameInstance) -> Bool {
    return false;
}

@if(ModuleExists("EquipmentEx"))
public func ArmSwapperIsOutfitSlot(game: GameInstance, slot: TweakDBID) -> Bool {
    let outfits: ref<OutfitSystem> = OutfitSystem.GetInstance(game);
    return IsDefined(outfits) && outfits.IsOutfitSlot(slot);
}

@if(!ModuleExists("EquipmentEx"))
public func ArmSwapperIsOutfitSlot(game: GameInstance, slot: TweakDBID) -> Bool {
    return false;
}

@wrapMethod(EquipmentSystemPlayerData)
public final static func HasLongSleeves(puppet: wref<ScriptedPuppet>) -> Bool {
    let gameAnswer: Bool = wrappedMethod(puppet);
    let choice: ArmSwapperSleeveVersion = (new SimpleArmSwapperSettings()).sleeveVersion;
    if Equals(choice, ArmSwapperSleeveVersion.AlwaysShort) { return false; }
    if Equals(choice, ArmSwapperSleeveVersion.AlwaysLong) { return true; }
    let owner: ref<ScriptedPuppet> = puppet;
    if !IsDefined(owner) || !ArmSwapperOutfitActive(owner.GetGame()) { return gameAnswer; }
    // The outfit's clothes decide, by the same tags the game looks for
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(owner.GetGame());
    let slots: array<TweakDBID> = [t"OutfitSlots.TorsoUnder", t"OutfitSlots.TorsoInner", t"OutfitSlots.TorsoMiddle",
        t"OutfitSlots.TorsoOuter", t"OutfitSlots.TorsoAux", t"OutfitSlots.BodyUnder", t"OutfitSlots.BodyInner",
        t"OutfitSlots.BodyMiddle", t"OutfitSlots.BodyOuter"];
    for slot in slots {
        let worn: ref<ItemObject> = ts.GetItemInSlot(owner, slot);
        if IsDefined(worn) {
            let data: wref<gameItemData> = worn.GetItemData();
            if IsDefined(data) && (data.HasTag(n"LongSleeve") || data.HasTag(n"BodySuit")) { return true; }
        }
    }
    return false;
}

// The sleeves V's arm styles were last set for: 0 not yet, 1 short, 2 long
@addField(PlayerPuppet)
public let m_armSwapperSleeves: Int32;

@addField(PlayerPuppet)
public let m_armSwapperOutfitGen: Int32;

// A piece of an Equipment-EX outfit went on or came off (or the whole outfit, switched on or off). The
// game does not look at its arm styles then, so the mod checks a moment later whether the sleeves
// changed. One check for a burst of changes.
public func ArmSwapperOutfitSlotChanged(player: ref<PlayerPuppet>, slot: TweakDBID) {
    if !IsDefined(player) || !ArmSwapperIsOutfitSlot(player.GetGame(), slot) { return; }
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    player.m_armSwapperOutfitGen += 1;
    let later: ref<ArmSwapperOutfitChangedCallback> = new ArmSwapperOutfitChangedCallback();
    later.player = player;
    later.gen = player.m_armSwapperOutfitGen;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(later, 1.0, false);
}

public class ArmSwapperOutfitChangedCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let gen: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) || this.gen != player.m_armSwapperOutfitGen { return; }
        let game: GameInstance = player.GetGame();
        // While a save loads the outfit goes on too: look again once the pass after loading has run
        let sinceAttach: Float = ArmSwapperNow(game) - player.m_armSwapperAttachTime;
        if sinceAttach < 15.0 {
            GameInstance.GetDelaySystem(game).DelayCallback(this, 15.5 - sinceAttach, false);
            return;
        }
        // Sleeves as they were: nothing to do, and nothing is sent
        let sleeves: Int32 = EquipmentSystemPlayerData.HasLongSleeves(player) ? 2 : 1;
        if sleeves == player.m_armSwapperSleeves { return; }
        ArmSwapperLog(game, "outfit changed: sleeves now " + (sleeves == 2 ? "long" : "short") + ", setting the arm styles' sleeve version");
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) { system.ArmSwapperSetAllSwitchersLater("top changed", 0.0); }
    }
}

// The style of the arms in use follows the sleeves: its saved option moves between the style's own
// two versions. The game does this itself when a top in its own slots changes; this covers the rest
// (an Equipment-EX outfit, the Sleeve Version setting, a style saved in the Glamdoc, which shows styles
// in full). An option that is neither version was picked by another mod and is left alone.
@addMethod(CyberwareCustomizationSystem)
private func ArmSwapperFollowSleeves(longSleeves: Bool) {
    if !this.savedData.enabled || !ItemID.IsValid(this.savedData.customizationItemID) { return; }
    let record: ref<UIGlamdocCustomizationItem_Record> = TweakDBInterface.GetUIGlamdocCustomizationItemRecord(ItemID.GetTDBID(this.savedData.customizationItemID));
    if !IsDefined(record) { return; }
    let shortIndex: Int32 = record.CustomizationIndex();
    let longIndex: Int32 = record.LongSleevesCustomizationIndex();
    if longIndex == -1 || longIndex == shortIndex { return; }
    let current: Int32 = Cast<Int32>(this.savedData.switcherIndex);
    let wanted: Int32 = longSleeves ? longIndex : shortIndex;
    if current == wanted || (current != shortIndex && current != longIndex) { return; }
    this.savedData.switcherIndex = Cast<Uint32>(wanted);
    ArmSwapperLog(this.GetGameInstance(), "style of the arms in use moved to its " + (longSleeves ? "long" : "short") + "-sleeve version (option "
        + IntToString(wanted) + ")");
}

// Changing the top can switch long sleeves on or off. The game then re-sends the style of the arms in
// use; with native styling the other arm types' styles are set again too (their long-sleeve
// versions), and V is tidied, a moment later.
public func ArmSwapperTopChanged(player: ref<PlayerPuppet>, slot: TweakDBID) {
    if !IsDefined(player) || !(slot == t"AttachmentSlots.Torso" || slot == t"AttachmentSlots.Chest" || slot == t"AttachmentSlots.Outfit") { return; }
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !ArmSwapperNativeStyling(player.GetGame()) { return; }
    // While a save loads the clothes go on too; the pass after loading covers that (styles set
    // mid-load brought V's hair into first person)
    if ArmSwapperNow(player.GetGame()) - player.m_armSwapperAttachTime < 15.0 { return; }
    // One pass for a burst of changes (an outfit swaps several pieces)
    player.m_armSwapperTopGen += 1;
    let later: ref<ArmSwapperTopChangedCallback> = new ArmSwapperTopChangedCallback();
    later.player = player;
    later.gen = player.m_armSwapperTopGen;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(later, 1.0, false);
}

@addField(PlayerPuppet)
public let m_armSwapperTopGen: Int32;

public class ArmSwapperTopChangedCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let gen: Int32;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) || this.gen != player.m_armSwapperTopGen { return; }
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        if IsDefined(system) { system.ArmSwapperSetAllSwitchersLater("top changed", 0.0); }
    }
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    ArmSwapperTopChanged(this, evt.GetSlotID());
    return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemRemovedFromSlot(evt: ref<ItemRemovedFromSlot>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    ArmSwapperTopChanged(this, evt.GetSlotID());
    return result;
}

// The arm cyberware a holstered arms item belongs to, among the arms V has equipped
public func ArmSwapperArmsForHolstered(player: ref<PlayerPuppet>, holstered: ItemID) -> ItemID {
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) || !ItemID.IsValid(holstered) { return ItemID.None(); }
    // Prefer the arms used last
    let active: ItemID = eqData.GetActiveMeleeWare();
    let candidates: array<ItemID>;
    if ItemID.IsValid(active) { ArrayPush(candidates, active); }
    let areaIndex: Int32 = eqData.GetEquipAreaIndex(gamedataEquipmentArea.ArmsCW);
    if areaIndex >= 0 {
        let i: Int32 = 0;
        while i < ArraySize(eqData.m_equipment.equipAreas[areaIndex].equipSlots) {
            ArrayPush(candidates, eqData.m_equipment.equipAreas[areaIndex].equipSlots[i].itemID);
            i += 1;
        }
    }
    for arms in candidates {
        if ItemID.IsValid(arms) {
            let record: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(arms));
            if IsDefined(record) && IsDefined(record.HolsteredItem()) && record.HolsteredItem().GetID() == ItemID.GetTDBID(holstered) {
                return arms;
            }
        }
    }
    return ItemID.None();
}

// The moment arm cyberware attaches to V's right hand
@wrapMethod(CyberwareCustomizationAttachmentSlotsScriptCallback)
public func OnItemEquippedVisual(slot: TweakDBID, item: ItemID) {
    wrappedMethod(slot, item);
    if !IsDefined(this.m_cyberwareCustomizationSystem) { return; }
    let player: ref<PlayerPuppet> = this.m_cyberwareCustomizationSystem.ArmSwapperPlayer();
    if !IsDefined(player) { return; }
    if slot == t"AttachmentSlots.WeaponRight" && ArmSwapperArmsType(item) > 0 {
        ArmSwapperStylePiecesSoon(player, player, item, n"out", slot, item);
        ArmSwapperTidyWornSoon(player, ArmSwapperArmsType(item), false);
    }
    if slot == t"AttachmentSlots.RightArm" {
        let arms: ItemID = ArmSwapperArmsForHolstered(player, item);
        if ItemID.IsValid(arms) {
            ArmSwapperTidyWornSoon(player, ArmSwapperArmsType(arms), true);
            ArmSwapperStylePiecesSoon(player, player, arms, n"hfppAuto", slot, item);
            ArmSwapperStylePiecesSoon(player, player, arms, n"htppAuto", slot, item);
        }
    }
}

// ---------------------------------------------------------------------------
// Nail items under Gorilla Arms. Equipment-EX has fingernail slots that nail mods use; their nails
// are shaped for V's own hands, and showed on top of the Gorilla Arms' metal fingers. While V wears
// Gorilla Arms (drawn or put away) the items in those slots are taken off, on V and on her copies
// (photo mode, inventory, Glamdoc preview). Without Equipment-EX the slots are simply empty.
// ---------------------------------------------------------------------------

// Slots whose items decide whether nail items show
public func ArmSwapperNailsMatter(slot: TweakDBID) -> Bool {
    return slot == t"AttachmentSlots.RightArm" || slot == t"AttachmentSlots.WeaponRight"
        || slot == t"OutfitSlots.FingernailsLeft" || slot == t"OutfitSlots.FingernailsRight";
}

// Gorilla Arms in the hand, or put away as the arms V shows
public func ArmSwapperWearsGorillaArms(player: ref<PlayerPuppet>, owner: ref<GameObject>) -> Bool {
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let inHand: ref<ItemObject> = ts.GetItemInSlot(owner, t"AttachmentSlots.WeaponRight");
    if IsDefined(inHand) && ArmSwapperArmsType(inHand.GetItemID()) == 3 { return true; }
    let holstered: ref<ItemObject> = ts.GetItemInSlot(owner, t"AttachmentSlots.RightArm");
    return IsDefined(holstered) && ArmSwapperArmsType(ArmSwapperArmsForHolstered(player, holstered.GetItemID())) == 3;
}

// Takes the items out of Equipment-EX's fingernail slots while V wears Gorilla Arms, and puts them
// back afterwards. Only what is shown changes: Equipment-EX keeps the items in its outfit and puts
// them back by itself (after a load, for one), when this is simply done again.
// Only nail items come off. The fingernail slots also hold whole cosmetic arms and hands
// (KiasuBurger's, for one), made to cover arm cyberware; taking those off showed the cyberware.
public func ArmSwapperIsNailItem(item: ref<ItemObject>) -> Bool {
    if !IsDefined(item) { return false; }
    if StrBeginsWith(TDBID.ToStringDEBUG(ItemID.GetTDBID(item.GetItemID())), "Items.kiasu_burger") { return false; }
    let armTags: array<CName> = [n"hide_arm_left", n"hide_arm_right", n"hide_nails_left", n"hide_nails_right",
        n"hide_nails_keep_link_left", n"hide_base_hand_left", n"hide_base_hand_right", n"hide_base_arm_left",
        n"hide_base_arm_right", n"hide_cyber_hand_wrist_left", n"hide_cyber_hand_wrist_right",
        n"hide_cyber_arm_hand_left", n"hide_cyber_arm_hand_right"];
    for tag in armTags {
        if item.MatchVisualTag(tag) { return false; }
    }
    return true;
}

public func ArmSwapperGorillaNails(player: ref<PlayerPuppet>, owner: ref<GameObject>) {
    if !IsDefined(player) || !IsDefined(owner) { return; }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if !IsDefined(memory) { return; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let hide: Bool = (new SimpleArmSwapperSettings()).hideNailItemsUnderGorillaArms && ArmSwapperWearsGorillaArms(player, owner);
    if !hide {
        // Only V gets her nails back; her copies (photo mode, inventory, Glamdoc) are built fresh
        if owner == player && ArraySize(memory.hiddenNailSlots) > 0 {
            let i: Int32 = 0;
            while i < ArraySize(memory.hiddenNailSlots) {
                if ts.IsSlotEmpty(player, memory.hiddenNailSlots[i]) {
                    ts.AddItemToSlot(player, memory.hiddenNailSlots[i], memory.hiddenNailItems[i], true);
                }
                i += 1;
            }
            ArrayClear(memory.hiddenNailSlots);
            ArrayClear(memory.hiddenNailItems);
            ArmSwapperLog(player.GetGame(), "nail items put back");
        }
        return;
    }
    let slots: array<TweakDBID> = [t"OutfitSlots.FingernailsLeft", t"OutfitSlots.FingernailsRight"];
    for slot in slots {
        let nails: ref<ItemObject> = ts.GetItemInSlot(owner, slot);
        if IsDefined(nails) && !ArmSwapperIsNailItem(nails) {
            ArmSwapperLog(player.GetGame(), "item " + ArmSwapperName(nails.GetItemID()) + " in " + TDBID.ToStringDEBUG(slot) + " is a cosmetic arm or hand, left on under Gorilla Arms");
        }
        if IsDefined(nails) && ArmSwapperIsNailItem(nails) {
            let nailItem: ItemID = nails.GetItemID();
            ts.RemoveItemFromSlot(owner, slot);
            if owner == player {
                ArrayPush(memory.hiddenNailSlots, slot);
                ArrayPush(memory.hiddenNailItems, nailItem);
            }
            ArmSwapperLog(player.GetGame(), "nail item " + ArmSwapperName(nailItem) + " taken off " + TDBID.ToStringDEBUG(slot) + " under Gorilla Arms");
        }
    }
}


public class ArmSwapperGorillaNailsCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let owner: wref<GameObject>;

    public func Call() -> Void {
        ArmSwapperGorillaNails(this.player, this.owner);
    }
}

// Slots change over a few frames (a holstered item comes off as another goes on): check again shortly
public func ArmSwapperGorillaNailsSoon(player: ref<PlayerPuppet>, opt owner: ref<GameObject>) {
    if !IsDefined(player) { return; }
    if !IsDefined(owner) { owner = player; }
    let delays: array<Float> = [0.1, 0.5];
    for delay in delays {
        let callback: ref<ArmSwapperGorillaNailsCallback> = new ArmSwapperGorillaNailsCallback();
        callback.player = player;
        callback.owner = owner;
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

// ---------------------------------------------------------------------------
// The Projectile Launch System beside melee arms.
//
// The launcher comes out in V's left hand next to the melee arms. The game styles arm cyberware
// from one owner, the melee arms, so the launcher showed its plain look. While it is out, the mod
// styles its pieces with the launcher's own saved style and paints the launcher's colours. The
// game holds one colour set for all arm cyberware, so melee arms on screen wear the launcher's
// colours too until it goes away; then the melee arms' colours come back.
// A launcher with no melee arms beside it is left to the game, which styles it as usual.
// ---------------------------------------------------------------------------

// Melee arm cyberware (Mantis Blades, Monowire, Gorilla Arms) equipped in any arm slot
public func ArmSwapperHasMeleeArms(player: ref<GameObject>) -> Bool {
    let armsType: Int32 = 1;
    while armsType < 4 {
        if ItemID.IsValid(ArmSwapperEquippedArmsOfType(player, armsType)) { return true; }
        armsType += 1;
    }
    return false;
}

// Watches V's left hand for the launcher. A listener of the mod's own, so it never clashes with
// other mods changing the game's callbacks.
public class ArmSwapperLauncherSlotCallback extends AttachmentSlotsScriptCallback {
    public let system: wref<CyberwareCustomizationSystem>;

    public func OnItemEquippedVisual(slot: TweakDBID, item: ItemID) -> Void {
        let system: ref<CyberwareCustomizationSystem> = this.system;
        if !IsDefined(system) { return; }
        if slot == t"AttachmentSlots.WeaponLeft" && ArmSwapperArmsType(item) == 0 {
            system.ArmSwapperLauncherOut(item);
        }
        if ArmSwapperNailsMatter(slot) {
            ArmSwapperGorillaNailsSoon(system.ArmSwapperPlayer());
        }
        ArmSwapperOutfitSlotChanged(system.ArmSwapperPlayer(), slot);
    }

    public func OnItemUnequipped(slot: TweakDBID, item: ItemID) -> Void {
        let system: ref<CyberwareCustomizationSystem> = this.system;
        if !IsDefined(system) { return; }
        if slot == t"AttachmentSlots.WeaponLeft" && ArmSwapperArmsType(item) == 0 {
            system.ArmSwapperLauncherAway(item);
        }
        if ArmSwapperNailsMatter(slot) {
            ArmSwapperGorillaNailsSoon(system.ArmSwapperPlayer());
        }
        ArmSwapperOutfitSlotChanged(system.ArmSwapperPlayer(), slot);
    }
}

// The launcher's style switcher stays off V while melee arms are equipped. Setting it adds the
// launcher's holstered arm and nail pieces to V for the rest of the session, beside the melee
// arms: a floating holstered launcher arm on menu characters, and V's own nails over styled
// hands. The mod paints the launcher's pieces itself instead, while it is out.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperHoldsBackSwitcher(switcherName: CName) -> Bool {
    if !Equals(switcherName, n"launcher") || !(new SimpleArmSwapperSettings()).stylePerArmType { return false; }
    // With native styling the game styles the launcher beside melee arms too; its stray pieces are
    // tidied away while it is put away (ArmSwapperHideStrayArms)
    if ArmSwapperNativeStyling(this.GetGameInstance()) { return false; }
    // The Glamdoc's launcher tab needs it to show the launcher on its preview character. The
    // pieces it leaves behind are hidden on menu characters (ArmSwapperHideStrayLauncher).
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if IsDefined(memory) && memory.glamdocOpen && IsDefined(memory.glamdoc) && memory.glamdoc.ArmSwapperInLauncherMode() { return false; }
    return ArmSwapperHasMeleeArms(this.m_playerPuppet);
}

// Launcher pieces on a menu character (inventory, Glamdoc) that does not hold the launcher. Once the
// launcher's style switcher was set in the Glamdoc, the game adds the launcher's holstered arm to
// these characters for the rest of the session, where it floats beside the melee arms.
@if(ModuleExists("Codeware"))
public func ArmSwapperHideStrayLauncher(player: ref<PlayerPuppet>, owner: ref<GameObject>) {
    if !IsDefined(player) || !IsDefined(owner) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let launcher: ItemID = ArmSwapperEquippedArmsOfType(player, 0);
    if !ItemID.IsValid(launcher) || !ArmSwapperHasMeleeArms(player) { return; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let inLeft: ref<ItemObject> = ts.GetItemInSlot(owner, t"AttachmentSlots.WeaponLeft");
    if IsDefined(inLeft) && ArmSwapperArmsType(inLeft.GetItemID()) == 0 { return; }
    let holstered: ref<ItemObject> = ts.GetItemInSlot(owner, t"AttachmentSlots.RightArm");
    let record: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(launcher));
    if IsDefined(holstered) && IsDefined(record) && IsDefined(record.HolsteredItem())
        && record.HolsteredItem().GetID() == ItemID.GetTDBID(holstered.GetItemID()) { return; }
    let hidden: Int32 = 0;
    for comp in owner.GetComponents() {
        // Every a0_006 piece belongs to the launcher
        if IsDefined(comp) && comp.IsEnabled() && StrBeginsWith(NameToString(comp.GetName()), "a0_006_") {
            comp.Toggle(false);
            hidden += 1;
        }
    }
    if hidden > 0 {
        ArmSwapperLog(player.GetGame(), "hid " + IntToString(hidden) + " stray launcher pieces on a menu character");
    }
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperHideStrayLauncher(player: ref<PlayerPuppet>, owner: ref<GameObject>) {}

// Every colour change the mod makes itself goes through here, so other mods hear about it
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperPaint(enabled: Bool, primary: Color, secondary: Color, why: CName) {
    this.SetCustomizationParameters(enabled, primary, secondary);
    // The arms these colours are for: the launcher while it is out, otherwise V's active arms
    let armsType: Int32 = -1;
    if Equals(why, n"launcherOut") {
        armsType = 0;
    } else if IsDefined(this.m_playerPuppet) {
        let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.m_playerPuppet);
        if IsDefined(eqData) { armsType = ArmSwapperArmsType(eqData.GetActiveMeleeWare()); }
    }
    this.ArmSwapperColoursPainted(why, armsType);
}

// The brand colours of the style in use (or none), as the game would paint them
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperPaintSaved(why: CName) {
    this.ArmSwapperPaint(this.savedData.enabled, Color.ToLinear(CyberwareCustomizationPersistentData.GetPrimaryColor(this.savedData)),
        Color.ToLinear(CyberwareCustomizationPersistentData.GetSecondaryColor(this.savedData)), why);
}

// For other mods: runs right after Simple Arm Swapper has set the arm colours itself with
// SetCustomizationParameters (a swap, a save load, the Glamdoc closing, the launcher drawn or put
// away...). A mod that paints its own colours can observe this (CET: ObserveAfter('CyberwareCustomizationSystem',
// 'ArmSwapperColoursPainted', ...)) and paint them again. why: load, swap, noStyle, glamdocClosed, topChanged,
// styleChanged, launcherOut, launcherAway, styleKept. armsType: the arms the colours are for, 0 Projectile
// Launch System, 1 Mantis Blades, 2 Monowire, 3 Gorilla Arms, -1 none or unknown
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperColoursPainted(why: CName, armsType: Int32) {
    ArmSwapperLog(this.GetGameInstance(), "colours painted (" + NameToString(why) + ", arm type " + IntToString(armsType) + ")");
}

@wrapMethod(CyberwareCustomizationSystem)
public func RestoreCyberwareCustomization(forcePlayerCustomization: Bool) {
    if this.ArmSwapperHoldsBackSwitcher(this.savedData.switcherName) {
        // Saved and coloured as usual, only the switcher is left alone
        this.ArmSwapperPaintSaved(n"styleKept");
        ArmSwapperLog(this.GetGameInstance(), "launcher style kept off V beside melee arms: " + ArmSwapperStyleDataText(this.savedData));
        return;
    }
    // The game picks its MaxTac version of the switch by this same test
    let maxTacVersion: Bool = this.savedData.hasMaxTacApperanceEquipped || this.ShouldApplyMaxTacApperance();
    wrappedMethod(forcePlayerCustomization);
    this.ArmSwapperNoteSwitcherSent(this.savedData.switcherName, Cast<Int32>(this.savedData.switcherIndex), maxTacVersion);
}

@addField(CyberwareCustomizationSystem)
private let m_armSwapperLauncherListener: ref<AttachmentSlotsScriptListener>;

// True while the launcher's colours are painted over the melee arms' colours
@addField(CyberwareCustomizationSystem)
private let m_armSwapperLauncherColoursOn: Bool;

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperListenForLauncher(player: ref<GameObject>) {
    if !IsDefined(player) { return; }
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    if IsDefined(this.m_armSwapperLauncherListener) {
        ts.UnregisterAttachmentSlotListener(player, this.m_armSwapperLauncherListener);
    }
    let callback: ref<ArmSwapperLauncherSlotCallback> = new ArmSwapperLauncherSlotCallback();
    callback.system = this;
    this.m_armSwapperLauncherListener = ts.RegisterAttachmentSlotListener(player, callback);
}

// Paints the launcher's colours (launcherOut) or puts the colours of the style in use back
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperLauncherColours(launcherOut: Bool) {
    if !launcherOut {
        if !this.m_armSwapperLauncherColoursOn { return; }
        this.m_armSwapperLauncherColoursOn = false;
        this.ArmSwapperPaintSaved(n"launcherAway");
        ArmSwapperLog(this.GetGameInstance(), "launcher away: colours of the arms in use back. " + ArmSwapperStyleDataText(this.savedData));
        return;
    }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if !IsDefined(memory) || !memory.HasStyle(0) || !memory.IsEnabled(0) { return; }
    let styleItem: ItemID = memory.GetStyleItem(0);
    if !ItemID.IsValid(styleItem) { return; }
    let record: ref<UIGlamdocCustomizationItem_Record> = TweakDBInterface.GetUIGlamdocCustomizationItemRecord(ItemID.GetTDBID(styleItem));
    if !IsDefined(record) || !IsDefined(record.BrandHandle()) { return; }
    let primary: Color = CyberwareCustomizationHelper.GetColorFromBrandData(record.BrandHandle(), Cast<Uint8>(memory.GetPrimaryColor(0)));
    let secondary: Color = CyberwareCustomizationHelper.GetColorFromBrandData(record.BrandHandle(), Cast<Uint8>(memory.GetSecondaryColor(0)));
    this.m_armSwapperLauncherColoursOn = true;
    this.ArmSwapperPaint(true, Color.ToLinear(primary), Color.ToLinear(secondary), n"launcherOut");
    ArmSwapperLog(this.GetGameInstance(), "launcher out: its colours " + ArmSwapperColorText(primary) + " and " + ArmSwapperColorText(secondary)
        + " (" + ArmSwapperName(styleItem) + ")");
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperLauncherOut(launcher: ItemID) {
    let player: ref<PlayerPuppet> = this.ArmSwapperPlayer();
    if !IsDefined(player) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if IsDefined(memory) && memory.glamdocOpen { return; }
    if !ArmSwapperHasMeleeArms(player) { return; }
    ArmSwapperLog(this.GetGameInstance(), "launcher out beside melee arms: " + ArmSwapperName(launcher) + ". " + ArmSwapperArmsState(player));
    this.ArmSwapperLauncherColours(true);
    ArmSwapperTidyWornNow(player, "launcher out");
    ArmSwapperDumpLauncherSoon(player);
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperLauncherAway(launcher: ItemID) {
    ArmSwapperLog(this.GetGameInstance(), "launcher away: " + ArmSwapperName(launcher));
    this.ArmSwapperLauncherColours(false);
    let player: ref<PlayerPuppet> = this.ArmSwapperPlayer();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if IsDefined(player) && !(IsDefined(memory) && memory.glamdocOpen) && (new SimpleArmSwapperSettings()).stylePerArmType {
        ArmSwapperTidyWornNow(player, "launcher away");
    }
}

// Debug: the pieces of the launcher item itself, once it is in V's hand
public class ArmSwapperLauncherDumpCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        if !IsDefined(player) { return; }
        let launcher: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(player, t"AttachmentSlots.WeaponLeft");
        if IsDefined(launcher) {
            ArmSwapperDumpMeshes(player.GetGame(), launcher, "launcher item");
            ArmSwapperDumpMeshes(player.GetGame(), player, "V with launcher out");
        }
    }
}

public func ArmSwapperDumpLauncherSoon(player: ref<PlayerPuppet>) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    let callback: ref<ArmSwapperLauncherDumpCallback> = new ArmSwapperLauncherDumpCallback();
    callback.player = player;
    // After the tidy passes (up to 3.5 s)
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, 4.0, false);
}

// Photo mode builds its own copy of V; its holstered arms use the third person pieces
@wrapMethod(PhotoModePlayerEntityComponent)
protected cb func OnItemVisualsAddedToSlot(evt: ref<ItemVisualsAddedToSlot>) -> Bool {
    let result: Bool = wrappedMethod(evt);
    if ArmSwapperNailsMatter(evt.GetSlotID()) {
        let nailOwner: ref<GameObject> = this.GetOwner() as GameObject;
        if IsDefined(nailOwner) {
            ArmSwapperGorillaNailsSoon(GetPlayer(nailOwner.GetGame()), nailOwner);
        }
    }
    // Arms drawn when photo mode opened: style them like V's arms in hand
    if evt.GetSlotID() == t"AttachmentSlots.WeaponRight" && ArmSwapperArmsType(evt.GetItemID()) > 0 {
        let photoOwner: ref<GameObject> = this.GetOwner() as GameObject;
        if IsDefined(photoOwner) {
            let photoPlayer: ref<PlayerPuppet> = GetPlayer(photoOwner.GetGame());
            ArmSwapperStylePiecesSoon(photoPlayer, photoOwner, evt.GetItemID(), n"out", evt.GetSlotID(), evt.GetItemID());
        }
    }
    if evt.GetSlotID() == t"AttachmentSlots.RightArm" {
        let photoPuppet: ref<GameObject> = this.GetOwner() as GameObject;
        if !IsDefined(photoPuppet) { return result; }
        let player: ref<PlayerPuppet> = GetPlayer(photoPuppet.GetGame());
        let arms: ItemID = ArmSwapperArmsForHolstered(player, evt.GetItemID());
        if ItemID.IsValid(arms) {
            ArmSwapperStylePiecesSoon(player, photoPuppet, arms, n"htpp", evt.GetSlotID(), evt.GetItemID());
        }
    }
    return result;
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperPlayer() -> ref<PlayerPuppet> {
    return this.m_playerPuppet as PlayerPuppet;
}

// --- Glamdoc preview ---
// The preview character is styled by the game the same way as V, so arms outside the first arm
// slot showed no style there either. It gets the third person pieces of the style being
// previewed, or of the saved style when nothing is being previewed.

@addField(GlamDocGameController)
private let m_armSwapperPreviewRun: Int32;

// True from a tab switch hiding the preview character until the new one is shown
@addField(GlamDocGameController)
private let m_armSwapperPreviewHidden: Bool;

@wrapMethod(GlamDocGameController)
protected cb func OnPuppetPreviewShown() -> Bool {
    let result: Bool = wrappedMethod();
    this.m_armSwapperPreviewHidden = false;
    // The new preview character is up: style it now
    this.ArmSwapperStylePreviewNow(this.m_armSwapperPreviewItem, this.m_armSwapperPreviewRun, "preview shown", false);
    return result;
}

// The style being previewed, or none while the saved style is shown
@addField(GlamDocGameController)
private let m_armSwapperPreviewItem: ItemID;

@addMethod(GlamDocGameController)
public func ArmSwapperStylePreviewNow(styleItem: ItemID, run: Int32, reason: String, dump: Bool) {
    if run != this.m_armSwapperPreviewRun { return; }
    // While the menu swaps its preview character (from hiding the old one until the new one is
    // shown), its pieces are left alone: changing pieces of a character being taken down or set up
    // could crash the game. OnPuppetPreviewShown styles the new one.
    if this.m_armSwapperPreviewHidden || this.m_isProcessingCustomizationChange { return; }
    let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
    let puppet: ref<GameObject> = this.m_previewPuppet;
    if !IsDefined(player) || !IsDefined(puppet) { return; }
    let arms: ItemID = this.ArmSwapperActiveArms();
    let armsType: Int32 = ArmSwapperArmsType(arms);
    ArmSwapperGorillaNails(player, puppet);
    // On the launcher tab the launcher is on its way to the preview's hand; elsewhere its pieces are strays
    if !this.m_armSwapperLauncherMode {
        ArmSwapperHideStrayLauncher(player, puppet);
    }
    if armsType < 0 || (armsType == 0 && !this.m_armSwapperLauncherMode) { return; }
    // The preview shows the arms out, with the same pieces V wears with arms out; until the arms
    // arrive in its hand it wears them holstered (third person pieces). The launcher is held in
    // the left hand.
    let handSlot: TweakDBID = armsType == 0 ? t"AttachmentSlots.WeaponLeft" : t"AttachmentSlots.WeaponRight";
    let inHand: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(puppet, handSlot);
    let armsOut: Bool = IsDefined(inHand) && ItemID.GetTDBID(inHand.GetItemID()) == ItemID.GetTDBID(arms);
    ArmSwapperStylePiecesOf(player, puppet, arms, reason, armsOut ? n"previewOut" : n"preview", styleItem);
    if dump {
        ArmSwapperDumpMeshes(player.GetGame(), puppet, "preview");
    }
}

// Styles the preview now and over the next moments, while it is dressed
@addMethod(GlamDocGameController)
public func ArmSwapperStylePreviewSoon(styleItem: ItemID, why: String) {
    this.m_armSwapperPreviewRun += 1;
    let run: Int32 = this.m_armSwapperPreviewRun;
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !IsDefined(this.m_player) { return; }
    ArmSwapperLog(this.m_player.GetGame(), "preview style (" + why + "): " + (ItemID.IsValid(styleItem) ? ArmSwapperName(styleItem) : "saved"));
    this.ArmSwapperStylePreviewNow(styleItem, run, why, false);
    let delays: array<Float> = [0.05, 0.2, 0.5, 1.0, 2.0];
    for delay in delays {
        let callback: ref<ArmSwapperPreviewStyleCallback> = new ArmSwapperPreviewStyleCallback();
        callback.controller = this;
        callback.styleItem = styleItem;
        callback.run = run;
        callback.reason = why + " after " + FloatToStringPrec(delay, 2) + "s";
        callback.dump = delay > 1.5;
        GameInstance.GetDelaySystem(this.m_player.GetGame()).DelayCallback(callback, delay, false);
    }
}

public class ArmSwapperPreviewStyleCallback extends DelayCallback {
    public let controller: wref<GlamDocGameController>;
    public let styleItem: ItemID;
    public let run: Int32;
    public let reason: String;
    public let dump: Bool;

    public func Call() -> Void {
        let controller: ref<GlamDocGameController> = this.controller;
        if IsDefined(controller) {
            controller.ArmSwapperStylePreviewNow(this.styleItem, this.run, this.reason, this.dump);
        }
    }
}

// --- Debug probe: the Glamdoc menu's own state (needs Codeware; only runs with Debug Logging on) ---
@if(ModuleExists("Codeware"))
public func ArmSwapperDumpGlamdoc(menu: ref<GlamDocGameController>, label: String, listFunctions: Bool) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(menu) { return; }
    let game: GameInstance = GetGameInstance();
    let cls: ref<ReflectionClass> = Reflection.GetClass(n"GlamDocGameController");
    if !IsDefined(cls) { return; }
    let line: String = "glamdoc state (" + label + "):";
    for prop in cls.GetProperties() {
        let typeName: CName = prop.GetType().GetName();
        let value: Variant = prop.GetValue(ToVariant(menu));
        let text: String = "";
        if Equals(typeName, n"Bool") { text = BoolToString(FromVariant<Bool>(value)); }
        if Equals(typeName, n"Int32") { text = IntToString(FromVariant<Int32>(value)); }
        if Equals(typeName, n"Uint32") { text = IntToString(Cast<Int32>(FromVariant<Uint32>(value))); }
        if Equals(typeName, n"Float") { text = FloatToString(FromVariant<Float>(value)); }
        if Equals(typeName, n"CName") { text = NameToString(FromVariant<CName>(value)); }
        if Equals(typeName, n"gameItemID") { text = ArmSwapperName(FromVariant<ItemID>(value)); }
        if Equals(prop.GetType().GetMetaType(), ERTTIType.Enum) { text = "(enum " + NameToString(typeName) + ")"; }
        if StrLen(text) > 0 {
            line += " " + NameToString(prop.GetName()) + "=" + text;
        }
    }
    ArmSwapperLog(game, line);
    if listFunctions {
        let names: String = "glamdoc functions:";
        for fn in cls.GetFunctions() {
            names += " " + NameToString(fn.GetName());
        }
        ArmSwapperLog(game, names);
        let fields: String = "glamdoc fields:";
        for prop in cls.GetProperties() {
            fields += " " + NameToString(prop.GetName()) + ":" + NameToString(prop.GetType().GetName());
        }
        ArmSwapperLog(game, fields);
    }
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperDumpGlamdoc(menu: ref<GlamDocGameController>, label: String, listFunctions: Bool) {}

// Debug: what the game has recorded as last used, and what drawing a weapon would bring out
public func ArmSwapperLogNextDraw(player: ref<PlayerPuppet>) {
    if !(new SimpleArmSwapperSettings()).debugLogging || !IsDefined(player) { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return; }
    let last: SLastUsedWeapon = eqData.GetLastUsedStruct();
    let tags: String = "";
    let lastRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(last.lastUsedWeapon));
    if IsDefined(lastRecord) {
        tags = " (melee tag " + BoolToString(lastRecord.TagsContains(n"MeleeWeapon")) + ", meleeware tag " + BoolToString(lastRecord.TagsContains(n"Meleeware")) + ")";
    }
    ArmSwapperLog(player.GetGame(), "  last used weapon=" + ArmSwapperName(last.lastUsedWeapon) + tags + " melee=" + ArmSwapperName(last.lastUsedMelee)
        + " ranged=" + ArmSwapperName(last.lastUsedRanged) + " | next draw: last-or-first=" + ArmSwapperName(eqData.GetLastUsedOrFirstAvailableWeapon())
        + " last-weapon=" + ArmSwapperName(eqData.GetLastUsedWeaponItemID()) + " slot-active=" + ArmSwapperName(eqData.GetSlotActiveWeapon()));
}

// --- Inventory screen ---
// The inventory screen builds its own copy of V too. Its arms are put away, so they get the third
// person pieces of the style of the arms shown, like photo mode.

public class ArmSwapperInventoryStyleCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let puppet: wref<gamePuppet>;
    public let reason: String;
    public let dump: Bool;

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        let puppet: ref<gamePuppet> = this.puppet;
        if !IsDefined(player) || !IsDefined(puppet) { return; }
        ArmSwapperHideStrayLauncher(player, puppet);
        ArmSwapperGorillaNails(player, puppet);
        let holstered: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(puppet, t"AttachmentSlots.RightArm");
        if !IsDefined(holstered) { return; }
        let arms: ItemID = ArmSwapperArmsForHolstered(player, holstered.GetItemID());
        if !ItemID.IsValid(arms) { return; }
        ArmSwapperStylePiecesOf(player, puppet, arms, this.reason, n"htpp");
        if this.dump {
            ArmSwapperDumpMeshes(player.GetGame(), puppet, "inventory");
        }
    }
}

public func ArmSwapperStyleInventorySoon(player: ref<PlayerPuppet>, puppet: ref<gamePuppet>) {
    if !IsDefined(player) || !IsDefined(puppet) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    // The inventory shows V's arms put away: with their own colours, even if the launcher was out
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) { system.ArmSwapperLauncherColours(false); }
    let delays: array<Float> = [0.0, 0.1, 0.3, 0.6, 1.0, 2.0];
    for delay in delays {
        let callback: ref<ArmSwapperInventoryStyleCallback> = new ArmSwapperInventoryStyleCallback();
        callback.player = player;
        callback.puppet = puppet;
        callback.reason = "inventory after " + FloatToStringPrec(delay, 1) + "s";
        callback.dump = delay > 1.5;
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

@wrapMethod(inkPuppetPreviewGameController)
protected cb func OnPreviewInitialized() -> Bool {
    let result: Bool = wrappedMethod();
    if Equals(this.GetClassName(), n"gameuiInventoryPuppetPreviewGameController") {
        ArmSwapperStyleInventorySoon(this.GetPlayerControlledObject() as PlayerPuppet, this.GetGamePuppet());
    }
    return result;
}
