import { useCallback } from 'react';
import styled, { css } from 'styled-components';

interface ColorInputProps {
  title?: string;
  colors?: number[][];
  defaultValue?: number;
  clientValue?: number;
  onChange: (value: number) => void;
}

interface ButtonProps {
  selected: boolean;
}

const Container = styled.div`
  width: 100%;

  > span {
    width: 100%;

    display: flex;
    justify-content: space-between;
    font-weight: 600;
    color: #a79eab;
    gap: 10px;
    font-size: 11px;

    small:first-child {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    small:last-child {
      flex: 0 0 auto;
      color: #c994e0;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
    }
  }

  > div {
    width: 100%;

    display: flex;
    flex-wrap: wrap;
    align-items: flex-start;
    justify-content: flex-start;

    margin-top: 11px;
    max-height: 142px;
    overflow-y: auto;
  }
`;

const Button = styled.button<ButtonProps>`
  height: 28px;
  width: 28px;

  border: 2px solid rgba(255,255,255,.08);

  margin: 1px;

  &:hover {
    border: 2px solid rgba(255, 255, 255, 0.5);
    ${props => props.theme.smoothBackgroundTransition ? 'transition: background 0.2s;' : ''}
    ${props => props.theme.scaleOnHover ? 'transform: scale(1.1);' : ''}
  }

  ${({ selected }) =>
    selected &&
    css`
      border: 2px solid #fff;
      box-shadow: 0 0 0 1px rgba(173,108,207,.85);
    `}
`;

const ColorInput: React.FC<ColorInputProps> = ({ title, colors = [], defaultValue, clientValue, onChange }) => {
  const selectColor = useCallback(
    (color: number) => {
      onChange(color);
    },
    [onChange],
  );

  return (
    <Container>
      <span>
        <small>{`${title}: ${defaultValue}`}</small>
        <small>{clientValue}</small>
      </span>
      <div>
        {colors.map((color, index) => (
          <Button
            key={index}
            style={{ backgroundColor: `rgb(${color[0]}, ${color[1]}, ${color[2]})` }}
            selected={defaultValue === index}
            onClick={() => selectColor(index)}
          />
        ))}
      </div>
    </Container>
  );
};

export default ColorInput;
