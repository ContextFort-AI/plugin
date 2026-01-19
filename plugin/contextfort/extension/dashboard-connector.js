/**
 * ContextFort Dashboard Connector
 * Sends monitoring data to local dashboard API
 */

const DASHBOARD_URL = 'http://localhost:8080';

class DashboardConnector {
  constructor() {
    this.sessionId = null;
    this.connected = false;
    this.init();
  }

  async init() {
    // Get session ID from storage or environment
    const stored = await chrome.storage.local.get(['contextfort_session_id']);

    if (stored.contextfort_session_id) {
      this.sessionId = stored.contextfort_session_id;
    } else {
      // Try to detect from profile path
      this.sessionId = await this.detectSessionId();

      if (this.sessionId) {
        await chrome.storage.local.set({ contextfort_session_id: this.sessionId });
      }
    }

    console.log('[ContextFort] Session ID:', this.sessionId);

    // Test connection
    await this.testConnection();
  }

  async detectSessionId() {
    // Try to read session ID from file system (via native messaging if available)
    // For now, use timestamp-based fallback
    return Date.now().toString();
  }

  async testConnection() {
    try {
      const response = await fetch(`${DASHBOARD_URL}/health`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });

      this.connected = response.ok;
      console.log('[ContextFort] Dashboard connection:', this.connected ? 'OK' : 'FAILED');
    } catch (error) {
      this.connected = false;
      console.warn('[ContextFort] Dashboard not available:', error.message);
    }
  }

  async sendEvent(eventType, data) {
    if (!this.sessionId) {
      console.warn('[ContextFort] No session ID, event not sent');
      return;
    }

    const event = {
      sessionId: this.sessionId,
      type: eventType,
      timestamp: Date.now(),
      data
    };

    try {
      const response = await fetch(`${DASHBOARD_URL}/api/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(event)
      });

      if (!response.ok) {
        console.warn('[ContextFort] Event send failed:', response.status);
      }
    } catch (error) {
      // Dashboard might not be running, fail silently
      if (!this.connected) {
        // Only warn once per session
        console.debug('[ContextFort] Dashboard offline, events queued locally');
      }
    }
  }

  async sendNavigation(url) {
    await this.sendEvent('navigation', { url });
  }

  async sendScreenshot(url, dataUrl) {
    await this.sendEvent('screenshot', { url, screenshot: dataUrl });
  }

  async sendAgentDetected(source) {
    await this.sendEvent('agent_detected', { source });
  }

  async sendAgentStopped(reason) {
    await this.sendEvent('agent_stopped', { reason });
  }

  async sendActionBlocked(action, reason) {
    await this.sendEvent('action_blocked', { action, reason });
  }
}

// Export for use in background.js
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { DashboardConnector };
}
