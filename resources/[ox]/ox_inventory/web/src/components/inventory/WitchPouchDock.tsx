import React, { useEffect, useRef, useState } from 'react';
import { WitchPouchContext } from '../../typings/inventory';
import { fetchNui } from '../../utils/fetchNui';
import { isEnvBrowser } from '../../utils/misc';
import witchPouchClosed from '../../../images/ui-witch-pouch-closed.png';
import witchPouchOpening from '../../../images/ui-witch-pouch-opening.gif';
import witchPouchOpen from '../../../images/ui-witch-pouch-open-consistent.png';

type Props = {
  context: WitchPouchContext;
  active: boolean;
  onPreviewOpen?: () => void;
};

const WitchPouchDock: React.FC<Props> = ({ context, active, onPreviewOpen }) => {
  const [opening, setOpening] = useState(false);
  const [opened, setOpened] = useState(context.opened === true);
  const timer = useRef<number>();
  const animationDuration = 1080;

  useEffect(() => {
    if (!active) {
      setOpening(false);
      setOpened(false);

      if (timer.current) window.clearTimeout(timer.current);
    }
  }, [active]);

  useEffect(() => {
    if (context.opened === true) {
      setOpening(false);
      setOpened(true);
      if (timer.current) window.clearTimeout(timer.current);
    }
  }, [context.opened]);

  useEffect(
    () => () => {
      if (timer.current) window.clearTimeout(timer.current);
    },
    []
  );

  if (!context.visible) return null;

  const handleOpen = () => {
    if (!context.present || opening || opened) return;

    setOpening(true);
    timer.current = window.setTimeout(async () => {
      setOpening(false);

      if (isEnvBrowser()) {
        setOpened(true);
        onPreviewOpen?.();
        return;
      }

      try {
        const didOpen = await fetchNui<boolean>('openWitchPouch', {
          owner: context.owner,
          targetId: context.targetId,
          inspected: context.inspected === true,
        });

        setOpened(didOpen === true);
      } catch {
        setOpened(false);
      }
    }, animationDuration);
  };

  const pouchImage = opening ? witchPouchOpening : opened ? witchPouchOpen : witchPouchClosed;

  return (
    <aside
      className={`witch-pouch-dock${context.present ? ' is-available' : ' is-missing'}${
        opening ? ' is-opening' : ''
      }${opened ? ' is-open' : ''}`}
    >
      <button
        className="witch-pouch-button"
        type="button"
        onClick={handleOpen}
        disabled={!context.present || opening || opened}
        aria-label={context.present ? 'Abrir Bolsa Arcana' : 'Bolsa Arcana ausente'}
        title={context.present ? 'Abrir Bolsa Arcana' : 'Bolsa Arcana ausente'}
      >
        <img
          key={opening ? 'opening' : opened ? 'open' : 'closed'}
          src={pouchImage}
          alt=""
          draggable={false}
        />
      </button>
    </aside>
  );
};

export default WitchPouchDock;
