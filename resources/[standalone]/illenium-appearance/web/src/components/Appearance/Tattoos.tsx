import { useEffect, useMemo, useRef, useState } from 'react';
import styled from 'styled-components';
import { FiTrash2 } from 'react-icons/fi';
import { FaPaintBrush } from 'react-icons/fa';
import { useNuiState } from '../../hooks/nuiState';
import Section from './components/Section';
import CurvedCategoryRail from './components/CurvedCategoryRail';
import CompactStepper from './components/CompactStepper';
import { TattoosSettings, TattooList, Tattoo } from './interfaces';

interface TattoosProps {
  settings: TattoosSettings;
  data: TattooList;
  storedData: TattooList;
  isPedMale: boolean;
  handleApplyTattoo: (value: Tattoo, opacity: number) => void;
  handlePreviewTattoo: (value: Tattoo, opacity: number) => void;
  handleDeleteTattoo: (value: Tattoo) => void;
  handleClearTattoos: () => void;
}

const BATCH_SIZE = 12;

const zoneIcons: Record<string, string> = {
  ZONE_HEAD: 'tattoo-head.png',
  ZONE_TORSO: 'tattoo-torso.png',
  ZONE_LEFT_ARM: 'tattoo-left-arm.png',
  ZONE_RIGHT_ARM: 'tattoo-right-arm.png',
  ZONE_LEFT_LEG: 'tattoo-left-leg.png',
  ZONE_RIGHT_LEG: 'tattoo-right-leg.png',
};

const Layout = styled.div`
  display: block;
`;

const Browser = styled.section`
  min-width: 0;
  padding: 15px;
  background: rgba(255,255,255,.022);
  border: 1px solid rgba(255,255,255,.075);
  border-radius: 4px;

  @media (max-height: 820px) { padding: 12px; }
`;

const BrowserHeader = styled.header`
  position: sticky;
  z-index: 5;
  top: -22px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin: -14px -14px 0;
  padding: 14px 14px 12px;
  background: rgba(13,11,16,.98);
  border-bottom: 1px solid rgba(176,125,203,.18);
  border-radius: 3px 3px 0 0;

  small { color: #b98ad0; font-size: 10px; font-weight: 700; text-transform: uppercase; }
  h3 { margin-top: 3px; color: #f1eaf4; font-family: Georgia, 'Times New Roman', serif; font-size: 20px; font-weight: 500; }
  p { margin-top: 3px; color: #908797; font-size: 11px; }

  > div:first-child { min-width: 0; margin-right: auto; }

  @media (max-height: 820px) {
    top: -15px;
    margin: -11px -11px 0;
    padding: 11px 11px 10px;
    gap: 9px;

    h3 { font-size: 18px; }
  }
`;

const HeaderTools = styled.div`
  flex: 1 1 100%;
  min-width: 0;
  display: flex;
  align-items: flex-end;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 6px;

  > div { max-width: 100%; }

  @media (min-width: 1760px) and (min-height: 821px) {
    flex: 0 1 auto;
    flex-wrap: nowrap;
  }
`;

const ApplyButton = styled.button<{ $applied: boolean }>`
  min-width: 76px;
  height: 31px;
  padding: 0 10px;
  color: ${props => props.$applied ? '#e4b4c1' : '#f3ebf6'};
  background: ${props => props.$applied ? 'rgba(112,48,67,.2)' : 'rgba(103,61,128,.44)'};
  border: 1px solid ${props => props.$applied ? 'rgba(193,102,126,.34)' : 'rgba(199,144,224,.5)'};
  border-radius: 3px;
  font-family: 'TT Commons', 'Segoe UI', Arial, sans-serif;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0;
  text-transform: uppercase;

  &:hover {
    color: #fff;
    background: ${props => props.$applied ? 'rgba(130,55,77,.32)' : 'rgba(116,69,143,.58)'};
  }
`;

const Grid = styled.div`
  margin-top: 12px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(104px, 1fr));
  gap: 7px;

  @media (max-height: 820px) { margin-top: 9px; gap: 6px; }
`;

const LoadSentinel = styled.div`
  min-height: 28px;
  margin-top: 9px;
  display: grid;
  place-items: center;
  color: #857b89;
  font-size: 9px;
  font-weight: 700;
  text-transform: uppercase;
`;

