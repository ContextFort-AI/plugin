/**
 * ContextFort Screenshot Capture
 * Periodic screenshots for audit trail
 */

// Configuration
let config = {
  enabled: false, // Disabled by default (privacy concern)
  interval: 30000, // 30 seconds
  quality: 80, // JPEG quality (0-100)
  maxWidth: 1920, // Max screenshot width
  storageLimit: 100 // Max screenshots to keep
};

let captureTimer = null;
let captureCount = 0;

// Load configuration
chrome.storage.local.get(['screenshotConfig'], (result) => {
  if (result.screenshotConfig) {
    config = { ...config, ...result.screenshotConfig };
  }

  if (config.enabled) {
    startCapture();
  }
});

// Listen for config changes
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.screenshotConfig) {
    config = { ...config, ...changes.screenshotConfig.newValue };

    if (config.enabled) {
      startCapture();
    } else {
      stopCapture();
    }
  }
});

/**
 * Start periodic screenshot capture
 */
function startCapture() {
  if (captureTimer) {
    clearInterval(captureTimer);
  }

  console.log('[ContextFort Screenshots] Starting capture (interval: ' + (config.interval / 1000) + 's)');

  // Capture immediately
  captureScreenshot();

  // Then on interval
  captureTimer = setInterval(captureScreenshot, config.interval);
}

/**
 * Stop screenshot capture
 */
function stopCapture() {
  if (captureTimer) {
    clearInterval(captureTimer);
    captureTimer = null;
  }

  console.log('[ContextFort Screenshots] Stopped capture');
}

/**
 * Capture screenshot
 */
async function captureScreenshot() {
  try {
    // Get current tab ID
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tabs || tabs.length === 0) return;

    const tab = tabs[0];

    // Capture visible tab
    const dataUrl = await chrome.tabs.captureVisibleTab(null, {
      format: 'jpeg',
      quality: config.quality
    });

    // Create screenshot metadata
    const screenshot = {
      id: `screenshot-${Date.now()}-${captureCount++}`,
      timestamp: new Date().toISOString(),
      url: tab.url,
      title: tab.title,
      windowId: tab.windowId,
      tabId: tab.id,
      dataUrl: dataUrl,
      size: dataUrl.length
    };

    // Save to storage
    await saveScreenshot(screenshot);

    // Log to background
    chrome.runtime.sendMessage({
      type: 'SCREENSHOT_CAPTURED',
      screenshot: {
        ...screenshot,
        dataUrl: undefined // Don't send full data in message
      }
    });

  } catch (error) {
    console.error('[ContextFort Screenshots] Error capturing:', error);
  }
}

/**
 * Save screenshot to storage
 */
async function saveScreenshot(screenshot) {
  try {
    // Get existing screenshots
    const result = await chrome.storage.local.get(['screenshots']);
    let screenshots = result.screenshots || [];

    // Add new screenshot
    screenshots.unshift(screenshot);

    // Trim to storage limit
    if (screenshots.length > config.storageLimit) {
      screenshots = screenshots.slice(0, config.storageLimit);
    }

    // Calculate total size
    const totalSize = screenshots.reduce((sum, s) => sum + (s.size || 0), 0);
    const totalSizeMB = (totalSize / (1024 * 1024)).toFixed(2);

    console.log(`[ContextFort Screenshots] Saved (${screenshots.length} total, ${totalSizeMB}MB)`);

    // Save back to storage
    await chrome.storage.local.set({ screenshots });

  } catch (error) {
    // Storage quota exceeded - remove oldest screenshots
    if (error.message && error.message.includes('QUOTA')) {
      console.warn('[ContextFort Screenshots] Storage quota exceeded, reducing limit');

      const result = await chrome.storage.local.get(['screenshots']);
      let screenshots = result.screenshots || [];

      // Keep only half
      screenshots = screenshots.slice(0, Math.floor(screenshots.length / 2));

      await chrome.storage.local.set({ screenshots });
    } else {
      throw error;
    }
  }
}

/**
 * Export screenshots as JSON
 */
async function exportScreenshots() {
  const result = await chrome.storage.local.get(['screenshots']);
  return result.screenshots || [];
}

/**
 * Clear all screenshots
 */
async function clearScreenshots() {
  await chrome.storage.local.set({ screenshots: [] });
  captureCount = 0;
}

// Message handler for export/clear commands
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'EXPORT_SCREENSHOTS') {
    exportScreenshots().then(screenshots => {
      sendResponse({ screenshots });
    });
    return true;
  }

  if (message.type === 'CLEAR_SCREENSHOTS') {
    clearScreenshots().then(() => {
      sendResponse({ success: true });
    });
    return true;
  }
});

// Note: Screenshot capture is DISABLED by default due to privacy concerns
// Enterprise admins must explicitly enable via screenshotConfig in chrome.storage
console.log('[ContextFort Screenshots] Module loaded (capture disabled by default)');
