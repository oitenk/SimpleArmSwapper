// r6/scripts/simple_arm_swapper/SimpleArmSwapper.reds
// Simple Arm Swapper v2.3

// Other mods can detect this one with @if(ModuleExists("SimpleArmSwapperMod"))
module SimpleArmSwapperMod

public func Version() -> String = "2.3"

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
    public func GetSwitcherName(armsType: Int32) -> CName { this.EnsureEntries(); return this.m_switcherName[armsType]; }
    public func IsEnabled(armsType: Int32) -> Bool { this.EnsureEntries(); return this.m_enabled[armsType]; }
    public func GetPrimaryColor(armsType: Int32) -> Int32 { this.EnsureEntries(); return this.m_primaryColor[armsType]; }
    public func GetSecondaryColor(armsType: Int32) -> Int32 { this.EnsureEntries(); return this.m_secondaryColor[armsType]; }
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
    memory.Remember(ArmSwapperStyleType(styleItem), styleItem, this.savedData.switcherName, this.savedData.enabled,
        Cast<Int32>(this.savedData.primaryColorIndex), Cast<Int32>(this.savedData.secondaryColorIndex));
}

// Puts back the style remembered for the given arms, if their type has one. While the
// Glamdoc is open this only happens when the menu itself asks for it.
@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperApplyStyleFor(armsItem: ItemID, opt fromGlamdoc: Bool) {
    if !(new SimpleArmSwapperSettings()).stylePerArmType { return; }
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.GetGameInstance());
    if !IsDefined(memory) || (memory.glamdocOpen && !fromGlamdoc) { return; }
    let armsType: Int32 = ArmSwapperArmsType(armsItem);
    if !memory.HasStyle(armsType) { return; }
    let player: ref<PlayerPuppet> = this.m_playerPuppet as PlayerPuppet;
    if !IsDefined(player) { return; }

    let styleItem: ItemID = memory.GetStyleItem(armsType);
    let enabled: Bool = memory.IsEnabled(armsType);
    let switcherIndex: Int32 = 0;
    let brandDataID: TweakDBID = TDBID.None();
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
    let primaryColor: Uint8 = Cast<Uint8>(memory.GetPrimaryColor(armsType));
    let secondaryColor: Uint8 = Cast<Uint8>(memory.GetSecondaryColor(armsType));

    // Already showing this style
    if this.savedData.customizationItemID == styleItem && this.savedData.switcherIndex == Cast<Uint32>(switcherIndex)
        && Equals(this.savedData.enabled, enabled) && this.savedData.primaryColorIndex == primaryColor
        && this.savedData.secondaryColorIndex == secondaryColor {
        return;
    }

    this.savedData.enabled = enabled;
    this.savedData.customizationItemID = styleItem;
    this.savedData.switcherName = memory.GetSwitcherName(armsType);
    this.savedData.switcherIndex = Cast<Uint32>(switcherIndex);
    this.savedData.brandDataID = brandDataID;
    this.savedData.primaryColorIndex = primaryColor;
    this.savedData.secondaryColorIndex = secondaryColor;
    this.RestoreCyberwareCustomization(true);

    // Keep the style item the Glamdoc shows as equipped in step
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    let equipmentSystem: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
    if !IsDefined(eqData) || !IsDefined(equipmentSystem) { return; }
    if ItemID.IsValid(styleItem) {
        if !eqData.IsEquipped(styleItem) && GameInstance.GetTransactionSystem(player.GetGame()).HasItem(player, styleItem) {
            let equipRequest: ref<EquipRequest> = new EquipRequest();
            equipRequest.owner = player;
            equipRequest.itemID = styleItem;
            equipRequest.slotIndex = 0;
            equipmentSystem.QueueRequest(equipRequest);
        }
    } else {
        if ItemID.IsValid(eqData.GetActiveItem(gamedataEquipmentArea.ArmsCWStyle)) {
            let unequipRequest: ref<UnequipRequest> = new UnequipRequest();
            unequipRequest.areaType = gamedataEquipmentArea.ArmsCWStyle;
            unequipRequest.owner = player;
            unequipRequest.slotIndex = 0;
            unequipRequest.force = false;
            equipmentSystem.QueueRequest(unequipRequest);
        }
    }
}

@addMethod(CyberwareCustomizationSystem)
public func ArmSwapperApplyStyleForActiveArms() {
    if !IsDefined(this.m_playerPuppet) { return; }
    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.m_playerPuppet);
    if !IsDefined(eqData) { return; }
    this.ArmSwapperApplyStyleFor(eqData.GetActiveMeleeWare());
}