const TattooCard = styled.button<{ active: boolean; applied: boolean }>`
  position: relative;
  aspect-ratio: 1;
  min-width: 0;
  overflow: hidden;
  color: ${props => props.active ? '#fff' : '#b3aab7'};
  background: rgba(5,5,8,.55);
  border: 1px solid ${props => props.active ? 'rgba(195,141,220,.72)' : props.applied ? 'rgba(116,190,145,.45)' : 'rgba(255,255,255,.07)'};
  border-radius: 4px;
  text-align: left;

  b { overflow: hidden; font-size: 10px; line-height: 1.12; text-overflow: ellipsis; white-space: nowrap; }
  small { margin-top: 2px; color: ${props => props.applied ? '#83c99e' : '#aaa0af'}; font-size: 8px; text-transform: uppercase; }
  &:hover { color: #fff; border-color: rgba(195,141,220,.5); }
`;

const TattooMedia = styled.div`
  position: absolute;
  inset: 0;
  overflow: hidden;
  background: #19171d;
`;

const TattooPhoto = styled.img<{ $visible: boolean }>`
  position: absolute;
  inset: 0;
  z-index: 2;
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
  opacity: ${props => props.$visible ? 1 : 0};
  transition: opacity .2s ease-out;
`;

const MissingPreview = styled.div<{ $hidden: boolean }>`
  position: absolute;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  display: grid;
  place-items: center;
  color: #8c719a;
  font-size: 25px;
  background: rgba(23, 19, 27, .78);
  opacity: ${props => props.$hidden ? 0 : 1};
  transition: opacity .2s ease-out;
`;

const TattooInfo = styled.div`
  position: absolute;
  z-index: 3;
  left: 0;
  right: 0;
  bottom: 0;
  min-width: 0;
  min-height: 38px;
  padding: 6px 7px 5px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  background: rgba(7,6,9,.9);
`;

const Selection = styled.div`
  margin-top: 13px;
  padding-top: 13px;
  border-top: 1px solid rgba(176,125,203,.18);

  @media (max-height: 820px) { margin-top: 9px; padding-top: 9px; }
`;

