import styled from 'styled-components';

export const Wrapper = styled.div`
  height: 100vh;
  width: 100vw;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  overflow: hidden;
  padding: var(--appearance-gutter-y) var(--appearance-gutter-x);
  pointer-events: none;

  @media (max-width: 900px) {
    align-items: flex-end;
    justify-content: center;
  }
`;

export const Container = styled.div`
  position: relative;
  height: min(96vh, 1040px);
  width: var(--appearance-panel-width);

  display: flex;
  flex-direction: column;
  background: rgba(10, 9, 13, .97);
  border: 1px solid rgba(168, 118, 193, .34);
  box-shadow: 0 24px 70px rgba(0,0,0,.46), inset 0 0 0 1px rgba(255,255,255,.024);
  border-radius: 5px;

  overflow: hidden;
  pointer-events: auto;

  @media (max-width: 900px) {
    height: min(56vh, 620px);
  }

  &::before {
    content: '';
    position: absolute;
    z-index: 4;
    top: 0;
    left: 28px;
    right: 28px;
    height: 1px;
    background: rgba(206, 158, 226, .72);
    pointer-events: none;
  }

  ::-webkit-scrollbar {
    width: 0px;
  }

  ::-webkit-scrollbar-track {
    background: rgba(${props => props.theme.primaryBackground || '0, 0, 0'}, 0.2);
  }

  ::-webkit-scrollbar-thumb {
    background: rgba(${props => props.theme.primaryBackground || '0, 0, 0'}, 0.2);
    border-radius: 3vh;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: rgba(${props => props.theme.primaryBackground || '0, 0, 0'}, 0.2);
  }
`;

export const PanelHeader = styled.header`
  position: relative;
  width: 100%;
  min-height: 126px;
  padding: 23px 30px 22px;
  border-bottom: 1px solid rgba(168, 118, 193, .17);
  background: rgba(31, 23, 36, .38);

  .header-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    margin-bottom: 7px;
  }

  small {
    color: #c4a3d0;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
  }

  .step-count {
    color: #8f8794;
    font-size: 11px;
    font-variant-numeric: tabular-nums;
  }

  h1 {
    color: #f2edf3;
    font-family: Georgia, 'Times New Roman', serif;
    font-size: clamp(27px, 1.8vw, 34px);
    font-weight: 500;
    line-height: 1.06;
  }

  p {
    max-width: 560px;
    margin-top: 8px;
    color: #a59da9;
    font-size: 13px;
    line-height: 1.45;
  }

  @media (max-width: 1440px) {
    padding-right: 18px;
    padding-left: 18px;
  }

  @media (max-width: 1100px) {
    padding-right: 14px;
    padding-left: 14px;
  }

  @media (max-height: 820px) {
    min-height: 104px;
    padding: 16px 22px 15px;

    .header-meta { margin-bottom: 4px; }
    h1 { font-size: 27px; }
    p { margin-top: 5px; font-size: 12px; line-height: 1.35; }
  }

  @media (max-height: 660px) {
    min-height: 88px;
    padding: 12px 18px 11px;

    h1 { font-size: 24px; }
    p { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  }
`;

export const Body = styled.div`
  display: grid;
  grid-template-columns: var(--appearance-nav-width) minmax(0, 1fr);
  min-height: 0;
  flex: 1;
  width: 100%;
`;

export const Navigation = styled.nav`
  padding: 14px 9px;
  border-right: 1px solid rgba(176, 125, 203, .15);
  background: rgba(4, 4, 7, .38);
  display: flex;
  flex-direction: column;
  gap: 5px;
  overflow-y: auto;

  @media (max-height: 820px) {
    padding: 9px 7px;
    gap: 3px;
  }
`;

export const NavButton = styled.button<{ active: boolean }>`
  position: relative;
  width: 100%;
  min-height: 66px;
  padding: 9px 6px;
  border: 1px solid ${props => props.active ? 'rgba(183,128,211,.38)' : 'transparent'};
  background: ${props => props.active ? 'rgba(100,60,121,.26)' : 'transparent'};
  color: ${props => props.active ? '#f4eafb' : '#89828f'};
  border-radius: 3px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  transition: border-color .16s, background .16s, color .16s;

  &::before {
    content: '';
    position: absolute;
    left: -1px;
    top: 13px;
    bottom: 13px;
    width: 2px;
    background: ${props => props.active ? '#b982ce' : 'transparent'};
  }

  svg { font-size: 21px; }
  span { font-size: 11px; font-weight: 700; line-height: 1.2; text-align: center; text-transform: uppercase; }
  &:hover { background: rgba(255,255,255,.025); color: #eee8f1; }

  @media (max-height: 820px) {
    min-height: 52px;
    padding: 6px 4px;
    gap: 4px;

    &::before { top: 10px; bottom: 10px; }
    svg { font-size: 18px; }
    span { font-size: 9px; }
  }

  @media (max-height: 660px) {
    min-height: 45px;
    svg { font-size: 16px; }
  }
`;

export const Content = styled.main`
  min-width: 0;
  min-height: 0;
  overflow-y: auto;
  padding: 22px 25px 28px;
  animation: appearance-content-in .2s ease-out;

  @keyframes appearance-content-in {
    from { opacity: 0; transform: translateY(5px); }
    to { opacity: 1; transform: translateY(0); }
  }

  &::-webkit-scrollbar { width: 4px; }
  &::-webkit-scrollbar-track { background: transparent; }
  &::-webkit-scrollbar-thumb { background: rgba(168,118,193,.34); border-radius: 0; }

  @media (max-width: 1440px) {
    padding-right: 18px;
    padding-left: 18px;
  }

  @media (max-width: 1100px) {
    padding-right: 14px;
    padding-left: 14px;
  }

  @media (max-height: 820px) {
    padding-top: 15px;
    padding-bottom: 18px;
  }

  @media (max-height: 660px) { padding: 12px 16px 14px; }
`;

export const FlexWrapper = styled.div`
  width: 100%;

  display: flex;

  > div {
    & + div {
      margin-left: 10px;
    }
  }
`;
