import { useCallback, useRef } from 'react';
import styled from 'styled-components';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';

interface InputProps {
  title?: string;
  min?: number;
  max?: number;
  blacklisted?: number[];
  defaultValue: number;
  clientValue: number;
  onChange: (value: number) => void;
}

const Container = styled.div`
  width: 100%;
  min-width: 0;

  display: flex;
  flex-direction: column;
  flex-grow: 1;

  margin-top: ${({ title }) => (title ? '4px' : '0')};

  > span {
    width: 100%;

    display: flex;
    justify-content: space-between;
    font-weight: 600;
    color: #a79eab;
    font-size: 12px;

    small:first-child {
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    small:last-child {
      flex: 0 0 auto;
      margin-left: 10px;
      color: #c994e0;
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
    }
  }

  > div {
    min-width: 0;
    height: 41px;

    display: flex;
    align-items: center;

    margin-top: 9px;

    button {
      height: 100%;
      min-width: 39px;

      display: flex;
      align-items: center;
      justify-content: center;

      color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 1);

      outline: 0;
      border: none;
      border-radius: 3px;

      background: rgba(255,255,255,.035);
      border: 1px solid rgba(255,255,255,.075);

      &:hover {
        color: rgba(${props => props.theme.fontColorHover || '255, 255, 255'}, 1);
        background: rgba(104, 61, 130, .32);
        ${props => props.theme.smoothBackgroundTransition ? 'transition: background 0.2s;' : ''}
        ${props => props.theme.scaleOnHover ? 'transform: scale(1.1);' : ''}
      }
    }

    input {
      min-width: 0;
      height: 100%;

      flex-grow: 1;
      flex-shrink: 1;

      text-align: center;
      font-size: 15px;
      font-weight: 700;
      color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 1);

      border: none;
      border: 1px solid rgba(255,255,255,.075);
      border-radius: 3px;
      margin: 0 2px;

      background: rgba(4,4,6,.46);

      &::-webkit-outer-spin-button,
      &::-webkit-inner-spin-button {
        -webkit-appearance: none;
        margin: 0;
      }
    }
  }
`;

const Input: React.FC<InputProps> = ({ title, min = 0, max = 255, blacklisted = [], defaultValue, clientValue, onChange }) => {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleContainerClick = useCallback(() => {
    if (inputRef.current) {
      inputRef.current.focus();
    }
  }, [inputRef]);

  const isBlacklisted = function (_value: number, blacklisted: number[]) {
    for (var i = 0; i < blacklisted.length; i++) {
      if (blacklisted[i] == _value) {
        return true
      }
    }
    return false
  }

  const normalize = function (_value: number) {
    if (_value < min) {
      _value = max;
    } else if (_value > max) {
      _value = min;
    }

    return _value;
  }

  const checkBlacklisted = function (_value: number, blacklisted: number[], factor: number) {
    if(factor === 0) {
      if(!isBlacklisted(_value, blacklisted)) {
        return normalize(_value);
      }
      factor = _value > defaultValue ? 1 : -1;
    }

    do {
      _value = normalize(_value + factor);
    } while (isBlacklisted(_value, blacklisted))
    return _value;
  };

  const getSafeValue = useCallback(
    (_value: number, factor: number) => {
      let safeValue = _value;

      return checkBlacklisted(safeValue, blacklisted, factor);
    },
    [min, max, blacklisted],
  );

  const handleChange = useCallback(
    (_value: any, factor: number) => {
      let parsedValue;

      if (!_value && _value !== 0) return;

      if (Number.isNaN(_value)) return;

      if (typeof _value === 'string') {
        parsedValue = parseInt(_value);
      } else {
        parsedValue = _value;
      }

      const safeValue = getSafeValue(parsedValue, factor);

      onChange(safeValue);
    },
    [getSafeValue, onChange],
  );

  return (
    <Container onClick={handleContainerClick}>
      <span>
        <small>{title}</small>
        <small>{clientValue} / {max}</small>
      </span>
      <div>
        <button type="button" onClick={() => handleChange(defaultValue, -1)}>
          <FiChevronLeft strokeWidth={5} />
        </button>
        <input type="number" ref={inputRef} value={defaultValue} onChange={e => handleChange(e.target.value, 0)} />
        <button type="button" onClick={() => handleChange(defaultValue, 1)}>
          <FiChevronRight strokeWidth={5} />
        </button>
      </div>
    </Container>
  );
};

export default Input;