// A style was saved or taken off: file it, then make sure the arms in use show theirs
@wrapMethod(CyberwareCustomizationSystem)
private final func OnSaveAndApplyCyberwareCustomizationDataRequest(request: ref<SaveAndApplyCyberwareCustomizationDataRequest>) {
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
    if !ItemID.IsValid(itemToDraw) || !TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemToDraw)).TagsContains(n"Meleeware") { return; }
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(this.m_owner.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) {
        system.ArmSwapperApplyStyleFor(itemToDraw);
    }
}

// --- The Glamdoc menu ---

// Arms picked on the Glamdoc's type tabs while the menu is open
@addField(GlamDocGameController)
private let m_armSwapperArms: ItemID;

// The arms the Glamdoc works on: those picked on its type tabs, otherwise the arms used last
@addMethod(GlamDocGameController)
private func ArmSwapperGlamdocArms() -> ItemID {
    if ItemID.IsValid(this.m_armSwapperArms) { return this.m_armSwapperArms; }
    return EquipmentSystem.GetData(this.m_player).GetActiveMeleeWare();
}

@wrapMethod(GlamDocGameController)
protected cb func OnInitialize() -> Bool {
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(GetGameInstance());
    if IsDefined(memory) { memory.glamdocOpen = true; }
    return wrappedMethod();
}

@wrapMethod(GlamDocGameController)
protected cb func OnUninitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let game: GameInstance = GetGameInstance();
    let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(game);
    if IsDefined(memory) { memory.glamdocOpen = false; }
    let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
    if IsDefined(system) { system.ArmSwapperApplyStyleForActiveArms(); }
    return result;
}

// Styles fit if any equipped arms are of their type, not only those in the first slot
@wrapMethod(GlamDocGameController)
private final func CheckIfCanApply(itemData: wref<gameItemData>) -> Bool {
    if wrappedMethod(itemData) { return true; }
    if !(new SimpleArmSwapperSettings()).stylePerArmType || !IsDefined(itemData) { return false; }
    return ItemID.IsValid(ArmSwapperEquippedArmsOfType(this.m_player, this.ItemTagToIndex(itemData)));
}

// The menu opens on the type of the arms used last
@wrapMethod(GlamDocGameController)
private final func GetCurrentArmsWareType() -> ArmsWareType {
    if (new SimpleArmSwapperSettings()).stylePerArmType {
        let armsType: Int32 = ArmSwapperArmsType(this.ArmSwapperGlamdocArms());
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
    let arms: ItemID = this.ArmSwapperGlamdocArms();
    if !ItemID.IsValid(arms) { return; }
    let items: array<wref<UIInventoryItem>> = this.m_uiInventorySystem.GetPlayerAreaItems(gamedataEquipmentArea.ArmsCW);
    for item in items {
        if IsDefined(item) && item.GetID() == arms {
            this.m_equippedArmItem = item;
        }
    }
}

// Picking another arm type's tab shows those arms on the preview character
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
    let arms: ItemID = ArmSwapperEquippedArmsOfType(this.m_player, tabType);
    if ItemID.IsValid(arms) && ItemID.GetTDBID(arms) != ItemID.GetTDBID(this.m_currentCyberarmItem) {
        this.m_armSwapperArms = arms;
        this.InitializeEquippedCyberArm();

        // Load that type's remembered style, so the menu shows it as the current one
        let system: ref<CyberwareCustomizationSystem> = GameInstance.GetScriptableSystemsContainer(this.m_player.GetGame()).Get(n"CyberwareCustomizationSystem") as CyberwareCustomizationSystem;
        let memory: ref<SimpleArmSwapperStyleMemory> = SimpleArmSwapperStyleMemory.Get(this.m_player.GetGame());
        if IsDefined(system) && IsDefined(memory) {
            if memory.HasStyle(tabType) {
                system.ArmSwapperApplyStyleFor(arms, true);
                let savedData: CyberwareCustomizationPersistentData = system.GetSavedData();
                this.UpdateCurrentCustomizationItem(savedData.customizationItemID);
                this.InitializeBrandData(CyberwareCustomizationPersistentData.GetBrandDataID(savedData));
            } else {
                this.UpdateCurrentCustomizationItem(ItemID.None());
            }
        }

        this.UpdatePuppetWithCyberware(arms);
    }
    return result;
}
