import { useNuiState } from '../../hooks/nuiState';
import VisualWardrobe, { WardrobeEntry } from './components/VisualWardrobe';
import { PropSettings, PedProp, PropConfig } from './interfaces';

interface PropsProps {
  settings: PropSettings[];
  data: PedProp[];
  storedData: PedProp[];
  handlePropDrawableChange: (propId: number, drawable: number) => void;
  handlePropTextureChange: (propId: number, texture: number) => void;
  propConfig: PropConfig;
}

const Props = ({ settings, data, storedData, handlePropDrawableChange, handlePropTextureChange, propConfig }: PropsProps) => {
  const { locales } = useNuiState();
  if (!locales) return null;

  const settingsById = Object.fromEntries(settings.map(item => [item.prop_id, item]));
  const dataById = Object.fromEntries(data.map(item => [item.prop_id, item]));
  const storedById = Object.fromEntries(storedData.map(item => [item.prop_id, item]));
  const entries: WardrobeEntry[] = [];

  const add = (enabled: boolean | undefined, id: number, key: string, label: string, subtitle: string, icon: string) => {
    const setting = settingsById[id];
    const current = dataById[id];
    const stored = storedById[id];
    if (!enabled || !setting || !current || !stored) return;
    entries.push({
      id, key, kind: 'prop', label, subtitle, icon,
      drawable: current.drawable, storedDrawable: stored.drawable,
      texture: current.texture, storedTexture: stored.texture,
      drawableMin: setting.drawable.min, drawableMax: setting.drawable.max,
      textureMin: setting.texture.min, textureMax: setting.texture.max,
      blacklistedDrawables: setting.blacklist.drawables,
      blacklistedTextures: setting.blacklist.textures,
      onDrawableChange: value => handlePropDrawableChange(id, value),
      onTextureChange: value => handlePropTextureChange(id, value),
    });
  };

  add(propConfig.hats, 0, 'hat', locales.props.hats, 'Bonés, chapéus, capacetes e adornos.', 'hat.png');
  add(propConfig.glasses, 1, 'glasses', locales.props.glasses, 'Óculos de grau, solares e lentes especiais.', 'glasses.png');
  add(propConfig.ear, 2, 'ears', locales.props.ear, 'Brincos, fones e acessórios de orelha.', 'earrings.png');
  add(propConfig.watches, 6, 'watch', locales.props.watches, 'Relógios e acessórios de pulso.', 'watch.png');
  add(propConfig.bracelets, 7, 'bracelet', locales.props.bracelets, 'Pulseiras e braceletes.', 'bracelet.png');

  return <VisualWardrobe title={locales.props.title} entries={entries} />;
};

export default Props;
