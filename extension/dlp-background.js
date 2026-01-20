/**
 * ContextFort DLP Background Logger
 * Logs clipboard events to storage for SIEM export
 */

// Event storage key
const DLP_EVENTS_KEY = 'dlp_events';
const DLP_EVENTS_MAX = 1000; // Keep last 1000 events

/**
 * Log DLP event to storage
 */
async function logDlpEvent(event) {
  try {
    // Get existing events
    const result = await chrome.storage.local.get([DLP_EVENTS_KEY]);
    let events = result[DLP_EVENTS_KEY] || [];

    // Add new event with full context
    const logEntry = {
      id: `dlp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: event.timestamp || new Date().toISOString(),
      event_type: 'dlp_clipboard',
      action: event.eventType, // copy, paste, cut
      result: event.action, // blocked, allowed
      url: event.url,
      title: event.title,
      findings: event.findings,
      severity: getMaxSeverity(event.findings),
      patterns_detected: event.findings.map(f => f.name).join(', ')
    };

    // Add to beginning of array
    events.unshift(logEntry);

    // Trim to max size
    if (events.length > DLP_EVENTS_MAX) {
      events = events.slice(0, DLP_EVENTS_MAX);
    }

    // Save back to storage
    await chrome.storage.local.set({ [DLP_EVENTS_KEY]: events });

    // Also log to console for debugging
    console.log('[ContextFort DLP]', logEntry);

    // Write to JSONL file via file system API if available
    // (This requires user permission and is optional)
    await exportToJsonl(logEntry);

  } catch (error) {
    console.error('[ContextFort DLP] Error logging event:', error);
  }
}

/**
 * Get maximum severity from findings
 */
function getMaxSeverity(findings) {
  const severityOrder = ['critical', 'high', 'medium', 'low'];

  for (const severity of severityOrder) {
    if (findings.some(f => f.severity === severity)) {
      return severity;
    }
  }

  return 'low';
}

/**
 * Export event to JSONL file (if file system access granted)
 */
async function exportToJsonl(logEntry) {
  // Check if we have file system access
  const result = await chrome.storage.local.get(['dlp_log_file_handle']);

  if (result.dlp_log_file_handle) {
    try {
      // This is a placeholder - actual file system API usage would go here
      // For now, events are only stored in chrome.storage
      console.log('[ContextFort DLP] Would export to JSONL:', logEntry);
    } catch (error) {
      console.error('[ContextFort DLP] Error exporting to JSONL:', error);
    }
  }
}

/**
 * Get DLP events for export
 */
async function getDlpEvents(limit = 100) {
  const result = await chrome.storage.local.get([DLP_EVENTS_KEY]);
  const events = result[DLP_EVENTS_KEY] || [];
  return events.slice(0, limit);
}

/**
 * Clear old DLP events
 */
async function clearDlpEvents() {
  await chrome.storage.local.set({ [DLP_EVENTS_KEY]: [] });
}

/**
 * Get DLP statistics
 */
async function getDlpStats() {
  const result = await chrome.storage.local.get([DLP_EVENTS_KEY]);
  const events = result[DLP_EVENTS_KEY] || [];

  const stats = {
    total_events: events.length,
    blocked: events.filter(e => e.result === 'blocked').length,
    allowed: events.filter(e => e.result === 'allowed').length,
    by_severity: {
      critical: events.filter(e => e.severity === 'critical').length,
      high: events.filter(e => e.severity === 'high').length,
      medium: events.filter(e => e.severity === 'medium').length,
      low: events.filter(e => e.severity === 'low').length
    },
    by_action: {
      copy: events.filter(e => e.action === 'copy').length,
      paste: events.filter(e => e.action === 'paste').length,
      cut: events.filter(e => e.action === 'cut').length
    },
    last_24h: events.filter(e => {
      const eventTime = new Date(e.timestamp);
      const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      return eventTime > dayAgo;
    }).length
  };

  return stats;
}

// Listen for DLP events from content script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'DLP_EVENT') {
    logDlpEvent(message);
    sendResponse({ success: true });
    return true;
  }

  if (message.type === 'GET_DLP_EVENTS') {
    getDlpEvents(message.limit).then(events => {
      sendResponse({ events });
    });
    return true;
  }

  if (message.type === 'GET_DLP_STATS') {
    getDlpStats().then(stats => {
      sendResponse({ stats });
    });
    return true;
  }

  if (message.type === 'CLEAR_DLP_EVENTS') {
    clearDlpEvents().then(() => {
      sendResponse({ success: true });
    });
    return true;
  }
});

console.log('[ContextFort DLP] Background logger initialized');
