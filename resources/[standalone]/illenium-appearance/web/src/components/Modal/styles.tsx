import styled from 'styled-components';

export const Wrapper = styled.div`
  width: 100vw;
  height: 100vh;

  position: fixed;

  left: 0;
  top: 0;

  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;

  user-select: none;

  font-size: 20px;
  color: rgba(255, 255, 255, 1);
  text-align: center;
  text-shadow: none;

  background: rgba(3, 3, 5, .66);
  z-index: 100;

  > p, > span, > div { width: min(420px, calc(100vw - 32px)); }
  > p {
    padding: 25px 26px 8px;
    border: 1px solid rgba(180,126,207,.32);
    border-bottom: 0;
    border-radius: 5px 5px 0 0;
    background: rgba(11,10,15,.98);
    font-family: Georgia, serif;
    font-weight: 600;
  }

  span {
    padding: 4px 26px 24px;
    border-left: 1px solid rgba(180,126,207,.32);
    border-right: 1px solid rgba(180,126,207,.32);
    color: #aaa2ae;
    background: rgba(11,10,15,.98);
    font-size: 12px;
    line-height: 1.45;
    opacity: 1;
  }
`;

export const Buttons = styled.div`
  display: flex;
  justify-content: center;
  align-items: center;

  margin-top: 0;
  padding: 0 26px 24px;
  gap: 8px;
  border: 1px solid rgba(180,126,207,.32);
  border-top: 0;
  border-radius: 0 0 5px 5px;
  background: rgba(11,10,15,.98);

  button {
    height: 40px;
    flex: 1;
    margin: 0;
    border-radius: ${props => props.theme.borderRadius || '0px'};

    display: flex;
    justify-content: center;
    align-items: center;

    color: rgba(${props => props.theme.fontColor || '255, 255, 255'}, 1);;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;

    opacity: 0.8;
    transition: all 0.2s;

    background: rgba(255,255,255,.025);
    border: 1px solid rgba(255,255,255,.09);

    &:hover {
      transform: none;
      opacity: 1;
      text-shadow: none;
      border-color: rgba(185,127,214,.5);
      background: rgba(103,61,129,.4);
    }
  }
`;
