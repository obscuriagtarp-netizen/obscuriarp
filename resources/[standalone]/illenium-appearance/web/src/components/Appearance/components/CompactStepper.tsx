import { useCallback } from 'react';
import styled from 'styled-components';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';

interface CompactStepperProps {
  label: string;
  value: number;
  min: number;
  max: number;
  width?: number;
  step?: number;
  blacklisted?: number[];
  wrap?: boolean;
  onChange: (value: number) => void;
}

const Container = styled.div<{ $width: number }>`
  flex: 0 0 ${props => props.$width}px;
  width: ${props => props.$width}px;
  max-width: 100%;
  min-width: 0;
  font-family: 'TT Commons', 'Segoe UI', Arial, sans-serif;

  > span {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 5px;
    color: #b8aebd;
    font-size: 8px;
    font-weight: 700;
    letter-spacing: 0;
    text-transform: uppercase;
  }

  > span small:last-child {
    color: #c994e0;
    font-variant-numeric: tabular-nums;
  }
`;

const Control = styled.div`
  height: 31px;
  display: grid;
  grid-template-columns: 31px minmax(0, 1fr) 31px;
  gap: 3px;

  button,
  input {
    min-width: 0;
    height: 31px;
    color: #f2ebf4;
    background: rgba(6,5,8,.72);
    border: 1px solid rgba(255,255,255,.09);
    border-radius: 3px;
  }

  button {
    display: grid;
    place-items: center;
    font-size: 14px;
    &:hover { color: #fff; background: rgba(103,61,128,.4); border-color: rgba(199,144,224,.48); }
  }

  input {
    width: 100%;
    padding: 0;
    text-align: center;
    text-indent: 0;
    line-height: 31px;
    font-family: 'TT Commons', 'Segoe UI', Arial, sans-serif;
    font-size: 12px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    appearance: textfield;
    caret-color: transparent;
    outline: none;
    &:focus { border-color: rgba(199,144,224,.55); }
    &::-webkit-inner-spin-button,
    &::-webkit-outer-spin-button { appearance: none; margin: 0; }
  }
`;

const CompactStepper = ({ label, value, min, max, width = 156, step = 1, blacklisted = [], wrap = true, onChange }: CompactStepperProps) => {
  const normalize = useCallback((candidate: number) => {
    let next = candidate;
    if (wrap) {
      if (next < min) next = max;
      if (next > max) next = min;
    } else {
      next = Math.min(max, Math.max(min, next));
    }
    return Number(next.toFixed(4));
  }, [max, min, wrap]);

  const changeBy = (direction: -1 | 1) => {
    let next = normalize(value + step * direction);
    const attempts = Math.max(1, Math.ceil((max - min) / step) + 1);
    for (let index = 0; index < attempts && blacklisted.includes(next); index += 1) {
      next = normalize(next + step * direction);
    }
    onChange(next);
  };

  const typeValue = (raw: string) => {
    if (raw.trim() === '') return;
    const parsed = Number(raw);
    if (!Number.isFinite(parsed)) return;
    const next = normalize(parsed);
    if (!blacklisted.includes(next)) onChange(next);
  };

  return (
    <Container $width={width}>
      <span><small>{label}</small><small>{value} / {max}</small></span>
      <Control>
        <button type="button" onClick={() => changeBy(-1)} aria-label={`${label} anterior`}><FiChevronLeft strokeWidth={3} /></button>
        <input type="number" value={value} min={min} max={max} step={step} onChange={event => typeValue(event.target.value)} aria-label={label} />
        <button type="button" onClick={() => changeBy(1)} aria-label={`Próxima ${label.toLowerCase()}`}><FiChevronRight strokeWidth={3} /></button>
      </Control>
    </Container>
  );
};

export default CompactStepper;
