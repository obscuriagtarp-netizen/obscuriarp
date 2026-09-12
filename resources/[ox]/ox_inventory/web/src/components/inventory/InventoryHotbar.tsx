import React, { useState } from 'react';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { Items } from '../../store/items';
import WeightBar from '../utils/WeightBar';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { SlotWithItem } from '../../typings';
import SlideUp from '../utils/transitions/SlideUp';
import InventorySlot from './InventorySlot';

type Props = {
  embedded?: boolean;
  hidden?: boolean;
};

const InventoryHotbar: React.FC<Props> = ({ embedded = false, hidden = false }) => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const inventory = useAppSelector(selectLeftInventory);
  const items = inventory.items.slice(0, 5);

  //stupid fix for timeout
  const [handle, setHandle] = useState<NodeJS.Timeout>();
  useNuiEvent('toggleHotbar', () => {
    if (hotbarVisible) {
      setHotbarVisible(false);
    } else {
      if (handle) clearTimeout(handle);
      setHotbarVisible(true);
      setHandle(setTimeout(() => setHotbarVisible(false), 3000));
    }
  });

  const embeddedHotbar = (
    <div className="hotbar-container hotbar-container--embedded">
      {items.map((item) => (
        <div className="hotbar-entry" key={`embedded-hotbar-${item.slot}`}>
          <span className="hotbar-keycap">{item.slot}</span>
          <InventorySlot
            item={item}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
            inventoryId={inventory.id}
          />
        </div>
      ))}
    </div>
  );

  const floatingHotbar = (
      <div className={`hotbar-container${embedded ? ' hotbar-container--embedded' : ''}`}>
        {items.map((item) => (
          <div className="hotbar-entry" key={`hotbar-${item.slot}`}>
            <span className="hotbar-keycap">{item.slot}</span>
            <div
              className="hotbar-item-slot"
              style={{
                backgroundImage: `url(${item?.name ? getItemUrl(item as SlotWithItem) : 'none'}`,
              }}
            >
              {isSlotWithItem(item) && (
                <div className="item-slot-wrapper">
                  <div className="hotbar-slot-header-wrapper">
                    <div className="item-slot-info-wrapper">
                      <p>
                        {item.weight > 0
                          ? item.weight >= 1000
                            ? `${(item.weight / 1000).toLocaleString('en-us', {
                                minimumFractionDigits: 2,
                              })}kg `
                            : `${item.weight.toLocaleString('en-us', {
                                minimumFractionDigits: 0,
                              })}g `
                          : ''}
                      </p>
                      <p>{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
                    </div>
                  </div>
                  <div>
                    {item?.durability !== undefined && <WeightBar percent={item.durability} durability />}
                    <div className="inventory-slot-label-box">
                      <div className="inventory-slot-label-text">
                        {item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name}
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
  );

  if (embedded) return embeddedHotbar;

  return <SlideUp in={!hidden && hotbarVisible}>{floatingHotbar}</SlideUp>;
};

export default InventoryHotbar;
