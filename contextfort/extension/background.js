/**
 * ContextFort Stage 1 Extension - Background Service Worker
 * Monitors AI agent activity in isolated Chrome instances
 */

import { DashboardConnector } from './dashboard-connector.js';

const dashboard = new DashboardConnector();

// Extension initialization
chrome.runtime.onInstalled.addListener((details) => {
  console.log('[ContextFort] Extension installed:', details.reason);
});

// Monitor tab navigation
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    console.log('[ContextFort] Navigation:', tab.url);
    dashboard.sendNavigation(tab.url);

    // Take screenshot after navigation
    setTimeout(() => {
      captureScreenshot(tab.url);
    }, 1000);
  }
});

// Capture screenshot
async function captureScreenshot(url) {
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab(null, {
      format: 'png',
      quality: 80
    });

    console.log('[ContextFort] Screenshot captured for:', url);
    await dashboard.sendScreenshot(url, dataUrl);
  } catch (error) {
    console.warn('[ContextFort] Screenshot capture failed:', error);
  }
}

// Listen for messages from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'agent_detected') {
    console.log('[ContextFort] Agent detected:', message.source);
    dashboard.sendAgentDetected(message.source);
  } else if (message.type === 'action_blocked') {
    console.log('[ContextFort] Action blocked:', message.action);
    dashboard.sendActionBlocked(message.action, message.reason);
  }
});

console.log('[ContextFort] Background service worker ready');
