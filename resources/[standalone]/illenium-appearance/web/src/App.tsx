import { NuiStateProvider } from './hooks/nuiState';
import GlobalStyles from './styles/global';

import Appearance from './components/Appearance';
import { ThemeProvider } from 'styled-components';
import { useState } from 'react';

const obscuriaTheme: any = {
  id: 'obscuria',
  borderRadius: '5px',
  fontColor: '244, 240, 247',
  fontColorHover: '255, 255, 255',
  fontColorSelected: '255, 255, 255',
  fontFamily: 'Inter',
  primaryBackground: '95, 57, 119',
  primaryBackgroundSelected: '112, 68, 142',
  secondaryBackground: '13, 12, 17',
  scaleOnHover: false,
  sectionFontWeight: '600',
  smoothBackgroundTransition: true,
};

const App: React.FC = () => {
  const [currentTheme] = useState(obscuriaTheme);

  return (
    <NuiStateProvider>
      <ThemeProvider theme={currentTheme}>
        <Appearance />
        <GlobalStyles />
      </ThemeProvider>
    </NuiStateProvider>
  );
};

export default App;
