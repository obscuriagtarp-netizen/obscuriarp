import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import type { WitchPouchContext } from '../../typings/inventory';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';
import WitchPouchDock from './WitchPouchDock';
import EquipmentDock from './EquipmentDock';

const hiddenPouch: WitchPouchContext = {
  visible: false,
  present: false,
};

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const [witchPouch, setWitchPouch] = useState<WitchPouchContext>(hiddenPouch);
  const dispatch = useAppDispatch();

  const openPreviewPouch = () => {
    dispatch(
      setupInventory({
        rightInventory: {
          id: `witch_pouch:${witchPouch.owner || 'preview'}`,
          type: 'stash',
          slots: 20,
          label: 'Bolsa Arcana',
          weight: 0,
          maxWeight: 15000,
          items: [],
        },
      })
    );
    setWitchPouch((current) => ({ ...current, present: true, opened: true, label: 'Bolsa Arcana' }));
  };

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
    witchPouch?: WitchPouchContext;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    setWitchPouch(data.witchPouch || hiddenPouch);
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className={`inventory-wrapper${witchPouch.visible ? ' inventory-wrapper--witch' : ''}`}>
          <section className="inventory-column inventory-column-left">
            <EquipmentDock />
            <div className="inventory-frame-shell">
              <LeftInventory />
            </div>
            <InventoryHotbar embedded />
          </section>
          <InventoryControl />
          <section className="inventory-column inventory-column-right">
            <div className="inventory-frame-shell">
              <RightInventory />
            </div>
          </section>
          <WitchPouchDock context={witchPouch} active={inventoryVisible} onPreviewOpen={openPreviewPouch} />
          <Tooltip />
          <InventoryContext />
        </div>
      </Fade>
      <InventoryHotbar hidden={inventoryVisible} />
    </>
  );
};

export default Inventory;
