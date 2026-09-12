import { createGlobalStyle } from 'styled-components';

export default createGlobalStyle<{theme: any}>`
  @font-face {
    font-family: 'TT Commons';
    src: url('./fonts/tt-commons.woff') format('woff');
    font-style: normal;
    font-display: swap;
  }

  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    outline: 0;
    font-family: 'TT Commons', '${props => props.theme.fontFamily}', Arial, sans-serif;
    letter-spacing: 0;
  }

  :root {
    --appearance-gutter-x: clamp(14px, 1.45vw, 28px);
    --appearance-gutter-y: clamp(10px, 1.6vh, 20px);
    --appearance-panel-width: clamp(620px, 35vw, 680px);
    --appearance-nav-width: 108px;
  }

  @media (max-width: 1600px) {
    :root {
      --appearance-panel-width: clamp(520px, 38vw, 610px);
      --appearance-nav-width: 102px;
    }
  }

  @media (max-width: 1280px) {
    :root {
      --appearance-panel-width: clamp(480px, 40vw, 520px);
      --appearance-nav-width: 92px;
    }
  }

  @media (max-width: 1100px) {
    :root {
      --appearance-panel-width: clamp(420px, 43vw, 450px);
      --appearance-gutter-x: 12px;
      --appearance-nav-width: 86px;
    }
  }

  @media (max-width: 900px) {
    :root {
      --appearance-panel-width: calc(100vw - 20px);
      --appearance-gutter-x: 10px;
      --appearance-nav-width: 84px;
    }
  }
  
  body {
    background: transparent;
    -webkit-font-smoothing: antialiased;
    overflow: hidden;
  }

  body.browser-preview { background: #302d35; }

  #root { width: 100vw; height: 100vh; }

  ::selection { background: rgba(142, 86, 180, .38); color: #fff; }

  ::-webkit-scrollbar { width: 5px; height: 5px; }
  ::-webkit-scrollbar-track { background: rgba(255,255,255,.025); }
  ::-webkit-scrollbar-thumb { background: rgba(151, 103, 180, .48); border-radius: 4px; }

  button {
    cursor: pointer;
    outline: 0;
  }
`;
