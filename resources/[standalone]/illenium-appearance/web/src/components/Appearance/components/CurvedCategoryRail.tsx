import styled from 'styled-components';
import { createPortal } from 'react-dom';

export interface CurvedCategoryItem {
  key: string;
  label: string;
  icon: string;
}

interface CurvedCategoryRailProps {
  items: CurvedCategoryItem[];
  activeKey: string;
  onSelect: (key: string) => void;
}

const Rail = styled.nav`
  position: fixed;
  z-index: 30;
  top: 50%;
  right: calc(var(--appearance-gutter-x) + var(--appearance-panel-width) + 16px);
  width: 116px;
  isolation: isolate;
  display: flex;
  flex-direction: column;
  gap: 4px;
  max-height: 78vh;
  padding: 5px 7px 5px 0;
  overflow-x: hidden;
  overflow-y: auto;
  transform: translateY(-50%);

  &::before {
    content: '';
    position: absolute;
    z-index: -1;
    top: 8px;
    left: 5px;
    bottom: 8px;
    width: 106px;
    border-left: 1px solid rgba(184, 126, 210, .3);
    border-radius: 50% 0 0 50%;
    opacity: .72;
    animation: arc-line-in .42s ease-out both;
  }

  &::-webkit-scrollbar { width: 2px; }
  &::-webkit-scrollbar-thumb { background: rgba(174,111,202,.38); }

  @keyframes arc-line-in {
    from { opacity: 0; transform: scaleY(.72); }
  }

  @media (max-width: 860px) {
    right: auto;
    left: 8px;
  }

  @media (max-height: 820px) {
    width: 106px;
    max-height: calc(100vh - 28px);
    gap: 3px;

    &::before { width: 96px; }
  }
`;

const CategoryButton = styled.button<{ $active: boolean; $offset: number; $delay: number; $originY: number }>`
  --arc-origin-y: ${props => props.$originY}px;
  position: relative;
  flex: 0 0 auto;
  width: 88px;
  min-height: 62px;
  padding: 7px 5px 6px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4px;
  color: ${props => props.$active ? '#f7edfb' : '#c5bac8'};
  background: ${props => props.$active ? 'rgba(106,61,132,.44)' : 'rgba(11,9,14,.82)'};
  border: 1px solid ${props => props.$active ? 'rgba(202,148,226,.72)' : 'rgba(255,255,255,.085)'};
  border-radius: 4px;
  transform: translateX(${props => props.$offset}px);
  animation: arc-item-in .46s cubic-bezier(.18,.78,.24,1) both;
  animation-delay: ${props => props.$delay}ms;
  transition: color .15s, border-color .15s, background .15s, transform .15s;

  img {
    width: 27px;
    height: 27px;
    object-fit: contain;
    opacity: ${props => props.$active ? 1 : .78};
  }

  span {
    width: 100%;
    min-height: 20px;
    display: grid;
    place-items: center;
    font-size: 10px;
    font-weight: 700;
    line-height: 1.12;
    text-align: center;
    text-transform: uppercase;
    white-space: normal;
  }

  &::after {
    content: '';
    position: absolute;
    top: 10px;
    right: -3px;
    bottom: 10px;
    width: 2px;
    background: ${props => props.$active ? '#c98ce3' : 'transparent'};
    box-shadow: ${props => props.$active ? '0 0 8px rgba(190,125,219,.52)' : 'none'};
  }

  &:hover {
    color: #fff;
    border-color: rgba(202,148,226,.48);
    transform: translateX(${props => props.$offset + 3}px);
  }

  @keyframes arc-item-in {
    0% {
      opacity: 0;
      transform: translate3d(0, var(--arc-origin-y), 0) scale(.28) rotate(-8deg);
      filter: brightness(1.8);
    }
    58% {
      opacity: 1;
      filter: brightness(1.35);
    }
    100% { filter: brightness(1); }
  }

  @media (max-height: 820px) {
    width: 80px;
    min-height: 50px;
    padding: 5px 4px 4px;
    gap: 2px;

    img { width: 22px; height: 22px; }
    span { min-height: 17px; font-size: 9px; }
  }
`;

const arcOffset = (index: number, total: number) => {
  if (total <= 1) return 10;
  return 22 - Math.round(Math.sin((Math.PI * index) / (total - 1)) * 22);
};

const arcOriginY = (index: number, total: number) =>
  Math.round((((total - 1) / 2) - index) * 59);

const arcDelay = (index: number, total: number) => {
  const distanceFromCenter = Math.abs(index - ((total - 1) / 2));
  const normalizedDistance = Math.max(0, distanceFromCenter - (total % 2 === 0 ? .5 : 0));
  return Math.round(normalizedDistance * 42);
};

const rail = (items: CurvedCategoryItem[], activeKey: string, onSelect: (key: string) => void) => (
  <Rail aria-label="Categorias">
    {items.map((item, index) => (
      <CategoryButton
        key={item.key}
        type="button"
        $active={item.key === activeKey}
        $offset={arcOffset(index, items.length)}
        $originY={arcOriginY(index, items.length)}
        $delay={arcDelay(index, items.length)}
        onClick={() => onSelect(item.key)}
        title={item.label}
      >
        <img src={item.icon} alt="" />
        <span>{item.label}</span>
      </CategoryButton>
    ))}
  </Rail>
);

const CurvedCategoryRail = ({ items, activeKey, onSelect }: CurvedCategoryRailProps) =>
  createPortal(rail(items, activeKey, onSelect), document.body);

export default CurvedCategoryRail;
