import React from 'react';
import { useAppSelector } from '../../store';
import { Items } from '../../store/items';
import { selectLeftInventory } from '../../store/inventory';
import InventorySlot from './InventorySlot';
import amuletPlaceholder from '../../../images/ui-equipment-amulet.png';
import necklacePlaceholder from '../../../images/ui-equipment-necklace.png';
import beltPlaceholder from '../../../images/ui-equipment-belt.png';
import ringPlaceholder from '../../../images/ui-equipment-ring.png';

const equipmentSlots = [
  { slot: 6, type: 'amulet', label: 'Amuleto', image: amuletPlaceholder },
  { slot: 7, type: 'necklace', label: 'Colar', image: necklacePlaceholder },
  { slot: 8, type: 'belt', label: 'Cinto', image: beltPlaceholder },
  { slot: 9, type: 'ring', label: 'Anel', image: ringPlaceholder },
] as const;

const EquipmentDock: React.FC = () => {
  const inventory = useAppSelector(selectLeftInventory);

  return (
    <aside className="equipment-dock" aria-label="Equipamentos">
      <div className="equipment-dock-slots">
        {equipmentSlots.map((equipment) => {
          const item = inventory.items[equipment.slot - 1] || { slot: equipment.slot };
          const itemData = item.name ? Items[item.name] : undefined;
          const isInvalid = Boolean(item.name && itemData && itemData.equipment !== equipment.type);

          return (
            <div
              className={`equipment-entry${item.name ? ' is-equipped' : ''}${isInvalid ? ' is-invalid' : ''}`}
              data-equipment={equipment.type}
              key={equipment.type}
            >
              <div className="equipment-slot-shell">
                <InventorySlot
                  item={item}
                  inventoryType={inventory.type}
                  inventoryGroups={inventory.groups}
                  inventoryId={inventory.id}
                />
                {!item.name && (
                  <img
                    className="equipment-empty-image"
                    src={equipment.image}
                    alt=""
                    aria-hidden="true"
                  />
                )}
              </div>
              <span className="equipment-label">{isInvalid ? 'Incompativel' : equipment.label}</span>
            </div>
          );
        })}
      </div>
    </aside>
  );
};

export default EquipmentDock;
