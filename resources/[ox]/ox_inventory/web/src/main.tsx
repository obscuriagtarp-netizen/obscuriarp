import React from 'react';
import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { DndProvider } from 'react-dnd';
import { TouchBackend } from 'react-dnd-touch-backend';
import { store } from './store';
import App from './App';
import './index.scss';
import '../rpg-v2.css';
import { ItemNotificationsProvider } from './components/utils/ItemNotifications';
import { isEnvBrowser } from './utils/misc';

const root = document.getElementById('root');

if (isEnvBrowser()) {
  const previewEnabled = new URLSearchParams(window.location.search).has('preview');

  if (previewEnabled) {
    document.body.classList.add('inventory-preview');
    document.documentElement.style.backgroundColor = '#55585d';
    document.body.style.backgroundColor = '#55585d';
    root!.style.backgroundColor = '#55585d';
  } else {
    root!.style.backgroundColor = '#0b0c10';
  }
}

createRoot(root!).render(
  <React.StrictMode>
    <Provider store={store}>
      <DndProvider backend={TouchBackend} options={{ enableMouseEvents: true }}>
        <ItemNotificationsProvider>
          <App />
        </ItemNotificationsProvider>
      </DndProvider>
    </Provider>
  </React.StrictMode>
);
