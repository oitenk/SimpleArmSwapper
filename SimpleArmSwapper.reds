// r6/scripts/SimpleArmSwapper.reds
// Simple Arm Swapper v2.0

public class SimpleArmSwapper extends ScriptableSystem {

    @runtimeProperty("ModSettings.mod", "Simple Arm Swapper")
    @runtimeProperty("ModSettings.displayName", "Weapon Wheel Shows Next Arms")
    @runtimeProperty("ModSettings.description", "While arm cyberware is drawn, the weapon wheel's cyberware slot starts on the next arms in line, so selecting it swaps right away. Turn off to have it start on the arms you are holding.")
    public let wheelShowsNextArms: Bool = true;

    // Keeps the settings above in sync with the Mod Settings menu
    private func OnAttach() -> Void {
        ModSettings.RegisterListenerToClass(this);
    }

    private func OnDetach() -> Void {
        ModSettings.UnregisterListenerToClass(this);
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

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionName: CName = ListenerAction.GetName(action);
    let actionType: gameinputActionType = ListenerAction.GetType(action);

    if (Equals(actionName, n"WeaponSlot4") || Equals(actionName, n"CycleArmCyberware")) && Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
        let swapper: ref<SimpleArmSwapper> = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"SimpleArmSwapper") as SimpleArmSwapper;
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
    return GameInstance.GetScriptableSystemsContainer(this.GetPlayer().GetGame()).Get(n"SimpleArmSwapper") as SimpleArmSwapper;
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
            if this.GetArmSwapper().wheelShowsNextArms {
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
