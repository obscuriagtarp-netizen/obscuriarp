import { useEffect, useMemo, useRef, useState } from 'react';
import styled from 'styled-components';
import Section from './Section';
import CurvedCategoryRail from './CurvedCategoryRail';
import CompactStepper from './CompactStepper';

export interface WardrobeEntry {
  id: number;
  key: string;
  kind: 'component' | 'prop';
  label: string;
  subtitle: string;
  icon: string;
  drawable: number;
  storedDrawable: number;
  texture: number;
  storedTexture: number;
  drawableMin: number;
  drawableMax: number;
  textureMin: number;
  textureMax: number;
  blacklistedDrawables: number[];
  blacklistedTextures: number[];
  onDrawableChange: (value: number) => void;
  onTextureChange: (value: number) => void;
}

interface VisualWardrobeProps {
  title: string;
  entries: WardrobeEntry[];
}

const BATCH_SIZE = 12;

const Catalog = styled.div`
  display: block;
`;

const Editor = styled.section`
  min-width: 0;
  padding: 17px;
  background: rgba(255,255,255,.022);
  border: 1px solid rgba(255,255,255,.075);
  border-radius: 4px;

  @media (max-height: 820px) { padding: 13px; }
`;

const EditorHeader = styled.header`
  position: sticky;
  z-index: 5;
  top: -22px;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 13px;
  margin: -16px -16px 0;
  padding: 16px 16px 14px;
  background: rgba(13,11,16,.98);
  border-bottom: 1px solid rgba(176,125,203,.18);
  border-radius: 3px 3px 0 0;

  > div:first-child {
    width: 54px;
    height: 54px;
    display: grid;
    place-items: center;
    flex: 0 0 auto;
    border: 1px solid rgba(190,135,216,.32);
    background: rgba(105,61,132,.2);
    border-radius: 4px;
  }

  img {
    width: 35px;
    height: 35px;
    object-fit: contain;
  }

  small { color: #b98ad0; font-size: 10px; font-weight: 700; text-transform: uppercase; }
  h3 { margin-top: 3px; color: #f1eaf4; font-family: Georgia, 'Times New Roman', serif; font-size: 21px; font-weight: 500; }
  p { margin-top: 3px; color: #9e95a3; font-size: 12px; line-height: 1.35; }

  .selection-copy { flex: 1 1 170px; min-width: 0; margin-right: auto; }

  @media (max-height: 820px) {
    top: -15px;
    margin: -12px -12px 0;
    padding: 12px 12px 11px;
    gap: 10px;

    > div:first-child { width: 46px; height: 46px; }
    img { width: 30px; height: 30px; }
    h3 { font-size: 19px; }
    p { font-size: 11px; }
  }
`;

const HeaderControls = styled.div`
  flex: 1 1 100%;
  width: 100%;
  min-width: 0;
  margin-top: 3px;
  padding-top: 11px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  flex-wrap: wrap;
  gap: 18px;
  border-top: 1px solid rgba(176,125,203,.12);

  > div { max-width: 100%; }

  @media (min-width: 1760px) and (min-height: 821px) {
    flex: 0 1 334px;
    width: auto;
    margin-top: 0;
    padding-top: 0;
    flex-wrap: nowrap;
    gap: 10px;
    border-top: 0;

    > div {
      flex: 1 1 0;
      width: auto;
    }
  }

  @media (max-height: 820px) {
    margin-top: 0;
    padding-top: 9px;
    gap: 10px;
  }
`;

const GalleryHeader = styled.div`
  margin-top: 15px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;

  span { color: #aba1af; font-size: 11px; font-weight: 700; text-transform: uppercase; }
  small { color: #827986; font-size: 10px; }

  @media (max-height: 820px) { margin-top: 11px; }
`;

const Gallery = styled.div`
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(104px, 1fr));
  gap: 7px;

  @media (max-height: 820px) { margin-top: 8px; gap: 6px; }
`;

const ModelCard = styled.button<{ active: boolean }>`
  position: relative;
  aspect-ratio: 1;
  min-width: 0;
  overflow: hidden;
  display: grid;
  grid-template-rows: minmax(0, 1fr) 29px;
  color: ${props => props.active ? '#fff' : '#b2a8b7'};
  background: ${props => props.active ? 'rgba(101,58,127,.34)' : 'rgba(5,5,8,.5)'};
  border: 1px solid ${props => props.active ? 'rgba(195,141,220,.68)' : 'rgba(255,255,255,.07)'};
  border-radius: 4px;

  > span {
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-width: 0;
    padding: 5px 7px 0;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
  }

  &:hover { border-color: rgba(195,141,220,.46); color: #fff; }
`;

const PreviewFrame = styled.div`
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  background: rgba(23,19,27,.68);
`;

const SmoothPreview = styled.img<{ $visible: boolean }>`
  position: absolute;
  inset: 0;
  z-index: 2;
    width: 100%;
    height: 100%;
    min-height: 0;
    object-fit: contain;
    display: block;
    padding: 6px;
  opacity: ${props => props.$visible ? 1 : 0};
  transition: opacity .18s ease-out;
`;

