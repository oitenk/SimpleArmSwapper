// r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
// Simple Arm Swapper v2.3.1

// Other mods can detect this one with @if(ModuleExists("SimpleArmSwapperMod"))
module SimpleArmSwapperMod

@if(ModuleExists("Codeware.Localization"))
import Codeware.Localization.*

public func Version() -> String = "2.4"

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
    @runtimeProperty("ModSettings.category", "Troubleshooting")
    @runtimeProperty("ModSettings.displayName", "Debug Logging")
    @runtimeProperty("ModSettings.description", "Writes what the mod does with arms and Glamdoc styles to the Cyber Engine Tweaks game log (up to 5000 lines per session). Leave off unless asked for a log.")
    public let debugLogging: Bool = false;
}

// --- Debug log (off by default) ---

@addField(PlayerPuppet)
public let m_armSwapperLogLines: Int32;

public func ArmSwapperLog(game: GameInstance, message: String) {
    if !(new SimpleArmSwapperSettings()).debugLogging { return; }
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) || player.m_armSwapperLogLines >= 5000 { return; }
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

public class SimpleArmSwapper extends ScriptableSystem {

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
        if count <= 1 { return; }

        // Only cycle while arms are already out. Otherwise the game draws the
        // remembered arms on its own (see the GetActiveMeleeWare wrap below)
        if !IsDefined(heldObject) || !ArrayContains(meleewareItems, heldObject.GetItemID()) { return; }

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

        // Immediate visual draw update if arms are already active
        let activeWeapon: ItemID = eqData.GetSlotActiveWeapon();
        if ItemID.IsValid(activeWeapon) {
            eqData.DrawItem(nextArmsID, gameEquipAnimationType.Default);
        }
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
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionName: CName = ListenerAction.GetName(action);
    let actionType: gameinputActionType = ListenerAction.GetType(action);

    if (Equals(actionName, n"WeaponSlot4") || Equals(actionName, n"CycleArmCyberware")) && Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
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

    public func TakeSnapshot() {
        this.EnsureEntries();
        this.m_snapKnown = this.m_known;
        this.m_snapStyleItem = this.m_styleItem;
        this.m_snapSwitcherName = this.m_switcherName;
        this.m_snapEnabled = this.m_enabled;
        this.m_snapPrimaryColor = this.m_primaryColor;
        this.m_snapSecondaryColor = this.m_secondaryColor;
    }

    public func RestoreSnapshot() {
        if ArraySize(this.m_snapKnown) < 4 { return; }
        this.m_known = this.m_snapKnown;
        this.m_styleItem = this.m_snapStyleItem;
        this.m_switcherName = this.m_snapSwitcherName;
        this.m_enabled = this.m_snapEnabled;
        this.m_primaryColor = this.m_snapPrimaryColor;
        this.m_secondaryColor = this.m_snapSecondaryColor;
    }

    // Style data for styling the pieces of V's arms (see "Styling arms the game leaves unstyled")
    private let m_stylePieces: array<ref<ArmSwapperStylePiece>>;

    private let m_elementHints: array<ref<ArmSwapperElementHint>>;

    // The element each arm type's item was last seen with, for when its pieces are already styled
    private let m_lastElement: array<CName>;

    // Holstered Mantis Blade pieces the mod hid on V while the blades are out, with their masks
    public let hiddenHolstered: array<wref<IComponent>>;
    public let hiddenMasks: array<Uint64>;
    // V's own nail pieces switched off under a painted-nail style
    public let hiddenNails: array<wref<IComponent>>;

    public func ArmSwapperStylePieces() -> array<ref<ArmSwapperStylePiece>> {
        if ArraySize(this.m_stylePieces) == 0 {
            ArmSwapperBuildStylePieces(this.m_stylePieces);
            ArmSwapperBuildElementHints(this.m_elementHints);
        }
        return this.m_stylePieces;
    }

    public func ArmSwapperElementHints() -> array<ref<ArmSwapperElementHint>> {
        this.ArmSwapperStylePieces();
        return this.m_elementHints;
    }

    public func ArmSwapperRememberElement(armsType: Int32, element: CName) {
        while ArraySize(this.m_lastElement) < 4 { ArrayPush(this.m_lastElement, n"base"); }
        if armsType >= 0 && armsType < 4 { this.m_lastElement[armsType] = element; }
    }

