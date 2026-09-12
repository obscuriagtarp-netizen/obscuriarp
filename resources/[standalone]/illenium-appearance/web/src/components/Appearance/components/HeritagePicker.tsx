import styled from 'styled-components';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';

interface HeritagePickerProps {
  title: string;
  min: number;
  max: number;
  value: number;
  onChange: (value: number) => void;
}

const Container = styled.div`
  width: 100%;
  & + & { margin-top: 12px; }
`;

const Header = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: #b9afbf;
  font-size: 12px;
  font-weight: 700;
  text-transform: uppercase;
  b { color: #e8dcef; font-weight: 600; }
`;

const Carousel = styled.div`
  display: grid;
  grid-template-columns: 28px repeat(5, minmax(0, 1fr)) 28px;
  gap: 5px;
  margin-top: 11px;
  align-items: center;
`;

const Arrow = styled.button`
  width: 28px;
  height: 76px;
  display: grid;
  place-items: center;
  color: #b9afbf;
  background: rgba(255,255,255,.025);
  border: 1px solid rgba(255,255,255,.08);
  border-radius: 3px;
  &:hover { color: #fff; border-color: rgba(184,126,211,.45); }
`;

const Portrait = styled.button<{ selected: boolean }>`
  position: relative;
  aspect-ratio: .76;
  min-width: 0;
  overflow: hidden;
  border-radius: 3px;
  border: 1px solid ${props => props.selected ? 'rgba(193,139,219,.8)' : 'rgba(255,255,255,.08)'};
  background: rgba(255,255,255,.025);
  opacity: ${props => props.selected ? 1 : .62};
  transform: ${props => props.selected ? 'translateY(-2px)' : 'none'};
  transition: opacity .15s, border-color .15s, transform .15s;

  img { width: 100%; height: 100%; object-fit: cover; display: block; }
  span {
    position: absolute;
    right: 3px;
    bottom: 3px;
    min-width: 18px;
    height: 18px;
    display: grid;
    place-items: center;
    border-radius: 2px;
    color: #eee8f1;
    background: rgba(7,6,9,.84);
    font-size: 9px;
  }
  &:hover { opacity: 1; border-color: rgba(193,139,219,.55); }
`;

const HeritagePicker = ({ title, min, max, value, onChange }: HeritagePickerProps) => {
  const range = max - min + 1;
  const normalize = (candidate: number) => min + ((((candidate - min) % range) + range) % range);
  const visible = [-2, -1, 0, 1, 2].map(offset => normalize(value + offset));

  return (
    <Container>
      <Header><span>{title}</span><b>{value.toString().padStart(2, '0')}</b></Header>
      <Carousel>
        <Arrow type="button" aria-label="Anterior" onClick={() => onChange(normalize(value - 1))}><FiChevronLeft /></Arrow>
        {visible.map((item, index) => (
          <Portrait type="button" key={`${item}-${index}`} selected={item === value} onClick={() => onChange(item)}>
            <img src={`./heritage/${item}.png`} alt={`Herança ${item}`} />
            <span>{item}</span>
          </Portrait>
        ))}
        <Arrow type="button" aria-label="Próximo" onClick={() => onChange(normalize(value + 1))}><FiChevronRight /></Arrow>
      </Carousel>
    </Container>
  );
};

export default HeritagePicker;
