// r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
// Simple Arm Swapper v2.3.1

// Other mods can detect this one with @if(ModuleExists("SimpleArmSwapperMod"))
module SimpleArmSwapperMod

@if(ModuleExists("Codeware.Localization"))
import Codeware.Localization.*

public func Version() -> String = "2.3.1"

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
        + " colours=" + IntToString(Cast<Int32>(data.primaryColorIndex)) + "," + IntToString(Cast<Int32>(data.secondaryColorIndex));
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
        if count <= 1 { return; }

        // Only cycle while arms are already out. Otherwise the game draws the
        // remembered arms on its own (see the GetActiveMeleeWare wrap below)
        let heldObject: ref<ItemObject> = ts.GetItemInSlot(player, t"AttachmentSlots.WeaponRight");
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

        // Send a native Equip Request using its true designated slot index instead of forcing slot 0
        let request: ref<EquipRequest> = new EquipRequest();
        request.owner = player;
        request.itemID = nextArmsID;
        request.slotIndex = targetSlotIndex;

        eqSystem.QueueRequest(request);

        // Immediate visual draw update if arms are already active
        let activeWeapon: ItemID = eqData.GetSlotActiveWeapon();
        if ItemID.IsValid(activeWeapon) {
            eqData.DrawItem(nextArmsID, gameEquipAnimationType.Default);
        }
    }
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
    ArmSwapperLog(player.GetGame(), "arms in hand: " + ArmSwapperName(arms) + ". " + ArmSwapperArmsState(player));
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
    if equipHolsteredItem {
        holsteredArms = EquipmentSystemPlayerData.GetArmSwapperHolsteredArms(player, lastUsedArms);
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

// Shows the given arms with their own style: the one remembered for their type, or no
// style if that type has never been styled, rather than another type's style. While the
// Glamdoc is open this only happens when the menu itself asks for it.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperApplyStyleFor(armsItem: ItemID, opt fromGlamdoc: Bool) {
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
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
    if this.savedData.customizationItemID == styleItem && this.savedData.switcherIndex == Cast<Uint32>(switcherIndex)
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
            if armsType >= 0 {
                memory.Remember(armsType, ItemID.None(), request.switcherName, false, 0, 0);
            }
        }
    }
    this.ArmSwapperApplyStyleForActiveArms();
}

@wrapMethod(CyberwareCustomizationSystem)
private final func OnSaveAndApplyCyberwareCustomizationColorRequest(request: ref<SaveAndApplyCyberWareCustomColorRequest>) {
    wrappedMethod(request);
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
    return result;
}

@wrapMethod(GlamDocGameController)
protected cb func OnUninitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let game: GameInstance = GetGameInstance();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) { memory.glamdocOpen = false; }

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
    return this.ItemTagToIndex(itemData) == activeType;
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
    if NotEquals(this.m_screenType, GlamdocScreenType.Appearance) || this.m_isInPopup || this.m_isInPreviewMode { return result; }
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
    if (new SimpleArmSwapperSettings()).stylePerArmType && ArmSwapperHasSeveralArmTypes(this.m_player) {
        this.m_buttonHintsController.AddButtonHint(n"UI_Apply", SimpleArmSwapperText("SimpleArmSwapper-Glamdoc-BuyAndApply"));
    }
}

@wrapMethod(GlamDocGameController)
private final func ExitPreviewMode(opt skipRestorePreviousCyberware: Bool) {
    wrappedMethod(skipRestorePreviousCyberware);
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
    wrappedMethod(slot, item);
}

@wrapMethod(GlamDocGameController)
protected cb func OnInventoryPuppetReceived(puppet: ref<gamePuppet>) -> Bool {
    ArmSwapperLog(this.m_player.GetGame(), "glamdoc preview character received. " + ArmSwapperArmsState(this.m_player));
    return wrappedMethod(puppet);
}