const Fallback = styled.div<{ $hidden: boolean }>`
  position: absolute;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  min-height: 0;
  display: grid;
  place-items: center;
  background: rgba(23, 19, 27, .68);
  opacity: ${props => props.$hidden ? 0 : 1};
  transition: opacity .18s ease-out;

  img {
    width: 42px;
    height: 42px;
    object-fit: contain;
    opacity: .68;
  }
`;

const LoadSentinel = styled.div`
  min-height: 28px;
  margin-top: 9px;
  display: grid;
  place-items: center;
  color: #857b89;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
`;

const PreviewImage = ({ src, fallback }: { src: string; fallback: string }) => {
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(false), [src]);

  return (
    <PreviewFrame>
      <Fallback $hidden={ready}><img src={fallback} alt="" /></Fallback>
      <SmoothPreview
        $visible={ready}
        src={src}
        alt=""
        loading="lazy"
        onLoad={() => setReady(true)}
        onError={() => setReady(false)}
      />
    </PreviewFrame>
  );
};

const VisualWardrobe = ({ title, entries }: VisualWardrobeProps) => {
  const [activeKey, setActiveKey] = useState(entries[0]?.key ?? '');
  const [visibleCount, setVisibleCount] = useState(BATCH_SIZE);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const active = entries.find(item => item.key === activeKey) ?? entries[0];

  useEffect(() => {
    if (!entries.some(item => item.key === activeKey)) setActiveKey(entries[0]?.key ?? '');
  }, [entries, activeKey]);

  const totalModels = active ? active.drawableMax - active.drawableMin + 1 : 0;

  useEffect(() => {
    if (!active) return;
    const selectedPosition = Math.max(1, active.drawable - active.drawableMin + 1);
    const initialBatch = Math.max(BATCH_SIZE, Math.ceil(selectedPosition / BATCH_SIZE) * BATCH_SIZE);
    setVisibleCount(Math.min(totalModels, initialBatch));
  }, [activeKey]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || visibleCount >= totalModels) return;

    const observer = new IntersectionObserver(entries => {
      if (!entries[0]?.isIntersecting) return;
      setVisibleCount(count => Math.min(totalModels, count + BATCH_SIZE));
    }, { rootMargin: '220px 0px' });

    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [activeKey, totalModels, visibleCount]);

  const models = useMemo(() => {
    if (!active) return [];
    return Array.from({ length: Math.min(visibleCount, totalModels) }, (_, index) => active.drawableMin + index);
  }, [active, totalModels, visibleCount]);

  if (!active) return null;

  const iconPath = `./wardrobe-icons/${active.icon}`;
  const assetFolder = active.kind === 'prop' ? 'props' : 'components';
  const selectDrawable = (value: number) => {
    const selectedPosition = Math.max(1, value - active.drawableMin + 1);
    if (selectedPosition > visibleCount) {
      setVisibleCount(Math.min(totalModels, Math.ceil(selectedPosition / BATCH_SIZE) * BATCH_SIZE));
    }
    active.onDrawableChange(value);
  };

  return (
    <Section title={title}>
      <Catalog>
        <CurvedCategoryRail
          items={entries.map(item => ({ key: item.key, label: item.label, icon: `./wardrobe-icons/${item.icon}` }))}
          activeKey={active.key}
          onSelect={setActiveKey}
        />
        <Editor>
          <EditorHeader>
            <div><img src={iconPath} alt="" /></div>
            <div className="selection-copy"><small>Seleção visual</small><h3>{active.label}</h3><p>{active.subtitle}</p></div>
            <HeaderControls>
              <CompactStepper
                label="Modelo"
                value={active.drawable}
                min={active.drawableMin}
                max={active.drawableMax}
                blacklisted={active.blacklistedDrawables}
                onChange={selectDrawable}
              />
              <CompactStepper
                label="Textura"
                value={active.texture}
                min={active.textureMin}
                max={active.textureMax}
                blacklisted={active.blacklistedTextures}
                onChange={active.onTextureChange}
              />
            </HeaderControls>
          </EditorHeader>
          <GalleryHeader>
            <div><span>Modelos disponíveis</span></div>
          </GalleryHeader>
          <Gallery>
            {models.map(value => {
              const padded = value < 0 ? 'none' : value.toString().padStart(3, '0');
              const source = `./clothing/${assetFolder}/${active.key}/${padded}.png`;
              return (
                <ModelCard key={value} active={value === active.drawable} onClick={() => selectDrawable(value)}>
                  <PreviewImage src={source} fallback={iconPath} />
                  <span><b>Modelo</b><b>{value.toString().padStart(2, '0')}</b></span>
                </ModelCard>
              );
            })}
          </Gallery>
          <LoadSentinel ref={sentinelRef}>
            {visibleCount < totalModels ? 'Role para carregar mais peças' : 'Todas as peças foram carregadas'}
          </LoadSentinel>
        </Editor>
      </Catalog>
    </Section>
  );
};

export default VisualWardrobe;