    public func ArmSwapperLastElement(armsType: Int32) -> CName {
        if armsType >= 0 && armsType < ArraySize(this.m_lastElement) { return this.m_lastElement[armsType]; }
        return n"base";
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
    // Only Mantis Blades have a MaxTac look. For any other arms just clear the flag in the saved style
    // data (their own style is applied next): calling the game's MaxTac functions now would apply
    // the Mantis Blade pieces again while the other arms come out.
    if ArmSwapperArmsType(active) != 1 {
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

// The game repeats its MaxTac check whenever the holstered Mantis Blades appear (mounting a bike,
// for one), which switches the MaxTac look back on over a style. Apply the style rule again
// straight after, and restyle the arms V is wearing.
@wrapMethod(CyberwareCustomizationSystem)
private final func OnPotentiallyRefreshMaxTacApperance(request: ref<PotentiallyRefreshMaxTacApperanceRequest>) {
    let before: Bool = this.savedData.hasMaxTacApperanceEquipped;
    wrappedMethod(request);
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
    // Restyle what V is wearing now: the arms in hand, or the holstered arms
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    let inHand: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
    if IsDefined(inHand) && inHand.GetItemID() == arms {
        ArmSwapperStylePiecesSoon(player, player, arms, n"out", t"AttachmentSlots.WeaponRight", arms);
    }
    let holstered: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.RightArm");
    if IsDefined(holstered) && ArmSwapperArmsForHolstered(player, holstered.GetItemID()) == arms {
        ArmSwapperStylePiecesSoon(player, player, arms, n"hfppAuto", t"AttachmentSlots.RightArm", holstered.GetItemID());
        ArmSwapperStylePiecesSoon(player, player, arms, n"htppAuto", t"AttachmentSlots.RightArm", holstered.GetItemID());
    }
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
    this.ArmSwapperRefreshMaxTacLook(styled);
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
        if NotEquals(ownSwitcher, n"None") {
            this.SetIndexForCustomizationSwitcher(ownSwitcher, Cast<Uint32>(0), true);
        }
        let noColor: Color;
        this.SetCustomizationParameters(false, noColor, noColor);
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
    this.RestoreCyberwareCustomization(true);
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
    this.ArmSwapperRememberCurrentStyle();
    this.ArmSwapperApplyStyleForActiveArms();
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

// More than one melee arm cyberware type equipped. The Projectile Launch System does not count:
// it cannot keep a style of its own beside melee arms.
public func ArmSwapperHasSeveralArmTypes(player: ref<GameObject>) -> Bool {
    let found: Int32 = 0;
    let armsType: Int32 = 1;
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

// The arms the menu is working on: V's active arms
@addMethod(GlamDocGameController)
private func ArmSwapperActiveArms() -> ItemID {
    return EquipmentSystem.GetData(this.m_player).GetActiveMeleeWare();
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
    if !eqData.ArmSwapperMakeActiveArms(arms) { return; }
    // A style previewed for the previous arms does not carry over
    this.m_armSwapperPreviewItem = ItemID.None();
    // The holstered arms in third person follow along
    EquipmentSystemPlayerData.UpdateArmSlot(player, arms, true);

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

    // The game puts V's weapons away while the menu is open and draws them again after it
    // closes; ArmSwapperArmsInHand matches the style to whatever arms come back.
    let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
    ArmSwapperLog(game, "glamdoc closed. " + ArmSwapperArmsState(player));
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) { system.ArmSwapperApplyStyleForActiveArms(); }
    return result;
}

// Discarding puts every arm type's style back, and the arms that were active when the menu
// opened, before the menu restores its own copy of their style
@wrapMethod(GlamDocGameController)
private final func DiscardChangesAndQuitVendor() {
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc closing without applying (changes to discard: " + BoolToString(this.m_hasChangesToApply) + ")");
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
    if IsDefined(memory) { memory.RestoreSnapshot(); }
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
    // Only melee arms are switched to. The launcher tab keeps the game's behaviour: the launcher
    // cannot keep a style of its own beside melee arms.
    if tabType < 1 { return result; }
    let arms: ItemID = ArmSwapperEquippedArmsOfType(this.m_player, tabType);
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc tab " + IntToString(tabType) + " -> arms " + ArmSwapperName(arms));
    if ItemID.IsValid(arms) && ArmSwapperArmsType(this.ArmSwapperActiveArms()) != tabType {
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
        this.ArmSwapperSwitchTo(arms);
    }
    return result;
}

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
    if slot == t"AttachmentSlots.RightArm" || slot == t"AttachmentSlots.WeaponRight" {
        let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
        if IsDefined(memory) {
            let glamdoc: ref<GlamDocGameController> = memory.glamdoc;
            if IsDefined(glamdoc) {
                glamdoc.ArmSwapperStylePreviewArrived();
            }
        }
    }
    wrappedMethod(slot, item);
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

// --- Styling arms the game leaves unstyled ---
// The game styles arm cyberware from one "owner": the arms in the first arm slot when the save
// loaded. Mantis Blades, Monowire and the Projectile Launch System share that styling, so with more
// than one of them installed, only the owner showed its Glamdoc style. A style only tells named
// pieces of V's arms which mesh and look to use, so the mod applies the saved style of the arms in
// use to those pieces itself, from the game's own style data (SimpleArmSwapperStyleData.reds). Pieces
// the game already styled are left alone.

// The game's style switcher for each melee arm type
public func ArmSwapperSwitcherForType(armsType: Int32) -> CName {
    if armsType == 0 { return n"launcher"; }
    if armsType == 1 { return n"mantis"; }
    if armsType == 2 { return n"monowire"; }
    if armsType == 3 { return n"strongarms"; }
    return n"None";
}

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

// Which parts of a piece's mesh show (its chunk mask)
@if(ModuleExists("Codeware"))
public func ArmSwapperPieceMask(comp: ref<IComponent>, out mask: Uint64) -> Bool {
    let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
    if IsDefined(skinned) { mask = skinned.chunkMask; return true; }
    let plain: ref<MeshComponent> = comp as MeshComponent;
    if IsDefined(plain) { mask = plain.chunkMask; return true; }
    return false;
}

@if(ModuleExists("Codeware"))
public func ArmSwapperSetPieceMask(comp: ref<IComponent>, mask: Uint64) {
    let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
    if IsDefined(skinned) { skinned.chunkMask = mask; return; }
    let plain: ref<MeshComponent> = comp as MeshComponent;
    if IsDefined(plain) { plain.chunkMask = mask; }
}

// Applies the saved style of the given arms to the pieces of V's arms. Returns how many pieces it
// changed, or -1 when there is nothing to apply.
@if(ModuleExists("Codeware"))
public func ArmSwapperStylePiecesOf(player: ref<PlayerPuppet>, owner: ref<Entity>, arms: ItemID, reason: String, opt view: CName, opt styleOverride: ItemID) -> Int32 {
    if Equals(view, n"None") { view = n"out"; }
    // V's holstered arms: "hfppAuto" styles only first person pieces, "htppAuto" only third person
    // ones (V wears those in vehicles, even in first person view)
    let onlyFpp: Bool = Equals(view, n"hfppAuto");
    let onlyTpp: Bool = Equals(view, n"htppAuto");
    if onlyFpp { view = n"hfpp"; }
    if onlyTpp { view = n"htpp"; }
    if (Equals(view, n"hfpp") || Equals(view, n"htpp")) && owner == player && ArmSwapperArmsType(arms) == 1 {
        ArmSwapperShowHiddenHolstered(player);
    }
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !IsDefined(player) || !IsDefined(owner) { return -1; }
    let game: GameInstance = player.GetGame();
    let armsType: Int32 = ArmSwapperArmsType(arms);
    // Mantis Blades and Monowire only: the game styles Gorilla Arms itself wherever they sit
    if armsType < 1 || armsType > 2 { return -1; }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if !IsDefined(memory) { return -1; }
    // The Glamdoc preview character shows the style being previewed, else the saved one, else
    // the plain look. Everywhere else only a saved style is applied.
    let isPreview: Bool = Equals(view, n"preview") || Equals(view, n"previewOut");
    let styleItem: ItemID = ItemID.None();
    if ItemID.IsValid(styleOverride) {
        if ArmSwapperStyleType(styleOverride) != armsType { return -1; }
        styleItem = styleOverride;
    } else {
        if memory.HasStyle(armsType) && memory.IsEnabled(armsType) {
            styleItem = memory.GetStyleItem(armsType);
        }
    }
    let index: Int32 = -1;
    let plainOnly: Bool = false;
    if ItemID.IsValid(styleItem) {
        index = ArmSwapperStyleIndex(player, styleItem);
    } else {
        if armsType == 1 {
            // Mantis Blades without a style: the plain pieces, which also undoes earlier styling
            // left behind on MaxTac-based blades. The blade look is left to the item (MaxTac blades
            // keep their MaxTac look). Only the Mantis Blades: the Monowire uses the same piece
            // names in hand and put away, so plain in-hand pieces would land on holstered ones.
            index = 0;
            plainOnly = true;
        } else {
            if isPreview { index = 0; }
        }
    }
    let switcher: CName = memory.GetKnownSwitcherName(armsType);
    if Equals(switcher, n"None") { switcher = ArmSwapperSwitcherForType(armsType); }
    if index < 0 || Equals(switcher, n"None") { return -1; }
    let gender: String = Equals(player.GetResolvedGenderName(), n"Female") ? "f" : "m";

    // Arms in every slot are checked, the first included. The game styles some of them itself, but
    // not always (MaxTac-based arms, arms swapped in at a ripperdoc); where it did, the pieces
    // already match and nothing changes.
    let comps: array<ref<IComponent>> = owner.GetComponents();

    // The item's element, from the look its element pieces start with (arms out only)
    let isOut: Bool = Equals(view, n"out") || Equals(view, n"previewOut");
    let useElement: Bool = (isOut || isPreview) && !plainOnly;
    let hintKey: CName = StringToName(gender + "_" + NameToString(switcher));
    let element: CName = n"None";
    for hint in memory.ArmSwapperElementHints() {
        if useElement && Equals(hint.key, hintKey) && Equals(element, n"None") {
            for comp in comps {
                if IsDefined(comp) && Equals(comp.GetName(), hint.comp) {
                    let m: ResRef;
                    let l: CName;
                    if ArmSwapperPieceLook(comp, m, l) && Equals(l, hint.app) {
                        element = hint.element;
                    }
                }
            }
        }
    }
    if Equals(element, n"None") {
        element = memory.ArmSwapperLastElement(armsType);
    } else {
        memory.ArmSwapperRememberElement(armsType, element);
    }

    let prefix: String = gender + "_" + NameToString(switcher) + "_" + IntToString(index) + "_";
    let armsSuffix: String = isOut ? "arms" : (isPreview ? "htpp" : NameToString(view));
    let armsKey: CName = StringToName(prefix + armsSuffix);
    let elementKey: CName = useElement ? StringToName(prefix + NameToString(element)) : n"None";
    let changed: Int32 = 0;
    let found: Int32 = 0;
    for piece in memory.ArmSwapperStylePieces() {
        if Equals(piece.key, armsKey) || Equals(piece.key, elementKey) {
            for comp in comps {
                if IsDefined(comp) && Equals(comp.GetName(), piece.comp) {
                    let mesh: ResRef;
                    let look: CName;
                    let mask: Uint64;
                    // A piece the game hid completely is a spare copy (V can carry several pieces of
                    // the same name, of which the game shows one) or not meant to show: leave it be
                    let pieceShown: Bool = ArmSwapperPieceLook(comp, mesh, look) && ArmSwapperPieceMask(comp, mask) && NotEquals(mask, 0ul);
                    if pieceShown && (onlyFpp || onlyTpp) {
                        let meshPath: String = ResRef.ToString(mesh);
                        let thirdPerson: Bool = StrContains(meshPath, "_tpp") || StrContains(meshPath, "photomode") || StrContains(meshPath, "photo_mode");
                        pieceShown = onlyTpp ? thirdPerson : !thirdPerson;
                    }
                    if pieceShown {
                        found += 1;
                        if piece.hide {
                            // A plain-style piece this style leaves out
                            if NotEquals(mask, 0ul) {
                                ArmSwapperSetPieceMask(comp, 0ul);
                                comp.RefreshAppearance();
                                changed += 1;
                                ArmSwapperLog(game, "  piece " + NameToString(piece.comp) + " hidden");
                            }
                        } else {
                            let wantLook: CName = piece.keepSkin ? look : piece.app;
                            // The game's own masks may set the top bit where the data does not;
                            // that bit makes no difference, so it is not a change
                            let maskChanged: Bool = NotEquals(mask | 9223372036854775808ul, piece.mask | 9223372036854775808ul);
                            if maskChanged {
                                ArmSwapperSetPieceMask(comp, piece.mask);
                                changed += 1;
                                ArmSwapperLog(game, "  piece " + NameToString(piece.comp) + " chunk mask " + s"\(mask) -> \(piece.mask)");
                            }
                            if NotEquals(mesh, piece.mesh) {
                                comp.ChangeResource(piece.mesh, true);
                                changed += 1;
                                ArmSwapperLog(game, "  piece " + NameToString(piece.comp) + " mesh " + ResRef.ToString(mesh) + " -> " + ResRef.ToString(piece.mesh));
                            }
                            if NotEquals(look, wantLook) {
                                comp.ChangeAppearance(wantLook, true);
                                changed += 1;
                                ArmSwapperLog(game, "  piece " + NameToString(piece.comp) + " look " + NameToString(look) + " -> " + NameToString(wantLook));
                            }
                            if maskChanged {
                                comp.RefreshAppearance();
                            }
                        }
                    }
                }
            }
        }
    }
    if changed > 0 {
        ArmSwapperLog(game, "styled pieces (" + reason + ") for " + ArmSwapperName(arms) + ": " + NameToString(armsKey)
            + (useElement ? " + " + NameToString(element) : "") + ", " + IntToString(changed) + " changes on " + IntToString(found) + " pieces");
    }
    if owner == player {
        // Leftover holstered Mantis hands while the blades are out (MaxTac-based blades after a style
        // change): hide them until the blades are put away
        if isOut && !isPreview && armsType == 1 {
            ArmSwapperHideHolsteredWhileOut(player, comps);
        }
        // Painted-nail styles replace V's own nails; switch those off, and back on without one
        ArmSwapperOwnNails(player, comps, armsType, index);
    }
    return changed;
}

@if(ModuleExists("Codeware"))
public func ArmSwapperHideHolsteredWhileOut(player: ref<PlayerPuppet>, comps: array<ref<IComponent>>) {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if !IsDefined(memory) { return; }
    for comp in comps {
        let mask: Uint64;
        if IsDefined(comp) && ArmSwapperPieceMask(comp, mask) && NotEquals(mask, 0ul) {
            let pieceName: String = NameToString(comp.GetName());
            if StrBeginsWith(pieceName, "a0_003_") && StrContains(pieceName, "holstered") {
                ArrayPush(memory.hiddenHolstered, comp);
                ArrayPush(memory.hiddenMasks, mask);
                ArmSwapperSetPieceMask(comp, 0ul);
                comp.RefreshAppearance();
                ArmSwapperLog(player.GetGame(), "  holstered piece " + pieceName + " hidden while the blades are out");
            }
        }
    }
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperHideHolsteredWhileOut(player: ref<PlayerPuppet>, comps: array<ref<IComponent>>) {}

// Styles that keep V's own nails: the plain style, two Mantis Blade styles and one Monowire style
public func ArmSwapperStyleKeepsOwnNails(armsType: Int32, index: Int32) -> Bool {
    // Gorilla Arms cover the hands: no own nails, as in the base game
    if armsType == 3 { return false; }
    if index <= 0 { return true; }
    if armsType == 1 { return index == 10 || index == 19; }
    if armsType == 2 { return index == 7; }
    return true;
}

// V's own nails go off under a painted-nail style and come back without one. The game does this
// itself, except after a style change on MaxTac-based blades, where they were left floating.
public func ArmSwapperOwnNails(player: ref<PlayerPuppet>, comps: array<ref<IComponent>>, armsType: Int32, index: Int32) {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if !IsDefined(memory) { return; }
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

// Whatever arms V now wears: leftover holstered Mantis Blade pieces only show while the Mantis
// Blades themselves are put away, and Gorilla Arms hide V's own nails
@if(ModuleExists("Codeware"))
public func ArmSwapperTidyWorn(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool) {
    if !IsDefined(player) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let comps: array<ref<IComponent>> = player.GetComponents();
    if !(armsType == 1 && holstered) {
        ArmSwapperHideHolsteredWhileOut(player, comps);
    }
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
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperTidyWorn(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool) {}

public class ArmSwapperTidyCallback extends DelayCallback {
    public let player: wref<PlayerPuppet>;
    public let armsType: Int32;
    public let holstered: Bool;

    public func Call() -> Void {
        ArmSwapperTidyWorn(this.player, this.armsType, this.holstered);
    }
}

public func ArmSwapperTidyWornSoon(player: ref<PlayerPuppet>, armsType: Int32, holstered: Bool) {
    if !IsDefined(player) { return; }
    ArmSwapperTidyWorn(player, armsType, holstered);
    let delays: array<Float> = [0.1, 0.4, 1.0];
    for delay in delays {
        let callback: ref<ArmSwapperTidyCallback> = new ArmSwapperTidyCallback();
        callback.player = player;
        callback.armsType = armsType;
        callback.holstered = holstered;
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

// Shows the holstered pieces hidden while the blades were out, as they were
@if(ModuleExists("Codeware"))
public func ArmSwapperShowHiddenHolstered(player: ref<PlayerPuppet>) {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(player.GetGame());
    if !IsDefined(memory) || ArraySize(memory.hiddenHolstered) == 0 { return; }
    let i: Int32 = 0;
    while i < ArraySize(memory.hiddenHolstered) {
        let comp: ref<IComponent> = memory.hiddenHolstered[i];
        if IsDefined(comp) && i < ArraySize(memory.hiddenMasks) {
            ArmSwapperSetPieceMask(comp, memory.hiddenMasks[i]);
            comp.RefreshAppearance();
        }
        i += 1;
    }
    ArmSwapperLog(player.GetGame(), "  " + IntToString(ArraySize(memory.hiddenHolstered)) + " holstered pieces shown again");
    ArrayClear(memory.hiddenHolstered);
    ArrayClear(memory.hiddenMasks);
}

@if(!ModuleExists("Codeware"))
public func ArmSwapperShowHiddenHolstered(player: ref<PlayerPuppet>) {}

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

    public func Call() -> Void {
        let player: ref<PlayerPuppet> = this.player;
        let target: ref<Entity> = this.target;
        if !IsDefined(player) || !IsDefined(target) { return; }
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
    if !IsDefined(player) || !IsDefined(target) || ArmSwapperArmsType(arms) < 1 { return; }
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
        callback.reason = NameToString(view) + " after " + FloatToStringPrec(delay, 2) + "s";
        GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(callback, delay, false);
    }
}

// Restyles the arms V wears right now, in hand or put away, over the next few seconds
public func ArmSwapperRestyleWorn(player: ref<PlayerPuppet>, why: String) {
    if !IsDefined(player) || !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(eqData) { return; }
    let arms: ItemID = eqData.GetActiveMeleeWare();
    if ArmSwapperArmsType(arms) < 1 { return; }
    ArmSwapperLog(player.GetGame(), "restyling worn arms (" + why + ") for " + ArmSwapperName(arms));
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let inHand: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
    if IsDefined(inHand) && inHand.GetItemID() == arms {
        ArmSwapperStylePiecesSoon(player, player, arms, n"out", t"AttachmentSlots.WeaponRight", arms, true);
    }
    let holstered: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.RightArm");
    if IsDefined(holstered) && ArmSwapperArmsForHolstered(player, holstered.GetItemID()) == arms {
        ArmSwapperStylePiecesSoon(player, player, arms, n"hfppAuto", t"AttachmentSlots.RightArm", holstered.GetItemID(), true);
        ArmSwapperStylePiecesSoon(player, player, arms, n"htppAuto", t"AttachmentSlots.RightArm", holstered.GetItemID(), true);
    }
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

// Photo mode builds its own copy of V; its holstered arms use the third person pieces
@wrapMethod(PhotoModePlayerEntityComponent)
protected cb func OnItemVisualsAddedToSlot(evt: ref<ItemVisualsAddedToSlot>) -> Bool {
    let result: Bool = wrappedMethod(evt);
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

// The style being previewed, or none while the saved style is shown
@addField(GlamDocGameController)
private let m_armSwapperPreviewItem: ItemID;

@addMethod(GlamDocGameController)
public func ArmSwapperStylePreviewNow(styleItem: ItemID, run: Int32, reason: String, dump: Bool) {
    if run != this.m_armSwapperPreviewRun { return; }
    let player: ref<PlayerPuppet> = this.m_player as PlayerPuppet;
    let puppet: ref<GameObject> = this.m_previewPuppet;
    if !IsDefined(player) || !IsDefined(puppet) { return; }
    let arms: ItemID = this.ArmSwapperActiveArms();
    if ArmSwapperArmsType(arms) < 1 { return; }
    // The preview shows the arms out, with the same pieces V wears with arms out; until the arms
    // arrive in its hand it wears them holstered (third person pieces)
    let inHand: ref<ItemObject> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemInSlot(puppet, t"AttachmentSlots.WeaponRight");
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