const SelectionInfo = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 11px;

  small { color: #b5aabb; font-size: 10px; font-weight: 700; text-transform: uppercase; }
  strong { display: block; margin-top: 2px; color: #eee7f1; font-size: 13px; }
`;

const Actions = styled.div`
  margin-top: 12px;
  display: flex;
  justify-content: flex-end;

  button {
    width: 43px;
    min-height: 41px;
    color: #eee7f1;
    background: rgba(104,61,130,.38);
    border: 1px solid rgba(193,139,219,.46);
    border-radius: 4px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    &:hover { background: rgba(112,67,140,.55); border-color: rgba(205,155,229,.7); }
    &:disabled { opacity: .35; cursor: default; }
  }

  button { color: #d7a0ae; background: rgba(112,48,67,.14); border-color: rgba(193,102,126,.28); }
`;

const TattooImage = ({ src }: { src: string }) => {
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(false), [src]);
  return (
    <TattooMedia>
      <MissingPreview $hidden={ready}><FaPaintBrush /></MissingPreview>
      <TattooPhoto $visible={ready} src={src} alt="" loading="lazy" onLoad={() => setReady(true)} onError={() => setReady(false)} />
    </TattooMedia>
  );
};

const Tattoos = ({ settings, data, isPedMale, handleApplyTattoo, handlePreviewTattoo, handleDeleteTattoo, handleClearTattoos }: TattoosProps) => {
  const { locales } = useNuiState();
  const zones = Object.keys(settings.items).filter(key => key !== 'ZONE_HAIR' && settings.items[key]?.length > 0);
  const [activeZone, setActiveZone] = useState(zones[0] ?? '');
  const [selectedName, setSelectedName] = useState('');
  const [opacity, setOpacity] = useState(Math.max(settings.opacity.min, .5));
  const [visibleCount, setVisibleCount] = useState(BATCH_SIZE);
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!zones.includes(activeZone)) setActiveZone(zones[0] ?? '');
  }, [zones.join('|'), activeZone]);

  const items = settings.items[activeZone] ?? [];
  const visibleItems = useMemo(() => items.slice(0, visibleCount), [items, visibleCount]);
  const selected = items.find(item => item.name === selectedName) ?? items[0];
  const selectedIndex = selected ? Math.max(0, items.findIndex(item => item.name === selected.name)) : 0;
  const appliedInZone = data[activeZone] ?? [];
  const applied = selected ? appliedInZone.some(item => item.name === selected.name) : false;
  const appliedTattoo = selected ? appliedInZone.find(item => item.name === selected.name) : undefined;

  useEffect(() => {
    setVisibleCount(BATCH_SIZE);
    setSelectedName('');
  }, [activeZone]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || visibleCount >= items.length) return;

    const observer = new IntersectionObserver(entries => {
      if (!entries[0]?.isIntersecting) return;
      setVisibleCount(count => Math.min(items.length, count + BATCH_SIZE));
    }, { rootMargin: '220px 0px' });

    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [activeZone, items.length, visibleCount]);

  useEffect(() => {
    const nextOpacity = appliedTattoo?.opacity ?? Math.max(settings.opacity.min, .5);
    setOpacity(nextOpacity);
  }, [selected?.name, appliedTattoo?.opacity, settings.opacity.min]);

  if (!locales || !zones.length) return null;

  const gender = isPedMale ? 'Male' : 'Female';
  const tattooImage = (tattoo: Tattoo) => {
    const hash = isPedMale ? tattoo.hashMale : tattoo.hashFemale;
    return `./tattoos/${gender}/${tattoo.collection}/${hash}.jpg`;
  };

  const selectTattoo = (tattoo: Tattoo) => {
    setSelectedName(tattoo.name);
    const nextOpacity = (data[tattoo.zone] ?? []).find(item => item.name === tattoo.name)?.opacity ?? Math.max(settings.opacity.min, .5);
    setOpacity(nextOpacity);
    handlePreviewTattoo({ ...tattoo }, nextOpacity);
  };

  const selectTattooModel = (value: number) => {
    const index = Math.max(0, Math.min(items.length - 1, Math.round(value)));
    const tattoo = items[index];
    if (!tattoo) return;
    if (index >= visibleCount) {
      setVisibleCount(Math.min(items.length, Math.ceil((index + 1) / BATCH_SIZE) * BATCH_SIZE));
    }
    selectTattoo(tattoo);
  };

  const changeOpacity = (value: number) => {
    setOpacity(value);
    if (selected) handlePreviewTattoo({ ...selected }, value);
  };

  return (
    <Section title={locales.tattoos.title}>
      <Layout>
        <CurvedCategoryRail
          items={zones.map(zone => ({
            key: zone,
            label: locales.tattoos.items[zone] ?? zone,
            icon: `./wardrobe-icons/${zoneIcons[zone] ?? 'decals.png'}`,
          }))}
          activeKey={activeZone}
          onSelect={setActiveZone}
        />

        <Browser>
          <BrowserHeader>
            <div>
              <small>Catálogo corporal</small>
              <h3>{locales.tattoos.items[activeZone] ?? activeZone}</h3>
            </div>
            <HeaderTools>
              <CompactStepper
                label="Modelo"
                value={selectedIndex}
                min={0}
                max={Math.max(0, items.length - 1)}
                width={126}
                onChange={selectTattooModel}
              />
              <CompactStepper
                label="Intensidade"
                value={opacity}
                min={settings.opacity.min}
                max={settings.opacity.max}
                width={126}
                step={settings.opacity.factor}
                wrap={false}
                onChange={changeOpacity}
              />
              {selected && (
                <ApplyButton $applied={applied} type="button" onClick={() => applied ? handleDeleteTattoo(selected) : handleApplyTattoo({ ...selected }, opacity)}>
                  {applied ? locales.tattoos.delete : locales.tattoos.apply}
                </ApplyButton>
              )}
            </HeaderTools>
          </BrowserHeader>

          <Grid>
            {visibleItems.map(tattoo => {
              const isApplied = appliedInZone.some(item => item.name === tattoo.name);
              return (
                <TattooCard key={tattoo.name} active={selected?.name === tattoo.name} applied={isApplied} onClick={() => selectTattoo(tattoo)}>
                  <TattooImage src={tattooImage(tattoo)} />
                  <TattooInfo><b>{tattoo.label}</b><small>{isApplied ? 'Aplicada' : 'Visualizar'}</small></TattooInfo>
                </TattooCard>
              );
            })}
          </Grid>

          <LoadSentinel ref={sentinelRef}>
            {visibleCount < items.length ? 'Role para carregar mais desenhos' : 'Todos os desenhos foram carregados'}
          </LoadSentinel>

          {selected && (
            <Selection>
              <SelectionInfo>
                <div><small>Desenho selecionado</small><strong>{selected.label}</strong></div>
                <small>{appliedInZone.length} aplicada(s) nesta região</small>
              </SelectionInfo>
              <Actions>
                <button type="button" disabled={!Object.values(data).some(list => list?.length)} onClick={handleClearTattoos} aria-label={locales.tattoos.deleteAll}><FiTrash2 /></button>
              </Actions>
            </Selection>
          )}
        </Browser>
      </Layout>
    </Section>
  );
};

export default Tattoos;
