// r6/scripts/simple_arm_swapper/SimpleArmSwapperArmSlots.reds
// Simple Arm Swapper: extra arm cyberware slots

module SimpleArmSwapperMod

// The base game has a single arm cyberware slot. This brings the arm area up to four slots, one
// for each arm type, so the swapper has something to swap between without any other mod.
//
// Only compiled with TweakXL installed (it provides ScriptableTweak) and Cyberware-EX absent.
// Cyberware-EX manages cyberware slots itself, through its own modes and configurations, so
// Simple Arm Swapper leaves the arm slots to it. Arm slots added by other mods count towards the
// four, so they are never stacked on top.
//
// Each new slot is a copy of the game's own arm slot, so it unlocks and keeps its cyberware
// across saves the same way. The game adds the new slots to existing saves when they load, and the
// ripperdoc puts new arms in an empty slot.
@if(ModuleExists("TweakXL") && !ModuleExists("CyberwareEx"))
public class SimpleArmSwapperArmSlots extends ScriptableTweak {

    protected cb func OnApply() -> Void {
        let target: Int32 = 4;
        let areaID: TweakDBID = t"EquipmentArea.ArmsCW";
        let slots: array<TweakDBID> = TweakDBInterface.GetForeignKeyArray(areaID + t".equipSlots");
        let existing: Int32 = ArraySize(slots);
        if existing == 0 || existing >= target { return; }

        let baseSlot: TweakDBID = slots[0];
        while ArraySize(slots) < target {
            let slotName: String = "EquipmentArea.SimpleArmSwapper_ArmsCW_Slot_" + IntToString(ArraySize(slots));
            let slotID: TweakDBID = TDBID.Create(slotName);
            if !IsDefined(TweakDBInterface.GetEquipSlotRecord(slotID)) {
                TweakDBManager.CloneRecord(StringToName(slotName), baseSlot);
            }
            ArrayPush(slots, slotID);
        }

        // Keep the area's default slot count at what it was before, as Cyberware-EX does
        if TweakDBInterface.GetIntDefault(areaID + t".defaultNumSlots") == 0 {
            TweakDBManager.SetFlat(areaID + t".defaultNumSlots", existing);
        }
        TweakDBManager.SetFlat(areaID + t".equipSlots", slots);
        TweakDBManager.UpdateRecord(areaID);
    }
}
