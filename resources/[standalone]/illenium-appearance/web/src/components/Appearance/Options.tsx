import styled from 'styled-components';
import {
  FaArrowsAltH,
  FaHatCowboy,
  FaMale,
  FaRedo,
  FaSave,
  FaShoePrints,
  FaSmile,
  FaSocks,
  FaTimes,
  FaTshirt,
  FaUndo,
} from 'react-icons/fa';

import { CameraState, ClothesState, RotateState } from './interfaces';

interface OptionsProps {
  camera: CameraState;
  rotate: RotateState;
  clothes: ClothesState;
  handleSetClothes: (key: keyof ClothesState) => void;
  handleSetCamera: (key: keyof CameraState) => void;
  handleTurnAround: () => void;
  handleRotateLeft: () => void;
  handleRotateRight: () => void;
  handleSave: () => void;
  handleExit: () => void;
  enableExit: boolean;
}

const Toolbar = styled.div`
  width: 100%;
  min-height: 66px;
  padding: 9px 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  border-top: 1px solid rgba(174, 123, 202, .18);
  background: rgba(7, 6, 10, .98);
  pointer-events: auto;

  @media (max-height: 820px) {
    min-height: 56px;
    padding: 7px 10px;
    gap: 6px;
  }

  @media (max-width: 1600px) {
    min-height: 56px;
    padding: 7px 8px;
    gap: 4px;
  }

  @media (max-width: 1200px) {
    padding-right: 6px;
    padding-left: 6px;
    gap: 3px;
  }
`;

const Group = styled.div`
  display: flex;
  gap: 5px;
  padding-right: 9px;
  border-right: 1px solid rgba(255,255,255,.09);
  &:last-child { border-right: 0; padding-right: 0; }

  @media (max-height: 820px) {
    gap: 4px;
    padding-right: 6px;
  }

  @media (max-width: 1600px) {
    gap: 3px;
    padding-right: 5px;
  }

  @media (max-width: 1200px) {
    gap: 2px;
    padding-right: 4px;
  }
`;

const IconButton = styled.button<{ active?: boolean; danger?: boolean; primary?: boolean; wide?: boolean }>`
  position: relative;
  width: ${props => props.wide ? '112px' : '40px'};
  height: 40px;
  display: grid;
  grid-auto-flow: column;
  gap: 8px;
  place-items: center;
  padding: ${props => props.wide ? '0 15px' : '0'};
  border-radius: 3px;
  border: 1px solid ${props => props.active || props.primary ? 'rgba(185,127,214,.58)' : 'rgba(255,255,255,.08)'};
  color: ${props => props.danger ? '#d9a6b2' : props.active || props.primary ? '#f2e8f8' : '#aaa2ae'};
  background: ${props => props.primary ? 'rgba(105,61,132,.56)' : props.active ? 'rgba(105,61,132,.36)' : 'rgba(255,255,255,.025)'};
  transition: background .15s, border-color .15s, color .15s;

  > span { font-size: 11px; font-weight: 700; text-transform: uppercase; }

  &:hover { color: #fff; border-color: rgba(185,127,214,.46); background: rgba(105,61,132,.26); }
  &:active { transform: translateY(1px); }
  &::after {
    content: attr(aria-label);
    position: absolute;
    bottom: calc(100% + 9px);
    left: 50%;
    transform: translateX(-50%);
    padding: 5px 7px;
    color: #d9d2dc;
    background: rgba(7,6,9,.96);
    border: 1px solid rgba(255,255,255,.1);
    border-radius: 3px;
    font-size: 11px;
    white-space: nowrap;
    opacity: 0;
    pointer-events: none;
    transition: opacity .12s;
  }
  &:hover::after { opacity: 1; }

  @media (max-height: 820px) {
    width: ${props => props.wide ? '94px' : '35px'};
    height: 35px;
    padding: ${props => props.wide ? '0 10px' : '0'};
    gap: 5px;
  }

  @media (max-width: 1600px) {
    width: ${props => props.wide ? '89px' : '34px'};
    height: 35px;
    padding: ${props => props.wide ? '0 9px' : '0'};
    gap: 5px;

    > span { font-size: 10px; }
  }

  @media (max-width: 1200px) {
    width: ${props => props.wide ? '72px' : '30px'};
    height: 32px;
    padding: ${props => props.wide ? '0 6px' : '0'};
    gap: 4px;

    > span { font-size: 9px; }
  }
`;

const Options: React.FC<OptionsProps> = ({
  camera,
  rotate,
  clothes,
  handleSetClothes,
  handleSetCamera,
  handleTurnAround,
  handleRotateLeft,
  handleRotateRight,
  handleExit,
  handleSave,
  enableExit,
}) => (
  <Toolbar>
    <Group>
      <IconButton aria-label="Rosto" active={camera.head} onClick={() => handleSetCamera('head')}><FaSmile /></IconButton>
      <IconButton aria-label="Corpo" active={camera.body} onClick={() => handleSetCamera('body')}><FaMale /></IconButton>
      <IconButton aria-label="Pernas" active={camera.bottom} onClick={() => handleSetCamera('bottom')}><FaShoePrints /></IconButton>
    </Group>
    <Group>
      <IconButton aria-label="Ocultar chapéu" active={clothes.head} onClick={() => handleSetClothes('head')}><FaHatCowboy /></IconButton>
      <IconButton aria-label="Ocultar torso" active={clothes.body} onClick={() => handleSetClothes('body')}><FaTshirt /></IconButton>
      <IconButton aria-label="Ocultar parte inferior" active={clothes.bottom} onClick={() => handleSetClothes('bottom')}><FaSocks /></IconButton>
    </Group>
    <Group>
      <IconButton aria-label="Girar para esquerda" active={rotate.left} onClick={handleRotateLeft}><FaUndo /></IconButton>
      <IconButton aria-label="Virar personagem" onClick={handleTurnAround}><FaArrowsAltH /></IconButton>
      <IconButton aria-label="Girar para direita" active={rotate.right} onClick={handleRotateRight}><FaRedo /></IconButton>
    </Group>
    <Group>
      <IconButton aria-label="Salvar aparência" primary wide onClick={handleSave}><FaSave /><span>Salvar</span></IconButton>
      {enableExit && <IconButton aria-label="Cancelar" danger onClick={handleExit}><FaTimes /></IconButton>}
    </Group>
  </Toolbar>
);

export default Options;
