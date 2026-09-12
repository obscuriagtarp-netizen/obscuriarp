import { ItemData } from '../typings/item';

export const Items: {
  [key: string]: ItemData | undefined;
} = {
  water: {
    name: 'water',
    close: false,
    label: 'VODA',
    stack: true,
    usable: true,
    count: 0,
  },
  burger: {
    name: 'burger',
    close: false,
    label: 'BURGR',
    stack: false,
    usable: false,
    count: 0,
  },
  amuleto_latente: {
    name: 'amuleto_latente',
    close: false,
    label: 'Amuleto Latente',
    stack: false,
    usable: false,
    count: 1,
    equipment: 'amulet',
    image: 'images/10kgoldchain.png',
  },
  anel_latente: {
    name: 'anel_latente',
    close: false,
    label: 'Anel Latente',
    stack: false,
    usable: false,
    count: 1,
    equipment: 'ring',
    image: 'images/diamond_ring.png',
  },
};
