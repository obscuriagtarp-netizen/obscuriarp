import { useNuiState } from '../../hooks/nuiState';
import VisualWardrobe, { WardrobeEntry } from './components/VisualWardrobe';
import { ComponentConfig, ComponentSettings, PedComponent } from './interfaces';

interface ComponentsProps {
  settings: ComponentSettings[];
  data: PedComponent[];
  storedData: PedComponent[];
  handleComponentDrawableChange: (componentId: number, drawable: number) => void;
  handleComponentTextureChange: (componentId: number, texture: number) => void;
  componentConfig: ComponentConfig;
  hasTracker: boolean;
  isPedFreemodeModel: boolean | undefined;
}

const Components = ({ settings, data, storedData, handleComponentDrawableChange, handleComponentTextureChange, componentConfig, hasTracker, isPedFreemodeModel }: ComponentsProps) => {
  const { locales } = useNuiState();
  if (!locales) return null;

  const settingsById = Object.fromEntries(settings.map(item => [item.component_id, item]));
  const dataById = Object.fromEntries(data.map(item => [item.component_id, item]));
  const storedById = Object.fromEntries(storedData.map(item => [item.component_id, item]));
  const entries: WardrobeEntry[] = [];

  const add = (enabled: boolean | undefined, id: number, key: string, label: string, subtitle: string, icon: string) => {
    const setting = settingsById[id];
    const current = dataById[id];
    const stored = storedById[id];
    if (!enabled || !setting || !current || !stored) return;
    entries.push({
      id, key, kind: 'component', label, subtitle, icon,
      drawable: current.drawable, storedDrawable: stored.drawable,
      texture: current.texture, storedTexture: stored.texture,
      drawableMin: setting.drawable.min, drawableMax: setting.drawable.max,
      textureMin: setting.texture.min, textureMax: setting.texture.max,
      blacklistedDrawables: setting.blacklist.drawables,
      blacklistedTextures: setting.blacklist.textures,
      onDrawableChange: value => handleComponentDrawableChange(id, value),
      onTextureChange: value => handleComponentTextureChange(id, value),
    });
  };

  add(!isPedFreemodeModel, 0, 'head', locales.components.head, 'Modelo base da cabeça do personagem.', 'head.png');
  add(componentConfig.masks, 1, 'mask', locales.components.mask, 'Máscaras, bandanas e coberturas faciais.', 'mask.png');
  add(componentConfig.jackets, 11, 'torso', locales.components.jackets, 'Casacos, jaquetas e peças externas.', 'jacket.png');
  add(componentConfig.shirts, 8, 'undershirt', locales.components.shirt, 'Camisas, regatas e peças internas.', 'shirt.png');
  add(componentConfig.upperBody, 3, 'arms', locales.components.upperBody, 'Braços, mangas e luvas compatíveis.', 'arms.png');
  add(componentConfig.bodyArmor, 9, 'vest', locales.components.bodyArmor, 'Coletes e proteções corporais.', 'vest.png');
  add(componentConfig.scarfAndChains && !hasTracker, 7, 'accessory', locales.components.scarfAndChains, 'Colares, gravatas e detalhes do torso.', 'necklace.png');
  add(componentConfig.bags, 5, 'bag', locales.components.bags, 'Mochilas, bolsas e paraquedas.', 'bag.png');
  add(componentConfig.lowerBody, 4, 'pants', locales.components.lowerBody, 'Calças, shorts e peças inferiores.', 'pants.png');
  add(componentConfig.shoes, 6, 'shoes', locales.components.shoes, 'Sapatos, tênis e botas.', 'shoes.png');
  add(componentConfig.decals, 10, 'decals', locales.components.decals, 'Estampas, emblemas e aplicações.', 'decals.png');

  return <VisualWardrobe title={locales.components.title} entries={entries} />;
};

export default Components;
