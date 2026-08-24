// Antigravity IDE Custom CSS Preload
// Injects /home/amtia/vscode-custom.css into webContents

const fs = require('fs');
const path = require('path');

const cssPath = '/home/amtia/vscode-custom.css';

try {
  if (fs.existsSync(cssPath)) {
    const customCSS = fs.readFileSync(cssPath, 'utf8');
    
    const injectCSS = () => {
      const { app } = require('electron');
      
      app.on('browser-window-created', (_, window) => {
        window.webContents.on('did-finish-load', () => {
          window.webContents.insertCSS(customCSS).catch(err => {
            console.error('[Antigravity Custom CSS] Failed to inject:', err);
          });
        });
      });
    };
    
    // Execute immediately if app is ready
    const { app } = require('electron');
    if (app.isReady()) {
      app.whenReady().then(injectCSS);
    } else {
      injectCSS();
    }
    
    console.log('[Antigravity Custom CSS] Preload script loaded');
  } else {
    console.warn('[Antigravity Custom CSS] CSS file not found:', cssPath);
  }
} catch (err) {
  console.error('[Antigravity Custom CSS] Preload error:', err);
}
