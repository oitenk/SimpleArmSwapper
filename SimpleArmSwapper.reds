// r6/scripts/SimpleArmSwapper.reds

public class SimpleArmSwapper extends ScriptableSystem {

    public func CycleMeleeware(player: ref<PlayerPuppet>) {
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
        let nextItemID: ItemID = meleewareItems[nextIndex];
        let targetSlotIndex: Int32 = slotIndices[nextIndex];

        // Send a native Equip Request using its true designated slot index instead of forcing slot 0
        let request: ref<EquipRequest> = new EquipRequest();
        request.owner = player;
        request.itemID = nextItemID;
        request.slotIndex = targetSlotIndex;

        eqSystem.QueueRequest(request);

        // Immediate visual draw update if arms are already active
        let activeWeapon: ItemID = eqData.GetSlotActiveWeapon();
        if ItemID.IsValid(activeWeapon) {
            eqData.DrawItem(nextItemID, gameEquipAnimationType.Default);
        }
    }
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let actionName: CName = ListenerAction.GetName(action);
    let actionType: gameinputActionType = ListenerAction.GetType(action);

    if (Equals(actionName, n"WeaponSlot4") || Equals(actionName, n"SwitchMeleeware")) && Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
        let swapper: ref<SimpleArmSwapper> = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"SimpleArmSwapper") as SimpleArmSwapper;
        if IsDefined(swapper) {
            swapper.CycleMeleeware(this);
        }
    }

    return wrappedMethod(action, consumer);
}
